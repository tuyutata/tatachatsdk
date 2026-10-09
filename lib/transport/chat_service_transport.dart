import 'dart:io';

import '../mls/mls_boundary.dart';
import 'chat_transport.dart';

/// 宿主签发的短期聊天许可。只接受完整WSS入口，Token只保存在内存中。
final class ChatAccess {
  const ChatAccess({
    required this.realtimeUrl,
    required this.accessToken,
    required this.expiresAtMillis,
  });

  final Uri realtimeUrl;
  final String accessToken;
  final int expiresAtMillis;

  bool isUsable(int nowMillis, {int skewMillis = 60 * 1000}) =>
      expiresAtMillis - skewMillis > nowMillis;

  void validate(int nowMillis) {
    if (realtimeUrl.scheme != 'wss' ||
        realtimeUrl.host.isEmpty ||
        realtimeUrl.userInfo.isNotEmpty ||
        realtimeUrl.path != '/api/tatachat/realtime' ||
        realtimeUrl.pathSegments.join('/') != 'api/tatachat/realtime' ||
        realtimeUrl.hasQuery ||
        realtimeUrl.hasFragment ||
        accessToken.isEmpty ||
        accessToken.length > 16 * 1024 ||
        accessToken.codeUnits.any((unit) => unit <= 32 || unit >= 127) ||
        expiresAtMillis <= 0 ||
        !isUsable(nowMillis)) {
      throw StateError('聊天访问凭证不合法或即将过期');
    }
  }

  /// 附件仅派生同主机/端口HTTPS地址；不接受第二地址或路径穿越标识。
  Uri attachmentChunkUrl(String attachmentId, int chunkIndex) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(attachmentId) ||
        chunkIndex < 0 ||
        chunkIndex > 0xffffffff) {
      throw ArgumentError('附件块路径无效');
    }
    return realtimeUrl.replace(
      scheme: 'https',
      path: '/api/tatachat/attachments/$attachmentId/chunks/$chunkIndex',
    );
  }
}

typedef ChatAccessProvider = Future<ChatAccess> Function();

typedef ChatServiceTransportFactory = ChatServiceTransport Function({
  required ChatDevice identity,
  required ChatAccessProvider accessProvider,
});

/// 聊天服务模块邮箱返回的一条按设备隔离的 OpenMLS 密文。
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
    required int createdAtMillis,
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
