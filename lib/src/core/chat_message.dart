/// Message kinds shared by every TataChatSDK host.
enum ChatMessageKind {
  /// Plain text or an inline emoji.
  text,

  /// An end-to-end encrypted image attachment.
  image,

  /// An end-to-end encrypted video attachment.
  video,

  /// An end-to-end encrypted generic file attachment.
  file,

  /// An end-to-end encrypted voice message.
  audio,

  /// A bundled sticker identified by pack and sticker IDs.
  sticker,
}

/// Local delivery state. It is not a read receipt.
enum ChatMessageDeliveryState {
  /// Persisted in the local outgoing queue.
  queued,

  /// Being submitted to the configured encrypted transport.
  sending,

  /// Accepted by the transport.
  sent,

  /// Confirmed by a recipient device.
  receivedByDevice,

  /// Delivery ended in failure.
  failed,
}

/// Maximum duration for one voice or video message.
const Duration chatMessageMaximumDuration = Duration(minutes: 3);

/// An attachment exceeds the byte limit supplied by the host application.
class ChatMediaTooLargeException implements Exception {
  const ChatMediaTooLargeException({
    required this.byteSize,
    required this.limitBytes,
    this.kind,
  });

  final int byteSize;
  final int limitBytes;
  final ChatMessageKind? kind;

  @override
  String toString() =>
      'attachment size $byteSize exceeds limit $limitBytes bytes';
}

/// A voice or video message exceeds [chatMessageMaximumDuration].
class ChatMediaTooLongException implements Exception {
  const ChatMediaTooLongException({
    required this.kind,
    required this.durationMs,
  });

  final ChatMessageKind kind;
  final int durationMs;

  @override
  String toString() => 'voice and video messages are limited to three minutes';
}
