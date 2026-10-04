import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/call.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  test('账户级信令把视频 offer 路由为唯一入站通话', () async {
    final transport = _Transport();
    final coordinator = ChatCallCoordinator(
      transport: transport,
      readLocalUserId: () async => 'local',
      peerFactory: _Peer.new,
      random: Random(1),
    );
    final incoming = coordinator.incomingCalls.first;
    await coordinator.handleSignal(
      senderUserId: 'remote',
      signalWire: <String, Object?>{
        'signal_kind': 'offer',
        'connection_id': 'rtc.123.abc',
        'sdp': 'v=0\r\nm=video 9 UDP/TLS/RTP/SAVPF 96',
        'sdp_type': 'offer',
      },
    );
    final handle = await incoming;
    expect(handle.incoming, isTrue);
    expect(handle.session.mediaKind, CallMediaKind.video);
    expect(coordinator.activeCall, same(handle));
    await coordinator.dispose();
  });
}

class _Transport implements CallTransport {
  @override
  Future<CallIceConfiguration> readIceConfiguration() async =>
      CallIceConfiguration(const ['stun:stun.example.com']);
  @override
  Future<bool> sendSignal({
    required String recipientUserId,
    required CallSignal signal,
  }) async => true;
}

class _Peer implements CallPeer {
  final _candidates = StreamController<CallIceCandidate>.broadcast();
  final _states = StreamController<CallPeerState>.broadcast();
  @override
  Stream<CallIceCandidate> get localCandidates => _candidates.stream;
  @override
  Stream<CallPeerState> get states => _states.stream;
  @override
  Future<void> open({
    required CallIceConfiguration configuration,
    required CallMediaKind mediaKind,
  }) async {}
  @override
  Future<CallSessionDescription> createOffer() async =>
      const CallSessionDescription(type: 'offer', sdp: 'v=0');
  @override
  Future<CallSessionDescription> createAnswer() async =>
      const CallSessionDescription(type: 'answer', sdp: 'v=0');
  @override
  Future<void> setRemoteDescription(CallSessionDescription description) async {}
  @override
  Future<void> addRemoteCandidate(CallIceCandidate candidate) async {}
  @override
  Future<void> restartIce() async {}
  @override
  Future<void> close() async {
    await _candidates.close();
    await _states.close();
  }
}
