import 'dart:convert';

import 'package:fixnum/fixnum.dart';

import '../protocol/media_content.pb.dart' as protocol;

enum MediaContentKind { image, video, file, audio }

/// Deployment-neutral metadata for one encrypted media attachment.
///
/// Product limits, capture policy, compression, and UI stay in the host. The
/// SDK owns only the interoperable encrypted descriptor and its validation.
final class MediaContent {
  factory MediaContent({
    required MediaContentKind kind,
    required String attachmentId,
    required String fileName,
    required String mime,
    required int byteSize,
    required List<int> cipherKey,
    required int cipherByteSize,
    required List<int> cipherSha256,
    int? width,
    int? height,
    int? durationMs,
    String? blurhash,
  }) => MediaContent._(
    kind: kind,
    attachmentId: attachmentId,
    fileName: fileName,
    mime: mime,
    byteSize: byteSize,
    cipherKey: List<int>.unmodifiable(cipherKey),
    cipherByteSize: cipherByteSize,
    cipherSha256: List<int>.unmodifiable(cipherSha256),
    width: width,
    height: height,
    durationMs: durationMs,
    blurhash: blurhash,
  );

  const MediaContent._({
    required this.kind,
    required this.attachmentId,
    required this.fileName,
    required this.mime,
    required this.byteSize,
    required this.cipherKey,
    required this.cipherByteSize,
    required this.cipherSha256,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.blurhash,
  });

  final MediaContentKind kind;
  final String attachmentId;
  final String fileName;
  final String mime;
  final int byteSize;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? blurhash;
  final List<int> cipherKey;
  final int cipherByteSize;
  final List<int> cipherSha256;
}

final class MediaContentCodec {
  const MediaContentCodec._();

  static const int maxWireBytes = 64 * 1024;
  static const int _maxUint32 = 0xffffffff;
  static final RegExp _attachmentId = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$',
  );
  static final RegExp _mime = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]*/[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]*$',
  );

  static List<int> encode(MediaContent content) {
    _validate(content);
    final descriptor = protocol.MediaDescriptor()
      ..attachmentId = content.attachmentId
      ..fileName = content.fileName
      ..mime = content.mime
      ..byteSize = Int64(content.byteSize)
      ..cipherKey = content.cipherKey
      ..cipherByteSize = Int64(content.cipherByteSize)
      ..cipherSha256 = content.cipherSha256;
    if (content.width case final value?) descriptor.width = value;
    if (content.height case final value?) descriptor.height = value;
    if (content.durationMs case final value?) descriptor.durationMs = value;
    if (content.blurhash case final value?) descriptor.blurhash = value;

    final payload = protocol.MediaPayload();
    switch (content.kind) {
      case MediaContentKind.image:
        payload.image = descriptor;
      case MediaContentKind.video:
        payload.video = descriptor;
      case MediaContentKind.file:
        payload.file = descriptor;
      case MediaContentKind.audio:
        payload.audio = descriptor;
    }
    final bytes = payload.writeToBuffer();
    if (bytes.length > maxWireBytes) {
      throw const FormatException('media payload exceeds the wire limit');
    }
    return bytes;
  }

  static MediaContent decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxWireBytes) {
      throw const FormatException('invalid media payload size');
    }
    late final protocol.MediaPayload payload;
    try {
      payload = protocol.MediaPayload.fromBuffer(bytes);
    } on Object {
      throw const FormatException('invalid media payload');
    }
    if (payload.unknownFields.isNotEmpty ||
        !_sameBytes(bytes, payload.writeToBuffer())) {
      throw const FormatException('non-canonical media payload');
    }

    late final MediaContentKind kind;
    late final protocol.MediaDescriptor descriptor;
    switch (payload.whichContent()) {
      case protocol.MediaPayload_Content.image:
        kind = MediaContentKind.image;
        descriptor = payload.image;
      case protocol.MediaPayload_Content.video:
        kind = MediaContentKind.video;
        descriptor = payload.video;
      case protocol.MediaPayload_Content.file:
        kind = MediaContentKind.file;
        descriptor = payload.file;
      case protocol.MediaPayload_Content.audio:
        kind = MediaContentKind.audio;
        descriptor = payload.audio;
      case protocol.MediaPayload_Content.notSet:
        throw const FormatException('media payload has no content');
    }
    if (descriptor.unknownFields.isNotEmpty) {
      throw const FormatException('media descriptor has unknown fields');
    }
    final content = MediaContent(
      kind: kind,
      attachmentId: descriptor.attachmentId,
      fileName: descriptor.fileName,
      mime: descriptor.mime,
      byteSize: descriptor.byteSize.toInt(),
      width: descriptor.width == 0 ? null : descriptor.width,
      height: descriptor.height == 0 ? null : descriptor.height,
      durationMs: descriptor.durationMs == 0 ? null : descriptor.durationMs,
      blurhash: descriptor.blurhash.isEmpty ? null : descriptor.blurhash,
      cipherKey: descriptor.cipherKey,
      cipherByteSize: descriptor.cipherByteSize.toInt(),
      cipherSha256: descriptor.cipherSha256,
    );
    _validate(content);
    return content;
  }

  static void _validate(MediaContent content) {
    if (!_attachmentId.hasMatch(content.attachmentId)) {
      throw const FormatException('invalid attachment id');
    }
    final fileNameBytes = utf8.encode(content.fileName);
    if (fileNameBytes.isEmpty ||
        fileNameBytes.length > 255 ||
        content.fileName.contains('/') ||
        content.fileName.contains('\\') ||
        content.fileName.contains('\u0000')) {
      throw const FormatException('invalid attachment file name');
    }
    if (!_mime.hasMatch(content.mime)) {
      throw const FormatException('invalid attachment MIME type');
    }
    if (content.byteSize <= 0 || content.cipherByteSize <= content.byteSize) {
      throw const FormatException('invalid attachment byte size');
    }
    if (content.cipherKey.length != 32 || content.cipherSha256.length != 32) {
      throw const FormatException('invalid attachment cryptographic metadata');
    }
    if ((content.width == null) != (content.height == null) ||
        (content.width != null &&
            (content.width! <= 0 || content.width! > _maxUint32)) ||
        (content.height != null &&
            (content.height! <= 0 || content.height! > _maxUint32)) ||
        (content.durationMs != null &&
            (content.durationMs! <= 0 || content.durationMs! > _maxUint32)) ||
        (content.blurhash != null &&
            (content.blurhash!.isEmpty ||
                utf8.encode(content.blurhash!).length > 512))) {
      throw const FormatException('invalid attachment presentation metadata');
    }
    switch (content.kind) {
      case MediaContentKind.image:
        if (!content.mime.startsWith('image/') || content.durationMs != null) {
          throw const FormatException('invalid image descriptor');
        }
      case MediaContentKind.video:
        if (!content.mime.startsWith('video/')) {
          throw const FormatException('invalid video descriptor');
        }
      case MediaContentKind.audio:
        if (!content.mime.startsWith('audio/') ||
            content.width != null ||
            content.blurhash != null) {
          throw const FormatException('invalid audio descriptor');
        }
      case MediaContentKind.file:
        if (content.width != null ||
            content.durationMs != null ||
            content.blurhash != null) {
          throw const FormatException('invalid file descriptor');
        }
    }
  }

  static bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
