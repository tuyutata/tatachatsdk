import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/call.dart';

void main() {
  test('私聊通话按 offer answer ICE 和 hangup 收口', () async {
    final transport = _Transport();
    final peer = _Peer();
    final session = DirectCallSession.outgoing(
      connectionId: 'rtc.123.abc',
      localUserId: 'local',
      remoteUserId: 'remote',
      mediaKind: CallMediaKind.voice,
      transport: transport,
      peer: peer,
    );

    await session.start();
    expect(transport.sent.first.kind, CallSignalKind.offer);
    await session.receive(
      CallSignal.answer(
        connectionId: session.connectionId,
        sdp: 'v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111',
      ),
    );
    peer.emitState(CallPeerState.connected);
    await Future<void>.delayed(Duration.zero);
    expect(session.state.phase, DirectCallPhase.connected);

    await session.hangUp();
    expect(session.state.phase, DirectCallPhase.ended);
    expect(transport.sent.last.kind, CallSignalKind.hangup);
    expect(peer.closed, isTrue);
  });

  test('入站 ICE 在接听设置远端 SDP 后再写入 Peer', () async {
    final transport = _Transport();
    final peer = _Peer();
    final offer = CallSignal.offer(
      connectionId: 'rtc.456.def',
      sdp: 'v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111',
    );
    final session = DirectCallSession.incoming(
      connectionId: offer.connectionId,
      localUserId: 'local',
      remoteUserId: 'remote',
      mediaKind: CallMediaKind.voice,
      offer: offer,
      transport: transport,
      peer: peer,
    );
    await session.receive(
      CallSignal.ice(
        connectionId: offer.connectionId,
        candidate: 'candidate:1 1 UDP 1 127.0.0.1 9 typ host',
      ),
    );
    expect(peer.remoteCandidates, isEmpty);
    await session.accept();
    expect(peer.remoteCandidates, hasLength(1));
    expect(transport.sent.first.kind, CallSignalKind.answer);
    await session.hangUp();
  });
}

class _Transport implements CallTransport {
  final List<CallSignal> sent = <CallSignal>[];

  @override
  Future<CallIceConfiguration> readIceConfiguration() async =>
      CallIceConfiguration(const ['stun:stun.example.com']);

  @override
  Future<bool> sendSignal({
    required String recipientUserId,
    required CallSignal signal,
  }) async {
    sent.add(signal);
    return true;
  }
}

class _Peer implements CallPeer {
  final StreamController<CallIceCandidate> _candidates =
      StreamController<CallIceCandidate>.broadcast();
  final StreamController<CallPeerState> _states =
      StreamController<CallPeerState>.broadcast();
  final List<CallIceCandidate> remoteCandidates = <CallIceCandidate>[];
  bool closed = false;

  @override
  Stream<CallIceCandidate> get localCandidates => _candidates.stream;
  @override
  Stream<CallPeerState> get states => _states.stream;
  void emitState(CallPeerState value) => _states.add(value);

  @override
  Future<void> open({
    required CallIceConfiguration configuration,
    required CallMediaKind mediaKind,
  }) async {}
  @override
  Future<CallSessionDescription> createOffer() async =>
      const CallSessionDescription(
        type: 'offer',
        sdp: 'v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111',
      );
  @override
  Future<CallSessionDescription> createAnswer() async =>
      const CallSessionDescription(
        type: 'answer',
        sdp: 'v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111',
      );
  @override
  Future<void> setRemoteDescription(CallSessionDescription description) async {}
  @override
  Future<void> addRemoteCandidate(CallIceCandidate candidate) async =>
      remoteCandidates.add(candidate);
  @override
  Future<void> restartIce() async {}
  @override
  Future<void> close() async {
    closed = true;
    await _candidates.close();
    await _states.close();
  }
}
