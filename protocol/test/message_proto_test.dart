import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_protocol/message.dart';

void main() {

  test('EncryptedMessage 只往返端到端密文瞬时投递字段', () {
    final message = EncryptedMessage(
      messageId: 'env-1',
      conversationId: 'conv-1',
      senderUserId:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      senderDeviceId: 'alice-phone',
      deliveries: <EncryptedDelivery>[
        EncryptedDelivery(
          recipient: Recipient(
            userId:
                '0x2222222222222222222222222222222222222222222222222222222222222222',
            deviceId: 'bob-phone',
          ),
          openmlsCiphertext: <int>[0xaa, 0xbb, 0xcc],
        ),
      ],
      createdAtMillis: Int64(1),
    );

    final restored = EncryptedMessage.fromBuffer(message.writeToBuffer());
    expect(restored.messageId, 'env-1');
    expect(restored.openmlsCiphertext, [0xaa, 0xbb, 0xcc]);
    expect(restored.recipientDeviceId, 'bob-phone');
    expect(
      restored.recipientUserId,
      '0x2222222222222222222222222222222222222222222222222222222222222222',
    );
  });

  test('ChatRoute 只保存宿主确认的设备路由', () {
    final route = ChatRoute(
      peerUserId:
          '0x2222222222222222222222222222222222222222222222222222222222222222',
      deviceId: 'bob-phone',
      createdAtMillis: Int64(1),
      expiresAtMillis: Int64(2),
    );

    final restored = ChatRoute.fromBuffer(route.writeToBuffer());
    expect(
      restored.peerUserId,
      '0x2222222222222222222222222222222222222222222222222222222222222222',
    );
    expect(restored.deviceId, 'bob-phone');
  });
  test('protocol uses deployment-neutral user identifiers', () {
    final route = ChatRoute(
      peerUserId: 'user-42',
      deviceId: 'device-a',
      createdAtMillis: Int64.ONE,
      expiresAtMillis: Int64.TWO,
    );
    final message = EncryptedMessage(
      messageId: 'message-a',
      conversationId: 'conversation-a',
      senderUserId: 'user-1',
      senderDeviceId: 'device-a',
      deliveries: <EncryptedDelivery>[
        EncryptedDelivery(
          recipient: Recipient(userId: 'user-2', deviceId: 'device-b'),
          openmlsCiphertext: <int>[1, 2, 3],
        ),
      ],
      createdAtMillis: Int64.ONE,
    );

    expect(route.peerUserId, 'user-42');
    expect(message.senderUserId, 'user-1');
    expect(message.recipientUserId, 'user-2');
    expect(message.openmlsCiphertext, <int>[1, 2, 3]);
  });
}

