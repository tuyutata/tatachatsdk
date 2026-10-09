import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:tatachat_sdk/call.dart';

import '../metrics.dart';

Future<void> openOutgoingCallPage(
  BuildContext context, {
  required ChatCallCoordinator coordinator,
  required String localUserId,
  required String peerUserId,
  required String title,
  required bool video,
}) async {
  try {
    final handle = await coordinator.startOutgoing(
      localUserId: localUserId,
      peerUserId: peerUserId,
      title: title,
      video: video,
    );
    if (!context.mounted) {
      await handle.session.hangUp();
      return;
    }
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => CallPage(handle: handle)));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前无法发起通话')));
    }
  }
}

Future<void> openIncomingCallPage(
  BuildContext context,
  ChatCallHandle handle,
) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => CallPage(handle: handle)));

class CallPage extends StatefulWidget {
  const CallPage({super.key, required this.handle});
  final ChatCallHandle handle;

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  late DirectCallState _state = widget.handle.session.state;
  StreamSubscription<DirectCallState>? _subscription;
  bool _microphoneEnabled = true;
  bool _cameraEnabled = true;
  bool _speakerEnabled = false;
  bool _closing = false;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _speakerEnabled = widget.handle.session.mediaKind == CallMediaKind.video;
    _subscription = widget.handle.session.states.listen(_handleState);
    if (!widget.handle.incoming) {
      unawaited(widget.handle.session.start());
    }
  }

  void _handleState(DirectCallState state) {
    if (!mounted) return;
    setState(() => _state = state);
    if (state.isTerminal && !_closing) {
      _closing = true;
      _autoCloseTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    unawaited(_subscription?.cancel());
    if (!_state.isTerminal) unawaited(widget.handle.session.hangUp());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.handle.session.mediaKind == CallMediaKind.video;
    final peer = widget.handle.peer is FlutterCallPeer
        ? widget.handle.peer as FlutterCallPeer
        : null;
    return PopScope<void>(
      canPop: _state.isTerminal,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(widget.handle.session.hangUp());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D171A),
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (video && peer != null)
                RTCVideoView(
                  peer.remoteRenderer,
                  key: const ValueKey('call-remote-video'),
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                _VoiceBackdrop(title: widget.handle.title),
              Positioned(
                top: ChatUiMetrics.scaled(context, 24),
                left: ChatUiMetrics.scaled(context, 24),
                right: ChatUiMetrics.scaled(context, 24),
                child: Column(
                  children: [
                    Text(
                      widget.handle.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ChatUiMetrics.scaled(context, 20),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: ChatUiMetrics.scaled(context, 8)),
                    Text(
                      _statusText(_state),
                      key: const ValueKey('call-status'),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: ChatUiMetrics.scaled(context, 14),
                      ),
                    ),
                  ],
                ),
              ),
              if (video && peer != null)
                Positioned(
                  top: ChatUiMetrics.scaled(context, 92),
                  right: ChatUiMetrics.scaled(context, 18),
                  width: ChatUiMetrics.scaled(context, 112),
                  height: ChatUiMetrics.scaled(context, 156),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      ChatUiMetrics.scaled(context, 16),
                    ),
                    child: RTCVideoView(
                      peer.localRenderer,
                      key: const ValueKey('call-local-video'),
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: ChatUiMetrics.scaled(context, 38),
                child: _buildControls(peer, video),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(FlutterCallPeer? peer, bool video) {
    if (_state.phase == DirectCallPhase.incoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallButton(
            key: const ValueKey('call-reject'),
            icon: Icons.call_end_rounded,
            label: '拒绝',
            color: Theme.of(context).colorScheme.error,
            onPressed: widget.handle.session.hangUp,
          ),
          _CallButton(
            key: const ValueKey('call-accept'),
            icon: video ? Icons.videocam_rounded : Icons.call_rounded,
            label: '接听',
            color: const Color(0xFF2E9D62),
            onPressed: widget.handle.session.accept,
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CallButton(
          key: const ValueKey('call-microphone'),
          icon: _microphoneEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
          label: _microphoneEnabled ? '静音' : '取消静音',
          onPressed: peer == null
              ? null
              : () async {
                  _microphoneEnabled = !_microphoneEnabled;
                  await peer.setMicrophoneEnabled(_microphoneEnabled);
                  if (mounted) setState(() {});
                },
        ),
        _CallButton(
          key: const ValueKey('call-hangup'),
          icon: Icons.call_end_rounded,
          label: '挂断',
          color: Theme.of(context).colorScheme.error,
          onPressed: widget.handle.session.hangUp,
        ),
        if (video)
          _CallButton(
            key: const ValueKey('call-camera'),
            icon: _cameraEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: _cameraEnabled ? '关闭摄像头' : '打开摄像头',
            onPressed: peer == null
                ? null
                : () async {
                    _cameraEnabled = !_cameraEnabled;
                    await peer.setCameraEnabled(_cameraEnabled);
                    if (mounted) setState(() {});
                  },
          )
        else
          _CallButton(
            key: const ValueKey('call-speaker'),
            icon: _speakerEnabled
                ? Icons.volume_up_rounded
                : Icons.hearing_rounded,
            label: '扬声器',
            onPressed: peer == null
                ? null
                : () async {
                    _speakerEnabled = !_speakerEnabled;
                    await peer.setSpeakerEnabled(_speakerEnabled);
                    if (mounted) setState(() {});
                  },
          ),
      ],
    );
  }
}

String _statusText(DirectCallState state) => switch (state.phase) {
  DirectCallPhase.incoming => '邀请你进行通话',
  DirectCallPhase.calling => '正在呼叫',
  DirectCallPhase.connecting => '正在建立安全直连',
  DirectCallPhase.connected => '通话中',
  DirectCallPhase.ended => '通话已结束',
  DirectCallPhase.failed => state.reason ?? '通话失败',
};

class _VoiceBackdrop extends StatelessWidget {
  const _VoiceBackdrop({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF173A3A), Color(0xFF071013)],
      ),
    ),
    alignment: Alignment.center,
    child: CircleAvatar(
      radius: ChatUiMetrics.scaled(context, 58),
      backgroundColor: Colors.white12,
      child: Text(
        title.isEmpty ? '?' : title.characters.first,
        style: TextStyle(
          color: Colors.white,
          fontSize: ChatUiMetrics.scaled(context, 46),
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = Colors.white24,
  });

  final IconData icon;
  final String label;
  final Future<void> Function()? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton.filled(
        onPressed: onPressed == null ? null : () => unawaited(onPressed!()),
        style: IconButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: Colors.white10,
          minimumSize: Size.square(ChatUiMetrics.scaled(context, 58)),
        ),
        icon: Icon(icon, color: Colors.white),
      ),
      SizedBox(height: ChatUiMetrics.scaled(context, 7)),
      Text(
        label,
        style: TextStyle(
          color: Colors.white70,
          fontSize: ChatUiMetrics.scaled(context, 12),
        ),
      ),
    ],
  );
}
