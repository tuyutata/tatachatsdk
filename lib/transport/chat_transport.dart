import '../core/chat_message.dart';

/// TataChatSDK 只存在 聊天服务模块这一种远程传输。
enum ChatTransportType { server }

/// 一条密文消息被 聊天服务模块明确接受后的结果。
class ChatDeliveryResult {
  const ChatDeliveryResult({
    required this.messageId,
    required this.transportType,
    required this.state,
    this.errorMessage,
  });

  final String messageId;
  final ChatTransportType transportType;
  final ChatMessageDeliveryState state;
  final String? errorMessage;
}

/// 页面和 OpenMLS 流程只依赖密文投递，不接触 WSS、HTTPS 或部署实现。
abstract interface class ChatTransport {
  ChatTransportType get type;

  Future<ChatDeliveryResult> sendEncryptedMessage({
    required String messageId,
    required List<int> messageBytes,
    required String recipientUserId,
    required String recipientDeviceId,
  });
}
