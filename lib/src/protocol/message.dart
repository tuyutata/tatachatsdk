import 'message.pb.dart';

export 'message.pb.dart';

/// 当前 SDK 每个传输记录只承载一个接收设备；多设备消息由同一 message_id
/// 下的多条传输记录组成，保证每台设备拿到自己的 OpenMLS 密文。
extension EncryptedMessageDeliveryView on EncryptedMessage {
  EncryptedDelivery get onlyDelivery {
    if (deliveries.length != 1 || !deliveries.single.hasRecipient()) {
      throw StateError('encrypted message must contain exactly one delivery');
    }
    return deliveries.single;
  }

  String get recipientUserId => onlyDelivery.recipient.userId;
  String get recipientDeviceId => onlyDelivery.recipient.deviceId;
  List<int> get openmlsCiphertext => onlyDelivery.openmlsCiphertext;
}
