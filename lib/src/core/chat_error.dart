/// TataChatSDK 对宿主公开的稳定错误分类；产品文案由宿主应用映射。
enum ChatSdkErrorCode {
  invalidContent,
  contentTooLarge,
  invalidMessage,
  routeMismatch,
  expired,
  recipientKeyUnavailable,
  encryptionFailed,
  decryptionFailed,
  protocolRejected,
  storageRequired,
  transportFailed,
}

/// 通用 TataChatSDK 异常不得包含明文、密钥或产品身份信息。
final class ChatSdkException implements Exception {
  const ChatSdkException(this.code, this.message);

  final ChatSdkErrorCode code;
  final String message;

  @override
  String toString() => 'ChatSdkException(${code.name}: $message)';
}
