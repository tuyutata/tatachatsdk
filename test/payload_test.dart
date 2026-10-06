import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  test('text content round-trips through the TataChatSDK codec', () {
    final encoded = ChatPayloadCodec.encode(ChatContent.text('你好'));
    final wire = BasicContentCodec.decode(_decodeWireBytes(encoded));
    expect(wire.kind, BasicContentKind.text);
    expect(wire.value, '你好');
    final decoded = ChatPayloadCodec.decode(encoded);
    expect(decoded.kind, ChatMessageKind.text);
    expect(decoded.text, '你好');
    expect(decoded.summary, '你好');
  });

  test('pure emoji uses the dedicated TataChatSDK emoji branch', () {
    final encoded = ChatPayloadCodec.encode(ChatContent.text('😀'));
    final wire = BasicContentCodec.decode(_decodeWireBytes(encoded));
    expect(wire.kind, BasicContentKind.emoji);
    expect(ChatPayloadCodec.decode(encoded).text, '😀');
  });

  test('all four media kinds use the TataChatSDK protobuf descriptor', () {
    final cases =
        <ChatMessageKind, ({String name, String mime, int? duration})>{
          ChatMessageKind.image: (
            name: 'IMG.jpg',
            mime: 'image/jpeg',
            duration: null,
          ),
          ChatMessageKind.video: (
            name: 'clip.mp4',
            mime: 'video/mp4',
            duration: 4200,
          ),
          ChatMessageKind.file: (
            name: 'doc.pdf',
            mime: 'application/pdf',
            duration: null,
          ),
          ChatMessageKind.audio: (
            name: 'voice.m4a',
            mime: 'audio/mp4',
            duration: 12500,
          ),
        };
    for (final entry in cases.entries) {
      final visual =
          entry.key == ChatMessageKind.image ||
          entry.key == ChatMessageKind.video;
      final encoded = ChatPayloadCodec.encode(
        ChatContent.media(
          kind: entry.key,
          attachmentId: 'att-1',
          fileName: entry.value.name,
          mime: entry.value.mime,
          byteSize: 2048,
          width: visual ? 1080 : null,
          height: visual ? 1920 : null,
          durationMs: entry.value.duration,
          blurhash: visual ? 'L6Pj0' : null,

      attachmentChatEpoch: 1,
      attachmentGroupId: 'attachment:CID-A:' + '11' * 32 + ':' + 'att-1',
      attachmentWelcome: 'AQID',
      attachmentMemberIdentities: ['CID-A:' + '11' * 32, 'CID-B:' + '22' * 32],
      attachmentSenderMemberIdentity: 'CID-A:' + '11' * 32,
      attachmentChunkCount: ((2048) + 1024 * 1024 - 1) ~/ (1024 * 1024),
      plainSha256: '00' * 32,
          cipherByteSize: 2084,
          cipherSha256:
              '0000000000000000000000000000000000000000000000000000000000000000',
        ),
      );
      final wire = MediaContentCodec.decode(_decodeWireBytes(encoded));
      expect(wire.attachmentId, 'att-1');
      final decoded = ChatPayloadCodec.decode(encoded);
      expect(decoded.kind, entry.key);
      expect(decoded.isMedia, isTrue);
      expect(decoded.fileName, entry.value.name);
      expect(decoded.mime, entry.value.mime);
      expect(decoded.byteSize, 2048);
      expect(decoded.durationMs, entry.value.duration);
      expect(decoded.cipherByteSize, 2084);
    }
  });

  test('媒体非法描述与非协议JSON拒绝', () {
    expect(
      () => ChatPayloadCodec.encode(
        ChatContent.media(
          kind: ChatMessageKind.audio,
          attachmentId: 'voice-1',
          fileName: 'voice.m4a',
          mime: 'video/mp4',
          byteSize: 1,
          durationMs: 1000,

      attachmentChatEpoch: 1,
      attachmentGroupId: 'attachment:CID-A:' + '11' * 32 + ':' + 'voice-1',
      attachmentWelcome: 'AQID',
      attachmentMemberIdentities: ['CID-A:' + '11' * 32, 'CID-B:' + '22' * 32],
      attachmentSenderMemberIdentity: 'CID-A:' + '11' * 32,
      attachmentChunkCount: ((1) + 1024 * 1024 - 1) ~/ (1024 * 1024),
      plainSha256: '00' * 32,
          cipherByteSize: 21,
          cipherSha256:
              '1111111111111111111111111111111111111111111111111111111111111111',
        ),
      ),
      throwsFormatException,
    );
    for (final raw in const <String>[
      '',
      'not json {{{',
      '{"kind":"text","text":"x"}',
      '{"kind":"image","attachment_id":"a"}',
    ]) {
      expect(() => ChatPayloadCodec.decode(raw), throwsFormatException);
    }
  });

  test('sticker carries only ids and JSON-looking text remains text', () {
    final sticker = ChatPayloadCodec.decode(
      ChatPayloadCodec.encode(
        ChatContent.sticker(packId: 'fluent3d', stickerId: 'grinning_face'),
      ),
    );
    expect(sticker.kind, ChatMessageKind.sticker);
    expect(sticker.packId, 'fluent3d');
    expect(sticker.stickerId, 'grinning_face');
    expect(sticker.summary, '[贴纸]');
    expect(sticker.isMedia, isFalse);

    const jsonyText = '{"type":"unknown_chat_attachment","file_name":"x"}';
    final text = ChatPayloadCodec.decode(
      ChatPayloadCodec.encode(ChatContent.text(jsonyText)),
    );
    expect(text.kind, ChatMessageKind.text);
    expect(text.text, jsonyText);
  });

  test('media summaries are typed placeholders', () {
    String summaryOf(ChatContent content) =>
        ChatPayloadCodec.decode(ChatPayloadCodec.encode(content)).summary;
    ChatContent media(
      ChatMessageKind kind,
      String name,
      String mime, {
      int? durationMs,
    }) => ChatContent.media(
      kind: kind,
      attachmentId: 'a',
      fileName: name,
      mime: mime,
      byteSize: 1,
      durationMs: durationMs,

      attachmentChatEpoch: 1,
      attachmentGroupId: 'attachment:CID-A:' + '11' * 32 + ':' + 'a',
      attachmentWelcome: 'AQID',
      attachmentMemberIdentities: ['CID-A:' + '11' * 32, 'CID-B:' + '22' * 32],
      attachmentSenderMemberIdentity: 'CID-A:' + '11' * 32,
      attachmentChunkCount: ((1) + 1024 * 1024 - 1) ~/ (1024 * 1024),
      plainSha256: '00' * 32,
      cipherByteSize: 21,
      cipherSha256:
          '2222222222222222222222222222222222222222222222222222222222222222',
    );
    expect(
      summaryOf(media(ChatMessageKind.image, 'p.png', 'image/png')),
      '[图片]',
    );
    expect(
      summaryOf(
        media(ChatMessageKind.video, 'v.mp4', 'video/mp4', durationMs: 1000),
      ),
      '[视频]',
    );
    expect(
      summaryOf(media(ChatMessageKind.file, 'doc.pdf', 'application/pdf')),
      '[文件] doc.pdf',
    );
    expect(
      summaryOf(
        media(ChatMessageKind.audio, 'v.m4a', 'audio/mp4', durationMs: 1000),
      ),
      '[语音]',
    );
  });
}

List<int> _decodeWireBytes(String encoded) {
  final padding = '=' * ((4 - encoded.length % 4) % 4);
  return base64Url.decode('$encoded$padding');
}
