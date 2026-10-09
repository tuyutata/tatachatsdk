import '../../core/basic_content.dart';

/// 已完成端到端解密与严格协议校验的私聊第一类消息。
final class DirectMessageInbound {
  const DirectMessageInbound({
    required this.conversationId,
    required this.content,
  });

  final String conversationId;
  final BasicContent content;
}
