import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/chat_message.dart';

class VoiceRecordingResult {
  const VoiceRecordingResult({required this.path, required this.duration});

  final String path;
  final Duration duration;
}

class VoiceRecordingState {
  const VoiceRecordingState({required this.recording, required this.duration});

  static const idle = VoiceRecordingState(
    recording: false,
    duration: Duration.zero,
  );

  final bool recording;
  final Duration duration;
}

class VoicePermissionDeniedException implements Exception {
  const VoicePermissionDeniedException();

  @override
  String toString() => '请在系统设置中允许麦克风权限';
}

/// Chat 语音录制唯一控制器：AAC-LC 单声道、三分钟自动停止、取消即删临时明文。
class VoiceRecorder {
  VoiceRecorder({
    AudioRecorder? recorder,
    this.maximumDuration = defaultMaximumDuration,
    this.onMaximumReached,
  }) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  static const defaultMaximumDuration = chatMessageMaximumDuration;
  final Duration maximumDuration;
  final Future<void> Function(VoiceRecordingResult result)? onMaximumReached;
  final ValueNotifier<VoiceRecordingState> state = ValueNotifier(
    VoiceRecordingState.idle,
  );

  Timer? _timer;
  Stopwatch? _stopwatch;
  String? _path;
  Future<void>? _startOperation;
  bool _finishing = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_disposed ||
        state.value.recording ||
        _finishing ||
        _startOperation != null) {
      return;
    }
    late final Future<void> created;
    created = _startInternal();
    _startOperation = created;
    try {
      await created;
    } finally {
      if (identical(_startOperation, created)) _startOperation = null;
    }
  }

  Future<void> _startInternal() async {
    if (!await _recorder.hasPermission()) {
      throw const VoicePermissionDeniedException();
    }
    if (_disposed) return;
    final directory = await getTemporaryDirectory();
    if (_disposed) return;
    final path =
        '${directory.path}/chat-voice-'
        '${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: path,
    );
    if (_disposed) {
      await _recorder.cancel();
      await _deleteIfPresent(path);
      return;
    }
    _path = path;
    _stopwatch = Stopwatch()..start();
    state.value = const VoiceRecordingState(
      recording: true,
      duration: Duration.zero,
    );
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final elapsed = _stopwatch?.elapsed ?? Duration.zero;
      state.value = VoiceRecordingState(
        recording: true,
        duration: elapsed > maximumDuration ? maximumDuration : elapsed,
      );
      if (elapsed >= maximumDuration) unawaited(_finishAtLimit());
    });
  }

  Future<VoiceRecordingResult?> stop({bool cancel = false}) async {
    if (!state.value.recording || _finishing) return null;
    _finishing = true;
    _timer?.cancel();
    _stopwatch?.stop();
    final duration = _stopwatch?.elapsed ?? Duration.zero;
    final expectedPath = _path;
    try {
      if (cancel) {
        await _recorder.cancel();
        await _deleteIfPresent(expectedPath);
        return null;
      }
      final stoppedPath = await _recorder.stop();
      final path = stoppedPath ?? expectedPath;
      if (path == null || !await File(path).exists()) {
        throw StateError('语音录制文件不存在');
      }
      return VoiceRecordingResult(
        path: path,
        duration: duration > maximumDuration ? maximumDuration : duration,
      );
    } finally {
      _timer = null;
      _stopwatch = null;
      _path = null;
      _finishing = false;
      state.value = VoiceRecordingState.idle;
    }
  }

  Future<void> cancel() async {
    await stop(cancel: true);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _startOperation;
    } catch (_) {
      // 启动失败仍必须继续释放原生录音器。
    }
    await cancel();
    await _recorder.dispose();
    state.dispose();
  }

  Future<void> _finishAtLimit() async {
    final result = await stop();
    if (result != null) await onMaximumReached?.call(result);
  }
}

Future<void> _deleteIfPresent(String? path) async {
  if (path == null) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
}
