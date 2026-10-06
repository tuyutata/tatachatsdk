import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import '../support/native_probe.dart';

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
}
