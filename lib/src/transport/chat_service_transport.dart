import 'dart:io';

import '../mls/mls_boundary.dart';
import 'chat_transport.dart';

/// 宿主签发的一次短期 TataChatServer 访问凭证。Token 只能保存在内存中。
final class TataChatServerAccess {
  const TataChatServerAccess({
    required this.tataChatServerUrl,
    required this.tataChatServerToken,
    required this.expiresAtMillis,
  });

  final Uri tataChatServerUrl;
  final String tataChatServerToken;
  final int expiresAtMillis;

  bool isUsable(int nowMillis, {int skewMillis = 60 * 1000}) =>
      expiresAtMillis - skewMillis > nowMillis;

  void validate(int nowMillis) {
    if (tataChatServerUrl.scheme != 'https' ||
        tataChatServerUrl.host.isEmpty ||
        tataChatServerUrl.userInfo.isNotEmpty ||
        (tataChatServerUrl.path.isNotEmpty && tataChatServerUrl.path != '/') ||
        tataChatServerUrl.hasQuery ||
        tataChatServerUrl.hasFragment ||
        tataChatServerToken.isEmpty ||
        tataChatServerToken.codeUnits.any((unit) => unit <= 32) ||
        !isUsable(nowMillis)) {
      throw StateError('TataChatServer 访问凭证不合法或即将过期');
    }
  }

  Uri get realtimeUrl =>
      tataChatServerUrl.replace(scheme: 'wss', path: '/realtime');
}

typedef TataChatServerAccessProvider = Future<TataChatServerAccess> Function();

typedef ChatServiceTransportFactory =
    ChatServiceTransport Function({
      required ChatDevice identity,
      required TataChatServerAccessProvider accessProvider,
    });

/// TataChatServer 邮箱返回的一条按设备隔离的 OpenMLS 密文。
abstract interface class ChatMailboxMessage {
  String get messageId;
  String get senderUserId;
  String get recipientUserId;
  String get recipientDeviceId;
  String get conversationId;
  List<int> get messageBytes;
  int get createdAtMillis;
}

sealed class ChatServiceEvent {
  const ChatServiceEvent();
}

/// WSS 只通知可靠邮箱已经变化，消息正文仍由同步命令读取。
final class ChatMessageAvailableEvent extends ChatServiceEvent {
  const ChatMessageAvailableEvent({
    required this.messageId,
    required this.conversationId,
    required this.serverTimeMillis,
  });

  final String messageId;
  final String conversationId;
  final int serverTimeMillis;
}

/// 推送只表示可靠邮箱可能变化，不携带发送者、会话或消息内容。
final class ChatPushWake {
  const ChatPushWake();
}

abstract interface class ChatPushToken {
  String get provider;
  String get token;
  String? get apnsEnvironment;
  String get registrationCacheValue;
}

abstract interface class ChatPushBridge {
  Stream<ChatPushWake> get wakes;
  Stream<ChatPushToken> get tokenChanges;

  Future<ChatPushToken> initialize();
  Future<bool> takePendingWake();
  Future<void> clearConversationNotifications(String conversationId);
  Future<void> dispose();
}

abstract interface class AttachmentTransfer {
  Future<void> uploadEncryptedAttachment({
    required String attachmentId,
    required List<String> recipientUserIds,
    required File cipherFile,
    required int cipherByteSize,
    required String cipherSha256,
  });

  Future<void> downloadEncryptedAttachment({
    required String attachmentId,
    required File target,
    required int expectedByteSize,
    required String expectedSha256,
  });

  Future<void> acknowledgeAttachment(String attachmentId);
  Future<void> abortAttachment(String attachmentId);
}

/// TataChatSDK 运行时唯一远程合同。控制面只允许 WSS Protobuf，附件只允许 HTTPS。
abstract interface class ChatServiceTransport
    implements ChatTransport, AttachmentTransfer {
  String? get lastRealtimeDiagnosticCode;
  set lastRealtimeDiagnosticCode(String? value);

  Future<void> connect();
  Future<void> dispose();

  Future<void> registerPushEndpoint({
    required String pushProvider,
    required String pushToken,
    required String? apnsEnvironment,
    required int expiresAtMillis,
  });

  Future<void> publishKeyPackage(MlsKeyPackage keyPackage);
  Future<List<MlsKeyPackage>> resolveKeyPackages(String recipientUserId);
  Future<List<ChatMailboxMessage>> fetchMailbox();
  Future<void> acknowledgeMailbox(List<String> messageIds);

  Future<Future<void> Function()> connectRealtime({
    required Future<void> Function(ChatServiceEvent event) onEvent,
    Future<void> Function()? onDisconnected,
  });
}
