import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:tatachat_sdk/call.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  test('flutter_webrtc 连接状态完整映射到 TataChatSDK', () {
    expect(
      callPeerStateFromRtc(
        RTCPeerConnectionState.RTCPeerConnectionStateConnected,
      ),
      CallPeerState.connected,
    );
    expect(
      callPeerStateFromRtc(RTCPeerConnectionState.RTCPeerConnectionStateFailed),
      CallPeerState.failed,
    );
    expect(
      callPeerStateFromRtc(
        RTCPeerConnectionState.RTCPeerConnectionStateDisconnected,
      ),
      CallPeerState.disconnected,
    );
  });
}
