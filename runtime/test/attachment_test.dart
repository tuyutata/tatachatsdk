import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_core/chat_content.dart';
import 'package:tatachat_core/chat_message.dart';
import 'package:tatachat_mls/mls_boundary.dart';
import 'package:tatachat_mls/mls_group_boundary.dart';
import 'package:tatachat_protocol/message.dart';
import 'package:tatachat_runtime/direct_flow.dart';
import 'package:tatachat_runtime/group_flow.dart';
import 'package:tatachat_storage/chat_store.dart';
import 'package:tatachat_storage/records.dart';
import 'package:tatachat_testing/isar.dart';
import 'package:tatachat_testing/native.dart';
import 'package:tatachat_transport/chat_transport.dart';

void main() {
  test('真实MLS同epoch改名A到B再到A，每次控制都实际应用', () async {
    final dir = await createMlsTestDirectory(),
        a = await createTestMlsDevice(dir, 'a'),
        b = await createTestMlsDevice(dir, 'b', cid: 'CID-B');
    final store = ChatStore(), account = '0x${'33' * 32}';
    Future<ChatBindingFenceToken> token(String user) =>
        store.activateBindingFence(
          ChatBinding(
            userId: user,
            accountId: account,
            bindingRevision: 1,
            bindingScope: '0x${'44' * 32}',
          ),
        );
    final receiver = ChatGroupFlow(
      crypto: b.crypto,
      store: store,
      bindingToken: await token('CID-B'),
      ownerUserId: 'CID-B',
      userId: 'CID-B',
      currentAccountId: account,
      localDeviceId: b.identity.deviceId,
      deliverer: (message, _, _, _) async => ChatDeliveryResult(
        messageId: message.messageId,
        transportType: ChatTransportType.server,
        state: ChatMessageDeliveryState.sent,
      ),
    );
    final ids = <String>[];
    final sender = ChatGroupFlow(
      crypto: a.crypto,
      store: store,
      bindingToken: await token('CID-A'),
      ownerUserId: 'CID-A',
      userId: 'CID-A',
      currentAccountId: account,
      localDeviceId: a.identity.deviceId,
      deliverer: (message, bytes, _, _) async {
        ids.add(message.messageId);
        await receiver.processIncomingGroupMessage(bytes);
        return ChatDeliveryResult(
          messageId: message.messageId,
          transportType: ChatTransportType.server,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );
    const group = 'grp:CID-A:rename';
    await sender.createGroup(
      groupId: group,
      name: '原名',
      userId: 'CID-A',
      localDeviceId: a.identity.deviceId,
      invitees: [await b.crypto.createKeyPackage(b.identity)],
    );
    ids.clear();
    for (final name in ['A', 'B', 'A']) {
      await sender.renameGroup(group, name);
      expect((await store.readGroup('CID-B', group))!.name, name);
    }
    expect(ids.toSet(), hasLength(3));
    expect((await a.crypto.groupState(group)).epoch, 1);
  });
  for (final sticker in [false, true]) {
    test(
      '真实MLS待发${sticker ? '贴纸' : '文字'}为每台设备保存Welcome和Application，重试不覆盖',
      () async {
        final dir = await createMlsTestDirectory(),
            a = await createTestMlsDevice(dir, 'a');
        final receivers = [
          await createTestMlsDevice(dir, 'b', cid: 'CID-B'),
          await createTestMlsDevice(dir, 'c', cid: 'CID-B'),
        ];
        final store = ChatStore(), account = '0x${'33' * 32}';
        final token = await store.activateBindingFence(
          ChatBinding(
            userId: 'CID-A',
            accountId: account,
            bindingRevision: 1,
            bindingScope: '0x${'44' * 32}',
          ),
        );
        final payload = sticker
            ? ChatContent.sticker(
                packId: 'fluent3d',
                stickerId: 'grinning_face',
              )
            : ChatContent.text('hello');
        await store.savePendingOutgoingMessage(
          bindingToken: token,
          ownerUserId: 'CID-A',
          currentAccountId: account,
          localMessageId: 'pending:devices',
          conversationId: 'direct-devices',
          recipientUserId: 'CID-B',
          messageKind: payload.kind,
          payload: ChatPayloadCodec.encode(payload),
          createdAtMillis: 1234,
        );
        final packages = <MlsKeyPackage>[];
        for (final receiver in receivers) {
          packages.add(
            await receiver.crypto.createKeyPackage(receiver.identity),
          );
        }
        final flow = ChatFlow(
          crypto: a.crypto,
          store: store,
          bindingToken: token,
          ownerUserId: 'CID-A',
          currentAccountId: account,
          deliveryScheduler: (_, _) {},
          deliverer: (_, _, _, _) async => throw StateError('队列持久化阶段不得联网'),
        );
        if (sticker) {
          await flow.sendSticker(
            conversationId: 'direct-devices',
            senderUserId: 'CID-A',
            recipientUserId: 'CID-B',
            senderDeviceId: a.identity.deviceId,
            recipientKeyPackages: packages,
            packId: 'fluent3d',
            stickerId: 'grinning_face',
            pendingLocalMessageId: 'pending:devices',
            createdAtMillis: 1234,
          );
        } else {
          await flow.sendText(
            conversationId: 'direct-devices',
            senderUserId: 'CID-A',
            recipientUserId: 'CID-B',
            senderDeviceId: a.identity.deviceId,
            recipientKeyPackages: packages,
            text: 'hello',
            pendingLocalMessageId: 'pending:devices',
            createdAtMillis: 1234,
          );
        }
        final queued = await store.readQueuedMessages(
          bindingToken: token,
          ownerUserId: 'CID-A',
        );
        expect(queued, hasLength(4));
        expect(queued.map((q) => q.messageId).toSet(), hasLength(4));
        expect(
          await store.readMessages(
            ownerUserId: 'CID-A',
            currentAccountId: account,
            conversationId: 'direct-devices',
          ),
          hasLength(1),
        );
        for (final receiver in receivers) {
          var applications = 0;
          for (final item in queued) {
            final message = EncryptedMessage.fromBuffer(item.messageBytes);
            if (message.recipientDeviceId != receiver.identity.deviceId) {
              continue;
            }
            final received = await receiver.crypto.withMessage(
              message.messageId,
              () => receiver.crypto.groupProcess(
                mlsWireMessageFromEncryptedMessage(message),
              ),
            );
            if (received.kind == GroupInboundKind.application) {
              applications++;
              expect(
                ChatPayloadCodec.decode(utf8.decode(received.plaintext!)).kind,
                payload.kind,
              );
            }
            await receiver.crypto.acknowledgeMessage(message.messageId);
            final replay = await receiver.crypto.withMessage(
              message.messageId,
              () => receiver.crypto.groupProcess(
                mlsWireMessageFromEncryptedMessage(message),
              ),
            );
            expect(replay.status, GroupProcessStatus.stale);
          }
          expect(applications, 1);
        }
      },
    );
  }

  useIsolatedChatIsar();
  requireChatSdkNative();

  test('真实MLS附件控制为同CID两台收件设备分别持久化Welcome和投递条目', () async {
    final dir = await createMlsTestDirectory(),
        a = await createTestMlsDevice(dir, 'a');
    final receivers = [
      await createTestMlsDevice(dir, 'b', cid: 'CID-B'),
      await createTestMlsDevice(dir, 'c', cid: 'CID-B'),
    ];
    final packages = <MlsKeyPackage>[];
    for (final receiver in receivers) {
      packages.add(
        await receiver.crypto.createKeyPackage(
          receiver.identity,
          lastResort: true,
        ),
      );
    }
    final database = ChatStore();
    final account = '0x${'33' * 32}';
    final token = await database.activateBindingFence(
      ChatBinding(
        userId: a.identity.userId,
        accountId: account,
        bindingRevision: 1,
        bindingScope: '0x${'44' * 32}',
      ),
    );
    final tasks = <Future<void> Function()>[];
    final controls = <ChatContent>[];
    final flow = ChatFlow<ChatBindingFenceToken>(
      crypto: a.crypto,
      store: database,
      bindingToken: token,
      ownerUserId: a.identity.userId,
      currentAccountId: account,
      deliveryScheduler: (_, delivery) => tasks.add(delivery),
      deliverer: (message, bytes, user, device) async {
        final receiver = receivers.singleWhere(
          (r) => r.identity.deviceId == device,
        );
        final result = await receiver.crypto.withMessage(
          message.messageId,
          () => receiver.crypto.groupProcess(
            MlsWireMessage(
              conversationId: message.conversationId,
              wireBytes: message.openmlsCiphertext,
            ),
          ),
        );
        if (result.kind == GroupInboundKind.application) {
          controls.add(ChatPayloadCodec.decode(utf8.decode(result.plaintext!)));
        }
        return ChatDeliveryResult(
          messageId: message.messageId,
          transportType: ChatTransportType.server,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );
    const conversation = 'direct-two-devices';
    final audience = await flow.prepareAttachmentAudience(
      conversationId: conversation,
      recipientUserId: 'CID-B',
      senderDeviceId: a.identity.deviceId,
      keyPackages: packages,
      messageId: 'file-1',
    );
    Future<List<ChatQueuedMessage>> queued() => database.readQueuedMessages(
      bindingToken: token,
      ownerUserId: a.identity.userId,
      conversationId: conversation,
    );
    final welcomes = await queued();
    expect(welcomes.length, 2);
    expect(welcomes.map((m) => m.messageId).toSet().length, 2);
    final welcomeTask = tasks.removeAt(0);
    await welcomeTask();
    final source = File('${a.root.path}/source'),
        cipher = File('${a.root.path}/cipher');
    await source.writeAsBytes([1, 2, 3], flush: true);
    final roster = [...audience.memberIdentities]..sort();
    final content = await a.attachment().seal(
      attachmentId: 'file-1',
      byteSize: 3,
      source: source,
      target: cipher,
      members: roster,
      keyPackages: packages,
      contentBuilder: (d) => createTestMediaContent(d, 3),
    );
    await flow.sendMediaControl(
      conversationId: conversation,
      senderUserId: a.identity.userId,
      recipientUserId: 'CID-B',
      senderDeviceId: a.identity.deviceId,
      media: content,
      createdAtMillis: 1234,
    );
    final media = await queued();
    expect(media.length, 2);
    expect(media.map((m) => m.messageId).toSet().length, 2);
    final envelopes = media
        .map((m) => EncryptedMessage.fromBuffer(m.messageBytes))
        .toList();
    expect(
      envelopes.map((m) => m.recipientDeviceId).toSet(),
      receivers.map((r) => r.identity.deviceId).toSet(),
    );
    expect(envelopes.first.openmlsCiphertext, envelopes.last.openmlsCiphertext);
    await tasks.removeAt(0)();
    expect(controls.length, 2);
    expect(
      controls.every((c) => c.attachmentGroupId == content.attachmentGroupId),
      true,
    );
    expect(
      (await a.crypto.groupState(conversation)).memberIdentities.toSet(),
      roster.toSet(),
    );
  });
}
