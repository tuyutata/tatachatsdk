import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import '../support/isar_test_env.dart';
import '../support/native_probe.dart';

class _Relay {
  final group = '11' * 16;
  final eligible = <String>{};
  final packages = <String, String>{};
  final queues = <String, List<Map<String, dynamic>>>{};
  final receipts = <String, Map<String, Object?>>{};
  List<String> members = [];
  Map<String, dynamic>? pending;
  String? creator;
  int revision = 0;
  int serial = 0;
  bool loseCommitReply = false;
  String? rejectNextAckFor;
  bool busy = false;
  Future<Map<String, dynamic>> call(
    String device,
    Map<String, Object?> request,
  ) async {
    switch (request['action']) {
      case 'publish':
        creator ??= device;
        eligible.add(device);
        packages[device] = request['key_package'] as String;
        return {'ok': true};
      case 'state':
        return {
          'ok': true,
          'group_id': group,
          'group_revision': revision,
          'creator_device_id': creator,
          'member_device_ids': members.toList(),
          'eligible_device_ids': eligible.toList(),
          'key_packages': packages.entries
              .where((entry) => eligible.contains(entry.key))
              .map(
                (entry) => {'device_id': entry.key, 'key_package': entry.value},
              )
              .toList(),
          'messages': List<Map<String, dynamic>>.from(queues[device] ?? []),
          'pending': pending?['device'] == device ? pending : null,
          'busy': busy || (pending != null && pending?['device'] != device),
        };
      case 'reserve':
        if (pending != null && pending!['device'] != device) {
          throw StateError('busy');
        }
        pending ??= {
          'operation_id': (++serial).toRadixString(16).padLeft(32, '0'),
          'operation_kind': request['operation_kind'],
          'group_revision': revision,
          'target_device_ids': request['target_device_ids'],
          'device': device,
        };
        return {'ok': true, ...pending!};
      case 'commit':
        final operation = request['operation_id'] as String;
        if (!receipts.containsKey(operation)) {
          if (pending?['operation_id'] != operation) {
            throw StateError('conflict');
          }
          receipts[operation] = Map<String, Object?>.from(request);
          revision++;
          members = (request['member_device_ids'] as List).cast<String>();
          var index = 0;
          for (final value in request['messages'] as List) {
            final message = (value as Map).cast<String, dynamic>();
            for (final recipient
                in (message['device_ids'] as List).cast<String>()) {
              (queues[recipient] ??= []).add({
                'operation_id': operation,
                'message_type': message['message_type'],
                'mls_message': message['mls_message'],
                'sender_device_id': device,
                'sequence': revision * 2 + index,
              });
            }
            index++;
          }
          pending = null;
        }
        if (loseCommitReply) {
          loseCommitReply = false;
          throw StateError('synthetic lost reply');
        }
        return {'ok': true, 'group_revision': revision};
      case 'ack':
        if (rejectNextAckFor == device &&
            request['message_type'] == 'application') {
          rejectNextAckFor = null;
          throw StateError('synthetic ack not delivered');
        }
        queues[device]?.removeWhere(
          (message) =>
              message['operation_id'] == request['operation_id'] &&
              message['message_type'] == request['message_type'],
        );
        return {'ok': true};
    }
    throw StateError('unexpected action');
  }
}

class _ContactHost implements ChatRuntimeHost {
  ChatRuntimeAccount account = const ChatRuntimeAccount(
    hostIndex: 1,
    bindingScope: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    userId: 'user-a',
    bindingRevision: 1,
    accountId: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    displayName: 'owner',
  );
  @override
  Future<ChatRuntimeAccount?> currentAccount({
    String? expectedAccountId,
  }) async => account;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('通讯录不得调用聊天网络或权益');
}

void main() {
  useIsolatedChatIsar();
  final skip = chatSdkNativeSkipReason();
  // 公共运行时真实调用与应用集成共享入口，避免只验证内部引擎而漏接能力。
  for (final change in [false, true]) {
    test('公开通讯录入口复用已有MLS身份，账户${change ? '变化拒绝晚回' : '不变完成同步'}', () async {
      final temp = await Directory.systemTemp.createTemp('contact_runtime_');
      final root = Directory(await temp.resolveSymbolicLinks());
      addTearDown(() => root.delete(recursive: true));
      final initial = MlsStateStore(root, ownerUserId: 'user-a');
      final identity = await initial.initializeIdentity();
      final host = _ContactHost(), relay = _Relay();
      final runtime = ChatSdk(
        host: host,
        documentsDirectoryProvider: () async => root,
        stateStoreFactory: (_) async =>
            MlsStateStore(root, ownerUserId: 'user-a'),
      );
      var requests = 0, applied = 0, snapshotsRead = 0;
      final payload = utf8.encode('snapshot');
      Future<List<List<int>>> synchronize() => runtime.synchronizeContacts(
        exchange: (request) async {
          requests++;
          final result = await relay.call(identity.deviceId, request);
          if (change) {
            host.account = const ChatRuntimeAccount(
              hostIndex: 1,
              bindingScope: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              userId: 'other-user',
              bindingRevision: 1,
              accountId: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
              displayName: 'other',
            );
          }
          return result;
        },
        snapshots: () async {
          snapshotsRead++;
          return [payload];
        },
        apply: (_) async {
          applied++;
        },
      );
      if (change) {
        await expectLater(synchronize(), throwsStateError);
        expect(requests, 1);
        expect(snapshotsRead, 0);
      } else {
        expect(await synchronize(), [payload]);
        expect(snapshotsRead, 1);
        expect(relay.members, [identity.deviceId]);
        expect((await initial.readIdentity()).publicKey, identity.publicKey);
      }
      expect(applied, 0);
      await runtime.close();
      final before = requests;
      await expectLater(synchronize(), throwsStateError);
      expect(requests, before);
    }, skip: skip);
  }
  test('公开通讯录入口拒绝错误所有者，不联网且不补建身份', () async {
    final temp = await Directory.systemTemp.createTemp('contact_wrong_owner_');
    final root = Directory(await temp.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    final runtime = ChatSdk(
      host: _ContactHost(),
      documentsDirectoryProvider: () async => root,
      stateStoreFactory: (_) async =>
          MlsStateStore(root, ownerUserId: 'other-user'),
    );
    await expectLater(
      runtime.synchronizeContacts(
        exchange: (_) async => throw StateError('不应联网'),
        snapshots: () async => [],
        apply: (_) async => fail('不应应用业务数据'),
      ),
      throwsStateError,
    );
    expect(File('${root.path}/state.bin').existsSync(), false);
    await runtime.close();
  }, skip: skip);

  test('同CID真实MLS Welcome、快照、丢回执重启和精确叶子移除', () async {
    final temporary = await Directory.systemTemp.createTemp('contact_mls_');
    final root = Directory(await temporary.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    final relay = _Relay();
    final devices = <ChatDevice>[];
    final stores = <MlsStateStore>[];
    final cryptos = <NativeMlsCrypto>[];
    for (var index = 0; index < 3; index++) {
      final directory = await Directory('${root.path}/$index').create();
      final store = MlsStateStore(directory, ownerUserId: 'CID-A');
      final identity = await store.initializeIdentity();
      stores.add(store);
      devices.add(identity);
      cryptos.add(NativeMlsCrypto(identity: identity, stateStore: store));
    }
    final received = [<String>[], <String>[], <String>[]];
    Future<List<List<int>>> sync(int index, {bool current = true}) =>
        MlsContactSync(
          identity: devices[index],
          crypto: cryptos[index],
          exchange: (request) => relay.call(devices[index].deviceId, request),
          requireCurrent: () async {
            if (!current) throw StateError('owner changed');
          },
        ).synchronize(
          snapshots: () async => [utf8.encode('snapshot-$index')],
          apply: (payload) async {
            received[index].add(utf8.decode(payload));
          },
        );
    await sync(0);
    await expectLater(sync(1), throwsStateError);
    await expectLater(sync(2), throwsStateError);
    relay.loseCommitReply = true;
    await expectLater(sync(0), throwsStateError);
    final identityBefore = await stores[0].readIdentity();
    cryptos[0] = NativeMlsCrypto(
      identity: identityBefore,
      stateStore: stores[0],
    );
    await sync(0);
    relay.rejectNextAckFor = devices[1].deviceId;
    await expectLater(sync(1), throwsStateError);
    cryptos[1] = NativeMlsCrypto(
      identity: await stores[1].readIdentity(),
      stateStore: stores[1],
    );
    await sync(1);
    await sync(2);
    expect(received[1], contains('snapshot-0'));
    expect(
      received[1].where((payload) => payload == 'snapshot-0'),
      hasLength(1),
    );
    expect(received[2], contains('snapshot-0'));
    expect(
      relay.members,
      containsAll(devices.map((device) => device.deviceId)),
    );
    relay.eligible.remove(devices[1].deviceId);
    relay.packages.remove(devices[1].deviceId);
    await sync(0);
    await sync(2);
    expect(
      (await cryptos[0].groupState(relay.group)).memberIdentities,
      unorderedEquals(
        [devices[0], devices[2]].map((device) => 'CID-A:${device.deviceId}'),
      ),
    );
    expect(
      (await cryptos[2].groupState(relay.group)).memberIdentities,
      unorderedEquals(
        [devices[0], devices[2]].map((device) => 'CID-A:${device.deviceId}'),
      ),
    );
    expect(
      (await stores[0].readIdentity()).publicKey,
      identityBefore.publicKey,
    );
    final calls = relay.receipts.length;
    await expectLater(sync(0, current: false), throwsStateError);
    expect(relay.receipts.length, calls);
  }, skip: skip);
}
