import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:tatachat_sdk/protocol.dart' as pb;
import 'package:tatachat_sdk/tatachat_sdk.dart' hide ChatRoute;
import 'package:tatachat_sdk/tatachat_sdk.dart';

import '../support/isar_test_env.dart';

/// user ID 是消息、MLS 名册和待投递路由的唯一身份键；当前钱包账户只解锁本地密钥。
const _bobUserId = 'CN220-CTZN2-100000002-2026';
const _ownerUserId = 'CN220-CTZN2-100000001-2026';
const _aliceAccountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _nextAccountId =
    '0x2222222222222222222222222222222222222222222222222222222222222222';
const _carolUserId = 'CN220-CTZN2-100000003-2026';
const _testBinding = ChatDataBinding(
  keyDomain:
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  userId: _ownerUserId,
  bindingRevision: 1,
  accountId: _aliceAccountId,
);
const _nextBinding = ChatDataBinding(
  keyDomain:
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  userId: _ownerUserId,
  bindingRevision: 2,
  accountId: _nextAccountId,
);

String _payload(String text) => ChatPayloadCodec.encode(ChatContent.text(text));

void main() {
  useIsolatedChatIsar();

  test(
    'Isar store persists outgoing, pending, and incoming Chat records',
    () async {
      final store = ChatStore();
      final bindingToken = await store.activateBindingFence(_testBinding);
      final message =
          const MlsWireMessage(
            wireBytes: [0x68, 0x69],
            conversationId: 'conv-store',
            messageKind: MlsMessageKind.application,
          ).toEncryptedMessage(
            messageId: 'env-store',
            senderUserId: _ownerUserId,
            recipientUserId: _bobUserId,
            senderDeviceId: 'alice-phone',
            recipientDeviceId: 'recipient-phone',
            createdAtMillis: 10,
          );

      await store.saveOutgoingMessage(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        currentAccountId: _aliceAccountId,
        message: message,
        messageBytes: message.writeToBuffer(),
        recipientUserId: _bobUserId,
        messageKind: ChatMessageKind.text,
        deliveryState: ChatMessageDeliveryState.queued,
        plaintext: _payload('hi'),
      );
      await store.markOutgoingDelivery(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        messageId: 'env-store',
        state: ChatMessageDeliveryState.sent,
      );

      final outgoing = await store.readMessages(
        ownerUserId: _ownerUserId,
        currentAccountId: _aliceAccountId,
        conversationId: 'conv-store',
      );
      expect(outgoing.single.deliveryState, ChatMessageDeliveryState.sent);
      expect(ChatPayloadCodec.decode(outgoing.single.plaintext!).text, 'hi');
      // sent 表示宿主聊天服务已持久保存密文，本机可靠重试副本立即收口。
      expect(await store.outboundQueueCount(_ownerUserId), 0);

      await store.savePendingInbound(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        message: message,
        messageBytes: message.writeToBuffer(),
        reason: 'waiting for welcome',
      );
      expect(await store.pendingInboundCount(_ownerUserId), 1);

      final pending = await store.takePendingInbound(
        _ownerUserId,
        'conv-store',
        bindingToken: bindingToken,
      );
      expect(pending.single.messageId, 'env-store');
      expect(await store.pendingInboundCount(_ownerUserId), 0);

      final incomingMessage = message.deepCopy()
        ..messageId = 'env-store-incoming'
        ..senderUserId = _bobUserId
        ..deliveries.single.recipient.userId = _ownerUserId;

      await store.saveIncomingMessage(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        currentAccountId: _aliceAccountId,
        message: incomingMessage,
        messageBytes: incomingMessage.writeToBuffer(),
        messageKind: ChatMessageKind.text,
        plaintext: _payload('hi back'),
      );
      // 同一 Message 可同时经 WSS 与七天邮箱到达；第二次只 ACK，未读不能累加。
      await store.saveIncomingMessage(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        currentAccountId: _aliceAccountId,
        message: incomingMessage,
        messageBytes: incomingMessage.writeToBuffer(),
        messageKind: ChatMessageKind.text,
        plaintext: _payload('hi back'),
      );
      final conversations = await store.readConversationPreviews(
        ownerUserId: _ownerUserId,
        currentAccountId: _aliceAccountId,
      );
      expect(conversations.single.unreadCount, 1);
      expect(conversations.single.lastMessage, 'hi back');

      // 当前窗口只清除已展示时间点以内的未读数，保证稍后到达的新消息不会被误标已读。
      await store.markConversationRead(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        conversationId: 'conv-store',
        readThroughMillis: 10,
      );
      expect(
        (await store.readConversationPreviews(
          ownerUserId: _ownerUserId,
          currentAccountId: _aliceAccountId,
        )).single.unreadCount,
        0,
      );
    },
  );

  test('队列与待投递媒体动作读取拒绝 fence generation 推进前的旧 token', () async {
    final store = ChatStore();
    final oldToken = await store.activateBindingFence(_testBinding);
    final message =
        const MlsWireMessage(
          wireBytes: [0x68, 0x69],
          conversationId: 'conv-stale-action',
          messageKind: MlsMessageKind.application,
        ).toEncryptedMessage(
          messageId: 'env-stale-action',
          senderUserId: _ownerUserId,
          recipientUserId: _bobUserId,
          senderDeviceId: 'alice-phone',
          recipientDeviceId: 'recipient-phone',
          createdAtMillis: 10,
        );
    await store.saveOutgoingMessage(
      bindingToken: oldToken,
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      message: message,
      messageBytes: message.writeToBuffer(),
      recipientUserId: _bobUserId,
      messageKind: ChatMessageKind.text,
      deliveryState: ChatMessageDeliveryState.queued,
      plaintext: _payload('stale action'),
    );
    await store.recordOutgoingMedia(
      bindingToken: oldToken,
      ownerUserId: _ownerUserId,
      attachmentId: 'att-stale-action',
      recipientUserId: _bobUserId,
      conversationId: 'conv-stale-action',
      fileName: 'stale.bin',
      contentType: 'application/octet-stream',
      byteSize: 3,
    );
    expect(
      await store.readQueuedMessages(
        bindingToken: oldToken,
        ownerUserId: _ownerUserId,
      ),
      hasLength(1),
    );
    expect(
      await store.readPendingOutgoingMedia(
        bindingToken: oldToken,
        ownerUserId: _ownerUserId,
      ),
      hasLength(1),
    );

    await store.isolateInaccessibleBinding(
      previous: _testBinding,
      current: _nextBinding,
    );

    await expectLater(
      store.readQueuedMessages(
        bindingToken: oldToken,
        ownerUserId: _ownerUserId,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.readPendingOutgoingMedia(
        bindingToken: oldToken,
        ownerUserId: _ownerUserId,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('出站重试按 message 创建时间排序，Welcome 始终先于 Application', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    pb.EncryptedMessage message({
      required String id,
      required int createdAt,
      required MlsMessageKind kind,
    }) =>
        MlsWireMessage(
          wireBytes: <int>[createdAt],
          conversationId: 'conv-order',
          messageKind: kind,
        ).toEncryptedMessage(
          messageId: id,
          senderUserId: _ownerUserId,
          recipientUserId: _bobUserId,
          senderDeviceId: 'alice-phone',
          recipientDeviceId: 'recipient-phone',
          createdAtMillis: createdAt,
        );
    final application = message(
      id: 'env-application',
      createdAt: 11,
      kind: MlsMessageKind.application,
    );
    final welcome = message(
      id: 'env-welcome',
      createdAt: 10,
      kind: MlsMessageKind.welcome,
    );
    // 故意反序写入，读取仍必须按 MLS 创建顺序返回。
    for (final item in <pb.EncryptedMessage>[application, welcome]) {
      await store.queueOutgoingMessage(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        message: item,
        messageBytes: item.writeToBuffer(),
        recipientUserId: _bobUserId,
        deliveryState: ChatMessageDeliveryState.queued,
      );
    }

    final queued = await store.readQueuedMessages(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
    );
    expect(queued.map((item) => item.messageId), <String>[
      'env-welcome',
      'env-application',
    ]);
  });

  test('聊天窗口只按当前 conversationId 索引读取待发送队列', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);

    Future<void> queue(String conversationId, String messageId) async {
      final message =
          MlsWireMessage(
            wireBytes: const <int>[1],
            conversationId: conversationId,
            messageKind: MlsMessageKind.application,
          ).toEncryptedMessage(
            messageId: messageId,
            senderUserId: _ownerUserId,
            recipientUserId: _bobUserId,
            senderDeviceId: 'alice-phone',
            recipientDeviceId: 'recipient-phone',
            createdAtMillis: 10,
          );
      await store.queueOutgoingMessage(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        message: message,
        messageBytes: message.writeToBuffer(),
        recipientUserId: _bobUserId,
        deliveryState: ChatMessageDeliveryState.queued,
      );
    }

    await queue('conv-current', 'env-current');
    await queue('conv-unrelated', 'env-unrelated');

    final current = await store.readQueuedMessages(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      conversationId: 'conv-current',
    );
    expect(current.map((item) => item.messageId), <String>['env-current']);
  });

  test(
    'Isar store deletes one local conversation without touching others',
    () async {
      final store = ChatStore();
      final bindingToken = await store.activateBindingFence(_testBinding);
      final targetMessage =
          const MlsWireMessage(
            wireBytes: [0x01],
            conversationId: 'conv-delete',
            messageKind: MlsMessageKind.application,
          ).toEncryptedMessage(
            messageId: 'env-delete',
            senderUserId: _ownerUserId,
            recipientUserId: _bobUserId,
            senderDeviceId: 'alice-phone',
            recipientDeviceId: 'recipient-phone',
            createdAtMillis: 10,
          );
      final keptMessage =
          const MlsWireMessage(
            wireBytes: [0x02],
            conversationId: 'conv-keep',
            messageKind: MlsMessageKind.application,
          ).toEncryptedMessage(
            messageId: 'env-keep',
            senderUserId: _ownerUserId,
            recipientUserId: _carolUserId,
            senderDeviceId: 'alice-phone',
            recipientDeviceId: 'recipient-phone',
            createdAtMillis: 20,
          );

      await store.saveOutgoingMessage(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        currentAccountId: _aliceAccountId,
        message: targetMessage,
        messageBytes: targetMessage.writeToBuffer(),
        recipientUserId: _bobUserId,
        messageKind: ChatMessageKind.text,
        deliveryState: ChatMessageDeliveryState.queued,
        plaintext: _payload('delete me'),
      );
      await store.savePendingInbound(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        message: targetMessage,
        messageBytes: targetMessage.writeToBuffer(),
        reason: 'waiting',
      );
      await store.saveOutgoingMessage(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        currentAccountId: _aliceAccountId,
        message: keptMessage,
        messageBytes: keptMessage.writeToBuffer(),
        recipientUserId: _carolUserId,
        messageKind: ChatMessageKind.text,
        deliveryState: ChatMessageDeliveryState.sent,
        plaintext: _payload('keep me'),
      );

      expect(await store.outboundQueueCount(_ownerUserId), 2);
      expect(await store.pendingInboundCount(_ownerUserId), 1);

      await store.deleteConversation(
        _ownerUserId,
        'conv-delete',
        bindingToken: bindingToken,
      );

      expect(
        await store.readMessages(
          ownerUserId: _ownerUserId,
          currentAccountId: _aliceAccountId,
          conversationId: 'conv-delete',
        ),
        isEmpty,
      );
      expect(await store.pendingInboundCount(_ownerUserId), 0);
      expect(await store.outboundQueueCount(_ownerUserId), 1);

      final conversations = await store.readConversationPreviews(
        ownerUserId: _ownerUserId,
        currentAccountId: _aliceAccountId,
      );
      expect(conversations.single.conversationId, 'conv-keep');
      expect(
        ChatPayloadCodec.decode(
          (await store.readMessages(
            ownerUserId: _ownerUserId,
            currentAccountId: _aliceAccountId,
            conversationId: 'conv-keep',
          )).single.plaintext!,
        ).text,
        'keep me',
      );
    },
  );

  test('附件控制投递事实:登记 / 按对端读 / 删 / 会话删连带清理', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    await store.recordOutgoingMedia(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      attachmentId: 'att-1',
      recipientUserId: _bobUserId,
      conversationId: 'conv-a',
      fileName: 'p.jpg',
      contentType: 'image/jpeg',
      byteSize: 100,
    );
    await store.recordOutgoingMedia(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      attachmentId: 'att-2',
      recipientUserId: _carolUserId,
      conversationId: 'conv-b',
      fileName: 'v.mp4',
      contentType: 'video/mp4',
      byteSize: 200,
    );
    expect(await store.outgoingMediaCount(_ownerUserId), 2);

    final forBob = await store.readPendingOutgoingMedia(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      recipientUserId: _bobUserId,
    );
    expect(forBob.single.attachmentId, 'att-1');
    expect(forBob.single.fileName, 'p.jpg');
    expect(forBob.single.conversationId, 'conv-a');
    expect(forBob.single.byteSize, 100);

    await store.deleteOutgoingMedia(
      _ownerUserId,
      'att-1',
      _bobUserId,
      bindingToken: bindingToken,
    ); // 当前收件人的附件投递完成后删除
    expect(await store.outgoingMediaCount(_ownerUserId), 1);

    // 删会话 conv-b 连带清理其附件投递事实，不留孤儿。
    await store.deleteConversation(
      _ownerUserId,
      'conv-b',
      bindingToken: bindingToken,
    );
    expect(await store.outgoingMediaCount(_ownerUserId), 0);
  });

  test('群媒体:同一 attachmentId 发多成员各占一行,按成员删', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    for (final memberUserId in [
      'CN220-CTZN2-100000004-2026',
      'CN220-CTZN2-100000005-2026',
      'CN220-CTZN2-100000006-2026',
    ]) {
      await store.recordOutgoingMedia(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        attachmentId: 'att-grp',
        recipientUserId: memberUserId,
        conversationId: 'grp:a:n',
        fileName: 'g.jpg',
        contentType: 'image/jpeg',
        byteSize: 100,
      );
    }
    expect(await store.outgoingMediaCount(_ownerUserId), 3);
    // 仅 c 完成附件投递：删 c 的行，b/d 待投递事实保留。
    await store.deleteOutgoingMedia(
      _ownerUserId,
      'att-grp',
      'CN220-CTZN2-100000005-2026',
      bindingToken: bindingToken,
    );
    expect(await store.outgoingMediaCount(_ownerUserId), 2);
    final forB = await store.readPendingOutgoingMedia(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      recipientUserId: 'CN220-CTZN2-100000004-2026',
    );
    expect(forB.single.attachmentId, 'att-grp');
  });

  test('clearAllForUserId 连带清理该 user ID 会话的附件投递事实', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    // 以出站消息建立 owner user ID 的会话行(conversationId=conv-own)。
    final message =
        const MlsWireMessage(
          wireBytes: [1],
          conversationId: 'conv-own',
          messageKind: MlsMessageKind.application,
        ).toEncryptedMessage(
          messageId: 'env-own',
          senderUserId: _ownerUserId,
          recipientUserId: _bobUserId,
          senderDeviceId: 'alice-phone',
          recipientDeviceId: 'recipient-phone',
          createdAtMillis: 1,
        );
    await store.saveOutgoingMessage(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      message: message,
      messageBytes: message.writeToBuffer(),
      recipientUserId: _bobUserId,
      messageKind: ChatMessageKind.text,
      deliveryState: ChatMessageDeliveryState.queued,
      plaintext: _payload('hi'),
    );
    await store.recordOutgoingMedia(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      attachmentId: 'att-own',
      recipientUserId: _bobUserId,
      conversationId: 'conv-own',
      fileName: 'p.jpg',
      contentType: 'image/jpeg',
      byteSize: 5,
    );
    await store.upsertGroupShell(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      groupId: 'group-clear',
      groupName: '待清理群',
      creatorUserId: _ownerUserId,
      epoch: 1,
    );
    await store.reconcileGroupRoster(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      groupId: 'group-clear',
      members: const <String, GroupMemberRole>{
        _ownerUserId: GroupMemberRole.admin,
        _bobUserId: GroupMemberRole.member,
      },
      epoch: 1,
    );
    await store.bufferGroupCommit(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      groupId: 'group-clear',
      messageEpoch: 2,
      message: message,
      messageBytes: message.writeToBuffer(),
    );
    expect(await store.outgoingMediaCount(_ownerUserId), 1);
    final before = await ChatIsar.instance.read(
      (isar) async => (
        groups: await isar.chatGroupEntitys
            .filter()
            .ownerUserIdEqualTo(_ownerUserId)
            .count(),
        members: await isar.chatGroupMemberEntitys
            .filter()
            .ownerUserIdEqualTo(_ownerUserId)
            .count(),
        commits: await isar.chatGroupPendingCommitEntitys
            .filter()
            .ownerUserIdEqualTo(_ownerUserId)
            .count(),
      ),
    );
    expect(before.groups, 1);
    expect(before.members, 2);
    expect(before.commits, 1);

    await store.clearAllForUserId(_ownerUserId);
    expect(await store.outgoingMediaCount(_ownerUserId), 0);
    final after = await ChatIsar.instance.read(
      (isar) async => (
        groups: await isar.chatGroupEntitys
            .filter()
            .ownerUserIdEqualTo(_ownerUserId)
            .count(),
        members: await isar.chatGroupMemberEntitys
            .filter()
            .ownerUserIdEqualTo(_ownerUserId)
            .count(),
        commits: await isar.chatGroupPendingCommitEntitys
            .filter()
            .ownerUserIdEqualTo(_ownerUserId)
            .count(),
      ),
    );
    expect(after.groups, 0);
    expect(after.members, 0);
    expect(after.commits, 0);
  });

  test('无签名交接时保留永久聊天密文并清空此前绑定的瞬时状态', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    final message =
        const MlsWireMessage(
          wireBytes: [0x68, 0x69],
          conversationId: 'conv-isolate',
          messageKind: MlsMessageKind.application,
        ).toEncryptedMessage(
          messageId: 'env-isolate',
          senderUserId: _ownerUserId,
          recipientUserId: _bobUserId,
          senderDeviceId: 'alice-phone',
          recipientDeviceId: 'recipient-phone',
          createdAtMillis: 10,
        );

    await store.saveOutgoingMessage(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      message: message,
      messageBytes: message.writeToBuffer(),
      recipientUserId: _bobUserId,
      messageKind: ChatMessageKind.text,
      deliveryState: ChatMessageDeliveryState.queued,
      plaintext: _payload('必须保留的历史密文'),
    );
    await store.savePendingInbound(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      message: message,
      messageBytes: message.writeToBuffer(),
      reason: 'waiting',
    );
    await store.recordOutgoingMedia(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      attachmentId: 'att-isolate',
      recipientUserId: _bobUserId,
      conversationId: 'conv-isolate',
      fileName: 'pending.bin',
      contentType: 'application/octet-stream',
      byteSize: 2,
    );
    await store.upsertRouteRecord(
      _ownerUserId,
      const ChatRouteRecord(
        peerUserId: _bobUserId,
        routeDisplayName: 'Bob',
        deviceId: 'bob-phone',
        safetyNumber: '123456',
      ),
      bindingToken: bindingToken,
    );
    await store.upsertGroupShell(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      groupId: 'group-isolate',
      groupName: '此前群上下文',
      creatorUserId: _ownerUserId,
      epoch: 1,
    );
    await store.reconcileGroupRoster(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      groupId: 'group-isolate',
      members: const <String, GroupMemberRole>{
        _ownerUserId: GroupMemberRole.admin,
        _bobUserId: GroupMemberRole.member,
      },
      epoch: 1,
    );
    await store.bufferGroupCommit(
      bindingToken: bindingToken,
      ownerUserId: _ownerUserId,
      groupId: 'group-isolate',
      messageEpoch: 2,
      message: message,
      messageBytes: message.writeToBuffer(),
    );

    await store.isolateInaccessibleBinding(
      previous: _testBinding,
      current: _nextBinding,
    );
    final nextBindingToken = await store.captureBindingFenceToken(_nextBinding);

    expect(await store.outboundQueueCount(_ownerUserId), 0);
    expect(await store.pendingInboundCount(_ownerUserId), 0);
    expect(await store.outgoingMediaCount(_ownerUserId), 0);
    expect(await store.readRouteRecords(_ownerUserId), isEmpty);
    expect(await store.readGroup(_ownerUserId, 'group-isolate'), isNull);
    expect(
      await store.takeGroupPendingCommit(
        _ownerUserId,
        'group-isolate',
        2,
        bindingToken: nextBindingToken,
      ),
      isNull,
    );

    // 隔离只移除不能跨绑定续用的任务和 MLS 镜像，不删除永久聊天密文。
    final retained = await store.readMessages(
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      conversationId: 'conv-isolate',
    );
    expect(
      ChatPayloadCodec.decode(retained.single.plaintext!).text,
      '必须保留的历史密文',
    );
  });

  test('searchMessages 跨会话按解码摘要检索：大小写不敏感、时间倒序、limit 截断', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_testBinding);
    const sender = _ownerUserId;
    const peer = _bobUserId;

    Future<void> save({
      required String messageId,
      required String conversationId,
      required int createdAtMillis,
      required String plaintext,
    }) async {
      final message =
          MlsWireMessage(
            wireBytes: const [0x68, 0x69],
            conversationId: conversationId,
            messageKind: MlsMessageKind.application,
          ).toEncryptedMessage(
            messageId: messageId,
            senderUserId: sender,
            recipientUserId: peer,
            senderDeviceId: 'alice-phone',
            recipientDeviceId: 'recipient-phone',
            createdAtMillis: createdAtMillis,
          );
      await store.saveOutgoingMessage(
        bindingToken: bindingToken,
        ownerUserId: _ownerUserId,
        currentAccountId: _aliceAccountId,
        message: message,
        messageBytes: message.writeToBuffer(),
        recipientUserId: _bobUserId,
        messageKind: ChatMessageKind.text,
        deliveryState: ChatMessageDeliveryState.sent,
        plaintext: _payload(plaintext),
      );
    }

    await save(
      messageId: 'env-search-a',
      conversationId: 'conv-search-1',
      createdAtMillis: 10,
      plaintext: '明天开会的材料',
    );
    await save(
      messageId: 'env-search-b',
      conversationId: 'conv-search-2',
      createdAtMillis: 30,
      plaintext: 'Meeting MATERIAL ready',
    );
    await save(
      messageId: 'env-search-c',
      conversationId: 'conv-search-2',
      createdAtMillis: 20,
      plaintext: '开会通知',
    );

    // 跨会话命中并按时间倒序（conv-search-2 的 env-c 比 conv-search-1 的 env-a 新）
    final ordered = await store.searchMessages(
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      keyword: '开会',
    );
    expect(ordered.map((item) => item.messageId).toList(), <String>[
      'env-search-c',
      'env-search-a',
    ]);

    // limit 截断保留最新的一条
    final limited = await store.searchMessages(
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      keyword: '开会',
      limit: 1,
    );
    expect(limited.map((item) => item.messageId).toList(), <String>[
      'env-search-c',
    ]);

    // 大小写不敏感
    final caseInsensitive = await store.searchMessages(
      ownerUserId: _ownerUserId,
      currentAccountId: _aliceAccountId,
      keyword: 'material',
    );
    expect(caseInsensitive.map((item) => item.messageId).toList(), <String>[
      'env-search-b',
    ]);

    // 空关键词 / 空账户不检索；他人账户查不到本账户消息
    expect(
      await store.searchMessages(
        ownerUserId: _ownerUserId,
        currentAccountId: sender,
        keyword: '   ',
      ),
      isEmpty,
    );
    expect(
      await store.searchMessages(
        ownerUserId: '',
        currentAccountId: sender,
        keyword: '开会',
      ),
      isEmpty,
    );
    expect(
      await store.searchMessages(
        ownerUserId: 'CN220-CTZN2-999999999-2026',
        currentAccountId: peer,
        keyword: '开会',
      ),
      isEmpty,
    );
  });
}
