import 'dart:convert';

import 'package:fixnum/fixnum.dart';

import '../protocol/media_content.pb.dart' as protocol;

enum MediaContentKind { image, video, file, audio }

/// 普通MLS消息内的唯一附件描述；文件组与实际设备叶子均须严格核验。
/// 宿主保留选择、压缩和展示策略，SDK拥有MLS线格式及体积界限。
final class MediaContent {
  factory MediaContent({
    required MediaContentKind kind,
    required String attachmentId,
    required String fileName,
    required String mime,
    required int byteSize,
    required int attachmentChatEpoch,
    required String attachmentGroupId,
    required List<int> attachmentWelcome,
    required List<String> attachmentMemberIdentities,
    required String attachmentSenderMemberIdentity,
    required int attachmentChunkCount,
    required List<int> plainSha256,
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
    attachmentChatEpoch: attachmentChatEpoch,
    attachmentGroupId: attachmentGroupId,
    attachmentWelcome: List<int>.unmodifiable(attachmentWelcome),
    attachmentMemberIdentities: List<String>.unmodifiable(attachmentMemberIdentities),
    attachmentSenderMemberIdentity: attachmentSenderMemberIdentity,
    attachmentChunkCount: attachmentChunkCount,
    plainSha256: List<int>.unmodifiable(plainSha256),
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
    required this.attachmentChatEpoch,
    required this.attachmentGroupId,
    required this.attachmentWelcome,
    required this.attachmentMemberIdentities,
    required this.attachmentSenderMemberIdentity,
    required this.attachmentChunkCount,
    required this.plainSha256,
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
  final int attachmentChatEpoch;
  final String attachmentGroupId;
  final List<int> attachmentWelcome;
  final List<String> attachmentMemberIdentities;
  final String attachmentSenderMemberIdentity;
  final int attachmentChunkCount;
  final List<int> plainSha256;
  final int cipherByteSize;
  final List<int> cipherSha256;
}

final class MediaContentCodec {
  const MediaContentCodec._();

  static const int maxWireBytes = 64 * 1024;
  static const int _maxUint32 = 0xffffffff;
  static final RegExp _attachmentId = RegExp(
    r'^[A-Za-z0-9_-]{1,128}$',
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
      ..attachmentChatEpoch = Int64(content.attachmentChatEpoch)
      ..attachmentGroupId = content.attachmentGroupId
      ..attachmentWelcome = content.attachmentWelcome
      ..attachmentMemberIdentities.addAll(content.attachmentMemberIdentities)
      ..attachmentSenderMemberIdentity = content.attachmentSenderMemberIdentity
      ..attachmentChunkCount = content.attachmentChunkCount
      ..plainSha256 = content.plainSha256
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
      attachmentChatEpoch: descriptor.attachmentChatEpoch.toInt(),
      attachmentGroupId: descriptor.attachmentGroupId,
      attachmentWelcome: descriptor.attachmentWelcome,
      attachmentMemberIdentities: descriptor.attachmentMemberIdentities,
      attachmentSenderMemberIdentity: descriptor.attachmentSenderMemberIdentity,
      attachmentChunkCount: descriptor.attachmentChunkCount,
      plainSha256: descriptor.plainSha256,
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
    final members = content.attachmentMemberIdentities;
    final sorted = [...members]..sort();
    if (content.attachmentChatEpoch < 0 || content.attachmentChatEpoch > 9007199254740991 || content.byteSize > 9007199254740991 ||
        content.attachmentChunkCount > _maxUint32 ||
        utf8.encode(content.attachmentGroupId).length > 320 ||
        [content.attachmentWelcome,content.plainSha256,content.cipherSha256].any((bytes)=>bytes.any((b)=>b<0||b>255)) ||
        content.attachmentChunkCount != (content.byteSize + 1024 * 1024 - 1) ~/ (1024 * 1024) ||
        content.cipherByteSize > content.byteSize + content.attachmentChunkCount * 4096 ||
        content.plainSha256.length != 32 || content.cipherSha256.length != 32 ||
        content.attachmentGroupId != 'attachment:${content.attachmentSenderMemberIdentity}:${content.attachmentId}' ||
        content.attachmentWelcome.isEmpty || content.attachmentWelcome.length > 48 * 1024 ||
        members.length < 2 || members.length > 1989 || members.toSet().length != members.length ||
        !members.contains(content.attachmentSenderMemberIdentity) ||
        !_sameStrings(members, sorted) ||
        members.any((m) => !RegExp(r'^[^:\x00-\x20]{1,256}:[0-9a-f]{64}$').hasMatch(m))) {
      throw const FormatException('附件MLS合同无效');
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

  static bool _sameStrings(List<String> a, List<String> b) => a.length == b.length && List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);

  static bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
