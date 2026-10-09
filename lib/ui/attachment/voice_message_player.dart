import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:just_audio/just_audio.dart';

import '../metrics.dart';

/// 本机已解密语音文件播放器。未到达时只触发既有附件下载，不读取远程明文 URL。
class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({
    super.key,
    required this.message,
    required this.isSentByMe,
    required this.onRequestDownload,
  });

  final AudioMessage message;
  final bool isSentByMe;
  final Future<void> Function() onRequestDownload;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  bool _loaded = false;
  bool _loading = false;
  bool _playing = false;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(
        () => _playing =
            state.playing && state.processingState != ProcessingState.completed,
      );
      if (state.processingState == ProcessingState.completed) {
        unawaited(_player.seek(Duration.zero));
      }
    });
    _positionSub = _player.positionStream.listen((position) {
      if (mounted) setState(() => _position = position);
    });
  }

  @override
  void didUpdateWidget(covariant VoiceMessagePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.source != widget.message.source) {
      _loaded = false;
      _position = Duration.zero;
      unawaited(_player.stop());
    }
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_loading) return;
    if (widget.message.source.isEmpty) {
      setState(() => _loading = true);
      try {
        await widget.onRequestDownload();
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }
    try {
      if (!_loaded) {
        await _player.setFilePath(widget.message.source);
        _loaded = true;
      }
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('语音无法播放，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.message.duration.inMilliseconds <= 0
        ? const Duration(seconds: 1)
        : widget.message.duration;
    final progress = (_position.inMilliseconds / total.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    final color = widget.isSentByMe
        ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.16)
        : Theme.of(context).colorScheme.surface;
    return Semantics(
      button: true,
      label: '${widget.message.duration.inSeconds}秒语音消息',
      child: InkWell(
        key: ValueKey('chat-audio-${widget.message.id}'),
        borderRadius: BorderRadius.circular(ChatUiMetrics.scaled(context, 18)),
        onTap: _handleTap,
        child: Container(
          width: ChatUiMetrics.scaled(
            context,
            126 + widget.message.duration.inSeconds.clamp(0, 60) * 1.4,
          ),
          constraints: BoxConstraints(
            minWidth: ChatUiMetrics.scaled(context, 126),
            maxWidth: MediaQuery.sizeOf(context).width * 0.68,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: ChatUiMetrics.scaled(context, 13),
            vertical: ChatUiMetrics.scaled(context, 11),
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(
              ChatUiMetrics.scaled(context, 18),
            ),
          ),
          child: Row(
            children: [
              if (_loading)
                SizedBox.square(
                  dimension: ChatUiMetrics.scaled(context, 22),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  widget.message.source.isEmpty
                      ? Icons.download_rounded
                      : _playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              SizedBox(width: ChatUiMetrics.scaled(context, 8)),
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: ChatUiMetrics.scaled(context, 3),
                  borderRadius: BorderRadius.circular(
                    ChatUiMetrics.scaled(context, 2),
                  ),
                  color: Theme.of(context).colorScheme.secondary,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.18),
                ),
              ),
              SizedBox(width: ChatUiMetrics.scaled(context, 8)),
              Text(
                '${widget.message.duration.inSeconds.clamp(1, 180)}″',
                style: TextStyle(
                  fontSize: ChatUiMetrics.scaled(context, 12),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
