import '../../core/basic_content.dart';

/// OpenMLS 解密后通过严格协议校验的群聊第一类消息。
final class GroupMessageInbound {
  const GroupMessageInbound({required this.groupId, required this.content});

  final String groupId;
  final BasicContent content;
}
