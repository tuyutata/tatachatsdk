import 'transport.dart';

enum CallMediaKind { voice, video }

enum CallPeerState {
  fresh,
  connecting,
  connected,
  disconnected,
  failed,
  closed,
}

class CallSessionDescription {
  const CallSessionDescription({required this.type, required this.sdp});
  final String type;
  final String sdp;
}

class CallIceCandidate {
  const CallIceCandidate({
    required this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
  });

  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
}

/// 平台 WebRTC 适配边界。TataChatSDK 不依赖任一具体 WebRTC 插件。
abstract interface class CallPeer {
  Stream<CallIceCandidate> get localCandidates;
  Stream<CallPeerState> get states;

  Future<void> open({
    required CallIceConfiguration configuration,
    required CallMediaKind mediaKind,
  });

  Future<CallSessionDescription> createOffer();
  Future<CallSessionDescription> createAnswer();
  Future<void> setRemoteDescription(CallSessionDescription description);
  Future<void> addRemoteCandidate(CallIceCandidate candidate);
  Future<void> restartIce();
  Future<void> close();
}
