import '../core/chat_message.dart';

/// 宿主应用 conversation-list presentation snapshot.
class ChatConversationPreview {
  const ChatConversationPreview({
    required this.conversationId,
    required this.title,
    required this.peerUserId,
    required this.lastMessage,
    required this.lastUpdatedAt,
    required this.unreadCount,
    required this.deliveryState,
    this.conversationKind = 'dm',
  });

  /// TataChatSDK conversation identifier.
  final String conversationId;

  /// 宿主应用-visible title.
  final String title;

  /// 宿主应用 maps this user ID to TataChatSDK's opaque peer user ID.
  final String peerUserId;

  /// Decrypted local summary. Plaintext never comes from the service.
  final String lastMessage;

  final DateTime lastUpdatedAt;
  final int unreadCount;
  final ChatMessageDeliveryState deliveryState;

  /// dm for direct chat, group for a private group.
  final String conversationKind;

  bool get isGroup => conversationKind == 'group';
}

/// 宿主应用 chat-tab overview.
class ChatInboxOverview {
  const ChatInboxOverview({
    required this.userId,
    required this.pendingOutgoing,
    required this.unreadCount,
  });

  final String? userId;
  final int pendingOutgoing;
  final int unreadCount;

  static const empty = ChatInboxOverview(
    userId: null,
    pendingOutgoing: 0,
    unreadCount: 0,
  );
}
