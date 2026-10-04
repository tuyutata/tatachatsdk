import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../core/chat_content.dart';
import '../core/chat_message.dart';
import '../runtime/media_limit_policy.dart';
import '../storage/records.dart';

/// 解析媒体消息在本机缓存中的绝对路径。字节尚未到达时返回 null,由 UI 占位。
typedef ChatMediaPathResolver = String? Function(ChatContent content);

/// 把 TataChatSDK 本地消息转换为现成聊天 UI 的消息模型。
///
/// 消息类型来自端到端载荷([ChatPayloadCodec]),按 kind 分发为文本 / 图片 /
/// 视频 / 文件 / 语音 / 贴纸。附件字节走既有端到端通道,渲染时用
/// [resolveLocalMediaPath] 查本机缓存路径,未到达则留空 source 由 UI 占位。
Message storedMessageToChatMessage(
  ChatStoredMessage message, {
  required String currentUserId,
  ChatMediaLimitPolicy mediaLimits = const ChatUnlimitedMediaLimitPolicy(),
  ChatMediaPathResolver? resolveLocalMediaPath,
}) {
  final createdAt = DateTime.fromMillisecondsSinceEpoch(
    message.createdAtMillis,
  ).toUtc();
  final content = ChatPayloadCodec.decode(message.plaintext ?? '');
  final metadata = <String, dynamic>{
    'conversation_id': message.conversationId,
    'direction': message.direction,
    'is_mine': message.senderUserId == currentUserId,
    'message_kind': message.messageKind.name,
  };

  // 门④:控制消息声明的大小超出该类型上限 → 渲染"已拒收"占位,永不解析/展示其
  // 字节(接收端本就在字节层拒收,此处保证 UI 一致,不诱导用户去拉取)。
  if (content.isMedia &&
      mediaLimits.exceedsForKind(content.kind, content.byteSize ?? 0)) {
    return Message.text(
      id: message.messageId,
      authorId: message.senderUserId,
      createdAt: createdAt,
      text: '⚠️ 对方发送的媒体超出大小上限，已拒收',
      metadata: {...metadata, 'oversized': true},
    );
  }

  switch (content.kind) {
    case ChatMessageKind.text:
      return Message.text(
        id: message.messageId,
        authorId: message.senderUserId,
        createdAt: createdAt,
        text: content.text ?? '',
        metadata: metadata,
      );
    case ChatMessageKind.image:
      return Message.image(
        id: message.messageId,
        authorId: message.senderUserId,
        createdAt: createdAt,
        source: resolveLocalMediaPath?.call(content) ?? '',
        blurhash: content.blurhash,
        width: content.width?.toDouble(),
        height: content.height?.toDouble(),
        size: content.byteSize,
        metadata: {
          ...metadata,
          'attachment_id': content.attachmentId,
          'attachment_control_plaintext': message.plaintext ?? '',
          'file_name': content.fileName,
        },
      );
    case ChatMessageKind.video:
      return Message.video(
        id: message.messageId,
        authorId: message.senderUserId,
        createdAt: createdAt,
        source: resolveLocalMediaPath?.call(content) ?? '',
        name: content.fileName,
        width: content.width?.toDouble(),
        height: content.height?.toDouble(),
        size: content.byteSize,
        metadata: {
          ...metadata,
          'attachment_id': content.attachmentId,
          'attachment_control_plaintext': message.plaintext ?? '',
          'blurhash': content.blurhash,
          'file_name': content.fileName,
        },
      );
    case ChatMessageKind.file:
      return Message.file(
        id: message.messageId,
        authorId: message.senderUserId,
        createdAt: createdAt,
        source: resolveLocalMediaPath?.call(content) ?? '',
        name: content.fileName ?? '文件',
        size: content.byteSize,
        mimeType: content.mime,
        metadata: {
          ...metadata,
          'attachment_id': content.attachmentId,
          'attachment_control_plaintext': message.plaintext ?? '',
        },
      );
    case ChatMessageKind.audio:
      return Message.audio(
        id: message.messageId,
        authorId: message.senderUserId,
        createdAt: createdAt,
        source: resolveLocalMediaPath?.call(content) ?? '',
        duration: Duration(milliseconds: content.durationMs ?? 0),
        size: content.byteSize,
        metadata: {
          ...metadata,
          'attachment_id': content.attachmentId,
          'attachment_control_plaintext': message.plaintext ?? '',
          'file_name': content.fileName,
        },
      );
    case ChatMessageKind.sticker:
      // 贴纸走 Message.custom,由 host chat page 的 customMessageBuilder 按 id 渲染内置
      // Fluent 3D PNG(无气泡大图);id 未内置(对端资产旧/缺)时降级为占位。
      return Message.custom(
        id: message.messageId,
        authorId: message.senderUserId,
        createdAt: createdAt,
        metadata: {
          ...metadata,
          'pack_id': content.packId,
          'sticker_id': content.stickerId,
        },
      );
  }
}

/// 把本地消息列表转换为聊天 UI controller 的初始列表。
List<Message> storedMessagesToChatMessages(
  List<ChatStoredMessage> messages, {
  required String currentUserId,
  ChatMediaLimitPolicy mediaLimits = const ChatUnlimitedMediaLimitPolicy(),
  ChatMediaPathResolver? resolveLocalMediaPath,
}) {
  return messages
      .map(
        (message) => storedMessageToChatMessage(
          message,
          currentUserId: currentUserId,
          mediaLimits: mediaLimits,
          resolveLocalMediaPath: resolveLocalMediaPath,
        ),
      )
      .toList(growable: false);
}
