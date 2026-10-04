import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

/// MLS 本地状态消息测试密钥（固定 32 字节，仅测试用）。
final Uint8List _testStateKey = Uint8List.fromList(
  List<int>.generate(32, (i) => i),
);

void main() {
  test('MLS 运行上下文失效后立即清零状态消息密钥', () async {
    final dir = await Directory.systemTemp.createTemp('gmb-im-mls-dispose-');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final key = Uint8List.fromList(
      List<int>.generate(32, (index) => index + 1),
    );
    final store = MlsStateStore(
      dir,
      ownerUserId: 'CN220-CTZN2-100000001-2026',
      stateKey: key,
    );

    store.dispose();

    expect(key, everyElement(0));
    expect(store.stateKey, everyElement(0));
  });

  test(
    'serialized MLS wire preserves bytes and defers kind parsing to OpenMLS',
    () {
      const wire = MlsWireMessage(
        wireBytes: [0x01, 0x02],
        conversationId: 'conv-1',
        messageKind: MlsMessageKind.welcome,
      );
      final restored = mlsWireMessageFromEncryptedMessage(
        wire.toEncryptedMessage(
          messageId: 'env-1',
          senderUserId: 'alice',
          recipientUserId: 'bob',
          senderDeviceId: 'alice-phone',
          recipientDeviceId: 'bob-phone',
          createdAtMillis: 1,
        ),
      );

      expect(restored.wireBytes, [0x01, 0x02]);
      expect(restored.messageKind, MlsMessageKind.unknown);
    },
  );

  test('state store persists pending inbound messages', () async {
    final dir = await Directory.systemTemp.createTemp('gmb-im-mls-state-');
    addTearDown(() async {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    });
    final store = MlsStateStore(
      dir,
      ownerUserId: 'CN220-CTZN2-100000001-2026',
      stateKey: _testStateKey,
    );

    const pending = MlsWireMessage(
      wireBytes: [0xaa, 0xbb],
      conversationId: 'conv-pending',
      messageKind: MlsMessageKind.application,
    );

    await store.queuePendingInbound(pending);
    final restored = await store.readPendingInbound();

    expect(restored, hasLength(1));
    expect(restored.single.conversationId, 'conv-pending');
    expect(restored.single.wireBytes, [0xaa, 0xbb]);

    final otherUserStore = MlsStateStore(
      dir,
      ownerUserId: 'CN220-CTZN2-999999999-2026',
      stateKey: _testStateKey,
    );
    await expectLater(otherUserStore.readPendingInbound(), throwsA(anything));

    await store.clearPendingInbound();
    expect(await store.readPendingInbound(), isEmpty);
  });

  test('pending MLS 队列换绑时旁路重加密，提交后只接受新钱包密钥', () async {
    final dir = await Directory.systemTemp.createTemp('gmb-im-mls-rekey-');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    final newKey = Uint8List.fromList(
      List<int>.generate(32, (index) => 255 - index),
    );
    final currentStore = MlsStateStore(
      dir,
      ownerUserId: 'CN220-CTZN2-100000001-2026',
      stateKey: _testStateKey,
    );
    await currentStore.queuePendingInbound(
      const MlsWireMessage(
        wireBytes: <int>[0x11, 0x22, 0x33],
        conversationId: 'conv-rekey',
        messageKind: MlsMessageKind.application,
      ),
    );

    await currentStore.stageAccountHandover(newKey);
    expect(
      (await currentStore.readPendingInbound()).single.conversationId,
      'conv-rekey',
    );
    final newStore = MlsStateStore(
      dir,
      ownerUserId: 'CN220-CTZN2-100000001-2026',
      stateKey: newKey,
    );
    await expectLater(newStore.readPendingInbound(), throwsA(anything));

    await MlsStateStore.commitAccountHandoverFiles(dir);
    expect((await newStore.readPendingInbound()).single.wireBytes, <int>[
      0x11,
      0x22,
      0x33,
    ]);
    await expectLater(currentStore.readPendingInbound(), throwsA(anything));
    expect(
      File('${dir.path}/pending_inbound.account_rekey').existsSync(),
      isFalse,
    );
    expect(
      File('${dir.path}/pending_inbound.bin.account_previous').existsSync(),
      isFalse,
    );
  });
}
