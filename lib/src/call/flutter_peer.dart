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
      await remoteRenderer.initialize();
      final connection = await createPeerConnection(<String, dynamic>{
        'iceServers': <Map<String, dynamic>>[
          <String, dynamic>{'urls': configuration.stunUrls},
        ],
        'iceTransportPolicy': 'all',
        'sdpSemantics': 'unified-plan',
      });
      _connection = connection;
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
      localRenderer.srcObject = localStream;
      for (final track in localStream.getTracks()) {
        await connection.addTrack(track, localStream);
      }
      await Helper.setSpeakerphoneOn(mediaKind == CallMediaKind.video);
    } catch (_) {
      await close();
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
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      await connection.close();
      await connection.dispose();
    }
    final stream = _localStream;
    _localStream = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    await localRenderer.dispose();
    await remoteRenderer.dispose();
    await _candidates.close();
    await _states.close();
  }
}
