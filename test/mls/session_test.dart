import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import '../support/native_probe.dart';

void main() {
  final skip = chatSdkNativeSkipReason();
  test('早到MLS密文在同一原生状态保存、去重及校验所有者', () async {
    final root = await Directory.systemTemp.createTemp('tatachat_pending_');
    addTearDown(() => root.delete(recursive: true));
    final store = MlsStateStore(
      Directory(await root.resolveSymbolicLinks()),
      ownerUserId: 'user',
    );
    final identity = await store.initializeIdentity();
    const wire = MlsWireMessage(wireBytes: [1, 2], conversationId: 'group');
    await store.queuePendingInbound(wire);
    await store.queuePendingInbound(wire);
    expect((await store.readPendingInbound()).single.wireHex, wire.wireHex);
    store.dispose();
    expect((await store.readIdentity()).deviceId, identity.deviceId);
    await expectLater(
      MlsStateStore(store.directory, ownerUserId: 'other').readPendingInbound(),
      throwsA(isA<MlsNativeException>()),
    );
    await store.clearPendingInbound();
    expect(await store.readPendingInbound(), isEmpty);
    await File('${store.path}/state.bin').writeAsString('broken', flush: true);
    await expectLater(store.readIdentity(), throwsA(isA<MlsNativeException>()));
    expect(await File('${store.path}/state.bin').readAsString(), 'broken');
  }, skip: skip);
  test('未准备或符号链接存储目录不得用于MLS', () async {
    final root = await Directory.systemTemp.createTemp(
      'tatachat_storage_boundary_',
    );
    addTearDown(() => root.delete(recursive: true));
    final missing = MlsStateStore(
      Directory('${root.path}/missing'),
      ownerUserId: 'user',
    );
    await expectLater(missing.ensureReady(), throwsStateError);
    final link = await Link('${root.path}/link').create(root.path);
    await expectLater(
      MlsStateStore(Directory(link.path), ownerUserId: 'user').ensureReady(),
      throwsStateError,
    );
  });
}
