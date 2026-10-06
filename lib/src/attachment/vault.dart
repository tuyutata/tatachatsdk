import '../storage/system_protected_storage.dart';
import 'dart:io';

/// 系统保护目录内的附件缓存；传输层由独立 MLS 附件协议负责。
class AttachmentVault {
  const AttachmentVault._();
  static const String plainDirName = '.plain';

  static File _cacheTarget(String path) {
    if (!File(path).isAbsolute || path.split(Platform.pathSeparator).any((part) => part == '.' || part == '..')) {
      throw StateError('附件缓存拒绝相对路径');
    }
    return File(path).absolute;
  }

  /// 读写前核对规范路径和已有父项；不得先创建越界目录再检查。
  static Future<void> _requireCachePath(File target) async {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      final root = await ChatSystemProtectedStorage.prepare();
      if (!target.path.startsWith(root.path + Platform.pathSeparator)) {
        throw StateError('附件缓存必须归SDK系统保护目录');
      }
    }
    var parent = target.parent;
    while (true) {
      final type = await FileSystemEntity.type(parent.path, followLinks: false);
      if (type == FileSystemEntityType.directory) break;
      if (type != FileSystemEntityType.notFound || parent.parent.path == parent.path) {
        throw StateError('附件缓存父路径异常');
      }
      parent = parent.parent;
    }
    if (await parent.resolveSymbolicLinks() != parent.path) throw StateError('附件缓存父路径异常');
  }

  static Future<bool> hasCache(String cachePath) async {
    final target = _cacheTarget(cachePath);
    await _requireCachePath(target);
    final type = await FileSystemEntity.type(target.path, followLinks: false);
    if (type == FileSystemEntityType.link) throw StateError('附件缓存拒绝文件链接');
    return type == FileSystemEntityType.file;
  }

  static Future<File> cache({required File source, required String cachePath}) async {
    final target = _cacheTarget(cachePath);
    final production = !Platform.environment.containsKey('FLUTTER_TEST');
    await _requireCachePath(target);
    await target.parent.create(recursive: true);
    if (await FileSystemEntity.type(target.path, followLinks: false) == FileSystemEntityType.link ||
        await target.parent.resolveSymbolicLinks() != target.parent.path) {
      throw StateError('附件缓存路径异常');
    }
    final partial = File(cachePath + '.part');
    if (await FileSystemEntity.type(partial.path, followLinks: false) == FileSystemEntityType.link) {
      throw StateError('附件临时路径异常');
    }
    try {
    final output = await partial.open(mode: FileMode.write);
    try {
      await for (final chunk in source.openRead()) { await output.writeFrom(chunk); }
      await output.flush();
    } finally { await output.close(); }
    if (production) await ChatSystemProtectedStorage.verify(target.parent);
    await partial.rename(target.path);
    if (production) await ChatSystemProtectedStorage.verify(target.parent);
    return target;
    } catch (_) {
      if (await FileSystemEntity.type(partial.path, followLinks:false) == FileSystemEntityType.file) await partial.delete();
      rethrow;
    }
  }

  /// 删除某个短命明文文件（用完即调，失败静默——文件可能已被清理）。
  static Future<void> releasePlain(File plain) async {
    try {
      if (await plain.exists()) {
        await plain.delete();
      }
    } on FileSystemException {
      // 已被 purge 或系统清理，无需处理。
    }
  }

  /// 整目录清空短命明文（App 启动 / 退出账户时调）。
  ///
  /// 崩溃或强杀会跳过 [releasePlain]，必须有这道兜底，否则明文会跨会话存活。
  static Future<void> purgePlainDirectory(Directory plainDirectory) async {
    if (!await plainDirectory.exists()) return;
    try {
      await plainDirectory.delete(recursive: true);
    } on FileSystemException {
      // 目录被占用时逐个删，尽力而为。
      await for (final entity in plainDirectory.list()) {
        try {
          await entity.delete(recursive: true);
        } on FileSystemException {
          continue;
        }
      }
    }
  }


}

