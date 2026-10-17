import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:tatachat_sdk/storage/isar_core_bootstrap.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

/// 每个测试文件独占物理数据库，只接受由原锁定位的本轮Isar动态库。
void useIsolatedChatIsar() {
  Directory? directory;
  setUpAll(() async {
    final work = Platform.environment['TATACHATSDK_TEST_WORK_ROOT'];
    final library = Platform.environment['ISAR_CORE_LIB_PATH'];
    if (work == null || library == null || !path.isAbsolute(work) ||
        !path.isAbsolute(library) ||
        Directory(work).resolveSymbolicLinksSync() != work ||
        FileSystemEntity.typeSync(library, followLinks: false) !=
            FileSystemEntityType.file ||
        File(library).resolveSymbolicLinksSync() != library ||
        !path.isWithin(work, library)) {
      throw StateError('Isar测试必须使用本轮Pub原锁交付的动态库');
    }
    final owned = await Directory.systemTemp.createTemp('tatachat_sdk_test_');
    directory = owned;
    IsarCoreBootstrap.debugTestDirectoryOverride = owned.path;
    await IsarCoreBootstrap.ensureTestCoreInitialized();
  });
  setUp(() => ChatIsar.instance.resetForTest());
  tearDown(() => ChatIsar.instance.resetForTest());
  tearDownAll(() async {
    try {
      await ChatIsar.instance.resetForTest();
    } finally {
      IsarCoreBootstrap.debugTestDirectoryOverride = null;
      final owned = directory;
      if (owned != null && owned.existsSync()) await owned.delete(recursive: true);
    }
  });
}
