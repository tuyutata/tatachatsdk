import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/src/storage/isar_core_bootstrap.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

/// Each test library owns an isolated physical database; no application storage keys.
void useIsolatedChatIsar() {
  late Directory directory;
  setUpAll(() async {
    directory = Directory.systemTemp.createTempSync('tatachat_sdk_test_');
    IsarCoreBootstrap.debugTestDirectoryOverride = directory.path;
    await IsarCoreBootstrap.ensureTestCoreInitialized();
  });
  setUp(() => ChatIsar.instance.resetForTest());
  tearDown(() => ChatIsar.instance.resetForTest());
  tearDownAll(() async {
    await ChatIsar.instance.resetForTest();
    IsarCoreBootstrap.debugTestDirectoryOverride = null;
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
}
