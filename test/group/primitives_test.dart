import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

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
}
