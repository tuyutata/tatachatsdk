import '../../core/basic_content.dart';
import '../../mls/mls_session.dart';

/// 单次 OpenMLS 加密后的群聊第一类消息，随后按成员扇出消息。
final class GroupMessageOutbound {
  const GroupMessageOutbound({required this.content, required this.wire});

  final BasicContent content;
  final MlsWireMessage wire;
}
