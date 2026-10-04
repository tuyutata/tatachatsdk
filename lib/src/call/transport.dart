import 'signal.dart';

/// 仅含 STUN 的 ICE 配置。TURN URI 在 SDK 边界直接拒绝。
class CallIceConfiguration {
  CallIceConfiguration(Iterable<String> urls)
    : stunUrls = List.unmodifiable(_validate(urls));

  final List<String> stunUrls;

  static List<String> _validate(Iterable<String> values) {
    final urls = values.toSet().toList(growable: false);
    if (urls.isEmpty ||
        urls.any(
          (url) => !(url.startsWith('stun:') || url.startsWith('stuns:')),
        )) {
      throw const FormatException('通话 ICE 配置只允许 STUN');
    }
    return urls;
  }
}

/// 部署端只负责读取 STUN 和经加密 WSS 转发瞬时信令。
abstract interface class CallTransport {
  Future<CallIceConfiguration> readIceConfiguration();

  Future<bool> sendSignal({
    required String recipientUserId,
    required CallSignal signal,
  });
}
