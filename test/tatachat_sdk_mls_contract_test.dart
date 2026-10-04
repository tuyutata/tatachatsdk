import 'dart:io';
import 'dart:typed_data';

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

  test(
    'MLS state reset removes only SDK state and keeps the active key',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'chat-sdk-state-reset-',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
      final directory = Directory('${root.path}/device-a');
      final store = MlsStateStore(
        directory,
        ownerUserId: 'user-a',
        stateKey: key,
      );
      await directory.create(recursive: true);
      await File(
        '${directory.path}/openmls_storage.bin',
      ).writeAsBytes(<int>[1]);
      await File('${directory.path}/device.bin').writeAsBytes(<int>[2]);
      await File(
        '${directory.path}/pending_inbound.bin',
      ).writeAsBytes(<int>[3]);

      await store.reset();

      expect(await directory.exists(), isTrue);
      expect(await directory.list().toList(), isEmpty);
      expect(
        store.stateKey,
        orderedEquals(List<int>.generate(32, (index) => index)),
      );
    },
  );

  test('native state failures expose stable redacted codes', () {
    final storage = MlsNativeException.fromTechnicalMessage(
      'CHAT_MLS_STORAGE_AUTH_FAILED:detail',
    );
    final device = MlsNativeException.fromTechnicalMessage(
      'CHAT_MLS_DEVICE_AUTH_FAILED:detail',
    );
    final invalid = MlsNativeException.fromTechnicalMessage(
      'CHAT_MLS_STATE_INVALID:detail',
    );

    expect(storage.code, MlsNativeErrorCode.storageAuthFailed);
    expect(storage.diagnosticCode, 'storage_auth_failed');
    expect(storage.requiresStateReset, isTrue);
    expect(device.code, MlsNativeErrorCode.deviceAuthFailed);
    expect(invalid.code, MlsNativeErrorCode.stateInvalid);
    expect(chatSdkDiagnosticCode(StateError('hidden')), 'operation_failed');
  });
}
