import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

/// 宿主应用各业务 Isar 实例可复用的底层启动能力。
///
/// 本类只负责定位数据库目录和 Flutter 测试期加载 Isar Core，不保存任何业务状态，
/// 也不提供跨业务数据库的统一操作队列。每个业务数据库必须拥有独立的打开、读写和
/// 关闭生命周期，禁止借本类重新形成全 App 活性依赖。
class IsarCoreBootstrap {
  IsarCoreBootstrap._();

  /// 仅测试使用：让同一测试文件内的多个业务数据库落入同一个隔离临时目录。
  static String? debugTestDirectoryOverride;

  static Future<void>? _testCoreInitialization;

  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Flutter 测试没有移动端插件自动加载 Isar Core，所有业务库共用一次初始化。
  static Future<void> ensureTestCoreInitialized() async {
    if (!isFlutterTest) return;
    final inflight = _testCoreInitialization;
    if (inflight != null) return inflight;

    final task = _initializeTestCore();
    _testCoreInitialization = task;
    try {
      await task;
    } catch (_) {
      if (identical(_testCoreInitialization, task)) {
        _testCoreInitialization = null;
      }
      rethrow;
    }
  }

  static Future<String> resolveDirectory() async {
    if (kIsWeb) return '.';
    if (isFlutterTest) {
      return debugTestDirectoryOverride ?? Directory.systemTemp.path;
    }
    return (await getApplicationSupportDirectory()).path;
  }

  static Future<void> _initializeTestCore() async {
    final localPath = _resolveLocalIsarCorePath();
    if (localPath == null) {
      throw StateError(
        'Flutter test 模式未找到 Isar Core 动态库，请先执行 flutter pub get。',
      );
    }
    await Isar.initializeIsarCore(
      libraries: <Abi, String>{Abi.current(): localPath},
    );
  }

  static String? _resolveLocalIsarCorePath() {
    final fromEnv = Platform.environment['ISAR_CORE_LIB_PATH'];
    if (fromEnv != null && fromEnv.trim().isNotEmpty) {
      final file = File(fromEnv.trim());
      if (file.existsSync()) return file.path;
    }

    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return null;
    final hosted = Directory('$home/.pub-cache/hosted/pub.dev');
    if (!hosted.existsSync()) return null;

    final candidates =
        hosted
            .listSync(followLinks: false)
            .whereType<Directory>()
            .where(
              (dir) => dir.path
                  .split(Platform.pathSeparator)
                  .last
                  .startsWith('isar_community_flutter_libs-'),
            )
            .toList(growable: false)
          ..sort((a, b) => b.path.compareTo(a.path));

    final relative = switch (Abi.current()) {
      Abi.macosArm64 || Abi.macosX64 => 'macos/libisar.dylib',
      Abi.linuxX64 => 'linux/libisar.so',
      Abi.windowsArm64 || Abi.windowsX64 => 'windows/isar.dll',
      _ => null,
    };
    if (relative == null) return null;

    for (final dir in candidates) {
      final path = '${dir.path}/$relative';
      if (File(path).existsSync()) return path;
    }
    return null;
  }
}
