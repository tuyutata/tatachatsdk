import 'dart:async';
import 'dart:math';

import '../direct/call/session.dart';
import '../direct/call/state.dart';
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

/// Coordinates one active direct call over a host-provided signal transport.
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
