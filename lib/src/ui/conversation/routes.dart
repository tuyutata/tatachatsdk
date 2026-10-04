import 'package:flutter/material.dart';

import '../../chat_client.dart';
import '../host.dart';
import 'conversation_page.dart';

/// SDK 完整会话页的统一路由入口；宿主不得重复拼装发送、同步和下载链路。
abstract final class ChatConversationRoutes {
  static Future<void> openDirect(
    BuildContext context, {
    required ChatSdk sdk,
    required ChatConversationHost host,
    required String currentUserId,
    required String accountId,
    required String peerUserId,
    required String title,
    ChatDeleteConversationCallback? onDeleteConversation,
  }) async {
    final conversationId = ChatSdk.directConversationId(
      currentUserId,
      peerUserId,
    );
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatConversationPage(
          sdk: sdk,
          conversationId: conversationId,
          currentUserId: currentUserId,
          accountId: accountId,
          peerUserId: peerUserId,
          title: title,
          host: host,
          onDeleteConversation:
              onDeleteConversation ??
              () => sdk.deleteLocalConversation(conversationId),
        ),
      ),
    );
  }

  static Future<void> openGroup(
    BuildContext context, {
    required ChatSdk sdk,
    required ChatConversationHost host,
    required String currentUserId,
    required String accountId,
    required String groupId,
    required String title,
    ChatDeleteConversationCallback? onDeleteConversation,
  }) async {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatConversationPage(
          sdk: sdk,
          conversationId: groupId,
          currentUserId: currentUserId,
          accountId: accountId,
          peerUserId: groupId,
          title: title,
          isGroup: true,
          host: host,
          onDeleteConversation:
              onDeleteConversation ??
              () => sdk.deleteLocalConversation(groupId),
        ),
      ),
    );
  }
}
