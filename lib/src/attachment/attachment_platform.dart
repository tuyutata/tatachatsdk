import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// 系统文件选择返回的TataChatSDK临时普通文件；宿主业务仍在Dart层决定最终额度。
final class ChatPickedFile {
  const ChatPickedFile({
    required this.path,
    required this.fileName,
    required this.mime,
  });

  final String path;
  final String fileName;
  final String mime;
}

/// TataChatSDK附件相关的唯一平台边界：单文件选择与视频小图探测共用同一通道。
final class ChatAttachmentPlatform {
  const ChatAttachmentPlatform();

  static const MethodChannel _channel = MethodChannel(
    'chat.tata.sdk/attachment',
  );

  Future<ChatPickedFile?> pickFile() async {
    final result = await _channel.invokeMapMethod<String, Object?>('pickFile');
    if (result == null) return null;
    final path = result['path'];
    final fileName = result['file_name'];
    final mime = result['mime'];
    if (path is! String ||
        !p.isAbsolute(path) ||
        path.contains('\u0000') ||
        fileName is! String ||
        !_validFileName(fileName) ||
        mime is! String ||
        !RegExp(
          r'^[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*$',
        ).hasMatch(mime)) {
      throw const FormatException('系统文件选择结果无效');
    }
    return ChatPickedFile(path: path, fileName: fileName, mime: mime);
  }

  Future<
    ({int? width, int? height, int? durationMs, List<int>? thumbnailBytes})
  >
  probeVideo(String path) async {
    if (!p.isAbsolute(path) || path.contains('\u0000')) {
      throw const FormatException('视频路径必须是有效绝对路径');
    }
    final result = await _channel.invokeMapMethod<String, Object?>(
      'probeVideo',
      <String, Object?>{'path': path},
    );
    if (result == null) throw const FormatException('视频探测结果缺失');

    int? positiveInt(String field) {
      final value = result[field];
      if (value == null) return null;
      if (value is! int || value <= 0 || value > 0xffffffff) {
        throw FormatException('视频探测字段无效：$field');
      }
      return value;
    }

    final rawThumbnail = result['thumbnail_bytes'];
    if (rawThumbnail != null && rawThumbnail is! Uint8List) {
      throw const FormatException('视频封面字节类型无效');
    }
    final thumbnail = rawThumbnail as Uint8List?;
    if (thumbnail != null && (thumbnail.isEmpty || thumbnail.length > 262144)) {
      throw const FormatException('视频封面字节超出限制');
    }
    return (
      width: positiveInt('width'),
      height: positiveInt('height'),
      durationMs: positiveInt('duration_ms'),
      thumbnailBytes: thumbnail,
    );
  }

  static bool _validFileName(String value) {
    if (value.isEmpty || utf8.encode(value).length > 255) return false;
    return !value.contains('/') &&
        !value.contains('\\') &&
        !value.runes.any((rune) => rune < 32 || rune == 127);
  }
}
