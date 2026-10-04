import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/protocol.dart' as pb;
import 'package:tatachat_sdk/tatachat_sdk.dart';

const _aliceUserId = 'CN220-CTZN2-100000001-2026';
const _bobUserId = 'CN220-CTZN2-100000002-2026';
const _cipherKey = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _cipherSha256 =
    '0000000000000000000000000000000000000000000000000000000000000000';

ChatStoredMessage _stored({
  required String messageId,
  required ChatMessageKind kind,
  required String plaintext,
  String direction = 'outgoing',
  ChatMessageDeliveryState state = ChatMessageDeliveryState.sent,
}) {
  final outgoing = direction == 'outgoing';
  return ChatStoredMessage(
    messageId: messageId,
    conversationId: 'dm:alice:bob',
    direction: direction,
    senderUserId: outgoing ? _aliceUserId : _bobUserId,
    recipientUserId: outgoing ? _bobUserId : _aliceUserId,
    messageKind: kind,
    deliveryState: state,
    createdAtMillis: 1000,
    plaintext: plaintext,
  );
}

void main() {
  test('text messages map without user-visible delivery or read status', () {
    final outgoing =
        storedMessageToChatMessage(
              _stored(
                messageId: 'env-out',
                kind: ChatMessageKind.text,
                plaintext: ChatPayloadCodec.encode(ChatContent.text('hello')),
              ),
              currentUserId: _aliceUserId,
            )
            as TextMessage;
    expect(outgoing.text, 'hello');
    expect(outgoing.status, isNull);
    expect(outgoing.sentAt, isNull);
    expect(outgoing.deliveredAt, isNull);
    expect(outgoing.failedAt, isNull);
    expect(outgoing.metadata?['is_mine'], isTrue);

    final incoming =
        storedMessageToChatMessage(
              _stored(
                messageId: 'env-in',
                kind: ChatMessageKind.text,
                direction: 'incoming',
                state: ChatMessageDeliveryState.receivedByDevice,
                plaintext: ChatPayloadCodec.encode(ChatContent.text('hi')),
              ),
              currentUserId: _aliceUserId,
            )
            as TextMessage;
    expect(incoming.text, 'hi');
    expect(incoming.status, isNull);
    expect(incoming.sentAt, isNull);
    expect(incoming.deliveredAt, isNull);
    expect(incoming.failedAt, isNull);
    expect(incoming.metadata?['is_mine'], isFalse);
  });

  test(
    'image maps to ImageMessage with resolved local path and dimensions',
    () {
      final payload = ChatPayloadCodec.encode(
        ChatContent.media(
          kind: ChatMessageKind.image,
          attachmentId: 'att-1',
          fileName: 'p.jpg',
          mime: 'image/jpeg',
          byteSize: 2048,
          cipherKey: _cipherKey,
          cipherByteSize: 16384,
          cipherSha256: _cipherSha256,
          width: 800,
          height: 600,
          blurhash: 'L6',
        ),
      );
      final msg =
          storedMessageToChatMessage(
                _stored(
                  messageId: 'env-img',
                  kind: ChatMessageKind.image,
                  plaintext: payload,
                ),
                currentUserId: _aliceUserId,
                resolveLocalMediaPath: (c) =>
                    c.attachmentId == 'att-1' ? '/cache/p.jpg' : null,
              )
              as ImageMessage;
      expect(msg.source, '/cache/p.jpg');
      expect(msg.width, 800);
      expect(msg.height, 600);
      expect(msg.blurhash, 'L6');
      expect(msg.metadata?['message_kind'], 'image');
      expect(msg.metadata?['file_name'], 'p.jpg'); // 全屏查看/存相册用
      expect(msg.metadata?['attachment_control_plaintext'], payload);
    },
  );

  test(
    'image without cached bytes yields empty source for the placeholder',
    () {
      final payload = ChatPayloadCodec.encode(
        ChatContent.media(
          kind: ChatMessageKind.image,
          attachmentId: 'att-2',
          fileName: 'p.jpg',
          mime: 'image/jpeg',
          byteSize: 2048,
          cipherKey: _cipherKey,
          cipherByteSize: 16384,
          cipherSha256: _cipherSha256,
        ),
      );
      final msg =
          storedMessageToChatMessage(
                _stored(
                  messageId: 'env-img2',
                  kind: ChatMessageKind.image,
                  plaintext: payload,
                ),
                currentUserId: _aliceUserId,
                resolveLocalMediaPath: (_) => null,
              )
              as ImageMessage;
      expect(msg.source, '');
    },
  );

  test(
    'video maps to VideoMessage with dims and tap-to-save control metadata',
    () {
      final payload = ChatPayloadCodec.encode(
        ChatContent.media(
          kind: ChatMessageKind.video,
          attachmentId: 'att-v',
          fileName: 'clip.mp4',
          mime: 'video/mp4',
          byteSize: 8192,
          cipherKey: _cipherKey,
          cipherByteSize: 16384,
          cipherSha256: _cipherSha256,
          width: 1920,
          height: 1080,
          durationMs: 4200,
          blurhash: 'L6Pj0',
        ),
      );
      final msg =
          storedMessageToChatMessage(
                _stored(
                  messageId: 'env-vid',
                  kind: ChatMessageKind.video,
                  plaintext: payload,
                ),
                currentUserId: _aliceUserId,
                resolveLocalMediaPath: (_) => '/cache/clip.mp4',
              )
              as VideoMessage;
      expect(msg.name, 'clip.mp4');
      expect(msg.width, 1920);
      expect(msg.height, 1080);
      expect(msg.size, 8192);
      expect(msg.source, '/cache/clip.mp4');
      expect(msg.metadata?['message_kind'], 'video');
      // _buildVideoMessage 读这些键:blurhash 出封面占位、file_name 供播放页存相册、
      // 控制载荷供另存。
      expect(msg.metadata?['blurhash'], 'L6Pj0');
      expect(msg.metadata?['file_name'], 'clip.mp4');
      expect(msg.metadata?['attachment_control_plaintext'], payload);
    },
  );

  test('file maps to FileMessage with name/size/mime', () {
    final payload = ChatPayloadCodec.encode(
      ChatContent.media(
        kind: ChatMessageKind.file,
        attachmentId: 'att-3',
        fileName: 'doc.pdf',
        mime: 'application/pdf',
        byteSize: 4096,
        cipherKey: _cipherKey,
        cipherByteSize: 16384,
        cipherSha256: _cipherSha256,
      ),
    );
    final msg =
        storedMessageToChatMessage(
              _stored(
                messageId: 'env-file',
                kind: ChatMessageKind.file,
                plaintext: payload,
              ),
              currentUserId: _aliceUserId,
              resolveLocalMediaPath: (_) => '/cache/doc.pdf',
            )
            as FileMessage;
    expect(msg.name, 'doc.pdf');
    expect(msg.size, 4096);
    expect(msg.mimeType, 'application/pdf');
    expect(msg.source, '/cache/doc.pdf');
  });

  test('audio maps to AudioMessage with duration and local path', () {
    final payload = ChatPayloadCodec.encode(
      ChatContent.media(
        kind: ChatMessageKind.audio,
        attachmentId: 'att-audio',
        fileName: 'voice.m4a',
        mime: 'audio/mp4',
        byteSize: 2048,
        cipherKey: _cipherKey,
        cipherByteSize: 16384,
        cipherSha256: _cipherSha256,
        durationMs: 9200,
      ),
    );
    final message =
        storedMessageToChatMessage(
              _stored(
                messageId: 'env-audio',
                kind: ChatMessageKind.audio,
                plaintext: payload,
              ),
              currentUserId: _aliceUserId,
              resolveLocalMediaPath: (_) => '/cache/voice.m4a',
            )
            as AudioMessage;
    expect(message.source, '/cache/voice.m4a');
    expect(message.duration, const Duration(milliseconds: 9200));
    expect(message.size, 2048);
    expect(message.metadata?['message_kind'], 'audio');
    expect(message.metadata?['attachment_control_plaintext'], payload);
  });

  test('sticker maps to a custom message carrying pack/sticker ids', () {
    final payload = ChatPayloadCodec.encode(
      ChatContent.sticker(packId: 'fluent3d', stickerId: 'grinning_face'),
    );
    final msg =
        storedMessageToChatMessage(
              _stored(
                messageId: 'env-st',
                kind: ChatMessageKind.sticker,
                plaintext: payload,
              ),
              currentUserId: _aliceUserId,
            )
            as CustomMessage;
    // 贴纸走 Message.custom,由 chat_page 的 customMessageBuilder 按 id 渲染;
    // id 只经 metadata 携带,不占正文文本。
    expect(msg.metadata?['pack_id'], 'fluent3d');
    expect(msg.metadata?['sticker_id'], 'grinning_face');
  });

  test('门④:声明超限的媒体渲染为拒收占位,且不解析本机路径', () {
    final payload = ChatPayloadCodec.encode(
      ChatContent.media(
        kind: ChatMessageKind.image,
        attachmentId: 'att-big',
        fileName: 'big.jpg',
        mime: 'image/jpeg',
        byteSize: _TestMediaLimitPolicy.maxBytes + 1,
        cipherKey: _cipherKey,
        cipherByteSize: _TestMediaLimitPolicy.maxBytes + 1024,
        cipherSha256: _cipherSha256,
      ),
    );
    var resolverCalled = false;
    final msg =
        storedMessageToChatMessage(
              _stored(
                messageId: 'env-big',
                kind: ChatMessageKind.image,
                plaintext: payload,
              ),
              currentUserId: _aliceUserId,
              mediaLimits: const _TestMediaLimitPolicy(),
              resolveLocalMediaPath: (_) {
                resolverCalled = true;
                return '/cache/big.jpg';
              },
            )
            as TextMessage;
    expect(msg.metadata?['oversized'], isTrue);
    expect(msg.text, contains('已拒收'));
    // 拒收媒体不解析路径,不诱导用户去拉取。
    expect(resolverCalled, isFalse);
  });

  test('generated protobuf exposes device-scoped MLS message', () {
    final message = pb.EncryptedMessage(
      deliveries: <pb.EncryptedDelivery>[
        pb.EncryptedDelivery(
          recipient: pb.Recipient(userId: 'user-b', deviceId: 'device-b'),
        ),
      ],
    );
    expect(message.recipientDeviceId, 'device-b');
  });
}

class _TestMediaLimitPolicy implements ChatMediaLimitPolicy {
  const _TestMediaLimitPolicy();

  static const int maxBytes = 10 * 1024 * 1024;

  @override
  int limitForKind(ChatMessageKind kind) => maxBytes;

  @override
  int limitForMime(String contentType) => maxBytes;

  @override
  bool exceedsForKind(ChatMessageKind kind, int byteSize) =>
      byteSize > maxBytes;
}
