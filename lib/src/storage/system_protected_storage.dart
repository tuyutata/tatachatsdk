import 'dart:io';

import 'package:flutter/services.dart';

/// SDK 独占系统保护目录；只保留系统文件保护，不生成应用包装密钥。
final class ChatSystemProtectedStorage {
  static const MethodChannel _channel = MethodChannel('tatachat_sdk/security');

  static Future<Directory> prepare() async {
    final path = await _channel.invokeMethod<String>('prepareDataStorage');
    if (path == null || !path.startsWith(Platform.pathSeparator)) {
      throw StateError('SDK 系统保护目录无效');
    }
    final directory = Directory(path);
    if (await FileSystemEntity.type(path, followLinks: false) != FileSystemEntityType.directory ||
        await directory.resolveSymbolicLinks() != path) {
      throw StateError('SDK 系统保护目录不可用');
    }
    return directory;
  }

  static Future<void> verify(Directory directory) async {
    final root = await prepare();
    if (directory.path != root.path &&
        !directory.path.startsWith(root.path + Platform.pathSeparator)) {
      throw StateError('拒绝 SDK 所属目录之外的路径');
    }
    if (await directory.resolveSymbolicLinks() != directory.path) {
      throw StateError('拒绝 SDK 链接目录');
    }
  }
}
