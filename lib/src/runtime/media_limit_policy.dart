import '../core/chat_message.dart';

/// Host-supplied attachment limits. TataChatSDK never reads a product membership
/// tier or a product service while enforcing these byte boundaries.
abstract interface class ChatMediaLimitPolicy {
  int limitForKind(ChatMessageKind kind);
  int limitForMime(String contentType);

  bool exceedsForKind(ChatMessageKind kind, int byteSize) =>
      byteSize > limitForKind(kind);
}

/// Deployment-neutral default for hosts that do not sell tiered attachment
/// limits. Product hosts should inject their own policy.
class ChatUnlimitedMediaLimitPolicy implements ChatMediaLimitPolicy {
  const ChatUnlimitedMediaLimitPolicy();

  static const int _maxBytes = 0x7fffffffffffffff;

  @override
  int limitForKind(ChatMessageKind kind) => _maxBytes;

  @override
  int limitForMime(String contentType) => _maxBytes;

  @override
  bool exceedsForKind(ChatMessageKind kind, int byteSize) => false;
}
