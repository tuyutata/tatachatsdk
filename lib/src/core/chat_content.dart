import 'dart:convert';

import 'basic_content.dart';
import 'chat_message.dart';
import 'media_content.dart';

/// SDK展示无关内容；唯一媒体合同由严格MLS描述编解码验证。
final class ChatContent {
  const ChatContent({
    required this.kind,
    this.text,
    this.attachmentId,
    this.fileName,
    this.mime,
    this.byteSize,
    this.width,
    this.height,
    this.durationMs,
    this.blurhash,
    this.packId,
    this.stickerId,
    this.attachmentChatEpoch,
    this.attachmentGroupId,
    this.attachmentWelcome,
    this.attachmentMemberIdentities,
    this.attachmentSenderMemberIdentity,
    this.attachmentChunkCount,
    this.plainSha256,
    this.cipherByteSize,
    this.cipherSha256,
  });

  factory ChatContent.text(String text) =>
      ChatContent(kind: ChatMessageKind.text, text: text);

  factory ChatContent.sticker({
    required String packId,
    required String stickerId,
  }) => ChatContent(
    kind: ChatMessageKind.sticker,
    packId: packId,
    stickerId: stickerId,
  );

  factory ChatContent.media({
    required ChatMessageKind kind,
    required String attachmentId,
    required String fileName,
    required String mime,
    required int byteSize,
    required int attachmentChatEpoch,
    required String attachmentGroupId,
    required String attachmentWelcome,
    required List<String> attachmentMemberIdentities,
    required String attachmentSenderMemberIdentity,
    required int attachmentChunkCount,
    required String plainSha256,
    required int cipherByteSize,
    required String cipherSha256,
    int? width,
    int? height,
    int? durationMs,
    String? blurhash,
  }) => ChatContent(
    kind: kind,
    attachmentId: attachmentId,
    fileName: fileName,
    mime: mime,
    byteSize: byteSize,
    width: width,
    height: height,
    durationMs: durationMs,
    blurhash: blurhash,
    attachmentChatEpoch: attachmentChatEpoch,
    attachmentGroupId: attachmentGroupId,
    attachmentWelcome: attachmentWelcome,
    attachmentMemberIdentities: attachmentMemberIdentities,
    attachmentSenderMemberIdentity: attachmentSenderMemberIdentity,
    attachmentChunkCount: attachmentChunkCount,
    plainSha256: plainSha256,
    cipherByteSize: cipherByteSize,
    cipherSha256: cipherSha256,
  );

  final ChatMessageKind kind;
  final String? text;
  final String? attachmentId;
  final String? fileName;
  final String? mime;
  final int? byteSize;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? blurhash;
  final String? packId;
  final String? stickerId;
  final int? attachmentChatEpoch;
  final String? attachmentGroupId;
  final String? attachmentWelcome;
  final List<String>? attachmentMemberIdentities;
  final String? attachmentSenderMemberIdentity;
  final int? attachmentChunkCount;
  final String? plainSha256;
  final int? cipherByteSize;
  final String? cipherSha256;

  bool get isMedia =>
      kind == ChatMessageKind.image ||
      kind == ChatMessageKind.video ||
      kind == ChatMessageKind.file ||
      kind == ChatMessageKind.audio;

  String get summary {
    if (kind == ChatMessageKind.image) return '[图片]';
    if (kind == ChatMessageKind.video) return '[视频]';
    if (kind == ChatMessageKind.audio) return '[语音]';
    if (kind == ChatMessageKind.file) {
      return '[文件] ${fileName ?? ''}'.trim();
    }
    if (kind == ChatMessageKind.sticker) return '[贴纸]';
    return text ?? '';
  }
}

/// One canonical base64url wire target for basic and media protobuf payloads.
final class ChatPayloadCodec {
  const ChatPayloadCodec._();

  static String encode(ChatContent content) {
    if (content.isMedia) {
      final media = MediaContent(
        kind: _wireMediaKind(content.kind),
        attachmentId: content.attachmentId ?? '',
        fileName: content.fileName ?? '',
        mime: content.mime ?? '',
        byteSize: content.byteSize ?? 0,
        width: content.width,
        height: content.height,
        durationMs: content.durationMs,
        blurhash: content.blurhash,
        attachmentChatEpoch: content.attachmentChatEpoch ?? -1,
        attachmentGroupId: content.attachmentGroupId ?? '',
        attachmentWelcome: _decodeWire(content.attachmentWelcome ?? ''),
        attachmentMemberIdentities:
            content.attachmentMemberIdentities ?? const [],
        attachmentSenderMemberIdentity:
            content.attachmentSenderMemberIdentity ?? '',
        attachmentChunkCount: content.attachmentChunkCount ?? 0,
        plainSha256: _decodeHex(
          content.plainSha256 ?? '',
          field: 'plain_sha256',
          expectedBytes: 32,
        ),
        cipherByteSize: content.cipherByteSize ?? 0,
        cipherSha256: _decodeHex(
          content.cipherSha256 ?? '',
          field: 'cipher_sha256',
          expectedBytes: 32,
        ),
      );
      return _encodeWire(MediaContentCodec.encode(media));
    }

    late final BasicContent basic;
    if (content.kind == ChatMessageKind.sticker) {
      basic = BasicContent.sticker(
        packId: content.packId ?? '',
        stickerId: content.stickerId ?? '',
      );
    } else if (content.kind == ChatMessageKind.text) {
      basic = BasicContent.textInput(content.text ?? '');
    } else {
      throw const FormatException('unsupported chat content kind');
    }
    return _encodeWire(BasicContentCodec.encode(basic));
  }

  static ChatContent decode(String encoded) {
    final bytes = _decodeWire(encoded);
    try {
      return _fromBasic(BasicContentCodec.decode(bytes));
    } on Object {
      try {
        return _fromMedia(MediaContentCodec.decode(bytes));
      } on Object {
        throw const FormatException('invalid chat payload');
      }
    }
  }

  static ChatContent _fromBasic(BasicContent content) {
    if (content.kind == BasicContentKind.sticker) {
      return ChatContent.sticker(
        packId: content.packId ?? '',
        stickerId: content.stickerId ?? '',
      );
    }
    return ChatContent.text(content.value ?? '');
  }

  static ChatContent _fromMedia(MediaContent content) => ChatContent.media(
    kind: _messageMediaKind(content.kind),
    attachmentId: content.attachmentId,
    fileName: content.fileName,
    mime: content.mime,
    byteSize: content.byteSize,
    width: content.width,
    height: content.height,
    durationMs: content.durationMs,
    blurhash: content.blurhash,
    attachmentChatEpoch: content.attachmentChatEpoch,
    attachmentGroupId: content.attachmentGroupId,
    attachmentWelcome: _encodeWire(content.attachmentWelcome),
    attachmentMemberIdentities: content.attachmentMemberIdentities,
    attachmentSenderMemberIdentity: content.attachmentSenderMemberIdentity,
    attachmentChunkCount: content.attachmentChunkCount,
    plainSha256: _encodeHex(content.plainSha256),
    cipherByteSize: content.cipherByteSize,
    cipherSha256: _encodeHex(content.cipherSha256),
  );

  static MediaContentKind _wireMediaKind(ChatMessageKind kind) {
    if (kind == ChatMessageKind.image) return MediaContentKind.image;
    if (kind == ChatMessageKind.video) return MediaContentKind.video;
    if (kind == ChatMessageKind.file) return MediaContentKind.file;
    if (kind == ChatMessageKind.audio) return MediaContentKind.audio;
    throw const FormatException('chat content is not media');
  }

  static ChatMessageKind _messageMediaKind(MediaContentKind kind) {
    switch (kind) {
      case MediaContentKind.image:
        return ChatMessageKind.image;
      case MediaContentKind.video:
        return ChatMessageKind.video;
      case MediaContentKind.file:
        return ChatMessageKind.file;
      case MediaContentKind.audio:
        return ChatMessageKind.audio;
    }
  }
}

String _encodeWire(List<int> bytes) =>
    base64UrlEncode(bytes).replaceAll('=', '');

List<int> _decodeWire(String encoded) {
  if (encoded.isEmpty ||
      encoded.trim() != encoded ||
      encoded.contains('=') ||
      encoded.contains(RegExp(r'\s'))) {
    throw const FormatException('chat payload is not canonical base64url');
  }
  try {
    final padding = '=' * ((4 - encoded.length % 4) % 4);
    final bytes = base64Url.decode('$encoded$padding');
    if (_encodeWire(bytes) != encoded) {
      throw const FormatException('chat payload is not canonical base64url');
    }
    return bytes;
  } on FormatException {
    rethrow;
  } on Object {
    throw const FormatException('chat payload is not valid base64url');
  }
}

List<int> _decodeHex(
  String encoded, {
  required String field,
  required int expectedBytes,
}) {
  if (encoded.length != expectedBytes * 2 ||
      !RegExp(r'^[0-9a-f]+$').hasMatch(encoded)) {
    throw FormatException('$field is not canonical lowercase hex');
  }
  return List<int>.generate(
    expectedBytes,
    (index) =>
        int.parse(encoded.substring(index * 2, index * 2 + 2), radix: 16),
    growable: false,
  );
}

String _encodeHex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
