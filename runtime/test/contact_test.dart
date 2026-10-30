import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_mls/mls_boundary.dart';
import 'package:tatachat_mls/mls_native.dart';
import 'package:tatachat_mls/mls_state_store.dart';
import 'package:tatachat_runtime/chat_runtime.dart';
import 'package:tatachat_testing/isar.dart';
import 'package:tatachat_testing/native.dart';

class _ContactHost implements ChatRuntimeHost {
  ChatRuntimeAccount account = const ChatRuntimeAccount(
    hostIndex: 1,
    bindingScope:
        '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    userId: 'user-a',
    bindingRevision: 1,
    accountId:
        '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
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
  requireChatSdkNative();
  // 公共运行时真实调用与应用集成共享入口，避免只验证内部引擎而漏接能力。
  for (final change in [false, true]) {
    test('公开通讯录入口复用已有MLS身份，账户${change ? '变化拒绝晚回' : '不变完成同步'}', () async {
      final temp = await Directory.systemTemp.createTemp('contact_runtime_');
      final root = Directory(await temp.resolveSymbolicLinks());
      addTearDown(() => root.delete(recursive: true));
      final initial = MlsStateStore(root, ownerUserId: 'user-a');
      final identity = await initial.prepareIdentity();
      final host = _ContactHost(), relay = TestContactRelay();
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
    });
  }
  test('通讯录签读不补密钥，统一离线自动准备后复用同一设备同步', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'mls_contact_empty_',
    );
    final root = Directory(
      await (await Directory(
        '${temporary.path}/mls',
      ).create()).resolveSymbolicLinks(),
    );
    addTearDown(() => temporary.delete(recursive: true));
    final host = _ContactHost();
    final runtime = ChatSdk(
      host: host,
      documentsDirectoryProvider: () async => temporary,
      stateStoreFactory: (user) async => MlsStateStore(root, ownerUserId: user),
    );
    addTearDown(runtime.close);
    var exchanges = 0;
    final relay = TestContactRelay();
    ChatDevice? identity;
    Future<List<List<int>>> sync() => runtime.synchronizeContacts(
      exchange: (request) async {
        exchanges++;
        return relay.call(identity!.deviceId, request);
      },
      snapshots: () async => [utf8.encode('synthetic snapshot')],
      apply: (_) async {},
    );
    await expectLater(sync(), throwsA(isA<MlsNativeException>()));
    expect(exchanges, 0);
    expect(await File('${root.path}/state.bin').exists(), isFalse);
    identity = await runtime.readLocalMlsIdentity();
    expect(await sync(), [utf8.encode('synthetic snapshot')]);
    expect((await runtime.readLocalMlsIdentity()).deviceId, identity.deviceId);
    expect(exchanges, greaterThan(0));
  });
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
  });
}

