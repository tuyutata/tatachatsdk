import '../../core/media_content.dart';

/// 已完成端到端解密与严格协议校验的私聊第二类媒体消息。
final class DirectAttachmentInbound {
  const DirectAttachmentInbound({
    required this.conversationId,
    required this.content,
  });

  final String conversationId;
  final MediaContent content;
}
