import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_call/coordinator.dart';
import 'package:tatachat_call/peer.dart';
import 'package:tatachat_call/signal.dart';
import 'package:tatachat_call/transport.dart';

void main() {
  test('挂断不等待挂起的信令，资源关闭失败可重试', () async {
    final transport = _Transport()..wait = Completer<bool>();
    final peer = _Peer()..closeFailures = 1;
    final session = DirectCallSession.outgoing(
      connectionId: 'rtc.1.a',
      localUserId: 'local',
      remoteUserId: 'remote',
      mediaKind: CallMediaKind.voice,
      transport: transport,
      peer: peer,
    );
    final starting = session.start();
    await Future<void>.delayed(Duration.zero);
    await expectLater(session.hangUp(), throwsStateError);
    expect(session.state.phase, DirectCallPhase.ended);
    await session.hangUp();
    expect(peer.closed, isTrue);
    expect(peer.closes, 2);
    transport.wait!.complete(true);
    await starting;
    expect(session.state.phase, DirectCallPhase.ended);
  });
  test('建立前的ICE等待也受超时约束，迟到结果不发送offer', () async {
    final transport = _Transport()..ice = Completer<CallIceConfiguration>();
    final peer = _Peer();
    final session = DirectCallSession.outgoing(
      connectionId: 'rtc.1.a',
      localUserId: 'local',
      remoteUserId: 'remote',
      mediaKind: CallMediaKind.voice,
      transport: transport,
      peer: peer,
      connectionTimeout: Duration.zero,
    );
    final starting = session.start();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(session.state.phase, DirectCallPhase.failed);
    expect(peer.closed, isTrue);
    transport.ice!.complete(
      CallIceConfiguration(const ['stun:stun.example.com']),
    );
    await starting;
    expect(transport.sent, isEmpty);
  });
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
  Completer<bool>? wait;
  Completer<CallIceConfiguration>? ice;
  final List<CallSignal> sent = <CallSignal>[];

  @override
  Future<CallIceConfiguration> readIceConfiguration() async =>
      await ice?.future ??
      CallIceConfiguration(const ['stun:stun.example.com']);

  @override
  Future<bool> sendSignal({
    required String recipientUserId,
    required CallSignal signal,
  }) async {
    sent.add(signal);
    return await wait?.future ?? true;
  }
}

class _Peer implements CallPeer {
  final StreamController<CallIceCandidate> _candidates =
      StreamController<CallIceCandidate>.broadcast();
  final StreamController<CallPeerState> _states =
      StreamController<CallPeerState>.broadcast();
  final List<CallIceCandidate> remoteCandidates = <CallIceCandidate>[];
  bool closed = false;
  int closes = 0, closeFailures = 0;

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
    closes++;
    if (closeFailures-- > 0) throw StateError('synthetic close failure');
    closed = true;
    await _candidates.close();
    await _states.close();
  }
}
