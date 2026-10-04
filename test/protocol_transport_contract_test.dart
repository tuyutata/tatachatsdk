import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  test('one message keeps distinct OpenMLS ciphertext per device', () {
    final message = EncryptedMessage(
      messageId: 'message-a',
      conversationId: 'conversation-a',
      senderUserId: 'user-a',
      senderDeviceId: 'device-a',
      deliveries: <EncryptedDelivery>[
        EncryptedDelivery(
          recipient: Recipient(userId: 'user-b', deviceId: 'device-b'),
          openmlsCiphertext: <int>[1, 2, 3],
        ),
        EncryptedDelivery(
          recipient: Recipient(userId: 'user-b', deviceId: 'device-c'),
          openmlsCiphertext: <int>[4, 5, 6],
        ),
      ],
      createdAtMillis: Int64.ONE,
    );
    final decoded = EncryptedMessage.fromBuffer(message.writeToBuffer());
    expect(decoded.messageId, 'message-a');
    expect(decoded.deliveries[0].openmlsCiphertext, <int>[1, 2, 3]);
    expect(decoded.deliveries[1].openmlsCiphertext, <int>[4, 5, 6]);
  });

  test('network endpoints fail closed unless encrypted', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    expect(
      () => TataChatServerAccess(
        tataChatServerUrl: Uri.parse(
          'ws'
          '://chat.example.test',
        ),
        tataChatServerToken: 'token',
        expiresAtMillis: now + 120000,
      ).validate(now),
      throwsStateError,
    );
    expect(
      () => TataChatServerAccess(
        tataChatServerUrl: Uri.parse(
          'http'
          '://chat.example.test',
        ),
        tataChatServerToken: 'token',
        expiresAtMillis: now + 120000,
      ).validate(now),
      throwsStateError,
    );
  });
}
