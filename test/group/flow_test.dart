import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import '../support/isar_test_env.dart';

const _ownerUserId = 'CN220-CTZN2-100000001-2026';
const _accountA =
    '0x3333333333333333333333333333333333333333333333333333333333333333';
const _binding = ChatBinding(
  bindingScope:
      '0x4242424242424242424242424242424242424242424242424242424242424242',
  userId: _ownerUserId,
  bindingRevision: 1,
  accountId: _accountA,
);

Future<ChatBindingFenceToken> _bindingToken(ChatStore store) =>
    store.activateBindingFence(_binding);

/// 内存态 fake:模拟 MLS 群语义(roster + epoch),不做真加密。
class _FakeGroupCrypto implements MlsGroupCrypto {
  _FakeGroupCrypto({required this.userId, required this.localDeviceId});

  final String userId;
  final String localDeviceId;
  final Map<String, List<String>> _roster = {};
  final Map<String, int> _epoch = {};
  GroupProcessStatus inboundStatus = GroupProcessStatus.applied;
  bool committed = false;

  String get _localIdentity => '$userId:$localDeviceId';

  @override
  Future<MlsKeyPackage> createKeyPackage(
    ChatDevice identity, {
    bool lastResort = true,
  }) async => _keyPackage(identity.userId, identity.deviceId);

  @override
  Future<GroupCreated> createGroup(String groupId) async {
    _roster[groupId] = [_localIdentity];
    _epoch[groupId] = 0;
    return GroupCreated(groupId: groupId, epoch: 0);
  }

  @override
  Future<GroupCommitBundle> addMembers(
    String groupId,
    List<MlsKeyPackage> keyPackages,
  ) async {
    final roster = _roster[groupId]!;
    for (final keyPackage in keyPackages) {
      roster.add('${keyPackage.userId}:${keyPackage.deviceId}');
    }
    _epoch[groupId] = (_epoch[groupId] ?? 0) + 1;
    return GroupCommitBundle(
      groupId: groupId,
      epoch: _epoch[groupId]!,
      commit: _wire(groupId, 'commit'),
      welcome: _wire(groupId, 'welcome'),
    );
  }

  @override
  Future<GroupCommitBundle> removeMembers(
    String groupId,
    List<String> memberIdentities,
  ) async {
    final roster = _roster[groupId]!;
    roster.removeWhere((identity) => memberIdentities.contains(identity));
    _epoch[groupId] = (_epoch[groupId] ?? 0) + 1;
    return GroupCommitBundle(
      groupId: groupId,
      epoch: _epoch[groupId]!,
      commit: _wire(groupId, 'commit'),
      removedMemberIdentities: memberIdentities,
    );
  }

  @override
  Future<MlsWireMessage> groupCreateMessage(
    String groupId,
    List<int> plaintext,
  ) async {
    return MlsWireMessage(
      wireBytes: plaintext,
      conversationId: groupId,
      messageKind: MlsMessageKind.application,
    );
  }

  @override
  Future<GroupInbound> groupProcess(MlsWireMessage wire) async {
    // 测试只驱动 application 入站:回显明文。
    final epoch = _epoch[wire.conversationId] ?? 0;
    return GroupInbound(
      groupId: wire.conversationId,
      kind: GroupInboundKind.application,
      status: inboundStatus,
      messageEpoch: epoch,
      groupEpoch: epoch,
      selfRemoved: false,
      plaintext: wire.wireBytes,
      committed: committed,
    );
  }

  @override
  Future<GroupState> groupState(String groupId) async {
    return GroupState(
      groupId: groupId,
      epoch: _epoch[groupId] ?? 0,
      memberIdentities: List.of(_roster[groupId] ?? const []),
    );
  }

  MlsWireMessage _wire(String groupId, String tag) => MlsWireMessage(
    wireBytes: utf8.encode(tag),
    conversationId: groupId,
    messageKind: MlsMessageKind.application,
  );
}

/// 群名册、消息、扇出队列与 WebRTC 信令均以 user ID 为唯一身份键。
const _userA = 'CN220-CTZN2-100000003-2026';
const _userB = 'CN220-CTZN2-100000004-2026';
const _userC = 'CN220-CTZN2-100000005-2026';
const _userD = 'CN220-CTZN2-100000006-2026';

Future<ChatDeliveryResult> _okDeliverer(
  EncryptedMessage message,
  List<int> bytes,
  String recipientUserId,
  String recipientDeviceId,
) async => ChatDeliveryResult(
  messageId: message.messageId,
  transportType: ChatTransportType.server,
  state: ChatMessageDeliveryState.sent,
);

MlsKeyPackage _keyPackage(String userId, String device) => MlsKeyPackage(
  userId: userId,
  deviceId: device,
  keyPackageRef: List<String>.filled(64, 'a').join(),
  keyPackageBytes: const [1, 2],
  cipherSuite: '',
  notBeforeMillis: 1,
  notAfterMillis: 9999999999999,
  lastResort: true,
);

void main() {
  useIsolatedChatIsar();

  test('stale只有精确已提交收据才进入设备确认集合', () async {
    final store = ChatStore();
    final crypto = _FakeGroupCrypto(userId: _userA, localDeviceId: 'devA')
      ..inboundStatus = GroupProcessStatus.stale;
    final flow = ChatGroupFlow(
      ownerUserId: _ownerUserId,
      crypto: crypto,
      store: store,
      bindingToken: await _bindingToken(store),
      deliverer: _okDeliverer,
      userId: _userA,
      currentAccountId: _accountA,
      localDeviceId: 'devA',
    );
    final message =
        MlsWireMessage(
          conversationId: 'grp:receipt',
          wireBytes: [1, 2, 3],
          messageKind: MlsMessageKind.application,
        ).toEncryptedMessage(
          messageId: 'receipt-message',
          senderUserId: _userB,
          recipientUserId: _userA,
          senderDeviceId: 'devB',
          recipientDeviceId: 'devA',
          createdAtMillis: 1,
        );
    expect(
      await flow.processIncomingGroupMessage(message.writeToBuffer()),
      isEmpty,
    );
    crypto.committed = true;
    expect(
      (await flow.processIncomingGroupMessage(
        message.writeToBuffer(),
      )).single.messageId,
      message.messageId,
    );
  });

  test('建群→发文本→收文本→删人 全链路(fake 密码学 + 真 Isar)', () async {
    final store = ChatStore();
    final crypto = _FakeGroupCrypto(userId: _userA, localDeviceId: 'devA');
    final delivered = <EncryptedMessage>[];
    final deliveredUserIds = <String>[];
    Future<ChatDeliveryResult> deliverer(
      EncryptedMessage message,
      List<int> bytes,
      String recipientUserId,
      String recipientDeviceId,
    ) async {
      delivered.add(message);
      deliveredUserIds.add(recipientUserId);
      return ChatDeliveryResult(
        messageId: message.messageId,
        transportType: ChatTransportType.server,
        state: ChatMessageDeliveryState.sent,
      );
    }

    final flow = ChatGroupFlow(
      ownerUserId: _ownerUserId,
      crypto: crypto,
      store: store,
      bindingToken: await _bindingToken(store),
      deliverer: deliverer,
      userId: _userA,
      currentAccountId: _accountA,
      localDeviceId: 'devA',
    );
    const groupId = 'grp:$_userA:testnonce';

    // 建群 + 邀请 B、C。
    final group = await flow.createGroup(
      groupId: groupId,
      name: '测试群',
      userId: _userA,
      localDeviceId: 'devA',
      invitees: [_keyPackage(_userB, 'devB'), _keyPackage(_userC, 'devC')],
    );
    expect(group.memberUserIds.toSet(), {_userA, _userB, _userC});
    expect(group.adminSet, {_userA});
    // Welcome 扇给 B、C(建群时无其他现有成员,无 Commit 扇出)。
    expect(delivered.map((e) => e.recipientUserId).toSet(), {_userB, _userC});
    expect(deliveredUserIds.toSet(), {_userB, _userC});

    // 群发文本 → 扇给 B、C,落 1 条逻辑消息。
    delivered.clear();
    deliveredUserIds.clear();
    final results = await flow.sendGroupText(
      groupId: groupId,
      senderUserId: _userA,
      senderDeviceId: 'devA',
      text: '大家好',
    );
    expect(results.length, 2);
    expect(delivered.map((e) => e.recipientUserId).toSet(), {_userB, _userC});
    // 同一份密文扇 2 封。
    expect(delivered[0].openmlsCiphertext, delivered[1].openmlsCiphertext);
    expect(deliveredUserIds.toSet(), {_userB, _userC});
    final afterSend = await store.readMessages(
      ownerUserId: _ownerUserId,
      currentAccountId: _accountA,
      conversationId: groupId,
    );
    final outgoing = afterSend.where((m) => m.direction == 'outgoing').toList();
    expect(outgoing.length, 1);
    expect(
      ChatPayloadCodec.decode(outgoing.single.plaintext ?? '').text,
      '大家好',
    );

    // 收到 B 的文本。
    final payload = ChatPayloadCodec.encode(ChatContent.text('收到'));
    final inboundWire = MlsWireMessage(
      wireBytes: utf8.encode(payload),
      conversationId: groupId,
      messageKind: MlsMessageKind.application,
    );
    final inbound = inboundWire.toEncryptedMessage(
      messageId: 'in-1',
      senderUserId: _userB,
      recipientUserId: _userA,
      senderDeviceId: 'devB',
      recipientDeviceId: 'devA',
      createdAtMillis: 100,
    );
    await flow.processIncomingGroupMessage(inbound.writeToBuffer());
    final afterIncoming = await store.readMessages(
      ownerUserId: _ownerUserId,
      currentAccountId: _accountA,
      conversationId: groupId,
    );
    final incoming = afterIncoming
        .where((m) => m.direction == 'incoming')
        .toList();
    expect(incoming.length, 1);
    expect(ChatPayloadCodec.decode(incoming.single.plaintext ?? '').text, '收到');

    // 删除 C → 名册剩 A、B;Commit 扇给删前成员 B、C(减自己)。
    delivered.clear();
    deliveredUserIds.clear();
    await flow.removeMembers(
      groupId: groupId,
      actorUserId: _userA,
      actorDeviceId: 'devA',
      targetUserIds: [_userC],
    );
    final afterRemove = await store.readGroup(_ownerUserId, groupId);
    expect(afterRemove!.memberUserIds.toSet(), {_userA, _userB});
    expect(delivered.map((e) => e.recipientUserId).toSet(), {_userB, _userC});
  });

  test('非 admin 加人被拒', () async {
    final store = ChatStore();
    final crypto = _FakeGroupCrypto(userId: _userA, localDeviceId: 'devA');
    Future<ChatDeliveryResult> deliverer(
      EncryptedMessage message,
      List<int> bytes,
      String recipientUserId,
      String recipientDeviceId,
    ) async => ChatDeliveryResult(
      messageId: message.messageId,
      transportType: ChatTransportType.server,
      state: ChatMessageDeliveryState.sent,
    );
    final flow = ChatGroupFlow(
      ownerUserId: _ownerUserId,
      crypto: crypto,
      store: store,
      bindingToken: await _bindingToken(store),
      deliverer: deliverer,
      userId: _userA,
      currentAccountId: _accountA,
      localDeviceId: 'devA',
    );
    const groupId = 'grp:$_userA:n';
    await flow.createGroup(
      groupId: groupId,
      name: 'g',
      userId: _userA,
      localDeviceId: 'devA',
      invitees: [_keyPackage(_userB, 'devB')],
    );

    await expectLater(
      flow.addMembers(
        groupId: groupId,
        actorUserId: _userB, // 非 admin
        actorDeviceId: 'devB',
        invitees: [_keyPackage(_userD, 'devD')],
      ),
      throwsA(isA<GroupMembershipException>()),
    );
  });

  test('admin 收到 leave_request → 自动移除退群者(后向保密)', () async {
    final store = ChatStore();
    final crypto = _FakeGroupCrypto(userId: _userA, localDeviceId: 'devA');
    final flow = ChatGroupFlow(
      ownerUserId: _ownerUserId,
      crypto: crypto,
      store: store,
      bindingToken: await _bindingToken(store),
      deliverer: (message, bytes, recipientUserId, recipientDeviceId) async =>
          ChatDeliveryResult(
            messageId: message.messageId,
            transportType: ChatTransportType.server,
            state: ChatMessageDeliveryState.sent,
          ),
      userId: _userA,
      currentAccountId: _accountA,
      localDeviceId: 'devA',
    );
    const groupId = 'grp:$_userA:n';
    await flow.createGroup(
      groupId: groupId,
      name: 'g',
      userId: _userA,
      localDeviceId: 'devA',
      invitees: [_keyPackage(_userB, 'devB'), _keyPackage(_userC, 'devC')],
    );

    // user ID B 发来退群请求(fake groupProcess 回显 wire 明文)。
    final payload = GroupControlCodec.encode(const GroupControl.leaveRequest());
    final wire = MlsWireMessage(
      wireBytes: utf8.encode(payload),
      conversationId: groupId,
      messageKind: MlsMessageKind.application,
    );
    final message = wire.toEncryptedMessage(
      messageId: 'lr-1',
      senderUserId: _userB,
      recipientUserId: _userA,
      senderDeviceId: 'devB',
      recipientDeviceId: 'devA',
      createdAtMillis: 1,
    );
    await flow.processIncomingGroupMessage(message.writeToBuffer());
    final group = await store.readGroup(_ownerUserId, groupId);
    expect(group!.memberUserIds.toSet(), {_userA, _userC}); // B 被移除
  });

  test('收到 rename → 群名更新(非 admin 收端也同步)', () async {
    final store = ChatStore();
    final crypto = _FakeGroupCrypto(userId: _userB, localDeviceId: 'devB');
    final flow = ChatGroupFlow(
      ownerUserId: _ownerUserId,
      crypto: crypto,
      store: store,
      bindingToken: await _bindingToken(store),
      deliverer: (message, bytes, recipientUserId, recipientDeviceId) async =>
          ChatDeliveryResult(
            messageId: message.messageId,
            transportType: ChatTransportType.server,
            state: ChatMessageDeliveryState.sent,
          ),
      userId: _userB,
      currentAccountId: _accountA,
      localDeviceId: 'devB',
    );
    const groupId = 'grp:$_userA:n2';
    await store.upsertGroupShell(
      ownerUserId: _ownerUserId,
      currentAccountId: _accountA,
      groupId: groupId,
      groupName: '旧名',
      creatorUserId: _userA,
      epoch: 1,
      bindingToken: await _bindingToken(store),
    );

    final payload = GroupControlCodec.encode(GroupControl.rename('新群名'));
    final wire = MlsWireMessage(
      wireBytes: utf8.encode(payload),
      conversationId: groupId,
      messageKind: MlsMessageKind.application,
    );
    final message = wire.toEncryptedMessage(
      messageId: 'rn-1',
      senderUserId: _userA,
      recipientUserId: _userB,
      senderDeviceId: 'devA',
      recipientDeviceId: 'devB',
      createdAtMillis: 1,
    );
    await flow.processIncomingGroupMessage(message.writeToBuffer());
    final group = await store.readGroup(_ownerUserId, groupId);
    expect(group!.name, '新群名');
  });

  test('群发贴纸:落 sticker 消息 + 扇出', () async {
    final store = ChatStore();
    final crypto = _FakeGroupCrypto(userId: _userA, localDeviceId: 'devA');
    final delivered = <EncryptedMessage>[];
    final flow = ChatGroupFlow(
      ownerUserId: _ownerUserId,
      crypto: crypto,
      store: store,
      bindingToken: await _bindingToken(store),
      deliverer: (message, bytes, recipientUserId, recipientDeviceId) async {
        delivered.add(message);
        return ChatDeliveryResult(
          messageId: message.messageId,
          transportType: ChatTransportType.server,
          state: ChatMessageDeliveryState.sent,
        );
      },
      userId: _userA,
      currentAccountId: _accountA,
      localDeviceId: 'devA',
    );
    const groupId = 'grp:$_userA:ns';
    await flow.createGroup(
      groupId: groupId,
      name: 'g',
      userId: _userA,
      localDeviceId: 'devA',
      invitees: [_keyPackage(_userB, 'devB')],
    );

    delivered.clear();
    await flow.sendGroupSticker(
      groupId: groupId,
      senderUserId: _userA,
      senderDeviceId: 'devA',
      packId: 'fluent3d',
      stickerId: 'grinning_face',
    );
    expect(delivered.map((e) => e.recipientUserId).toSet(), {_userB});
    final messages = await store.readMessages(
      ownerUserId: _ownerUserId,
      currentAccountId: _accountA,
      conversationId: groupId,
    );
    final sticker = messages.firstWhere(
      (m) => m.messageKind == ChatMessageKind.sticker,
    );
    expect(sticker.direction, 'outgoing');
  });

  group('群媒体云端密文控制消息', () {
    Future<ChatGroupFlow<ChatBindingFenceToken>> buildGroup(
      ChatStore store, {
      EncryptedMessageDeliverer deliverer = _okDeliverer,
    }) async {
      final crypto = _FakeGroupCrypto(userId: _userA, localDeviceId: 'devA');
      final flow = ChatGroupFlow<ChatBindingFenceToken>(
        ownerUserId: _ownerUserId,
        crypto: crypto,
        store: store,
        bindingToken: await _bindingToken(store),
        deliverer: deliverer,
        userId: _userA,
        currentAccountId: _accountA,
        localDeviceId: 'devA',
      );
      await flow.createGroup(
        groupId: 'grp:$_userA:nm',
        name: 'g',
        userId: _userA,
        localDeviceId: 'devA',
        invitees: [_keyPackage(_userB, 'devB'), _keyPackage(_userC, 'devC')],
      );
      return flow;
    }

    ChatContent mediaContent(int byteSize) => ChatContent.media(
      kind: ChatMessageKind.file,
      attachmentId: 'att-group-1',
      fileName: 'archive.bin',
      mime: 'application/octet-stream',
      byteSize: byteSize,

      attachmentChatEpoch: 1,
      attachmentGroupId: 'attachment:CID-A:${'11' * 32}:att-group-1',
      attachmentWelcome: 'AQID',
      attachmentMemberIdentities: ['CID-A:${'11' * 32}', 'CID-B:${'22' * 32}'],
      attachmentSenderMemberIdentity: 'CID-A:${'11' * 32}',
      attachmentChunkCount: ((byteSize) + 1024 * 1024 - 1) ~/ (1024 * 1024),
      plainSha256: '00' * 32,
      cipherByteSize: byteSize + 16,
      cipherSha256: List<String>.filled(64, 'a').join(),
    );

    test('群附件收件人只包含其他成员且每个 user ID 只出现一次', () async {
      final store = ChatStore();
      final flow = await buildGroup(store);

      final recipients = await flow.recipientUserIds(
        groupId: 'grp:$_userA:nm',
        senderUserId: _userA,
      );

      expect(recipients.toSet(), {_userB, _userC});
      expect(recipients, hasLength(2));
    });

    test('群附件只保存一条控制消息并向所有成员扇出', () async {
      final store = ChatStore();
      final delivered = <EncryptedMessage>[];
      final events = <String>[];
      final flow = await buildGroup(
        store,
        deliverer: (message, _, _, _) async {
          events.add('deliver');
          delivered.add(message);
          return ChatDeliveryResult(
            messageId: message.messageId,
            transportType: ChatTransportType.server,
            state: ChatMessageDeliveryState.sent,
          );
        },
      );
      events.clear();
      delivered.clear();

      await flow.sendGroupAttachmentControl(
        groupId: 'grp:$_userA:nm',
        senderUserId: _userA,
        senderDeviceId: 'devA',
        content: mediaContent(200 * 1024 * 1024),
        onApplicationStored: () async => events.add('stored'),
      );

      expect(events.first, 'stored');
      expect(delivered.map((e) => e.recipientUserId).toSet(), {_userB, _userC});
      expect(delivered.every((e) => e.deliveries.length == 1), isTrue);
      final messages = await store.readMessages(
        ownerUserId: _ownerUserId,
        currentAccountId: _accountA,
        conversationId: 'grp:$_userA:nm',
      );
      final content = ChatPayloadCodec.decode(messages.last.plaintext ?? '');
      expect(content.attachmentId, 'att-group-1');
      expect(content.byteSize, 200 * 1024 * 1024);
      expect(content.cipherSha256, List<String>.filled(64, 'a').join());
    });
  });
}
