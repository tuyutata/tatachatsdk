import '../../core/media_content.dart';

/// OpenMLS 解密后通过严格协议校验的群聊第二类媒体消息。
final class GroupAttachmentInbound {
  const GroupAttachmentInbound({required this.groupId, required this.content});

  final String groupId;
  final MediaContent content;
}
