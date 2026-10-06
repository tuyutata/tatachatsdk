import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

// 合同测试锁定 TataChatSDK 的中性身份、状态清理边界和脱敏错误码。
void main() {
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

  test('TataChatSDK source does not own product identity names', () {
    final sourceRoot = Directory('lib');
    final legacyIdentityWord = String.fromCharCodes(const <int>[99, 105, 100]);
    final titledLegacyIdentityWord =
        '${legacyIdentityWord[0].toUpperCase()}${legacyIdentityWord.substring(1)}';
    final unrelatedNativeLibrary = String.fromCharCodes(const <int>[
      115,
      109,
      111,
      108,
      100,
      111,
      116,
    ]);
    final forbidden = RegExp(
      <String>[
        legacyIdentityWord,
        '_number|${titledLegacyIdentityWord}Number|'
            '${legacyIdentityWord}Number|chat_mls_|lib$unrelatedNativeLibrary',
      ].join(),
    );
    final violations = <String>[];

    for (final entity in sourceRoot.listSync(recursive: true)) {
      if (entity is! File ||
          !(entity.path.endsWith('.dart') || entity.path.endsWith('.proto'))) {
        continue;
      }
      if (forbidden.hasMatch(entity.readAsStringSync())) {
        violations.add(entity.path);
      }
    }

    expect(violations, isEmpty);
  });

  test('原生存储错误只有固定分类，不授权自动清理', () {
    final storage = MlsNativeException.fromTechnicalMessage(
      'CHAT_MLS_STORAGE_READ_FAILED:detail',
    );
    final invalid = MlsNativeException.fromTechnicalMessage(
      'CHAT_MLS_STATE_INVALID:detail',
    );
    expect(storage.code, MlsNativeErrorCode.storageReadFailed);
    expect(storage.diagnosticCode, 'storage_read_failed');
    expect(invalid.code, MlsNativeErrorCode.stateInvalid);
    expect(chatSdkDiagnosticCode(StateError('hidden')), 'operation_failed');
  });
}
