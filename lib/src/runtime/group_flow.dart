// 私密小群收发编排。串起 MlsGroupCrypto(密码学)、GroupFanout(扇出)、
// GroupEpochOrdering(有序)、ChatFlowStore<TBindingToken>(落库)与 deliverer(投递)。
// 本层不实现密码学;核心可注入 fake 单测。
// 群消息流程由本模块测试固定。

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../core/chat_content.dart';
import '../core/chat_message.dart';
import '../core/message_id.dart';
import '../group/control.dart';
import '../group/epoch_ordering.dart';
import '../group/membership.dart';
import '../group/message/fanout.dart';
import '../group/model.dart';
import '../mls/mls_boundary.dart';
import '../mls/mls_group_boundary.dart';
import '../protocol/message.dart';
import '../storage/flow_store.dart';
import '../transport/chat_transport.dart';
import 'direct_flow.dart';

/// 群 ID 形如 `grp:<creator user ID>:<nonce>`。
String creatorUserIdFromGroupId(String groupId) {
  final parts = groupId.split(':');
  return parts.length >= 2 ? parts[1] : '';
}

/// 生成群 ID（创建者 user ID + 随机 nonce）。
String newGroupId(String creatorUserId) {
  return 'grp:$creatorUserId:${_nonce()}';
}

/// 登记/清除某成员的待投递群媒体(离线补发按成员;键 attachmentId+成员 user ID)。
class ChatGroupFlow<TBindingToken> {
  const ChatGroupFlow({
    required MlsGroupCrypto crypto,
    required ChatFlowStore<TBindingToken> store,
    required EncryptedMessageDeliverer deliverer,
    required TBindingToken bindingToken,
    required String ownerUserId,
    required String userId,
    required String currentAccountId,
    required String localDeviceId,
    this.deliveryScheduler,
    this.afterIncomingStore,
  }) : _crypto = crypto,
       _store = store,
       _deliverer = deliverer,
       _bindingToken = bindingToken,
       _ownerUserId = ownerUserId,
       _userId = userId,
       _currentAccountId = currentAccountId,
       _localDeviceId = localDeviceId;

  final MlsGroupCrypto _crypto;
  final ChatFlowStore<TBindingToken> _store;
  final EncryptedMessageDeliverer _deliverer;
  final TBindingToken _bindingToken;

  final String _ownerUserId;

  /// 本机聊天 user ID 与设备 ID（入站处理判定自身、代提交退群移除的 fanout 发送者）。
  final String _userId;
  final String _currentAccountId;
  final String _localDeviceId;
  final EncryptedMessageDeliveryScheduler? deliveryScheduler;

  /// 群消息已经落库后的独立附件任务；不得阻塞群 epoch 与后续消息。
  final ChatIncomingContentHandler? afterIncomingStore;

  /// 建群:创建者为唯一成员(admin),可选带初始邀请。
  Future<ChatGroup> createGroup({
    required String groupId,
    required String name,
    required String userId,
    required String localDeviceId,
    List<MlsKeyPackage> invitees = const [],
  }) async {
    GroupMembership.ensureCanCreate(inviteeCount: invitees.length);
    final created = await _crypto.createGroup(groupId);
    await _store.upsertGroupShell(
      bindingToken: _bindingToken,
      ownerUserId: _ownerUserId,
      currentAccountId: _currentAccountId,
      groupId: groupId,
      groupName: name,
      creatorUserId: userId,
      epoch: created.epoch,
    );
    await _store.reconcileGroupRoster(
      bindingToken: _bindingToken,
      ownerUserId: _ownerUserId,
      groupId: groupId,
      members: {userId: GroupMemberRole.admin},
      epoch: created.epoch,
    );
    if (invitees.isNotEmpty) {
      await _addMembersInternal(
        groupId: groupId,
        actorUserId: userId,
        actorDeviceId: localDeviceId,
        creatorUserId: userId,
        existingUserIds: [userId],
        invitees: invitees,
      );
    }
    final group = await _store.readGroup(_ownerUserId, groupId);
    return group!;
  }

  /// 加人(仅 admin)。
  Future<void> addMembers({
    required String groupId,
    required String actorUserId,
    required String actorDeviceId,
    required List<MlsKeyPackage> invitees,
  }) async {
    final group = await _requireGroup(groupId);
    GroupMembership.ensureAdmin(
      adminSet: group.adminSet,
      actorUserId: actorUserId,
    );
    GroupMembership.ensureCanAdd(
      currentCount: group.roster.length,
      addingCount: invitees.length,
    );
    await _addMembersInternal(
      groupId: groupId,
      actorUserId: actorUserId,
      actorDeviceId: actorDeviceId,
      creatorUserId: group.creatorUserId,
      existingUserIds: group.memberUserIds,
      invitees: invitees,
    );
  }

  Future<void> _addMembersInternal({
    required String groupId,
    required String actorUserId,
    required String actorDeviceId,
    required String creatorUserId,
    required List<String> existingUserIds,
    required List<MlsKeyPackage> invitees,
  }) async {
    final existingMembers = membersFromMemberIdentities(
      (await _crypto.groupState(groupId)).memberIdentities,
    );
    final bundle = await _crypto.addMembers(groupId, invitees);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

    // Welcome → 全部新人;Commit → 现有成员(减自己)。
    final inviteeMembers = invitees
        .map(
          (keyPackage) => MlsMemberIdentity(
            userId: keyPackage.userId,
            deviceId: keyPackage.deviceId,
          ),
        )
        .toList(growable: false);
    final welcome = bundle.welcome;
    if (welcome != null && inviteeMembers.isNotEmpty) {
      await _fanoutHandshake(
        wire: welcome,
        recipients: inviteeMembers,
        senderUserId: actorUserId,
        senderDeviceId: actorDeviceId,
        groupId: groupId,
        nowMillis: nowMillis,
        tag: 'welcome',
      );
    }
    final commitRecipients = existingMembers
        .where(
          (member) =>
              member.userId != actorUserId || member.deviceId != actorDeviceId,
        )
        .toList(growable: false);
    if (commitRecipients.isNotEmpty) {
      await _fanoutHandshake(
        wire: bundle.commit,
        recipients: commitRecipients,
        senderUserId: actorUserId,
        senderDeviceId: actorDeviceId,
        groupId: groupId,
        nowMillis: nowMillis,
        tag: 'commit',
      );
    }
    await _reconcileFromChain(groupId, creatorUserId);
  }

  /// 删人（仅 admin，按 user ID）。
  Future<void> removeMembers({
    required String groupId,
    required String actorUserId,
    required String actorDeviceId,
    required List<String> targetUserIds,
  }) async {
    final group = await _requireGroup(groupId);
    GroupMembership.ensureAdmin(
      adminSet: group.adminSet,
      actorUserId: actorUserId,
    );
    final recipients =
        membersFromMemberIdentities(
              (await _crypto.groupState(groupId)).memberIdentities,
            )
            .where(
              (member) =>
                  member.userId != actorUserId ||
                  member.deviceId != actorDeviceId,
            )
            .toList(growable: false);
    final bundle = await _crypto.removeMembers(groupId, targetUserIds);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

    // Commit → 剩余成员 + 被删者(镜像此刻仍含被删者),都减自己。
    if (recipients.isNotEmpty) {
      await _fanoutHandshake(
        wire: bundle.commit,
        recipients: recipients,
        senderUserId: actorUserId,
        senderDeviceId: actorDeviceId,
        groupId: groupId,
        nowMillis: nowMillis,
        tag: 'commit',
      );
    }
    await _reconcileFromChain(groupId, group.creatorUserId);
  }

  /// 退群:先发退群请求(群 admin 收到后自动 removeMembers 重钥,保证后向保密),
  /// 再本机即刻标记已退、停止参与。发送失败不阻断本机退出。
  Future<void> leaveGroup(String groupId) async {
    final group = await _store.readGroup(_ownerUserId, groupId);
    if (group != null && !group.leftLocally) {
      try {
        await sendGroupControl(groupId, const GroupControl.leaveRequest());
      } catch (_) {
        // 控制消息发送失败(离线等)不阻断本机退出;后向保密待 admin 后续收敛。
      }
    }
    await _store.markGroupLeft(
      _ownerUserId,
      groupId,
      bindingToken: _bindingToken,
    );
  }

  /// 改群名(仅 admin):本机改 + 广播 rename 让全员同步(补 Welcome 不带名的缺口)。
  Future<void> renameGroup(String groupId, String name) async {
    final group = await _requireGroup(groupId);
    GroupMembership.ensureAdmin(adminSet: group.adminSet, actorUserId: _userId);
    await _store.renameGroup(
      _ownerUserId,
      groupId,
      name,
      bindingToken: _bindingToken,
    );
    await sendGroupControl(groupId, GroupControl.rename(name));
  }

  /// 广播群控制消息(改名/退群请求):走 E2E application 扇出,**不落聊天消息行**。
  Future<void> sendGroupControl(String groupId, GroupControl control) async {
    await _requireGroup(groupId);
    final recipients =
        membersFromMemberIdentities(
              (await _crypto.groupState(groupId)).memberIdentities,
            )
            .where(
              (member) =>
                  member.userId != _userId || member.deviceId != _localDeviceId,
            )
            .toList(growable: false);
    if (recipients.isEmpty) {
      return;
    }
    final wire = await _crypto.groupCreateMessage(
      groupId,
      utf8.encode(GroupControlCodec.encode(control)),
    );
    await _fanoutHandshake(
      wire: wire,
      recipients: recipients,
      senderUserId: _userId,
      senderDeviceId: _localDeviceId,
      groupId: groupId,
      nowMillis: DateTime.now().millisecondsSinceEpoch,
      tag: 'ctrl',
    );
  }

  /// 群发文本:单次加密 → 扇 N 条设备消息 → 1 条逻辑消息 + N 出站队列。
  Future<List<ChatDeliveryResult>> sendGroupText({
    required String groupId,
    required String senderUserId,
    required String senderDeviceId,
    required String text,
  }) {
    return _sendGroupUserMessage(
      groupId: groupId,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      messageKind: ChatMessageKind.text,
      payload: ChatPayloadCodec.encode(ChatContent.text(text)),
    );
  }

  /// 群发内置贴纸(零字节,收端本地渲染;复用群发用户消息编排)。
  Future<List<ChatDeliveryResult>> sendGroupSticker({
    required String groupId,
    required String senderUserId,
    required String senderDeviceId,
    required String packId,
    required String stickerId,
  }) {
    return _sendGroupUserMessage(
      groupId: groupId,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      messageKind: ChatMessageKind.sticker,
      payload: ChatPayloadCodec.encode(
        ChatContent.sticker(packId: packId, stickerId: stickerId),
      ),
    );
  }

  /// Returns the current group recipients for one encrypted cloud object.
  Future<List<String>> recipientUserIds({
    required String groupId,
    required String senderUserId,
  }) async {
    final group = await _store.readGroup(_ownerUserId, groupId);
    if (group == null || group.leftLocally) {
      throw StateError('群聊不存在或已退出');
    }
    return group.memberUserIds
        .where((userId) => userId != senderUserId)
        .toList(growable: false);
  }

  /// Queues only the encrypted attachment control payload. Attachment bytes are
  /// uploaded once to private R2 and are never sent through WebRTC DataChannel.
  Future<List<ChatDeliveryResult>> sendGroupAttachmentControl({
    required String groupId,
    required String senderUserId,
    required String senderDeviceId,
    required ChatContent content,
    ChatMediaLocalCommitNotifier? onApplicationStored,
    String? pendingLocalMessageId,
    int? createdAtMillis,
  }) {
    if (!content.isMedia) {
      throw ArgumentError.value(content.kind, 'content', '必须是媒体消息');
    }
    return _sendGroupUserMessage(
      groupId: groupId,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      messageKind: content.kind,
      payload: ChatPayloadCodec.encode(content),
      onApplicationStored: onApplicationStored,
      pendingLocalMessageId: pendingLocalMessageId,
      createdAtMillis: createdAtMillis,
    );
  }

  /// 群发用户消息(文本/贴纸)共用编排:单次加密 → 扇 N → 1 逻辑消息 + N 出站队列。
  Future<List<ChatDeliveryResult>> _sendGroupUserMessage({
    required String groupId,
    required String senderUserId,
    required String senderDeviceId,
    required ChatMessageKind messageKind,
    required String payload,
    ChatMediaLocalCommitNotifier? onApplicationStored,
    String? pendingLocalMessageId,
    int? createdAtMillis,
  }) async {
    final group = await _requireGroup(groupId);
    if (group.leftLocally) {
      throw StateError('已退出该群，无法发送');
    }
    final nowMillis = createdAtMillis ?? DateTime.now().millisecondsSinceEpoch;
    final wire = await _crypto.groupCreateMessage(
      groupId,
      utf8.encode(payload),
    );
    final recipients =
        membersFromMemberIdentities(
              (await _crypto.groupState(groupId)).memberIdentities,
            )
            .where(
              (member) =>
                  member.userId != senderUserId ||
                  member.deviceId != senderDeviceId,
            )
            .toList(growable: false);
    if (pendingLocalMessageId != null &&
        !pendingLocalMessageId.startsWith('pending:')) {
      throw StateError('Chat 群待发送消息编号不合法');
    }
    final messages = GroupMessageFanout.fanOut(
      wire: wire,
      recipients: recipients,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      createdAtMillis: nowMillis,
    );
    // 群逻辑行直接由本次 OpenMLS 密文的既有字段确定，不再生成另一套消息编号。
    final logicalMessageId = MessageId.derive(
      conversationId: groupId,
      senderUserId: senderUserId,
      recipientUserId: senderUserId,
      createdAtMillis: nowMillis,
      encryptedMessage: wire.wireBytes,
    );
    await _store.saveOutgoingGroupMessage(
      bindingToken: _bindingToken,
      ownerUserId: _ownerUserId,
      currentAccountId: _currentAccountId,
      groupId: groupId,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      logicalMessageId: logicalMessageId,
      messageKind: messageKind,
      payload: payload,
      createdAtMillis: nowMillis,
      messages: messages,
      recipientUserByUserId: {
        for (final member in recipients) member.userId: member.userId,
      },
      pendingLocalMessageId: pendingLocalMessageId,
    );
    await onApplicationStored?.call();
    Future<List<ChatDeliveryResult>> deliverQueued() async {
      final results = <ChatDeliveryResult>[];
      for (final message in messages) {
        final result = await _deliverer(
          message,
          message.writeToBuffer(),
          message.recipientUserId,
          message.recipientDeviceId,
        );
        await _store.markOutgoingDelivery(
          bindingToken: _bindingToken,
          ownerUserId: _ownerUserId,
          messageId: message.messageId,
          state: result.state,
          errorMessage: result.errorMessage,
        );
        results.add(result);
      }
      // 逻辑消息态:任一投出即 sent,否则维持 queued。
      final anySent = results.any(
        (result) => result.state == ChatMessageDeliveryState.sent,
      );
      await _store.markOutgoingDelivery(
        bindingToken: _bindingToken,
        ownerUserId: _ownerUserId,
        messageId: logicalMessageId,
        state: anySent
            ? ChatMessageDeliveryState.sent
            : ChatMessageDeliveryState.queued,
      );
      return results;
    }

    final scheduler = deliveryScheduler;
    if (scheduler != null) {
      scheduler(groupId, () async {
        await deliverQueued();
      });
      return const <ChatDeliveryResult>[];
    }
    return deliverQueued();
  }

  /// 处理入站群 message:经 epoch 有序处理后落地。
  ///
  /// 入群前(未处理 Welcome)到达的 Commit/Application 会让 Rust 报"群会话不存在",
  /// 此时存入 pending-inbound,由 Welcome 处理后回放(复用 1:1 机制)。
  Future<List<EncryptedMessage>> processIncomingGroupMessage(
    List<int> messageBytes,
  ) async {
    final message = EncryptedMessage.fromBuffer(messageBytes);
    final wire = mlsWireMessageFromEncryptedMessage(message);
    final acceptedMessages = <EncryptedMessage>[];
    try {
      await GroupEpochOrdering.processOrdered(
        wire: wire,
        message: message,
        process: _crypto.groupProcess,
        bufferPut: (groupId, messageEpoch, bufferedMessage) =>
            _store.bufferGroupCommit(
              bindingToken: _bindingToken,
              ownerUserId: _ownerUserId,
              groupId: groupId,
              messageEpoch: messageEpoch,
              message: bufferedMessage,
              messageBytes: bufferedMessage.writeToBuffer(),
            ),
        bufferTake: (groupId, messageEpoch) => _store.takeGroupPendingCommit(
          _ownerUserId,
          groupId,
          messageEpoch,
          bindingToken: _bindingToken,
        ),
        wireFromMessage: mlsWireMessageFromEncryptedMessage,
        onProcessed: (processedMessage, result) async {
          if (result.status == GroupProcessStatus.applied) {
            final replayed = await _applyInbound(
              processedMessage,
              processedMessage.writeToBuffer(),
              result,
            );
            acceptedMessages
              ..add(processedMessage)
              ..addAll(replayed);
          } else if (result.status == GroupProcessStatus.stale) {
            // stale 表示该 epoch 已被本机处理；重复 message 只需重发设备确认。
            acceptedMessages.add(processedMessage);
          }
        },
      );
      return List<EncryptedMessage>.unmodifiable(acceptedMessages);
    } catch (error) {
      if (_needsWelcomeFirst(error)) {
        await _store.savePendingInbound(
          bindingToken: _bindingToken,
          ownerUserId: _ownerUserId,
          message: message,
          messageBytes: messageBytes,
          reason: error.toString(),
        );
        return const <EncryptedMessage>[];
      }
      rethrow;
    }
  }

  Future<List<EncryptedMessage>> _applyInbound(
    EncryptedMessage message,
    List<int> messageBytes,
    GroupInbound result,
  ) async {
    if (!result.isApplied) {
      return const <EncryptedMessage>[]; // out_of_order 已缓冲;stale 丢弃。
    }
    final replayedMessages = <EncryptedMessage>[];
    final creator = creatorUserIdFromGroupId(result.groupId);
    switch (result.kind) {
      case GroupInboundKind.welcome:
        await _store.upsertGroupShell(
          bindingToken: _bindingToken,
          ownerUserId: _ownerUserId,
          currentAccountId: _currentAccountId,
          groupId: result.groupId,
          groupName: '群聊',
          creatorUserId: creator,
          epoch: result.groupEpoch,
        );
        await _reconcileRosterFrom(result, creator);
        // 回放入群前缓冲的同群消息。
        final pending = await _store.takePendingInbound(
          _ownerUserId,
          result.groupId,
          bindingToken: _bindingToken,
        );
        for (final buffered in pending) {
          replayedMessages.addAll(
            await processIncomingGroupMessage(buffered.writeToBuffer()),
          );
        }
      case GroupInboundKind.commit:
        if (result.selfRemoved) {
          await _store.markGroupLeft(
            _ownerUserId,
            result.groupId,
            bindingToken: _bindingToken,
          );
          return replayedMessages;
        }
        await _reconcileRosterFrom(result, creator);
      case GroupInboundKind.application:
        final plaintext = utf8.decode(result.plaintext ?? const []);
        // 群控制消息先判别:是控制则处理、绝不当聊天消息显示;否则落普通消息。
        final control = GroupControlCodec.tryDecode(plaintext);
        if (control != null) {
          await _handleGroupControl(message, control);
          return replayedMessages;
        }
        final content = ChatPayloadCodec.decode(plaintext);
        await _store.saveIncomingGroupMessage(
          bindingToken: _bindingToken,
          ownerUserId: _ownerUserId,
          currentAccountId: _currentAccountId,
          message: message,
          messageBytes: messageBytes,
          messageKind: content.kind,
          plaintext: plaintext,
        );
        final postStore = afterIncomingStore?.call(message, content);
        if (postStore != null) {
          // 群附件失败只影响该附件；控制消息已落库，后续群 epoch 必须继续推进。
          unawaited(postStore.catchError((Object _) {}));
        }
      case GroupInboundKind.unknown:
        break;
    }
    return replayedMessages;
  }

  Future<void> _handleGroupControl(
    EncryptedMessage message,
    GroupControl control,
  ) async {
    final groupId = message.conversationId;
    switch (control.op) {
      case GroupControlOp.rename:
        await _store.renameGroup(
          _ownerUserId,
          groupId,
          control.groupName ?? '',
          bindingToken: _bindingToken,
        );
      case GroupControlOp.leaveRequest:
        final group = await _store.readGroup(_ownerUserId, groupId);
        if (group == null || group.leftLocally) {
          return;
        }
        // 仅本机是 admin 时代提交移除退群者;其余成员忽略,靠 admin 的 Commit 收敛。
        if (group.adminSet.contains(_userId)) {
          await removeMembers(
            groupId: groupId,
            actorUserId: _userId,
            actorDeviceId: _localDeviceId,
            targetUserIds: [message.senderUserId],
          );
        }
    }
  }

  Future<void> _reconcileFromChain(String groupId, String creatorUserId) async {
    final state = await _crypto.groupState(groupId);
    await _store.reconcileGroupRoster(
      bindingToken: _bindingToken,
      ownerUserId: _ownerUserId,
      groupId: groupId,
      members: _rolesFor(state.memberIdentities, creatorUserId),
      epoch: state.epoch,
    );
  }

  Future<void> _reconcileRosterFrom(
    GroupInbound result,
    String creatorUserId,
  ) async {
    final identities = result.memberIdentities ?? const [];
    await _store.reconcileGroupRoster(
      bindingToken: _bindingToken,
      ownerUserId: _ownerUserId,
      groupId: result.groupId,
      members: _rolesFor(identities, creatorUserId),
      epoch: result.groupEpoch,
    );
  }

  Map<String, GroupMemberRole> _rolesFor(
    Iterable<String> identities,
    String creatorUserId,
  ) {
    final userIds = userIdsFromMemberIdentities(identities);
    return {
      for (final userId in userIds)
        userId: userId == creatorUserId
            ? GroupMemberRole.admin
            : GroupMemberRole.member,
    };
  }

  Future<void> _fanoutHandshake({
    required MlsWireMessage wire,
    required List<MlsMemberIdentity> recipients,
    required String senderUserId,
    required String senderDeviceId,
    required String groupId,
    required int nowMillis,
    required String tag,
  }) async {
    if (tag.isEmpty) throw ArgumentError.value(tag, 'tag', '群握手类型不能为空');
    final messages = GroupMessageFanout.fanOut(
      wire: wire,
      recipients: recipients,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      createdAtMillis: nowMillis,
    );
    for (final message in messages) {
      final bytes = message.writeToBuffer();
      final recipientUserId = message.recipientUserId;
      await _store.queueOutgoingMessage(
        bindingToken: _bindingToken,
        ownerUserId: _ownerUserId,
        message: message,
        messageBytes: bytes,
        recipientUserId: recipientUserId,
        deliveryState: ChatMessageDeliveryState.queued,
      );
      final result = await _deliverer(
        message,
        bytes,
        recipientUserId,
        message.recipientDeviceId,
      );
      await _store.markOutgoingDelivery(
        bindingToken: _bindingToken,
        ownerUserId: _ownerUserId,
        messageId: message.messageId,
        state: result.state,
        errorMessage: result.errorMessage,
      );
    }
  }

  Future<ChatGroup> _requireGroup(String groupId) async {
    final group = await _store.readGroup(_ownerUserId, groupId);
    if (group == null) {
      throw StateError('群不存在: $groupId');
    }
    return group;
  }
}

bool _needsWelcomeFirst(Object error) {
  return error.toString().contains('群会话不存在');
}

String _nonce() {
  final random = Random.secure();
  final bytes = List<int>.generate(8, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
