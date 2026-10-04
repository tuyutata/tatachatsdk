import 'dart:convert';
import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

import '../protocol/basic_content.pb.dart' as wire;

/// 第一类消息的闭集，媒体、通话和扩展消息不得进入该结构。
enum BasicContentKind { text, emoji, sticker }

/// 私聊和群聊共用的第一类消息内容模型。
final class BasicContent {
  const BasicContent._({
    required this.kind,
    this.value,
    this.packId,
    this.stickerId,
  });

  factory BasicContent.text(String value) =>
      BasicContent._(kind: BasicContentKind.text, value: value);

  factory BasicContent.emoji(String value) =>
      BasicContent._(kind: BasicContentKind.emoji, value: value);

  /// 输入框中的纯 emoji 自动进入 emoji 分支，其余内容进入文本分支。
  factory BasicContent.textInput(String value) =>
      isEmojiOnly(value) ? BasicContent.emoji(value) : BasicContent.text(value);

  factory BasicContent.sticker({
    required String packId,
    required String stickerId,
  }) => BasicContent._(
    kind: BasicContentKind.sticker,
    packId: packId,
    stickerId: stickerId,
  );

  final BasicContentKind kind;
  final String? value;
  final String? packId;
  final String? stickerId;

  static bool isEmojiOnly(String value) {
    if (value.isEmpty) return false;
    final runes = value.runes.toList(growable: false);
    final hasKeycap = runes.contains(0x20e3);
    var hasEmoji = false;
    for (final rune in runes) {
      if (rune == 0x200d ||
          rune == 0xfe0f ||
          rune == 0x20e3 ||
          (rune >= 0x1f3fb && rune <= 0x1f3ff)) {
        continue;
      }
      if (hasKeycap &&
          (rune == 0x23 || rune == 0x2a || (rune >= 0x30 && rune <= 0x39))) {
        hasEmoji = true;
        continue;
      }
      final emoji =
          (rune >= 0x1f000 && rune <= 0x1faff) ||
          (rune >= 0x2600 && rune <= 0x27ff) ||
          (rune >= 0x2300 && rune <= 0x23ff) ||
          rune == 0x00a9 ||
          rune == 0x00ae ||
          rune == 0x2122 ||
          rune == 0x3030 ||
          rune == 0x303d ||
          rune == 0x3297 ||
          rune == 0x3299;
      if (!emoji) return false;
      hasEmoji = true;
    }
    return hasEmoji;
  }
}

/// 第一类消息唯一 protobuf 编解码器，所有非法结构均失败关闭。
final class BasicContentCodec {
  BasicContentCodec._();

  static const int maxTextBytes = 16 * 1024;
  static const int maxEmojiBytes = 256;
  static const int maxPayloadBytes = 64 * 1024;
  static final RegExp _stickerId = RegExp(r'^[A-Za-z0-9._-]{1,64}$');

  static Uint8List encode(BasicContent content) {
    _validate(content);
    final payload = switch (content.kind) {
      BasicContentKind.text => wire.BasicPayload(
        text: wire.TextContent(value: content.value),
      ),
      BasicContentKind.emoji => wire.BasicPayload(
        emoji: wire.EmojiContent(value: content.value),
      ),
      BasicContentKind.sticker => wire.BasicPayload(
        sticker: wire.StickerContent(
          packId: content.packId,
          stickerId: content.stickerId,
        ),
      ),
    };
    final encoded = Uint8List.fromList(payload.writeToBuffer());
    if (encoded.length > maxPayloadBytes) {
      throw const FormatException('第一类消息超过最大载荷');
    }
    return encoded;
  }

  static BasicContent decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxPayloadBytes) {
      throw const FormatException('第一类消息载荷大小不合法');
    }
    late final wire.BasicPayload payload;
    try {
      payload = wire.BasicPayload.fromBuffer(bytes);
    } on Object {
      throw const FormatException('第一类消息不是合法 protobuf');
    }
    if (payload.unknownFields.isNotEmpty) {
      throw const FormatException('第一类消息包含未知字段');
    }
    final content = switch (payload.whichContent()) {
      wire.BasicPayload_Content.text => _decodeText(payload.text),
      wire.BasicPayload_Content.emoji => _decodeEmoji(payload.emoji),
      wire.BasicPayload_Content.sticker => _decodeSticker(payload.sticker),
      wire.BasicPayload_Content.notSet => throw const FormatException(
        '第一类消息内容类型缺失',
      ),
    };
    _validate(content);
    return content;
  }

  static BasicContent _decodeText(wire.TextContent value) {
    _rejectUnknown(value);
    return BasicContent.text(value.value);
  }

  static BasicContent _decodeEmoji(wire.EmojiContent value) {
    _rejectUnknown(value);
    return BasicContent.emoji(value.value);
  }

  static BasicContent _decodeSticker(wire.StickerContent value) {
    _rejectUnknown(value);
    return BasicContent.sticker(
      packId: value.packId,
      stickerId: value.stickerId,
    );
  }

  static void _rejectUnknown(GeneratedMessage message) {
    if (message.unknownFields.isNotEmpty) {
      throw const FormatException('第一类消息子结构包含未知字段');
    }
  }

  static void _validate(BasicContent content) {
    switch (content.kind) {
      case BasicContentKind.text:
        final value = content.value ?? '';
        final length = utf8.encode(value).length;
        if (length == 0 || length > maxTextBytes) {
          throw const FormatException('文本消息大小不合法');
        }
      case BasicContentKind.emoji:
        final value = content.value ?? '';
        final length = utf8.encode(value).length;
        if (length == 0 ||
            length > maxEmojiBytes ||
            !BasicContent.isEmojiOnly(value)) {
          throw const FormatException('emoji 消息内容不合法');
        }
      case BasicContentKind.sticker:
        if (!_stickerId.hasMatch(content.packId ?? '') ||
            !_stickerId.hasMatch(content.stickerId ?? '')) {
          throw const FormatException('贴纸标识不合法');
        }
    }
  }
}
