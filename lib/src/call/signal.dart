/// WebRTC 信令类型。字段值与部署端既有 WSS 合同完全一致。
enum CallSignalKind {
  offer('offer'),
  answer('answer'),
  ice('ice'),
  hangup('hangup'),
  iceRestart('ice_restart'),
  peerReady('peer_ready');

  const CallSignalKind(this.wireName);
  final String wireName;

  static CallSignalKind parse(Object? value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    throw const FormatException('通话信令类型不合法');
  }
}

enum CallSdpType {
  offer('offer'),
  answer('answer');

  const CallSdpType(this.wireName);
  final String wireName;

  static CallSdpType parse(Object? value) {
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    throw const FormatException('WebRTC 会话描述类型不合法');
  }
}

/// 部署无关的扁平 WebRTC 信令。
///
/// 唯一关联键使用既有 connection_id，禁止再创建其他重复编号。
class CallSignal {
  const CallSignal._({
    required this.kind,
    required this.connectionId,
    this.sdp,
    this.sdpType,
    this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
  });

  factory CallSignal.offer({
    required String connectionId,
    required String sdp,
  }) => CallSignal._(
    kind: CallSignalKind.offer,
    connectionId: _connectionId(connectionId),
    sdp: _bounded(sdp, 'sdp', 48000),
    sdpType: CallSdpType.offer,
  );

  factory CallSignal.answer({
    required String connectionId,
    required String sdp,
  }) => CallSignal._(
    kind: CallSignalKind.answer,
    connectionId: _connectionId(connectionId),
    sdp: _bounded(sdp, 'sdp', 48000),
    sdpType: CallSdpType.answer,
  );

  factory CallSignal.ice({
    required String connectionId,
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) {
    if (sdpMLineIndex != null && sdpMLineIndex < 0) {
      throw const FormatException('WebRTC 媒体描述行索引不合法');
    }
    return CallSignal._(
      kind: CallSignalKind.ice,
      connectionId: _connectionId(connectionId),
      candidate: _bounded(candidate, 'candidate', 4096),
      sdpMid: sdpMid == null ? null : _bounded(sdpMid, 'sdp_mid', 256),
      sdpMLineIndex: sdpMLineIndex,
    );
  }

  factory CallSignal.control({
    required CallSignalKind kind,
    required String connectionId,
  }) {
    if (kind == CallSignalKind.offer ||
        kind == CallSignalKind.answer ||
        kind == CallSignalKind.ice) {
      throw const FormatException('该信令必须携带 WebRTC 载荷');
    }
    return CallSignal._(kind: kind, connectionId: _connectionId(connectionId));
  }

  factory CallSignal.fromWire(Map<String, Object?> value) {
    final kind = CallSignalKind.parse(value['signal_kind']);
    final connectionId = _connectionId(value['connection_id']);
    switch (kind) {
      case CallSignalKind.offer:
      case CallSignalKind.answer:
        _requireKeys(value, const {
          'signal_kind',
          'connection_id',
          'sdp',
          'sdp_type',
        });
        final type = CallSdpType.parse(value['sdp_type']);
        if (type.wireName != kind.wireName) {
          throw const FormatException('WebRTC 信令与会话描述类型不一致');
        }
        return CallSignal._(
          kind: kind,
          connectionId: connectionId,
          sdp: _bounded(value['sdp'], 'sdp', 48000),
          sdpType: type,
        );
      case CallSignalKind.ice:
        final expected = <String>{
          'signal_kind',
          'connection_id',
          'candidate',
          if (value.containsKey('sdp_mid')) 'sdp_mid',
          if (value.containsKey('sdp_mline_index')) 'sdp_mline_index',
        };
        _requireKeys(value, expected);
        final index = value['sdp_mline_index'];
        if (index != null && (index is! int || index < 0)) {
          throw const FormatException('WebRTC 媒体描述行索引不合法');
        }
        return CallSignal.ice(
          connectionId: connectionId,
          candidate: _bounded(value['candidate'], 'candidate', 4096),
          sdpMid: value['sdp_mid'] == null
              ? null
              : _bounded(value['sdp_mid'], 'sdp_mid', 256),
          sdpMLineIndex: index as int?,
        );
      case CallSignalKind.hangup:
      case CallSignalKind.iceRestart:
      case CallSignalKind.peerReady:
        _requireKeys(value, const {'signal_kind', 'connection_id'});
        return CallSignal.control(kind: kind, connectionId: connectionId);
    }
  }

  final CallSignalKind kind;
  final String connectionId;
  final String? sdp;
  final CallSdpType? sdpType;
  final String? candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;

  bool get containsVideo =>
      sdp?.split(RegExp(r'\r?\n')).any((line) => line.startsWith('m=video ')) ??
      false;

  Map<String, Object?> toWire() => <String, Object?>{
    'signal_kind': kind.wireName,
    'connection_id': connectionId,
    if (sdp != null) 'sdp': sdp,
    if (sdpType != null) 'sdp_type': sdpType!.wireName,
    if (candidate != null) 'candidate': candidate,
    if (sdpMid != null) 'sdp_mid': sdpMid,
    if (sdpMLineIndex != null) 'sdp_mline_index': sdpMLineIndex,
  };
}

final RegExp _connectionPattern = RegExp(r'^[A-Za-z0-9_.:-]{3,220}$');

String _connectionId(Object? value) {
  if (value is! String || !_connectionPattern.hasMatch(value)) {
    throw const FormatException('WebRTC 连接唯一标识不合法');
  }
  return value;
}

String _bounded(Object? value, String name, int maximum) {
  if (value is! String || value.isEmpty || value.length > maximum) {
    throw FormatException('$name 不合法');
  }
  return value;
}

void _requireKeys(Map<String, Object?> value, Set<String> expected) {
  if (value.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(value.keys.toSet()).isNotEmpty) {
    throw const FormatException('WebRTC 信令字段不合法');
  }
}
