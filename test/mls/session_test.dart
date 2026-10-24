import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import '../support/native_probe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  requireChatSdkNative();
  test('早到MLS密文在同一原生状态保存、去重及校验所有者', () async {
    final root = await Directory.systemTemp.createTemp('tatachat_pending_');
    addTearDown(() => root.delete(recursive: true));
    final store = MlsStateStore(
      Directory(await root.resolveSymbolicLinks()),
      ownerUserId: 'user',
    );
    final identity = await store.prepareIdentity();
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
  });
  test('平台验证后的系统目录别名被规范化，末级符号链接仍拒绝', () async {
    final root = await Directory.systemTemp.createTemp(
      'tatachat_platform_path_',
    );
    addTearDown(() => root.delete(recursive: true));
    const channel = MethodChannel('tatachat_sdk/security');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var path = root.path;
    messenger.setMockMethodCallHandler(channel, (call) async => {'path': path});
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final store = await MlsStateStore.prepare('synthetic-user');
    expect(store.path, await root.resolveSymbolicLinks());
    final identity = await store.prepareIdentity();
    // 平台再次打开既有目录不需要创建标记，仍复用原身份。
    final reopened = await MlsStateStore.prepare('synthetic-user');
    expect((await reopened.prepareIdentity()).deviceId, identity.deviceId);
    final link = await Link('${root.path}/link').create(root.path);
    path = link.path;
    await expectLater(
      MlsStateStore.prepare('synthetic-user'),
      throwsA(
        isA<MlsNativeException>().having(
          (error) => error.code,
          'code',
          MlsNativeErrorCode.directoryInvalid,
        ),
      ),
    );
  });
  test('未准备或符号链接存储目录不得用于MLS', () async {
    final root = await Directory.systemTemp.createTemp(
      'tatachat_storage_boundary_',
    );
    addTearDown(() => root.delete(recursive: true));
    final missing = MlsStateStore(
      Directory('${root.path}/missing'),
      ownerUserId: 'user',
    );
    await expectLater(
      missing.ensureReady(),
      throwsA(
        isA<MlsNativeException>().having(
          (e) => e.code,
          'code',
          MlsNativeErrorCode.directoryUnavailable,
        ),
      ),
    );
    final link = await Link('${root.path}/link').create(root.path);
    await expectLater(
      MlsStateStore(Directory(link.path), ownerUserId: 'user').ensureReady(),
      throwsA(
        isA<MlsNativeException>().having(
          (e) => e.code,
          'code',
          MlsNativeErrorCode.directoryInvalid,
        ),
      ),
    );
  });
}
