import '../../core/basic_content.dart';
import '../../core/serial_executor.dart';
import '../../mls/mls_group_boundary.dart';
import 'inbound.dart';
import 'outbound.dart';

/// 群聊第一类消息只加密一次，同一群内密码学操作严格串行。
final class GroupMessageChannel {
  GroupMessageChannel(this._crypto, {SerialExecutor? serialExecutor})
    : _serial = serialExecutor ?? SerialExecutor();

  final MlsGroupCrypto _crypto;
  final SerialExecutor _serial;

  Future<GroupMessageOutbound> encrypt({
    required String groupId,
    required BasicContent content,
  }) => _serial.run(groupId, () async {
    final wire = await _crypto.groupCreateMessage(
      groupId,
      BasicContentCodec.encode(content),
    );
    return GroupMessageOutbound(content: content, wire: wire);
  });

  Future<GroupMessageInbound> decodeApplication({
    required String groupId,
    required List<int> plaintext,
  }) => _serial.run(
    groupId,
    () async => GroupMessageInbound(
      groupId: groupId,
      content: BasicContentCodec.decode(plaintext),
    ),
  );
}
