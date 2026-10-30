import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_group/attachment/fanout.dart';
import 'package:tatachat_group/epoch_ordering.dart';
import 'package:tatachat_group/limits.dart';
import 'package:tatachat_group/membership.dart';
import 'package:tatachat_group/message/fanout.dart';
import 'package:tatachat_mls/mls_group_boundary.dart';
import 'package:tatachat_mls/mls_session.dart';
import 'package:tatachat_protocol/message.dart';

void main() {
  group('GroupMessageFanout', () {
    test('one ciphertext fans out to stable recipient messages', () {
      const wire = MlsWireMessage(
        wireBytes: [1, 2, 3, 4],
        conversationId: 'group:owner:n1',
        messageKind: MlsMessageKind.application,
      );
      final messages = GroupMessageFanout.fanOut(
        wire: wire,
        recipients: const [
          MlsMemberIdentity(userId: 'user-d', deviceId: 'device-d'),
          MlsMemberIdentity(userId: 'user-c', deviceId: 'device-c'),
          MlsMemberIdentity(userId: 'user-e', deviceId: 'device-e'),
        ],
        senderUserId: 'user-a',
        senderDeviceId: 'device-a',
        createdAtMillis: 1000,
      );

      expect(messages.length, 3);
      expect(messages.map((message) => message.recipientUserId).toList(), [
        'user-d',
        'user-c',
        'user-e',
      ]);
      for (final message in messages) {
        expect(message.openmlsCiphertext, const [1, 2, 3, 4]);
        expect(message.senderUserId, 'user-a');
        expect(message.conversationId, 'group:owner:n1');
      }
      expect(messages.map((message) => message.messageId).toSet().length, 3);

      final retried = GroupMessageFanout.fanOut(
        wire: wire,
        recipients: const [
          MlsMemberIdentity(userId: 'user-d', deviceId: 'device-d'),
          MlsMemberIdentity(userId: 'user-c', deviceId: 'device-c'),
          MlsMemberIdentity(userId: 'user-e', deviceId: 'device-e'),
        ],
        senderUserId: 'user-a',
        senderDeviceId: 'device-a',
        createdAtMillis: 1000,
      );
      expect(
        retried.map((message) => message.messageId),
        messages.map((message) => message.messageId),
      );
    });

    test('an empty recipient set produces no messages', () {
      const wire = MlsWireMessage(
        wireBytes: [9],
        conversationId: 'group:owner:n1',
        messageKind: MlsMessageKind.application,
      );
      expect(
        GroupMessageFanout.fanOut(
          wire: wire,
          recipients: const <MlsMemberIdentity>[],
          senderUserId: 'user-a',
          senderDeviceId: 'device-a',
          createdAtMillis: 1,
        ),
        isEmpty,
      );
    });
  });

  test('群附件入口保留相同用户其他设备、去重及失败边界', () {
    const wire = MlsWireMessage(
      wireBytes: [1, 2, 3],
      conversationId: 'grp:owner:fanout',
      messageKind: MlsMessageKind.application,
    );
    const recipients = [
      MlsMemberIdentity(userId: 'owner', deviceId: 'phone'),
      MlsMemberIdentity(userId: 'owner', deviceId: 'tablet'),
      MlsMemberIdentity(userId: 'peer', deviceId: 'phone'),
      MlsMemberIdentity(userId: 'peer', deviceId: 'phone'),
      MlsMemberIdentity(userId: '', deviceId: 'phone'),
      MlsMemberIdentity(userId: 'peer', deviceId: ''),
    ];
    final messages = GroupAttachmentFanout.fanOut(
      wire: wire,
      recipients: recipients,
      senderUserId: 'owner',
      senderDeviceId: 'phone',
      createdAtMillis: 10,
    );
    expect(messages.map((m) => (m.recipientUserId, m.recipientDeviceId)), [
      ('owner', 'tablet'),
      ('peer', 'phone'),
    ]);
    expect(messages.map((m) => m.openmlsCiphertext), everyElement([1, 2, 3]));
    expect(messages.map((m) => m.messageId).toSet(), hasLength(2));
    final ordinary = GroupMessageFanout.fanOut(
      wire: wire,
      recipients: recipients,
      senderUserId: 'owner',
      senderDeviceId: 'phone',
      createdAtMillis: 10,
    );
    expect(
      messages.map((m) => m.writeToBuffer()),
      ordinary.map((m) => m.writeToBuffer()),
    );
    expect(
      GroupAttachmentFanout.fanOut(
        wire: wire,
        recipients: const [],
        senderUserId: 'owner',
        senderDeviceId: 'phone',
        createdAtMillis: 10,
      ),
      isEmpty,
    );
    expect(
      () => GroupAttachmentFanout.fanOut(
        wire: wire,
        recipients: recipients,
        senderUserId: '',
        senderDeviceId: 'phone',
        createdAtMillis: 10,
      ),
      throwsArgumentError,
    );
  });

  group('GroupMembership', () {
    test('enforces the group member limit', () {
      expect(
        () =>
            GroupMembership.ensureCanCreate(inviteeCount: kMaxGroupMembers - 1),
        returnsNormally,
      );
      expect(
        () => GroupMembership.ensureCanCreate(inviteeCount: kMaxGroupMembers),
        throwsA(isA<GroupMembershipException>()),
      );
      expect(
        () => GroupMembership.ensureCanAdd(
          currentCount: kMaxGroupMembers - 1,
          addingCount: 1,
        ),
        returnsNormally,
      );
      expect(
        () => GroupMembership.ensureCanAdd(
          currentCount: kMaxGroupMembers,
          addingCount: 1,
        ),
        throwsA(isA<GroupMembershipException>()),
      );
    });

    test('allows only an administrator to change membership', () {
      expect(
        () => GroupMembership.ensureAdmin(
          adminSet: const {'user-a'},
          actorUserId: 'user-a',
        ),
        returnsNormally,
      );
      expect(
        () => GroupMembership.ensureAdmin(
          adminSet: const {'user-a'},
          actorUserId: 'user-d',
        ),
        throwsA(isA<GroupMembershipException>()),
      );
    });
  });

  test('GroupEpochOrdering buffers and drains future commits', () async {
    const groupId = 'group:owner:n1';
    var current = 5;
    final buffer = <int, List<EncryptedMessage>>{};
    final processedEpochs = <int>[];

    MlsWireMessage commitWire(int messageEpoch) => MlsWireMessage(
      wireBytes: [messageEpoch],
      conversationId: groupId,
      messageKind: MlsMessageKind.application,
    );
    EncryptedMessage messageFor(int messageEpoch) =>
        commitWire(messageEpoch).toEncryptedMessage(
          messageId: 'e$messageEpoch',
          senderUserId: 'user-s',
          recipientUserId: 'user-r',
          senderDeviceId: 'device-s',
          recipientDeviceId: 'device-r',
          createdAtMillis: 0,
        );

    Future<GroupInbound> process(MlsWireMessage wire) async {
      final messageEpoch = wire.wireBytes.first;
      if (messageEpoch > current) {
        return GroupInbound(
          groupId: groupId,
          kind: GroupInboundKind.unknown,
          status: GroupProcessStatus.outOfOrder,
          messageEpoch: messageEpoch,
          groupEpoch: current,
          selfRemoved: false,
        );
      }
      if (messageEpoch < current) {
        return GroupInbound(
          groupId: groupId,
          kind: GroupInboundKind.unknown,
          status: GroupProcessStatus.stale,
          messageEpoch: messageEpoch,
          groupEpoch: current,
          selfRemoved: false,
        );
      }
      current = messageEpoch + 1;
      return GroupInbound(
        groupId: groupId,
        kind: GroupInboundKind.commit,
        status: GroupProcessStatus.applied,
        messageEpoch: messageEpoch,
        groupEpoch: current,
        selfRemoved: false,
        memberIdentities: const [],
      );
    }

    Future<void> put(String group, int epoch, EncryptedMessage message) async {
      (buffer[epoch] ??= <EncryptedMessage>[]).add(message);
    }

    Future<EncryptedMessage?> take(String group, int epoch) async {
      final list = buffer[epoch];
      if (list == null || list.isEmpty) return null;
      return list.removeAt(0);
    }

    final first = await GroupEpochOrdering.processOrdered(
      wire: commitWire(6),
      message: messageFor(6),
      process: process,
      bufferPut: put,
      bufferTake: take,
      wireFromMessage: mlsWireMessageFromEncryptedMessage,
      onProcessed: (message, result) async {
        if (result.isApplied) processedEpochs.add(result.messageEpoch);
      },
    );
    expect(first.status, GroupProcessStatus.outOfOrder);
    expect(current, 5);

    final second = await GroupEpochOrdering.processOrdered(
      wire: commitWire(5),
      message: messageFor(5),
      process: process,
      bufferPut: put,
      bufferTake: take,
      wireFromMessage: mlsWireMessageFromEncryptedMessage,
      onProcessed: (message, result) async {
        if (result.isApplied) processedEpochs.add(result.messageEpoch);
      },
    );
    expect(second.status, GroupProcessStatus.applied);
    expect(current, 7);
    expect(processedEpochs, <int>[5, 6]);
    expect(buffer.values.every((items) => items.isEmpty), isTrue);
  });

  test('群消息单密文扇出且同一重试产生同一消息 ID', () {
    const wire = MlsWireMessage(
      wireBytes: <int>[1, 2, 3],
      conversationId: 'group-a',
      messageKind: MlsMessageKind.application,
    );
    List<EncryptedMessage> run() => GroupMessageFanout.fanOut(
      wire: wire,
      recipients: const <MlsMemberIdentity>[
        MlsMemberIdentity(userId: 'user-b', deviceId: 'device-b'),
        MlsMemberIdentity(userId: 'user-c', deviceId: 'device-c'),
        MlsMemberIdentity(userId: 'user-b', deviceId: 'device-b'),
      ],
      senderUserId: 'user-a',
      senderDeviceId: 'device-a',
      createdAtMillis: 100,
    );
    final first = run();
    final retried = run();
    expect(first.length, 2);
    expect(
      first.map((item) => item.openmlsCiphertext),
      everyElement(<int>[1, 2, 3]),
    );
    expect(
      retried.map((item) => item.messageId),
      first.map((item) => item.messageId),
    );
    expect(first[0].messageId, isNot(first[1].messageId));
  });
}
