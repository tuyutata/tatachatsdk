import 'dart:async';

import '../../call/peer.dart';
import '../../call/signal.dart';
import '../../call/transport.dart';
import 'state.dart';

/// 一对一 WebRTC 通话状态机。媒体永远只经过 PeerConnection。
class DirectCallSession {
  DirectCallSession.outgoing({
    required this.connectionId,
    required this.localUserId,
    required this.remoteUserId,
    required this.mediaKind,
    required CallTransport transport,
    required CallPeer peer,
    this.connectionTimeout = const Duration(seconds: 45),
  }) : _transport = transport,
       _peer = peer,
       _outgoing = true,
       _state = const DirectCallState(DirectCallPhase.calling) {
    _bindPeer();
  }

  DirectCallSession.incoming({
    required this.connectionId,
    required this.localUserId,
    required this.remoteUserId,
    required this.mediaKind,
    required CallSignal offer,
    required CallTransport transport,
    required CallPeer peer,
    this.connectionTimeout = const Duration(seconds: 45),
  }) : assert(offer.kind == CallSignalKind.offer),
       _transport = transport,
       _peer = peer,
       _outgoing = false,
       _pendingOffer = offer,
       _state = const DirectCallState(DirectCallPhase.incoming) {
    _bindPeer();
    _armTimeout();
  }

  final String connectionId;
  final String localUserId;
  final String remoteUserId;
  final CallMediaKind mediaKind;
  final Duration connectionTimeout;
  final CallTransport _transport;
  final CallPeer _peer;
  final bool _outgoing;
  final StreamController<DirectCallState> _states =
      StreamController<DirectCallState>.broadcast(sync: true);
  final List<CallIceCandidate> _localIce = <CallIceCandidate>[];
  final List<CallIceCandidate> _remoteIce = <CallIceCandidate>[];
  Future<void> _tail = Future<void>.value();
  late StreamSubscription<CallIceCandidate> _candidateSubscription;
  late StreamSubscription<CallPeerState> _peerStateSubscription;
  DirectCallState _state;
  CallSignal? _pendingOffer;
  Timer? _timeout;
  bool _peerOpened = false;
  bool _remoteDescriptionSet = false;
  bool _negotiationSent = false;
  bool _terminal = false;

  DirectCallState get state => _state;
  Stream<DirectCallState> get states => _states.stream;

  void _bindPeer() {
    _candidateSubscription = _peer.localCandidates.listen(
      (candidate) => unawaited(_serial(() => _handleLocalCandidate(candidate))),
    );
    _peerStateSubscription = _peer.states.listen(
      (state) => unawaited(_serial(() => _handlePeerState(state))),
    );
  }

  Future<void> start() => _serial(() async {
    if (!_outgoing || _terminal || _peerOpened) return;
    try {
      await _openPeer();
      final description = await _peer.createOffer();
      final sent = await _transport.sendSignal(
        recipientUserId: remoteUserId,
        signal: CallSignal.offer(
          connectionId: connectionId,
          sdp: description.sdp,
        ),
      );
      if (!sent) {
        await _finish(DirectCallPhase.failed, '对方当前无法接听');
        return;
      }
      _negotiationSent = true;
      await _flushLocalIce();
      _emit(const DirectCallState(DirectCallPhase.calling));
      _armTimeout();
    } catch (_) {
      await _finish(DirectCallPhase.failed, '通话连接失败');
    }
  });

  Future<void> accept() => _serial(() async {
    if (_outgoing || _terminal || _peerOpened) return;
    try {
      final offer = _pendingOffer;
      if (offer == null || offer.sdp == null) {
        await _finish(DirectCallPhase.failed, '通话请求不完整');
        return;
      }
      _emit(const DirectCallState(DirectCallPhase.connecting));
      await _openPeer();
      await _setRemoteOffer(offer);
      final description = await _peer.createAnswer();
      final sent = await _transport.sendSignal(
        recipientUserId: remoteUserId,
        signal: CallSignal.answer(
          connectionId: connectionId,
          sdp: description.sdp,
        ),
      );
      if (!sent) {
        await _finish(DirectCallPhase.failed, '对方已离线');
        return;
      }
      _negotiationSent = true;
      await _flushLocalIce();
      _armTimeout();
    } catch (_) {
      await _finish(DirectCallPhase.failed, '通话连接失败');
    }
  });

  Future<void> receive(CallSignal signal) => _serial(() async {
    if (_terminal || signal.connectionId != connectionId) return;
    try {
      switch (signal.kind) {
        case CallSignalKind.offer:
          if (!_peerOpened) {
            _pendingOffer = signal;
          } else {
            await _setRemoteOffer(signal);
            final answer = await _peer.createAnswer();
            await _transport.sendSignal(
              recipientUserId: remoteUserId,
              signal: CallSignal.answer(
                connectionId: connectionId,
                sdp: answer.sdp,
              ),
            );
          }
          break;
        case CallSignalKind.answer:
          if (!_outgoing || !_peerOpened || signal.sdp == null) return;
          await _peer.setRemoteDescription(
            CallSessionDescription(type: 'answer', sdp: signal.sdp!),
          );
          _remoteDescriptionSet = true;
          await _flushRemoteIce();
          _emit(const DirectCallState(DirectCallPhase.connecting));
          break;
        case CallSignalKind.ice:
          final candidate = CallIceCandidate(
            candidate: signal.candidate!,
            sdpMid: signal.sdpMid,
            sdpMLineIndex: signal.sdpMLineIndex,
          );
          if (_remoteDescriptionSet) {
            await _peer.addRemoteCandidate(candidate);
          } else {
            _remoteIce.add(candidate);
          }
          break;
        case CallSignalKind.hangup:
          await _finish(DirectCallPhase.ended, null);
          break;
        case CallSignalKind.iceRestart:
          if (_peerOpened) await _peer.restartIce();
          break;
        case CallSignalKind.peerReady:
          break;
      }
    } catch (_) {
      await _finish(DirectCallPhase.failed, '通话信令处理失败');
    }
  });

  Future<void> hangUp() => _serial(() async {
    if (_terminal) return;
    try {
      await _transport.sendSignal(
        recipientUserId: remoteUserId,
        signal: CallSignal.control(
          kind: CallSignalKind.hangup,
          connectionId: connectionId,
        ),
      );
    } catch (_) {
      // 本机挂断必须立即收口，不等待网络恢复。
    }
    await _finish(DirectCallPhase.ended, null);
  });

  Future<void> _openPeer() async {
    final configuration = await _transport.readIceConfiguration();
    await _peer.open(configuration: configuration, mediaKind: mediaKind);
    _peerOpened = true;
  }

  Future<void> _setRemoteOffer(CallSignal offer) async {
    await _peer.setRemoteDescription(
      CallSessionDescription(type: 'offer', sdp: offer.sdp!),
    );
    _remoteDescriptionSet = true;
    await _flushRemoteIce();
  }

  Future<void> _handleLocalCandidate(CallIceCandidate candidate) async {
    if (_terminal) return;
    if (!_negotiationSent) {
      _localIce.add(candidate);
      return;
    }
    final sent = await _transport.sendSignal(
      recipientUserId: remoteUserId,
      signal: CallSignal.ice(
        connectionId: connectionId,
        candidate: candidate.candidate,
        sdpMid: candidate.sdpMid,
        sdpMLineIndex: candidate.sdpMLineIndex,
      ),
    );
    if (!sent) await _finish(DirectCallPhase.failed, '通话连接失败');
  }

  Future<void> _flushLocalIce() async {
    final queued = List<CallIceCandidate>.from(_localIce);
    _localIce.clear();
    for (final candidate in queued) {
      await _handleLocalCandidate(candidate);
      if (_terminal) return;
    }
  }

  Future<void> _flushRemoteIce() async {
    final queued = List<CallIceCandidate>.from(_remoteIce);
    _remoteIce.clear();
    for (final candidate in queued) {
      await _peer.addRemoteCandidate(candidate);
    }
  }

  Future<void> _handlePeerState(CallPeerState state) async {
    if (_terminal) return;
    switch (state) {
      case CallPeerState.connected:
        _timeout?.cancel();
        _emit(const DirectCallState(DirectCallPhase.connected));
        break;
      case CallPeerState.disconnected:
      case CallPeerState.failed:
      case CallPeerState.closed:
        await _finish(DirectCallPhase.failed, 'WebRTC 直连已断开');
        break;
      case CallPeerState.fresh:
      case CallPeerState.connecting:
        if (_state.phase != DirectCallPhase.calling) {
          _emit(const DirectCallState(DirectCallPhase.connecting));
        }
        break;
    }
  }

  void _armTimeout() {
    _timeout?.cancel();
    _timeout = Timer(
      connectionTimeout,
      () => unawaited(
        _serial(() => _finish(DirectCallPhase.failed, '对方未接听或无法直连')),
      ),
    );
  }

  void _emit(DirectCallState value) {
    if (_terminal && !value.isTerminal) return;
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  Future<void> _finish(DirectCallPhase phase, String? reason) async {
    if (_terminal) return;
    _terminal = true;
    _timeout?.cancel();
    _emit(DirectCallState(phase, reason: reason));
    await _candidateSubscription.cancel();
    await _peerStateSubscription.cancel();
    await _peer.close();
    await _states.close();
  }

  Future<void> _serial(Future<void> Function() operation) {
    final next = _tail.then<void>(
      (_) => operation(),
      onError: (Object _, StackTrace __) => operation(),
    );
    _tail = next.then<void>((_) {}, onError: (_, __) {});
    return next;
  }
}
