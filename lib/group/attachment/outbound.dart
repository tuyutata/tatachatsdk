import '../../core/media_content.dart';
import '../../mls/mls_session.dart';

/// 单次 OpenMLS 加密后的群聊第二类媒体消息，随后按成员扇出消息。
final class GroupAttachmentOutbound {
  const GroupAttachmentOutbound({required this.content, required this.wire});

  final MediaContent content;
  final MlsWireMessage wire;
}
