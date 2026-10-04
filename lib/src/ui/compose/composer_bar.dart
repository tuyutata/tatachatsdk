import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:provider/provider.dart';

import '../metrics.dart';

enum ChatInputMode { keyboard, voice }

enum _VoiceDragTarget { none, cancel, send }

/// 文本态与语音态共用的唯一输入控件高度，禁止两种模式各自漂移。
const double _inputControlHeight = 42;
const double _inputTextFontSize = 15;
const double _inputTextLineHeight = 22;

/// 聊天页唯一输入栏：语音/键盘、输入区、表情/贴纸、加号按固定顺序排列。
class ComposerBar extends StatefulWidget {
  const ComposerBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.inputMode,
    required this.expressionOpen,
    required this.actionsOpen,
    required this.recording,
    required this.recordingDuration,
    required this.onToggleInputMode,
    required this.onToggleExpression,
    required this.onToggleActions,
    required this.onTextInputTap,
    required this.onSendText,
    required this.onVoicePressStart,
    required this.onVoicePressEnd,
    this.panel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ChatInputMode inputMode;
  final bool expressionOpen;
  final bool actionsOpen;
  final bool recording;
  final Duration recordingDuration;
  final VoidCallback onToggleInputMode;
  final VoidCallback onToggleExpression;
  final VoidCallback onToggleActions;
  final VoidCallback onTextInputTap;
  final ValueChanged<String> onSendText;
  final VoidCallback onVoicePressStart;
  final ValueChanged<bool> onVoicePressEnd;
  final Widget? panel;

  @override
  State<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<ComposerBar> {
  final _measureKey = GlobalKey();
  final _voiceCancelTargetKey = GlobalKey();
  final _voiceSendTargetKey = GlobalKey();
  int? _voicePointer;
  Offset? _voiceStart;
  bool _cancelBySlide = false;
  _VoiceDragTarget _voiceDragTarget = _VoiceDragTarget.none;
  OverlayEntry? _voiceOverlayEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant ComposerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    if (widget.recording != oldWidget.recording) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.recording) {
          _showVoiceOverlay();
        } else {
          _hideVoiceOverlay();
        }
      });
    } else if (widget.recording &&
        widget.recordingDuration != oldWidget.recordingDuration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _voiceOverlayEntry?.markNeedsBuild();
      });
    }
  }

  @override
  void dispose() {
    _hideVoiceOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final panelOpen = widget.panel != null;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        key: _measureKey,
        color: Theme.of(context).colorScheme.surface,
        elevation: 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 确认稿的唯一垂直顺序：输入栏在上，表达/功能面板在下。
            Padding(
              padding: EdgeInsets.fromLTRB(
                ChatUiMetrics.scaled(context, 8),
                ChatUiMetrics.scaled(context, 7),
                ChatUiMetrics.scaled(context, 8),
                ChatUiMetrics.scaled(context, 7) + (panelOpen ? 0 : safeBottom),
              ),
              child: Row(
                // 按钮与可变高度输入区始终共用同一水平中心线。
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _roundIconButton(
                    key: const ValueKey('chat-input-mode-toggle'),
                    tooltip: widget.inputMode == ChatInputMode.keyboard
                        ? '切换到语音'
                        : '切换到键盘',
                    icon: widget.inputMode == ChatInputMode.keyboard
                        ? Icons.mic_none_rounded
                        : Icons.keyboard_alt_outlined,
                    onTap: widget.onToggleInputMode,
                  ),
                  SizedBox(width: ChatUiMetrics.scaled(context, 6)),
                  Expanded(child: _buildInputArea(context)),
                  SizedBox(width: ChatUiMetrics.scaled(context, 6)),
                  _roundIconButton(
                    key: const ValueKey('chat-actions-toggle'),
                    tooltip: '更多功能',
                    icon: Icons.add_circle_outline_rounded,
                    active: widget.actionsOpen,
                    onTap: widget.onToggleActions,
                  ),
                ],
              ),
            ),
            if (panelOpen)
              Padding(
                padding: EdgeInsets.only(bottom: safeBottom),
                child: widget.panel!,
              ),
          ],
        ),
      ),
    );
  }

  /// 文本/语音两态共用同一胶囊表面，表情入口固定在内部右侧。
  Widget _buildInputArea(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: ChatUiMetrics.scaled(context, _inputControlHeight),
      ),
      child: DecoratedBox(
        key: const ValueKey('chat-input-surface'),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          // 输入区是紧凑圆角长方形，不使用胶囊形大圆角。
          borderRadius: BorderRadius.circular(
            ChatUiMetrics.scaled(context, 10),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: widget.inputMode == ChatInputMode.keyboard
                  ? _buildTextField(context)
                  : _buildVoiceButton(context),
            ),
            _roundIconButton(
              key: const ValueKey('chat-expression-toggle'),
              tooltip: '表情和贴纸',
              icon: Icons.emoji_emotions_outlined,
              active: widget.expressionOpen,
              onTap: widget.onToggleExpression,
              buttonHeight: _inputControlHeight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context) {
    final lineHeight = ChatUiMetrics.scaled(context, _inputTextLineHeight);
    return ConstrainedBox(
      // 单行文本态与语音态统一为 42px；多行内容仍可向上增长至 4 行。
      constraints: BoxConstraints(
        minHeight: ChatUiMetrics.scaled(context, _inputControlHeight),
      ),
      child: TextField(
        key: const ValueKey('chat-text-input'),
        controller: widget.controller,
        focusNode: widget.focusNode,
        minLines: 1,
        maxLines: 4,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontSize: ChatUiMetrics.scaled(context, _inputTextFontSize),
          height: _inputTextLineHeight / _inputTextFontSize,
        ),
        strutStyle: StrutStyle(
          fontSize: ChatUiMetrics.scaled(context, _inputTextFontSize),
          height: _inputTextLineHeight / _inputTextFontSize,
          forceStrutHeight: true,
        ),
        cursorHeight: lineHeight,
        textInputAction: TextInputAction.send,
        onTap: widget.onTextInputTap,
        // Flutter 对 send 的默认 onEditingComplete 会主动 unfocus。聊天必须
        // 覆盖该默认行为，让用户发送后继续保持键盘和输入焦点。
        onEditingComplete: () {},
        onSubmitted: _submit,
        decoration: InputDecoration(
          hintText: '输入消息',
          isDense: true,
          isCollapsed: true,
          // 聊天输入栏必须覆盖全局表单 52px 最小高度，否则正式主题会把
          // 42px 输入区重新撑高，并把按 42px 计算的文字/光标留在上半部。
          constraints: BoxConstraints(
            minHeight: ChatUiMetrics.scaled(context, _inputControlHeight),
          ),
          // 42px 输入区减去 22px 文字行，剩余空间上下各 10px；提示文字、
          // 输入文字和光标因此共用输入区的真实几何中心线。
          contentPadding: EdgeInsets.symmetric(
            horizontal: ChatUiMetrics.scaled(context, 14),
            vertical: ChatUiMetrics.scaled(context, 10),
          ),
          // 中间区域只由外层 chat-input-surface 绘制一层圆角长方形背景。
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildVoiceButton(BuildContext context) {
    final label = widget.recording
        ? _cancelBySlide
              ? '松开 取消'
              : '松开 发送  ${_formatDuration(widget.recordingDuration)}'
        : '按住 说话';
    return Listener(
      key: const ValueKey('chat-hold-to-talk'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (_voicePointer != null) return;
        _voicePointer = event.pointer;
        _voiceStart = event.position;
        _cancelBySlide = false;
        _setVoiceDragTarget(_VoiceDragTarget.none);
        widget.onVoicePressStart();
      },
      onPointerMove: (event) {
        if (_voicePointer != event.pointer || _voiceStart == null) return;
        final target = _voiceTargetAt(event.position);
        _setVoiceDragTarget(target);
        // 浮层尚未出现时保留原上滑 48px 取消兜底；浮层出现后只认真实目标。
        final cancel =
            target == _VoiceDragTarget.cancel ||
            (_voiceOverlayEntry == null &&
                event.position.dy < _voiceStart!.dy - 48);
        if (cancel != _cancelBySlide) {
          setState(() => _cancelBySlide = cancel);
        }
      },
      onPointerUp: (event) {
        if (_voicePointer != event.pointer) return;
        _finishVoice(_cancelBySlide);
      },
      onPointerCancel: (event) {
        if (_voicePointer != event.pointer) return;
        _finishVoice(true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: ChatUiMetrics.scaled(context, _inputControlHeight),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.recording
              ? _cancelBySlide
                    ? Colors.red.withValues(alpha: 0.14)
                    : Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(
            ChatUiMetrics.scaled(context, 10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ChatUiMetrics.scaled(context, 14),
            fontWeight: FontWeight.w600,
            color: _cancelBySlide
                ? Colors.red
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _roundIconButton({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
    double buttonHeight = 44,
  }) {
    return SizedBox(
      key: key,
      width: ChatUiMetrics.scaled(context, 44),
      height: ChatUiMetrics.scaled(context, buttonHeight),
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        color: active
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.onSurface,
        onPressed: onTap,
        icon: Icon(icon, size: ChatUiMetrics.scaled(context, 30)),
      ),
    );
  }

  void _submit(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    widget.onSendText(text);
    widget.controller.clear();
  }

  void _finishVoice(bool cancel) {
    _voicePointer = null;
    _voiceStart = null;
    _hideVoiceOverlay();
    _setVoiceDragTarget(_VoiceDragTarget.none);
    widget.onVoicePressEnd(cancel);
    if (_cancelBySlide) setState(() => _cancelBySlide = false);
  }

  void _showVoiceOverlay() {
    if (_voiceOverlayEntry != null || !widget.recording) return;
    final entry = OverlayEntry(
      builder: (context) => _VoiceRecordingOverlay(
        duration: widget.recordingDuration,
        target: _voiceDragTarget,
        cancelTargetKey: _voiceCancelTargetKey,
        sendTargetKey: _voiceSendTargetKey,
      ),
    );
    _voiceOverlayEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _hideVoiceOverlay() {
    _voiceOverlayEntry?.remove();
    _voiceOverlayEntry = null;
  }

  _VoiceDragTarget _voiceTargetAt(Offset globalPosition) {
    if (_targetRect(_voiceCancelTargetKey)?.contains(globalPosition) ?? false) {
      return _VoiceDragTarget.cancel;
    }
    if (_targetRect(_voiceSendTargetKey)?.contains(globalPosition) ?? false) {
      return _VoiceDragTarget.send;
    }
    return _VoiceDragTarget.none;
  }

  Rect? _targetRect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    // 稍微扩展命中区域，手指遮挡目标时也能稳定选中。
    return (box.localToGlobal(Offset.zero) & box.size).inflate(
      ChatUiMetrics.scaled(context, 10),
    );
  }

  void _setVoiceDragTarget(_VoiceDragTarget target) {
    if (_voiceDragTarget == target) return;
    _voiceDragTarget = target;
    _voiceOverlayEntry?.markNeedsBuild();
    if (target != _VoiceDragTarget.none) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  void _measure() {
    if (!mounted) return;
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    context.read<ComposerHeightNotifier>().setHeight(
      box.size.height - safeBottom,
    );
  }
}

String _formatDuration(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 180);
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${remainder.toString().padLeft(2, '0')}';
}

class _VoiceRecordingOverlay extends StatelessWidget {
  const _VoiceRecordingOverlay({
    required this.duration,
    required this.target,
    required this.cancelTargetKey,
    required this.sendTargetKey,
  });

  final Duration duration;
  final _VoiceDragTarget target;
  final GlobalKey cancelTargetKey;
  final GlobalKey sendTargetKey;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    final cancelSelected = target == _VoiceDragTarget.cancel;
    final sendSelected = target == _VoiceDragTarget.send;
    final centerColor = cancelSelected
        ? Colors.redAccent
        : sendSelected
        ? accent
        : Colors.white;
    return Positioned.fill(
      child: IgnorePointer(
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              // 浮层位于屏幕下半部，但与输入栏保留明确间隔；既不回到屏幕
              // 正中，也不能贴住“按住 说话”按钮。
              padding: EdgeInsets.only(
                bottom: ChatUiMetrics.scaled(context, 148),
              ),
              child: Material(
                key: const ValueKey('chat-voice-recording-overlay'),
                color: Colors.transparent,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ChatUiMetrics.scaled(context, 14),
                    vertical: ChatUiMetrics.scaled(context, 16),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xEE172126),
                    borderRadius: BorderRadius.circular(
                      ChatUiMetrics.scaled(context, 24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: ChatUiMetrics.scaled(context, 24),
                        offset: Offset(0, ChatUiMetrics.scaled(context, 10)),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _arcTarget(
                        context,
                        key: cancelTargetKey,
                        icon: Icons.close_rounded,
                        label: cancelSelected ? '松开取消' : '取消',
                        color: Colors.redAccent,
                        selected: cancelSelected,
                        leftArc: true,
                      ),
                      SizedBox(width: ChatUiMetrics.scaled(context, 16)),
                      SizedBox(
                        width: ChatUiMetrics.scaled(context, 70),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic_rounded,
                              key: const ValueKey('chat-voice-recording-mic'),
                              color: centerColor,
                              size: ChatUiMetrics.scaled(context, 38),
                            ),
                            SizedBox(height: ChatUiMetrics.scaled(context, 6)),
                            Text(
                              _formatDuration(duration),
                              key: const ValueKey('chat-voice-recording-timer'),
                              style: TextStyle(
                                color: centerColor,
                                fontSize: ChatUiMetrics.scaled(context, 16),
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: ChatUiMetrics.scaled(context, 16)),
                      _arcTarget(
                        context,
                        key: sendTargetKey,
                        icon: Icons.send_rounded,
                        label: sendSelected ? '松开发送' : '发送',
                        color: accent,
                        selected: sendSelected,
                        leftArc: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _arcTarget(
    BuildContext context, {
    required GlobalKey key,
    required IconData icon,
    required String label,
    required Color color,
    required bool selected,
    required bool leftArc,
  }) {
    final outerRadius = Radius.circular(ChatUiMetrics.scaled(context, 34));
    final innerRadius = Radius.circular(ChatUiMetrics.scaled(context, 12));
    return Semantics(
      key: ValueKey(
        leftArc ? 'chat-voice-cancel-target' : 'chat-voice-send-target',
      ),
      label: label,
      selected: selected,
      child: AnimatedContainer(
        key: key,
        duration: const Duration(milliseconds: 120),
        width: ChatUiMetrics.scaled(context, 82),
        height: ChatUiMetrics.scaled(context, 64),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.34 : 0.14),
          border: Border.all(
            color: color.withValues(alpha: selected ? 1 : 0.56),
            width: ChatUiMetrics.scaled(context, selected ? 2 : 1),
          ),
          borderRadius: BorderRadius.only(
            topLeft: leftArc ? outerRadius : innerRadius,
            bottomLeft: leftArc ? outerRadius : innerRadius,
            topRight: leftArc ? innerRadius : outerRadius,
            bottomRight: leftArc ? innerRadius : outerRadius,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: ChatUiMetrics.scaled(context, 24)),
            SizedBox(height: ChatUiMetrics.scaled(context, 2)),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontSize: ChatUiMetrics.scaled(context, 11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
