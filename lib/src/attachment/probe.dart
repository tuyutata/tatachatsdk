import 'dart:io';
import 'dart:typed_data';

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';

import '../core/chat_message.dart';
import 'attachment_platform.dart';

/// 媒体探测结果:宽高、时长、blurhash 占位。任一探测失败对应字段留空,不阻断发送。
class MediaProbeResult {
  const MediaProbeResult({
    this.width,
    this.height,
    this.durationMs,
    this.blurhash,
  });

  final int? width;
  final int? height;
  final int? durationMs;
  final String? blurhash;
}

typedef ImageSizeReader = ({int width, int height})? Function(String path);
typedef MediaBytesReader = Future<List<int>?> Function(String path);
typedef VideoProbeReader =
    Future<
      ({int? width, int? height, int? durationMs, List<int>? thumbnailBytes})
    >
    Function(String path);
typedef BlurhashEncoder = String? Function(List<int> smallImageBytes);

/// 采集媒体的宽高 / 时长 / blurhash 探测。
///
/// **内存安全**:blurhash 一律由**原生降采样出的小缩略图**(图走
/// flutter_image_compress、视频走 TataChatSDK 平台通道抽帧)编码,绝不在 Dart 侧整解码
/// 100MB 原图;图片宽高走 image_size_getter 读文件头,不解码。native 读取全部经
/// 可注入的 seam,编排与 blurhash 编码为纯 Dart,可单测。
class MediaProbe {
  MediaProbe({
    ImageSizeReader? imageSize,
    MediaBytesReader? imageThumbBytes,
    VideoProbeReader? videoProbe,
    BlurhashEncoder? blurhashOf,
  }) : _imageSize = imageSize ?? _defaultImageSize,
       _imageThumbBytes = imageThumbBytes ?? _defaultImageThumbBytes,
       _videoProbe = videoProbe ?? _defaultVideoProbe,
       _blurhashOf = blurhashOf ?? encodeBlurhash;

  final ImageSizeReader _imageSize;
  final MediaBytesReader _imageThumbBytes;
  final VideoProbeReader _videoProbe;
  final BlurhashEncoder _blurhashOf;

  Future<MediaProbeResult> probe({
    required String path,
    required ChatMessageKind kind,
  }) async {
    try {
      switch (kind) {
        case ChatMessageKind.image:
          final size = _imageSize(path);
          final thumb = await _imageThumbBytes(path);
          return MediaProbeResult(
            width: size?.width,
            height: size?.height,
            blurhash: thumb == null ? null : _blurhashOf(thumb),
          );
        case ChatMessageKind.video:
          final video = await _videoProbe(path);
          return MediaProbeResult(
            width: video.width,
            height: video.height,
            durationMs: video.durationMs,
            blurhash: video.thumbnailBytes == null
                ? null
                : _blurhashOf(video.thumbnailBytes!),
          );
        case ChatMessageKind.text ||
            ChatMessageKind.file ||
            ChatMessageKind.audio ||
            ChatMessageKind.sticker:
          return const MediaProbeResult();
      }
    } catch (_) {
      // 探测失败(文件损坏/native 异常)不阻断发送,占位退化为灰底。
      return const MediaProbeResult();
    }
  }

  /// 由**小缩略图字节**编码 blurhash(纯 Dart,可直接单测)。输入应已是缩略图;
  /// 保险起见**仅缩小**(不放大)到较大边 ≤64px 后编码——把主导的那一边降到 64,
  /// 另一边按比例随之 ≤64。
  static String? encodeBlurhash(List<int> smallImageBytes) {
    try {
      final decoded = img.decodeImage(Uint8List.fromList(smallImageBytes));
      if (decoded == null) return null;
      final img.Image tiny;
      if (decoded.width <= 64 && decoded.height <= 64) {
        tiny = decoded; // 已足够小,不放大
      } else if (decoded.width >= decoded.height) {
        tiny = img.copyResize(decoded, width: 64); // 宽为主导 → 高按比例 ≤64
      } else {
        tiny = img.copyResize(decoded, height: 64); // 高为主导 → 宽按比例 ≤64
      }
      return BlurHash.encode(tiny, numCompX: 4, numCompY: 3).hash;
    } catch (_) {
      return null;
    }
  }
}

({int width, int height})? _defaultImageSize(String path) {
  try {
    final result = ImageSizeGetter.getSizeResult(FileInput(File(path)));
    final size = result.size;
    // needRotate=true 时宽高需互换。
    return size.needRotate
        ? (width: size.height, height: size.width)
        : (width: size.width, height: size.height);
  } catch (_) {
    return null;
  }
}

Future<List<int>?> _defaultImageThumbBytes(String path) async {
  // 原生降采样出小缩略图,不在 Dart 侧整解码。
  final bytes = await FlutterImageCompress.compressWithFile(
    path,
    minWidth: 64,
    minHeight: 64,
    quality: 60,
  );
  return bytes;
}

Future<({int? width, int? height, int? durationMs, List<int>? thumbnailBytes})>
_defaultVideoProbe(String path) =>
    const ChatAttachmentPlatform().probeVideo(path);
