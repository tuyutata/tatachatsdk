import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  testWidgets('私聊语音通话页显示真实状态和挂断操作', (tester) async {
    final coordinator = ChatCallCoordinator(
      transport: _Transport(),
      readLocalUserId: () async => 'local',
      peerFactory: _Peer.new,
      random: Random(1),
    );
    final handle = await coordinator.startOutgoing(
      localUserId: 'local',
      peerUserId: 'remote',
      title: '测试用户',
      video: false,
    );
    await tester.pumpWidget(MaterialApp(home: CallPage(handle: handle)));
    await tester.pump();
    expect(find.text('测试用户'), findsOneWidget);
    expect(find.byKey(const ValueKey('call-hangup')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('call-hangup')));
    await tester.pump();
    expect(find.text('通话已结束'), findsOneWidget);
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
      const CallSessionDescription(
        type: 'offer',
        sdp: 'v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111',
      );
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
