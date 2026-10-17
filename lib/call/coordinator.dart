import 'dart:async';
import 'dart:math';

import 'flutter_peer.dart';
import 'peer.dart';
import 'signal.dart';
import 'transport.dart';

typedef ChatCallPeerFactory = CallPeer Function();
typedef ChatCallUserReader = Future<String> Function();

class ChatCallHandle {
  const ChatCallHandle({
    required this.session,
    required this.peer,
    required this.title,
    required this.incoming,
  });

  final DirectCallSession session;
  final CallPeer peer;
  final String title;
  final bool incoming;
}

/// 通过宿主提供的信令传输协调唯一活动的一对一通话。
class ChatCallCoordinator {
  ChatCallCoordinator({
    required CallTransport transport,
    required ChatCallUserReader readLocalUserId,
    ChatCallPeerFactory? peerFactory,
    Random? random,
  }) : _transport = transport,
       _readLocalUserId = readLocalUserId,
       _peerFactory = peerFactory ?? FlutterCallPeer.new,
       _random = random ?? Random.secure();

  final CallTransport _transport;
  final ChatCallUserReader _readLocalUserId;
  final ChatCallPeerFactory _peerFactory;
  final Random _random;
  final StreamController<ChatCallHandle> _incoming =
      StreamController<ChatCallHandle>.broadcast(sync: true);
  ChatCallHandle? _active;
  StreamSubscription<DirectCallState>? _activeState;

  Stream<ChatCallHandle> get incomingCalls => _incoming.stream;
  ChatCallHandle? get activeCall => _active;

  Future<ChatCallHandle> startOutgoing({
    required String localUserId,
    required String peerUserId,
    required String title,
    required bool video,
  }) async {
    if (_active != null) throw StateError('当前已有通话');
    if (localUserId.isEmpty || peerUserId.isEmpty) {
      throw StateError('通话身份不完整');
    }
    final peer = _peerFactory();
    final session = DirectCallSession.outgoing(
      connectionId: _newConnectionId(),
      localUserId: localUserId,
      remoteUserId: peerUserId,
      mediaKind: video ? CallMediaKind.video : CallMediaKind.voice,
      transport: _transport,
      peer: peer,
    );
    final handle = ChatCallHandle(
      session: session,
      peer: peer,
      title: title,
      incoming: false,
    );
    _setActive(handle);
    return handle;
  }

  Future<void> handleSignal({
    required String senderUserId,
    required Map<String, Object?> signalWire,
  }) async {
    if (senderUserId.isEmpty) return;
    final signal = CallSignal.fromWire(signalWire);
    final active = _active;
    if (active != null) {
      if (active.session.connectionId == signal.connectionId &&
          active.session.remoteUserId == senderUserId) {
        await active.session.receive(signal);
      } else if (signal.kind == CallSignalKind.offer) {
        await _transport.sendSignal(
          recipientUserId: senderUserId,
          signal: CallSignal.control(
            kind: CallSignalKind.hangup,
            connectionId: signal.connectionId,
          ),
        );
      }
      return;
    }
    if (signal.kind != CallSignalKind.offer) return;
    final localUserId = await _readLocalUserId();
    if (localUserId.isEmpty) return;
    final peer = _peerFactory();
    final session = DirectCallSession.incoming(
      connectionId: signal.connectionId,
      localUserId: localUserId,
      remoteUserId: senderUserId,
      mediaKind: signal.containsVideo
          ? CallMediaKind.video
          : CallMediaKind.voice,
      offer: signal,
      transport: _transport,
      peer: peer,
    );
    final handle = ChatCallHandle(
      session: session,
      peer: peer,
      title: senderUserId,
      incoming: true,
    );
    _setActive(handle);
    _incoming.add(handle);
  }

  void _setActive(ChatCallHandle handle) {
    _active = handle;
    unawaited(_activeState?.cancel());
    _activeState = handle.session.states.listen((state) {
      if (state.isTerminal && identical(_active, handle)) {
        _active = null;
        unawaited(_activeState?.cancel());
        _activeState = null;
      }
    });
  }

  String _newConnectionId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final randomHex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'rtc.${DateTime.now().microsecondsSinceEpoch}.$randomHex';
  }

  Future<void> dispose() async {
    await _active?.session.hangUp();
    await _activeState?.cancel();
    _activeState = null;
    _active = null;
    await _incoming.close();
  }
}

enum DirectCallPhase { incoming, calling, connecting, connected, ended, failed }

class DirectCallState {
  const DirectCallState(this.phase, {this.reason});
  final DirectCallPhase phase;
  final String? reason;

  bool get isTerminal =>
      phase == DirectCallPhase.ended || phase == DirectCallPhase.failed;
}

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
      onError: (Object _, StackTrace _) => operation(),
    );
    _tail = next.then<void>((_) {}, onError: (_, _) {});
    return next;
  }
}
