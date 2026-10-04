import 'package:fixnum/fixnum.dart';

import '../protocol/message.dart';

/// 发送端已知的 MLS wire 语义；接收端由 OpenMLS 解析真实类型。
enum MlsMessageKind { welcome, commit, application, unknown }

/// 一条标准 MLS wire message。
class MlsWireMessage {
  const MlsWireMessage({
    required this.wireBytes,
    required this.conversationId,
    this.messageKind = MlsMessageKind.unknown,
  });

  final List<int> wireBytes;
  final String conversationId;
  final MlsMessageKind messageKind;

  String get wireHex =>
      wireBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  EncryptedMessage toEncryptedMessage({
    required String messageId,
    required String senderUserId,
    required String recipientUserId,
    required String senderDeviceId,
    required String recipientDeviceId,
    required int createdAtMillis,
  }) {
    return EncryptedMessage(
      messageId: messageId,
      conversationId: conversationId,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      deliveries: <EncryptedDelivery>[
        EncryptedDelivery(
          recipient: Recipient(
            userId: recipientUserId,
            deviceId: recipientDeviceId,
          ),
          openmlsCiphertext: wireBytes,
        ),
      ],
      createdAtMillis: Int64(createdAtMillis),
    );
  }
}

/// 从服务端不透明消息恢复 wire bytes；消息类型必须交给 OpenMLS 判断。
MlsWireMessage mlsWireMessageFromEncryptedMessage(EncryptedMessage message) {
  return MlsWireMessage(
    wireBytes: List<int>.from(message.openmlsCiphertext),
    conversationId: message.conversationId,
  );
}
