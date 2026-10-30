import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_call/coordinator.dart';
import 'package:tatachat_call/peer.dart';
import 'package:tatachat_call/signal.dart';
import 'package:tatachat_call/transport.dart';

void main() {
  test('终态清理失败的句柄保留至协调器dispose重试成功', () async {
    final peer = _Peer()..closeFailures = 1;
    final coordinator = ChatCallCoordinator(
      transport: _Transport(),
      readLocalUserId: () async => 'local',
      peerFactory: () => peer,
    );
    final handle = await coordinator.startOutgoing(
      localUserId: 'local',
      peerUserId: 'peer',
      title: 'peer',
      video: false,
    );
    await expectLater(handle.session.hangUp(), throwsStateError);
    await coordinator.dispose();
    expect(peer.closed, true);
    expect(peer.closes, 2);
  });
  test('并发offer等待同一身份后只建立一个会话，关闭后不再接收', () async {
    final identity = Completer<String>();
    final coordinator = ChatCallCoordinator(
      transport: _Transport(),
      readLocalUserId: () => identity.future,
      peerFactory: _Peer.new,
    );
    final incoming = <ChatCallHandle>[];
    final subscription = coordinator.incomingCalls.listen(incoming.add);
    Map<String, Object?> offer(String id) =>
        CallSignal.offer(connectionId: id, sdp: 'v=0').toWire();
    final first = coordinator.handleSignal(
      senderUserId: 'a',
      signalWire: offer('rtc.1.a'),
    );
    final second = coordinator.handleSignal(
      senderUserId: 'b',
      signalWire: offer('rtc.2.b'),
    );
    identity.complete('local');
    await Future.wait([first, second]);
    expect(incoming, hasLength(1));
    expect(coordinator.activeCall, same(incoming.single));
    await coordinator.dispose();
    await coordinator.handleSignal(
      senderUserId: 'a',
      signalWire: offer('rtc.3.c'),
    );
    expect(incoming, hasLength(1));
    await expectLater(
      coordinator.startOutgoing(
        localUserId: 'local',
        peerUserId: 'a',
        title: 'a',
        video: false,
      ),
      throwsStateError,
    );
    await subscription.cancel();
  });
  test('关闭期间身份晚回不分配Peer或交付来电', () async {
    final identity = Completer<String>();
    var peers = 0;
    final coordinator = ChatCallCoordinator(
      transport: _Transport(),
      readLocalUserId: () => identity.future,
      peerFactory: () {
        peers++;
        return _Peer();
      },
    );
    final signal = coordinator.handleSignal(
      senderUserId: 'a',
      signalWire: CallSignal.offer(
        connectionId: 'rtc.1.a',
        sdp: 'v=0',
      ).toWire(),
    );
    await coordinator.dispose();
    identity.complete('local');
    await signal;
    expect(peers, 0);
    expect(coordinator.activeCall, isNull);
  });
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
  int closes = 0, closeFailures = 0;
  bool closed = false;
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
    closes++;
    if (closeFailures-- > 0) throw StateError('synthetic peer close failure');
    closed = true;
    await _candidates.close();
    await _states.close();
  }
}
