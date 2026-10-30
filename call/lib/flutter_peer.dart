import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'peer.dart';
import 'transport.dart';

CallPeerState callPeerStateFromRtc(
  RTCPeerConnectionState state,
) => switch (state) {
  RTCPeerConnectionState.RTCPeerConnectionStateNew => CallPeerState.fresh,
  RTCPeerConnectionState.RTCPeerConnectionStateConnecting =>
    CallPeerState.connecting,
  RTCPeerConnectionState.RTCPeerConnectionStateConnected =>
    CallPeerState.connected,
  RTCPeerConnectionState.RTCPeerConnectionStateDisconnected =>
    CallPeerState.disconnected,
  RTCPeerConnectionState.RTCPeerConnectionStateFailed => CallPeerState.failed,
  RTCPeerConnectionState.RTCPeerConnectionStateClosed => CallPeerState.closed,
};

/// Flutter WebRTC peer for voice and video calls only.
///
/// It never creates a data channel and never configures TURN.
class FlutterCallPeer implements CallPeer {
  final StreamController<CallIceCandidate> _candidates =
      StreamController<CallIceCandidate>.broadcast(sync: true);
  final StreamController<CallPeerState> _states =
      StreamController<CallPeerState>.broadcast(sync: true);
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _connection;
  MediaStream? _localStream;
  CallMediaKind? _mediaKind;
  bool _closed = false;
  bool _localReady = false, _remoteReady = false, _connectionClosed = false;
  final Set<MediaStreamTrack> _stopped = <MediaStreamTrack>{};
  Future<void>? _closing;

  @override
  Stream<CallIceCandidate> get localCandidates => _candidates.stream;

  @override
  Stream<CallPeerState> get states => _states.stream;

  @override
  Future<void> open({
    required CallIceConfiguration configuration,
    required CallMediaKind mediaKind,
  }) async {
    if (_connection != null || _closed) return;
    _mediaKind = mediaKind;
    try {
      await localRenderer.initialize();
      _localReady = true;
      if (_closed) {
        await _closeLate();
        return;
      }
      await remoteRenderer.initialize();
      _remoteReady = true;
      if (_closed) {
        await _closeLate();
        return;
      }
      final connection = await createPeerConnection(<String, dynamic>{
        'iceServers': <Map<String, dynamic>>[
          <String, dynamic>{'urls': configuration.stunUrls},
        ],
        'iceTransportPolicy': 'all',
        'sdpSemantics': 'unified-plan',
      });
      _connection = connection;
      _connectionClosed = false;
      if (_closed) {
        await _closeLate();
        return;
      }
      connection.onIceCandidate = (candidate) {
        final value = candidate.candidate;
        if (!_closed && value != null && value.isNotEmpty) {
          _candidates.add(
            CallIceCandidate(
              candidate: value,
              sdpMid: candidate.sdpMid,
              sdpMLineIndex: candidate.sdpMLineIndex,
            ),
          );
        }
      };
      connection.onConnectionState = (state) {
        if (!_closed) _states.add(callPeerStateFromRtc(state));
      };
      connection.onTrack = (event) {
        if (_closed || event.streams.isEmpty) return;
        remoteRenderer.srcObject = event.streams.first;
      };
      final localStream = await navigator.mediaDevices.getUserMedia(
        <String, dynamic>{
          'audio': <String, dynamic>{
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': mediaKind == CallMediaKind.video
              ? <String, dynamic>{
                  'facingMode': 'user',
                  'width': <String, int>{'ideal': 1280},
                  'height': <String, int>{'ideal': 720},
                  'frameRate': <String, int>{'ideal': 24},
                }
              : false,
        },
      );
      _localStream = localStream;
      if (_closed) {
        await _closeLate();
        return;
      }
      localRenderer.srcObject = localStream;
      for (final track in localStream.getTracks()) {
        await connection.addTrack(track, localStream);
        if (_closed) {
          await _closeLate();
          return;
        }
      }
      await Helper.setSpeakerphoneOn(mediaKind == CallMediaKind.video);
    } catch (_) {
      await _closeLate();
      rethrow;
    }
  }

  @override
  Future<CallSessionDescription> createOffer() async {
    final connection = _requireConnection();
    final value = await connection.createOffer(<String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _mediaKind == CallMediaKind.video,
    });
    await connection.setLocalDescription(value);
    return CallSessionDescription(type: 'offer', sdp: value.sdp ?? '');
  }

  @override
  Future<CallSessionDescription> createAnswer() async {
    final connection = _requireConnection();
    final value = await connection.createAnswer(<String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _mediaKind == CallMediaKind.video,
    });
    await connection.setLocalDescription(value);
    return CallSessionDescription(type: 'answer', sdp: value.sdp ?? '');
  }

  @override
  Future<void> setRemoteDescription(CallSessionDescription description) =>
      _requireConnection().setRemoteDescription(
        RTCSessionDescription(description.sdp, description.type),
      );

  @override
  Future<void> addRemoteCandidate(CallIceCandidate candidate) =>
      _requireConnection().addCandidate(
        RTCIceCandidate(
          candidate.candidate,
          candidate.sdpMid,
          candidate.sdpMLineIndex,
        ),
      );

  @override
  Future<void> restartIce() => _requireConnection().restartIce();

  Future<void> setMicrophoneEnabled(bool enabled) async {
    for (final track in _localStream?.getAudioTracks() ?? const []) {
      track.enabled = enabled;
    }
  }

  Future<void> setCameraEnabled(bool enabled) async {
    for (final track in _localStream?.getVideoTracks() ?? const []) {
      track.enabled = enabled;
    }
  }

  Future<void> setSpeakerEnabled(bool enabled) =>
      Helper.setSpeakerphoneOn(enabled);

  RTCPeerConnection _requireConnection() {
    final value = _connection;
    if (value == null || _closed) throw StateError('WebRTC 尚未建立');
    return value;
  }

  @override
  Future<void> close() {
    _closed = true;
    final active = _closing;
    if (active != null) return active;
    late final Future<void> task;
    task = _release().whenComplete(() {
      if (identical(_closing, task)) _closing = null;
    });
    _closing = task;
    return task;
  }

  // 先等已有清理收口，再接管其快照之后才返回的平台资源。
  Future<void> _closeLate() async {
    try {
      await _closing;
    } catch (_) {
      /* 保留失败资源继续清理。 */
    }
    await close();
  }

  Future<void> _release() async {
    Object? failure;
    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        failure ??= error;
      }
    }

    // 子资源独立清理；失败保持原引用，下次close只重试未完成部分。
    final connection = _connection;
    if (connection != null) {
      await attempt(() async {
        if (!_connectionClosed) {
          await connection.close();
          _connectionClosed = true;
        }
        await connection.dispose();
        _connection = null;
      });
    }
    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        if (!_stopped.contains(track)) {
          await attempt(() async {
            await track.stop();
            _stopped.add(track);
          });
        }
      }
      if (stream.getTracks().every(_stopped.contains)) {
        await attempt(() async {
          await stream.dispose();
          _localStream = null;
        });
      }
    }
    if (_localReady) {
      await attempt(() async {
        localRenderer.srcObject = null;
        await localRenderer.dispose();
        _localReady = false;
      });
    }
    if (_remoteReady) {
      await attempt(() async {
        remoteRenderer.srcObject = null;
        await remoteRenderer.dispose();
        _remoteReady = false;
      });
    }
    await attempt(() async {
      if (!_candidates.isClosed) await _candidates.close();
    });
    await attempt(() async {
      if (!_states.isClosed) await _states.close();
    });
    if (failure != null) throw failure!;
  }
}
