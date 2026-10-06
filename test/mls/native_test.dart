import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import '../support/native_probe.dart';

MlsAuthenticationRequest _authenticationRequest() => MlsAuthenticationRequest(
  serviceOrigin: 'https://api.example.test',
  challenge: '0x${List.filled(32, '22').join()}',
  expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 120000,
  method: 'POST',
  requestTarget: '/auth/session?scope=chat',
  bodyBytes: [1, 2, 3],
);

void main() {
  final skip = chatSdkNativeSkipReason();
  test('KeyPackage只在已持久化的同一MLS身份上生成', () async {
    final root = await Directory.systemTemp.createTemp(
      'tatachat_native_identity_',
    );
    addTearDown(() => root.delete(recursive: true));
    final store = MlsStateStore(
      Directory(await root.resolveSymbolicLinks()),
      ownerUserId: 'user-a',
    );
    final identity = await store.initializeIdentity();
    final crypto = NativeMlsCrypto(identity: identity, stateStore: store);
    final package = await crypto.createKeyPackage(identity, lastResort: true);
    final again = await crypto.createKeyPackage(
      await store.readIdentity(),
      lastResort: true,
    );
    expect(package.keyPackageHex, again.keyPackageHex);
    expect(package.lastResort, isTrue);
    expect(
      package.notAfterMillis - package.notBeforeMillis,
      (84 * 24 + 1) * 60 * 60 * 1000,
    );
    expect(identity.publicKey, matches(RegExp(r'^0x[0-9a-f]{64}$')));
    expect((await store.readIdentity()).deviceId, identity.deviceId);
    await expectLater(
      store.initializeIdentity(),
      throwsA(isA<MlsNativeException>()),
    );
    final wrongOwner = MlsStateStore(store.directory, ownerUserId: 'other');
    await expectLater(
      wrongOwner.readIdentity(),
      throwsA(isA<MlsNativeException>()),
    );
  }, skip: skip);

  test('真实FFI认证复用MLS身份，重建后签名一致且不改快照', () async {
    final root = await Directory.systemTemp.createTemp('tatachat_native_auth_');
    addTearDown(() => root.delete(recursive: true));
    final directory = Directory(await root.resolveSymbolicLinks());
    final store = MlsStateStore(directory, ownerUserId: 'user-a');
    final identity = await store.initializeIdentity();
    final request = _authenticationRequest();
    final account = '0x${List.filled(32, '11').join()}';
    final snapshot = File('${directory.path}/state.bin');
    final before = await snapshot.readAsBytes();
    final proof = await store.signAuthentication(
      accountId: account,
      bindingRevision: 1,
      request: request,
    );
    store.dispose();
    final restarted = MlsStateStore(directory, ownerUserId: 'user-a');
    final again = await restarted.signAuthentication(
      accountId: account,
      bindingRevision: 1,
      request: request,
    );
    expect(again.toJson(), proof.toJson());
    expect(proof.userId, identity.userId);
    expect(proof.deviceId, identity.deviceId);
    expect(proof.publicKey, identity.publicKey);
    expect(
      proof.toJson().keys,
      unorderedEquals([
        'user_id',
        'device_id',
        'public_key',
        'account_id',
        'binding_revision',
        'service_origin',
        'challenge',
        'expires_at_millis',
        'method',
        'request_target',
        'body_sha256',
        'signature',
      ]),
    );
    expect(proof.signature, matches(RegExp(r'^0x[0-9a-f]{128}$')));
    expect(await snapshot.readAsBytes(), before);
    final wrongOwner = MlsStateStore(directory, ownerUserId: 'other');
    await expectLater(
      wrongOwner.signAuthentication(
        accountId: account,
        bindingRevision: 1,
        request: request,
      ),
      throwsA(isA<MlsNativeException>()),
    );
  }, skip: skip);

  test('认证缺状态或损坏时失败，禁止补身份或清空恢复', () async {
    final root = await Directory.systemTemp.createTemp(
      'tatachat_native_auth_bad_',
    );
    addTearDown(() => root.delete(recursive: true));
    final directory = Directory(await root.resolveSymbolicLinks());
    final store = MlsStateStore(directory, ownerUserId: 'user-a');
    await store.initializeIdentity();
    final snapshot = File('${directory.path}/state.bin');
    final request = _authenticationRequest();
    Future<MlsAuthenticationProof> sign() => store.signAuthentication(
      accountId: '0x${List.filled(32, '11').join()}',
      bindingRevision: 1,
      request: request,
    );
    await snapshot.writeAsString('synthetic corrupt state');
    await expectLater(sign(), throwsA(isA<MlsNativeException>()));
    expect(await snapshot.readAsString(), 'synthetic corrupt state');
    await snapshot.delete();
    await expectLater(sign(), throwsA(isA<MlsNativeException>()));
    expect(await snapshot.exists(), isFalse);
  }, skip: skip);
  test('同CID三设备移除只影响指定叶子，伪造KeyPackage登记身份拒绝', () async {
    final temporary = await Directory.systemTemp.createTemp('mls_leaf_');
    final root = Directory(await temporary.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    final devices = <ChatDevice>[], cryptos = <NativeMlsCrypto>[];
    for (var index = 0; index < 3; index++) {
      final directory = await Directory('${root.path}/$index').create();
      final store = MlsStateStore(directory, ownerUserId: 'CID-A');
      final identity = await store.initializeIdentity();
      devices.add(identity);
      cryptos.add(NativeMlsCrypto(identity: identity, stateStore: store));
    }
    final b = await cryptos[1].createKeyPackage(devices[1], lastResort: true);
    final c = await cryptos[2].createKeyPackage(devices[2], lastResort: true);
    await cryptos[0].withMessage(
      'create',
      () => cryptos[0].createGroup('exact-leaves'),
    );
    final forged = MlsKeyPackage(
      userId: 'CID-A',
      deviceId: devices[1].deviceId,
      keyPackageRef: c.keyPackageRef,
      keyPackageBytes: c.keyPackageBytes,
      cipherSuite: c.cipherSuite,
      notBeforeMillis: c.notBeforeMillis,
      notAfterMillis: c.notAfterMillis,
      lastResort: true,
    );
    await expectLater(
      cryptos[0].withMessage(
        'forged',
        () => cryptos[0].addMembers('exact-leaves', [forged]),
      ),
      throwsA(isA<MlsNativeException>()),
    );
    expect((await cryptos[0].groupState('exact-leaves')).memberCount, 1);
    final added = await cryptos[0].withMessage(
      'add',
      () => cryptos[0].addMembers('exact-leaves', [b, c]),
    );
    for (var index = 1; index < 3; index++) {
      await cryptos[index].withMessage(
        'welcome',
        () => cryptos[index].groupProcess(added.welcome!),
      );
    }
    final target = 'CID-A:${devices[1].deviceId}';
    await expectLater(
      cryptos[0].withMessage(
        'duplicate-remove',
        () => cryptos[0].removeMembers('exact-leaves', [target, target]),
      ),
      throwsA(isA<MlsNativeException>()),
    );
    await expectLater(
      cryptos[0].withMessage(
        'unknown-remove',
        () => cryptos[0].removeMembers('exact-leaves', [
          target,
          'CID-A:${'00' * 32}',
        ]),
      ),
      throwsA(isA<MlsNativeException>()),
    );
    expect((await cryptos[0].groupState('exact-leaves')).memberCount, 3);
    final removed = await cryptos[0].withMessage(
      'remove',
      () => cryptos[0].removeMembers('exact-leaves', [target]),
    );
    expect(removed.removedMemberIdentities, [target]);
    final accepted = await cryptos[2].withMessage(
      'commit',
      () => cryptos[2].groupProcess(removed.commit),
    );
    expect(accepted.selfRemoved, false);
    expect(accepted.senderMemberIdentity, 'CID-A:${devices[0].deviceId}');
    expect(
      (await cryptos[2].groupState('exact-leaves')).memberIdentities,
      unorderedEquals(
        [
          devices[0],
          devices[2],
        ].map((identity) => 'CID-A:${identity.deviceId}'),
      ),
    );
  }, skip: skip);
}
