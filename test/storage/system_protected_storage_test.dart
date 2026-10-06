import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tatachat_sdk/security');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('系统保护失败不返回可用SDK路径', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'data_storage_unavailable'),
    );
    await expectLater(
      ChatSystemProtectedStorage.prepare(),
      throwsA(isA<PlatformException>()),
    );
  });
  test('SDK所属路径之外和链接子目录均拒绝', () async {
    final temporary = await Directory.systemTemp.createTemp('chat_policy_');
    final root = Directory(await temporary.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    messenger.setMockMethodCallHandler(channel, (_) async => root.path);
    final child = await Directory('${root.path}/child').create();
    await ChatSystemProtectedStorage.verify(child);
    await expectLater(
      ChatSystemProtectedStorage.verify(root.parent),
      throwsStateError,
    );
    await Link('${root.path}/link').create(child.path);
    await expectLater(
      ChatSystemProtectedStorage.verify(Directory('${root.path}/link')),
      throwsStateError,
    );
  });
}
