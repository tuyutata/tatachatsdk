import '../core/chat_message.dart';
import '../group/model.dart';
import '../protocol/message.dart';
import 'records.dart';

/// Storage operations required by the direct and group message state machines.
///
/// The binding token is supplied by the host so TataChatSDK does not depend on a
/// wallet, database engine, account format, or chain-specific binding model.
abstract interface class ChatFlowStore<TBindingToken> {
  Future<void> saveOutgoingMessage({
    required TBindingToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    required EncryptedMessage message,
    required List<int> messageBytes,
    required String recipientUserId,
    required ChatMessageKind messageKind,
    required ChatMessageDeliveryState deliveryState,
    String? plaintext,
    String? pendingLocalMessageId,
    ChatPendingMedia? pendingMedia,
  });

  Future<void> queueOutgoingMessage({
    required TBindingToken bindingToken,
    required String ownerUserId,
    required EncryptedMessage message,
    required List<int> messageBytes,
    required String recipientUserId,
    required ChatMessageDeliveryState deliveryState,
  });

  Future<void> saveIncomingMessage({
    required TBindingToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    required EncryptedMessage message,
    required List<int> messageBytes,
    required ChatMessageKind messageKind,
    required String plaintext,
  });

  Future<void> markOutgoingDelivery({
    required TBindingToken bindingToken,
    required String ownerUserId,
    required String messageId,
    required ChatMessageDeliveryState state,
    String? errorMessage,
  });

  Future<void> savePendingInbound({
    required TBindingToken bindingToken,
    required String ownerUserId,
    required EncryptedMessage message,
    required List<int> messageBytes,
    required String reason,
  });

  Future<List<EncryptedMessage>> takePendingInbound(
    String ownerUserId,
    String conversationId, {
    required TBindingToken bindingToken,
  });

  Future<void> upsertGroupShell({
    required TBindingToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    required String groupId,
    required String groupName,
    required String creatorUserId,
    required int epoch,
  });

  Future<void> reconcileGroupRoster({
    required TBindingToken bindingToken,
    required String ownerUserId,
    required String groupId,
    required Map<String, GroupMemberRole> members,
    required int epoch,
  });

  Future<ChatGroup?> readGroup(String ownerUserId, String groupId);

  Future<void> markGroupLeft(
    String ownerUserId,
    String groupId, {
    required TBindingToken bindingToken,
  });

  Future<void> renameGroup(
    String ownerUserId,
    String groupId,
    String name, {
    required TBindingToken bindingToken,
  });

  Future<void> bufferGroupCommit({
    required TBindingToken bindingToken,
    required String ownerUserId,
    required String groupId,
    required int messageEpoch,
    required EncryptedMessage message,
    required List<int> messageBytes,
  });

  Future<EncryptedMessage?> takeGroupPendingCommit(
    String ownerUserId,
    String groupId,
    int messageEpoch, {
    required TBindingToken bindingToken,
  });

  Future<void> saveOutgoingGroupMessage({
    required TBindingToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    required String groupId,
    required String senderUserId,
    required String senderDeviceId,
    required String logicalMessageId,
    required ChatMessageKind messageKind,
    required String payload,
    required int createdAtMillis,
    required List<EncryptedMessage> messages,
    required Map<String, String> recipientUserByUserId,
    String? pendingLocalMessageId,
  });

  Future<void> saveIncomingGroupMessage({
    required TBindingToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    required EncryptedMessage message,
    required List<int> messageBytes,
    required ChatMessageKind messageKind,
    required String plaintext,
  });
}
