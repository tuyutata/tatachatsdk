import 'message.pb.dart';

export 'message.pb.dart';

/// 每个传输记录只承载一个接收设备，并使用稳定的设备投递编号。
/// 同一逻辑消息复用一份OpenMLS密文，分别持久化每台设备的投递事实。
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
