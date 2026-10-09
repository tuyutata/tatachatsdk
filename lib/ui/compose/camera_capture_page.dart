import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../attachment/mime.dart';
import '../../core/chat_message.dart';
import '../attachment/media_picker.dart';
import '../metrics.dart';

/// 打开 Chat 应用内拍摄页。点按拍照；长按开始录像，松开结束，最长三分钟。
Future<PickedMediaFile?> openChatCameraCapture(BuildContext context) {
  return Navigator.of(context).push<PickedMediaFile>(
    MaterialPageRoute(builder: (_) => const CameraCapturePage()),
  );
}

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  static const maximumVideoDuration = chatMessageMaximumDuration;

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _initializing = true;
  bool _capturing = false;
  bool _recording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  Stopwatch? _recordingStopwatch;
  Future<void>? _videoStartInFlight;
  int _cameraEpoch = 0;
  bool _disposed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_pauseCamera());
    } else if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_initialize(cameraIndex: _cameraIndex));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cameraEpoch++;
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    unawaited(_stopAndDiscard().whenComplete(_disposeController));
    super.dispose();
  }

  Future<void> _initialize({int cameraIndex = 0}) async {
    final epoch = ++_cameraEpoch;
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }
    try {
      final cameras = _cameras.isEmpty ? await availableCameras() : _cameras;
      if (cameras.isEmpty) throw StateError('设备没有可用摄像头');
      final index = cameraIndex.clamp(0, cameras.length - 1);
      final next = CameraController(
        cameras[index],
        ResolutionPreset.high,
        enableAudio: true,
      );
      await next.initialize();
      if (_disposed || epoch != _cameraEpoch) {
        await next.dispose();
        return;
      }
      final previous = _controller;
      _controller = next;
      _cameras = cameras;
      _cameraIndex = index;
      await previous?.dispose();
      if (mounted) setState(() => _initializing = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = _cameraError(error);
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(_picked(file, isVideo: false));
    } catch (error) {
      if (mounted) setState(() => _error = _cameraError(error));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _startVideo() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _capturing ||
        _recording) {
      return;
    }
    try {
      await controller.startVideoRecording();
      _recording = true;
      // 页面销毁流程会等待本启动操作完成后统一停止并删除录像；
      // 这里不能反向等待 `_videoStartInFlight`，否则会形成自等待。
      if (_disposed) return;
      _recordingStopwatch = Stopwatch()..start();
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final duration = _recordingStopwatch?.elapsed ?? Duration.zero;
        if (mounted) setState(() => _recordingDuration = duration);
        if (duration >= CameraCapturePage.maximumVideoDuration) {
          unawaited(_stopVideo());
        }
      });
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = _cameraError(error));
    }
  }

  void _beginVideoGesture() {
    if (_videoStartInFlight != null || _recording || _capturing) return;
    late final Future<void> created;
    created = _startVideo();
    _videoStartInFlight = created;
    unawaited(
      created.whenComplete(() {
        if (identical(_videoStartInFlight, created)) {
          _videoStartInFlight = null;
        }
      }),
    );
  }

  Future<void> _finishVideoGesture() async {
    final starting = _videoStartInFlight;
    if (starting != null) await starting;
    await _stopVideo();
  }

  Future<void> _stopVideo() async {
    final controller = _controller;
    if (controller == null || !_recording || _capturing) return;
    setState(() => _capturing = true);
    _recordingTimer?.cancel();
    _recordingStopwatch?.stop();
    try {
      final file = await controller.stopVideoRecording();
      if (!mounted) return;
      Navigator.of(context).pop(_picked(file, isVideo: true));
    } catch (error) {
      if (mounted) setState(() => _error = _cameraError(error));
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
          _recording = false;
          _recordingDuration = Duration.zero;
        });
      }
    }
  }

  Future<void> _stopAndDiscard() async {
    final starting = _videoStartInFlight;
    if (starting != null) await starting;
    _recordingTimer?.cancel();
    _recordingStopwatch?.stop();
    final controller = _controller;
    if (controller != null && controller.value.isRecordingVideo) {
      try {
        final discarded = await controller.stopVideoRecording();
        final file = File(discarded.path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // 生命周期中断时只保证结束原生录制，文件不进入消息管道。
      }
    }
    _recording = false;
    _recordingDuration = Duration.zero;
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  Future<void> _pauseCamera() async {
    _cameraEpoch++;
    await _stopAndDiscard();
    await _disposeController();
  }

  Future<void> _close() async {
    await _stopAndDiscard();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _recording || _capturing) return;
    await _initialize(cameraIndex: (_cameraIndex + 1) % _cameras.length);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && controller.value.isInitialized)
              Center(child: CameraPreview(controller))
            else
              const Center(child: CircularProgressIndicator()),
            Positioned(
              left: ChatUiMetrics.scaled(context, 8),
              top: ChatUiMetrics.scaled(context, 8),
              child: IconButton(
                tooltip: '关闭',
                color: Colors.white,
                onPressed: _capturing ? null : () => unawaited(_close()),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            if (_cameras.length > 1)
              Positioned(
                right: ChatUiMetrics.scaled(context, 8),
                top: ChatUiMetrics.scaled(context, 8),
                child: IconButton(
                  tooltip: '切换摄像头',
                  color: Colors.white,
                  onPressed: _switchCamera,
                  icon: const Icon(Icons.cameraswitch_rounded),
                ),
              ),
            if (_recording)
              Positioned(
                top: ChatUiMetrics.scaled(context, 18),
                left: 0,
                right: 0,
                child: Text(
                  '● ${_formatDuration(_recordingDuration)} / 03:00',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (_error != null)
              Positioned(
                left: ChatUiMetrics.scaled(context, 20),
                right: ChatUiMetrics.scaled(context, 20),
                bottom: ChatUiMetrics.scaled(context, 140),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: ChatUiMetrics.scaled(context, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _recording ? '松开结束录像' : '点按拍照，长按录像',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  SizedBox(height: ChatUiMetrics.scaled(context, 14)),
                  GestureDetector(
                    key: const ValueKey('chat-camera-shutter'),
                    onTap: _initializing || _recording ? null : _takePhoto,
                    onLongPressStart: _initializing || _capturing
                        ? null
                        : (_) => _beginVideoGesture(),
                    onLongPressEnd: (_) => unawaited(_finishVideoGesture()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: ChatUiMetrics.scaled(
                        context,
                        _recording ? 76 : 70,
                      ),
                      height: ChatUiMetrics.scaled(
                        context,
                        _recording ? 76 : 70,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _recording ? Colors.redAccent : Colors.white,
                        border: Border.all(color: Colors.white70, width: 5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

PickedMediaFile _picked(XFile file, {required bool isVideo}) {
  final mime = file.mimeType ?? mimeFromFileName(file.name);
  return PickedMediaFile(
    path: file.path,
    fileName: file.name,
    mime: isVideo && !mime.startsWith('video/') ? 'video/mp4' : mime,
    kind: isVideo ? ChatMessageKind.video : ChatMessageKind.image,
  );
}

String _formatDuration(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 180);
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

String _cameraError(Object error) {
  final text = error.toString();
  if (text.contains('AccessDenied') || text.contains('permission')) {
    return '请在系统设置中允许相机和麦克风权限';
  }
  return '拍摄暂时不可用，请稍后重试';
}
