import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/call.dart';

void main() {
  test('信令只接受既有 connection_id 和精确字段', () {
    final signal = CallSignal.fromWire(<String, Object?>{
      'signal_kind': 'offer',
      'connection_id': 'rtc.123.abc',
      'sdp': 'v=0\r\nm=video 9 UDP/TLS/RTP/SAVPF 96',
      'sdp_type': 'offer',
    });
    expect(signal.kind, CallSignalKind.offer);
    expect(signal.containsVideo, isTrue);
    expect(signal.toWire()['connection_id'], 'rtc.123.abc');
    expect(
      () => CallSignal.fromWire(<String, Object?>{
        ...signal.toWire(),
        'call_id': 'forbidden',
      }),
      throwsFormatException,
    );
  });

  test('ICE 配置拒绝 TURN', () {
    expect(
      CallIceConfiguration(const ['stun:stun.example.com']).stunUrls,
      const ['stun:stun.example.com'],
    );
    expect(
      () => CallIceConfiguration(const ['turn:turn.example.com']),
      throwsFormatException,
    );
  });
}
