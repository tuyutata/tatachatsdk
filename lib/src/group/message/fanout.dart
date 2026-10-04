import '../../core/message_id.dart';
import '../../mls/mls_group_boundary.dart';
import '../../mls/mls_session.dart';
import '../../protocol/message.dart';

/// 一份群 OpenMLS 密文按成员生成独立路由消息，密文绝不重复加密。
final class GroupMessageFanout {
  GroupMessageFanout._();

  static List<EncryptedMessage> fanOut({
    required MlsWireMessage wire,
    required Iterable<MlsMemberIdentity> recipients,
    required String senderUserId,
    required String senderDeviceId,
    required int createdAtMillis,
  }) {
    if (senderUserId.isEmpty || senderDeviceId.isEmpty) {
      throw ArgumentError('群消息发送身份不完整');
    }
    final unique = <String, MlsMemberIdentity>{};
    for (final recipient in recipients) {
      if (recipient.userId.isEmpty ||
          recipient.deviceId.isEmpty ||
          (recipient.userId == senderUserId &&
              recipient.deviceId == senderDeviceId)) {
        continue;
      }
      unique[recipient.wireValue] = recipient;
    }
    return unique.values
        .map((recipient) {
          final messageId = MessageId.derive(
            conversationId: wire.conversationId,
            senderUserId: senderUserId,
            recipientUserId: '${recipient.userId}:${recipient.deviceId}',
            createdAtMillis: createdAtMillis,
            encryptedMessage: wire.wireBytes,
          );
          return wire.toEncryptedMessage(
            messageId: messageId,
            senderUserId: senderUserId,
            recipientUserId: recipient.userId,
            senderDeviceId: senderDeviceId,
            recipientDeviceId: recipient.deviceId,
            createdAtMillis: createdAtMillis,
          );
        })
        .toList(growable: false);
  }
}
