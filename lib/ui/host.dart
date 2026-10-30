import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:tatachat_core/chat_message.dart';
import 'package:tatachat_runtime/media_limit_policy.dart';
import 'compose/composer_action_panel.dart';
import 'style.dart';

/// 宿主提供给完整聊天页的产品边界。
///
/// SDK 只消费资料展示、发送资格和产品动作，不读取宿主账户或业务服务。
class ChatConversationHost {
  const ChatConversationHost({
    required this.style,
    required this.mediaLimits,
    required this.canSend,
    required this.unavailableMessage,
    required this.errorMessage,
    required this.headerBuilder,
    required this.resolveUser,
    this.groupSenderBuilder,
    this.onTransfer,
    this.onLocation,
    this.actionIconBuilder,
    this.prepareAttachment,
  });

  final ChatViewStyle style;
  final ChatMediaLimitPolicy mediaLimits;

  /// 可选宿主准备边界：附件选取/录制、处理和发送前等待；打开聊天和文字不调用。
  /// SDK不解析会员或查链，宿主自行合并请求、校验会话及额度；失败以异常停止动作。
  final Future<void> Function(String userId)? prepareAttachment;
  final bool Function(String userId) canSend;
  final String Function(String userId) unavailableMessage;
  final String Function(Object error) errorMessage;
  final Widget Function(BuildContext context, ChatConversationHeader header)
  headerBuilder;
  final Future<User> Function(String userId, String currentUserId, bool isGroup)
  resolveUser;
  final Widget Function(BuildContext context, String userId)?
  groupSenderBuilder;
  final Future<void> Function(BuildContext context, String peerUserId)?
  onTransfer;
  final Future<void> Function(BuildContext context, String peerUserId)?
  onLocation;
  final ChatComposerActionIconBuilder? actionIconBuilder;

  String attachmentTooLargeMessage(ChatMessageKind kind) => '附件超过当前允许的大小';

  String attachmentTooLongMessage(ChatMessageKind kind) => '语音、视频消息每条最长 3 分钟';
}

/// 完整聊天页传给宿主标题组件的稳定数据。
class ChatConversationHeader {
  const ChatConversationHeader({
    required this.peerUserId,
    required this.title,
    required this.isGroup,
  });

  final String peerUserId;
  final String title;
  final bool isGroup;
}
