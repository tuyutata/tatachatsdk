import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_mls/mls_boundary.dart';
import 'package:tatachat_mls/mls_contact_sync.dart';
import 'package:tatachat_mls/mls_native.dart';
import 'package:tatachat_mls/mls_state_store.dart';
import 'package:tatachat_testing/native.dart';

void main() {

  requireChatSdkNative();

  test('同CID真实MLS Welcome、快照、丢回执重启和精确叶子移除', () async {
    final temporary = await Directory.systemTemp.createTemp('contact_mls_');
    final root = Directory(await temporary.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    final relay = TestContactRelay();
    final devices = <ChatDevice>[];
    final stores = <MlsStateStore>[];
    final cryptos = <NativeMlsCrypto>[];
    for (var index = 0; index < 3; index++) {
      final directory = await Directory('${root.path}/$index').create();
      final store = MlsStateStore(directory, ownerUserId: 'CID-A');
      final identity = await store.prepareIdentity();
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
  });
}

