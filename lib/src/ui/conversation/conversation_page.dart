import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../attachment.dart';
import '../../attachment/attachment_platform.dart';
import '../../chat_client.dart';
import '../../core/chat_message.dart';
import '../../runtime/direct_flow.dart';
import '../attachment/media_picker.dart';
import '../compose/camera_capture_page.dart';
import '../compose/composer_action_panel.dart';
import '../compose/composer_bar.dart';
import '../compose/expression_panel.dart';
import '../host.dart';
import 'message_view.dart';

typedef ChatPickMediaCallback = Future<ChatMediaDraft?> Function();
typedef ChatDeleteConversationCallback = Future<void> Function();

/// SDK 提供的完整聊天会话页。
///
/// 文本、表情、贴纸、媒体选择、录音、下载、删除和消息渲染均在此收口；
/// 宿主只注入产品资料、发送资格与产品专属动作。
class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({
    super.key,
    required this.sdk,
    required this.conversationId,
    required this.currentUserId,
    required this.accountId,
    required this.peerUserId,
    required this.title,
    required this.host,
    this.isGroup = false,
    this.pickMedia,
    this.onDeleteConversation,
  });

  /// 页面直接持有唯一 SDK；宿主不得再拼装发送、补拉、ACK 或实时连接回调。
  final ChatSdk sdk;
  final String conversationId;
  final String currentUserId;
  final String accountId;
  final String peerUserId;
  final String title;
  final bool isGroup;
  final ChatConversationHost host;
  final ChatPickMediaCallback? pickMedia;
  final ChatDeleteConversationCallback? onDeleteConversation;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  late final ChatConversationController _conversationController;
  late final VoiceRecorder _voiceRecorder;
  late final MediaCompressor _mediaCompressor;
  final MediaPicker _mediaPicker = MediaPicker();
  final MediaProbe _mediaProbe = MediaProbe();
  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  ChatComposerPanel _openPanel = ChatComposerPanel.none;
  ChatExpressionTab _expressionTab = ChatExpressionTab.emoji;
  ChatInputMode _inputMode = ChatInputMode.keyboard;
  VoiceRecordingState _voiceState = VoiceRecordingState.idle;
  Future<void>? _voiceStartInFlight;
  bool _deleting = false;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    _voiceRecorder = VoiceRecorder(onMaximumReached: _sendVoiceResult);
    _voiceRecorder.state.addListener(_onVoiceStateChanged);
    _mediaCompressor = MediaCompressor(
      limitForKind: widget.host.mediaLimits.limitForKind,
    );
    _conversationController = ChatConversationController(
      conversationId: widget.conversationId,
      currentUserId: widget.currentUserId,
      loadSnapshot: () async {
        final batch = await widget.sdk.store.readMessagesForDisplay(
          ownerUserId: widget.currentUserId,
          currentAccountId: widget.accountId,
          conversationId: widget.conversationId,
        );
        return (
          messages: batch.messages,
          integrityFailureCount: batch.integrityFailureCount,
        );
      },
      onSendText: (text) async {
        if (widget.isGroup) {
          await widget.sdk.sendGroupText(
            groupId: widget.conversationId,
            text: text,
          );
        } else {
          await widget.sdk.sendText(
            peerUserId: widget.peerUserId,
            conversationId: widget.conversationId,
            text: text,
          );
        }
      },
      onSendMedia: (media, {onLocalCommitted}) async {
        if (widget.isGroup) {
          await widget.sdk.sendGroupAttachment(
            groupId: widget.conversationId,
            media: media,
            onLocalCommitted: onLocalCommitted,
          );
        } else {
          await widget.sdk.sendMedia(
            peerUserId: widget.peerUserId,
            conversationId: widget.conversationId,
            media: media,
            onLocalCommitted: onLocalCommitted,
          );
        }
      },
      onSendSticker: (packId, stickerId) async {
        if (widget.isGroup) {
          await widget.sdk.sendGroupSticker(
            groupId: widget.conversationId,
            packId: packId,
            stickerId: stickerId,
          );
        } else {
          await widget.sdk.sendSticker(
            peerUserId: widget.peerUserId,
            conversationId: widget.conversationId,
            packId: packId,
            stickerId: stickerId,
          );
        }
      },
      onSync: () => widget.sdk.retryOutgoing(
        conversationId: widget.conversationId,
        recipientUserId: widget.isGroup ? null : widget.peerUserId,
      ),
      onStartRealtime: ({required onNotice, onDisconnected}) =>
          widget.sdk.startRealtimeSync(
            onNotice: onNotice,
            onDisconnected: onDisconnected,
            retryOutgoingOnConnect: false,
          ),
      onDownloadAttachment: (controlPlaintext) => widget.sdk.downloadAttachment(
        conversationId: widget.conversationId,
        controlPlaintext: controlPlaintext,
      ),
      onResolveMediaPaths: (contents) => widget.sdk.resolveCachedMediaPaths(
        conversationId: widget.conversationId,
        contents: contents,
      ),
      onMarkRead: (readThroughMillis) => widget.sdk.markConversationRead(
        conversationId: widget.conversationId,
        readThroughMillis: readThroughMillis,
      ),
      isVisible: () => mounted && (ModalRoute.of(context)?.isCurrent ?? false),
      onPause: _cancelVoiceRecording,
      mediaLimits: widget.host.mediaLimits,
      errorMessage: widget.host.errorMessage,
    );
    _conversationController.addListener(_refresh);
    _conversationController.start();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onVoiceStateChanged() {
    if (mounted) setState(() => _voiceState = _voiceRecorder.state.value);
  }

  @override
  void dispose() {
    _conversationController.removeListener(_refresh);
    _conversationController.dispose();
    _composerController.dispose();
    _composerFocusNode.dispose();
    _voiceRecorder.state.removeListener(_onVoiceStateChanged);
    unawaited(_voiceRecorder.dispose());
    super.dispose();
  }

  bool _requireSendPermission() {
    if (widget.host.canSend(widget.currentUserId)) return true;
    if (mounted) {
      setState(() {
        _pageError = widget.host.unavailableMessage(widget.currentUserId);
      });
    }
    return false;
  }

  Future<void> _sendText(String text) async {
    if (_requireSendPermission()) await _conversationController.sendText(text);
  }

  Future<void> _sendSticker(String packId, String stickerId) async {
    if (_requireSendPermission()) {
      await _conversationController.sendSticker(packId, stickerId);
    }
  }

  Future<void> _sendMediaDrafts(Iterable<ChatMediaDraft> drafts) async {
    if (_conversationController.attachmentBusy || !_requireSendPermission()) {
      return;
    }
    final prepared = drafts.toList(growable: false);
    for (final draft in prepared) {
      if (widget.host.mediaLimits.exceedsForKind(draft.kind, draft.byteSize)) {
        setState(() {
          _pageError = widget.host.attachmentTooLargeMessage(draft.kind);
        });
        return;
      }
      final durationMs = draft.durationMs;
      if (durationMs != null &&
          durationMs > chatMessageMaximumDuration.inMilliseconds) {
        setState(() {
          _pageError = widget.host.attachmentTooLongMessage(draft.kind);
        });
        return;
      }
    }
    await _conversationController.sendMediaDrafts(prepared);
  }

  Future<void> _pickGallery() async {
    if (widget.pickMedia != null) {
      final draft = await widget.pickMedia!.call();
      if (draft != null) await _sendMediaDrafts([draft]);
      return;
    }
    final picked = await _mediaPicker.gallery(context);
    if (picked.isEmpty) return;
    final drafts = <ChatMediaDraft>[];
    for (final item in picked) {
      drafts.add(await _buildMediaDraft(item));
    }
    await _sendMediaDrafts(drafts);
  }

  Future<void> _capture() async {
    final picked = await openChatCameraCapture(context);
    if (picked == null || !mounted) return;
    ChatMediaDraft? draft;
    try {
      draft = await _buildMediaDraft(picked);
      await _sendMediaDrafts([draft]);
    } finally {
      final paths = <String>{picked.path, if (draft != null) draft.sourcePath};
      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
  }

  Future<void> _pickFile() async {
    final file = await const ChatAttachmentPlatform().pickFile();
    if (file == null) return;
    ChatMediaDraft? draft;
    try {
      final mime = file.mime == 'application/octet-stream'
          ? mimeFromFileName(file.fileName)
          : file.mime;
      draft = await _buildMediaDraft(
        PickedMediaFile(
          path: file.path,
          fileName: file.fileName,
          mime: mime,
          kind: mediaKindFromMime(mime),
        ),
      );
      await _sendMediaDrafts([draft]);
    } finally {
      final paths = <String>{file.path, if (draft != null) draft.sourcePath};
      for (final path in paths) {
        final temporary = File(path);
        if (await temporary.exists()) await temporary.delete();
      }
    }
  }

  Future<ChatMediaDraft> _buildMediaDraft(PickedMediaFile picked) async {
    final path = await _mediaCompressor.ensureWithinLimit(
      path: picked.path,
      kind: picked.kind,
    );
    final probe = await _mediaProbe.probe(path: path, kind: picked.kind);
    final durationMs = probe.durationMs;
    if (durationMs != null &&
        durationMs > chatMessageMaximumDuration.inMilliseconds) {
      throw ChatMediaTooLongException(
        kind: picked.kind,
        durationMs: durationMs,
      );
    }
    return ChatMediaDraft(
      kind: picked.kind,
      fileName: picked.fileName,
      contentType: picked.mime,
      sourcePath: path,
      byteSize: await File(path).length(),
      width: probe.width,
      height: probe.height,
      durationMs: durationMs,
      blurhash: probe.blurhash,
    );
  }

  Future<void> _handleAction(ChatComposerAction action) async {
    if (!_requireSendPermission()) return;
    _togglePanel(ChatComposerPanel.none);
    try {
      switch (action) {
        case ChatComposerAction.gallery:
          await _pickGallery();
        case ChatComposerAction.capture:
          await _capture();
        case ChatComposerAction.file:
          await _pickFile();
        case ChatComposerAction.transfer:
          final action = widget.host.onTransfer;
          if (!widget.isGroup && action != null) {
            await action(context, widget.peerUserId);
          }
        case ChatComposerAction.location:
          final action = widget.host.onLocation;
          if (action != null) await action(context, widget.peerUserId);
        case ChatComposerAction.voiceCall:
        case ChatComposerAction.videoCall:
          return;
      }
    } on ChatMediaTooLargeException {
      if (mounted) {
        setState(() {
          _pageError = widget.host.attachmentTooLargeMessage(
            ChatMessageKind.file,
          );
        });
      }
    } on ChatMediaTooLongException catch (error) {
      if (mounted) {
        setState(() {
          _pageError = widget.host.attachmentTooLongMessage(error.kind);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _pageError = widget.host.errorMessage(error));
    }
  }

  void _togglePanel(ChatComposerPanel panel) {
    final close = _openPanel == panel;
    setState(() {
      _openPanel = close ? ChatComposerPanel.none : panel;
    });
    if (_openPanel == ChatComposerPanel.none) {
      _requestKeyboard();
    } else {
      _composerFocusNode.unfocus();
    }
  }

  void _handleTextInputTap() {
    if (_openPanel == ChatComposerPanel.none) return;
    setState(() => _openPanel = ChatComposerPanel.none);
    _requestKeyboard();
  }

  void _requestKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _inputMode == ChatInputMode.keyboard) {
        _composerFocusNode.requestFocus();
      }
    });
  }

  void _toggleInputMode() {
    unawaited(_cancelVoiceRecording());
    setState(() {
      _inputMode = _inputMode == ChatInputMode.keyboard
          ? ChatInputMode.voice
          : ChatInputMode.keyboard;
      _openPanel = ChatComposerPanel.none;
    });
    if (_inputMode == ChatInputMode.voice) {
      _composerFocusNode.unfocus();
    } else {
      _composerFocusNode.requestFocus();
    }
  }

  Future<void> _startVoiceRecording() async {
    if (!_requireSendPermission() ||
        _voiceStartInFlight != null ||
        _voiceState.recording) {
      return;
    }
    late final Future<void> pending;
    pending = _voiceRecorder.start();
    _voiceStartInFlight = pending;
    try {
      await pending;
    } catch (error) {
      if (mounted) setState(() => _pageError = widget.host.errorMessage(error));
    } finally {
      if (identical(_voiceStartInFlight, pending)) _voiceStartInFlight = null;
    }
  }

  Future<void> _finishVoiceRecording(bool cancel) async {
    try {
      final starting = _voiceStartInFlight;
      if (starting != null) await starting;
      final result = await _voiceRecorder.stop(cancel: cancel);
      if (result == null) return;
      if (result.duration < const Duration(milliseconds: 800)) {
        await File(result.path).delete();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('说话时间太短')));
        }
        return;
      }
      await _sendVoiceResult(result);
    } catch (error) {
      if (mounted) setState(() => _pageError = widget.host.errorMessage(error));
    }
  }

  Future<void> _cancelVoiceRecording() async {
    try {
      final starting = _voiceStartInFlight;
      if (starting != null) await starting;
      await _voiceRecorder.cancel();
    } catch (_) {
      // 页面退出时只收口录音资源，不向已销毁页面写入异步错误。
    }
  }

  Future<void> _sendVoiceResult(VoiceRecordingResult result) async {
    final file = File(result.path);
    try {
      await _sendMediaDrafts([
        ChatMediaDraft(
          kind: ChatMessageKind.audio,
          fileName: result.path.split(Platform.pathSeparator).last,
          contentType: 'audio/mp4',
          sourcePath: result.path,
          byteSize: await file.length(),
          durationMs: result.duration.inMilliseconds.clamp(
            1,
            chatMessageMaximumDuration.inMilliseconds,
          ),
        ),
      ]);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _downloadMedia(String controlPlaintext) async {
    final downloaded = await _conversationController.downloadAttachment(
      controlPlaintext,
    );
    if (!mounted || downloaded == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已保存：${downloaded.fileName}')));
  }

  Future<void> _deleteConversation() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除聊天记录'),
            content: const Text('确定删除这台设备上的聊天记录？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final deleter = widget.onDeleteConversation;
    if (deleter == null) {
      setState(() => _pageError = '当前会话不能删除');
      return;
    }
    setState(() => _deleting = true);
    _conversationController.pause();
    final deletion = deleter();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      unawaited(deletion.catchError((Object _) {}));
      return;
    }
    await deletion;
    await _conversationController.chatController.setMessages(
      const [],
      animated: false,
    );
    if (mounted) setState(() => _deleting = false);
  }

  Widget _buildComposer(BuildContext context) {
    if (!widget.host.canSend(widget.currentUserId)) {
      return Container(
        key: const ValueKey('chat-membership-required'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: widget.host.style.surfaceColor,
        child: Text(
          widget.host.unavailableMessage(widget.currentUserId),
          textAlign: TextAlign.center,
          style: TextStyle(color: widget.host.style.textSecondaryColor),
        ),
      );
    }
    final panel = switch (_openPanel) {
      ChatComposerPanel.none => null,
      ChatComposerPanel.expression => ChatExpressionPanel(
        controller: _composerController,
        selectedTab: _expressionTab,
        onTabChanged: (tab) => setState(() => _expressionTab = tab),
        onStickerPick: (packId, stickerId) =>
            unawaited(_sendSticker(packId, stickerId)),
        onSendText: (text) => unawaited(_sendText(text)),
        style: widget.host.style,
      ),
      ChatComposerPanel.actions => ComposerActionPanel(
        isGroup: widget.isGroup,
        callsEnabled: false,
        onAction: (action) => unawaited(_handleAction(action)),
        iconBuilder: widget.host.actionIconBuilder,
      ),
    };
    return ComposerBar(
      controller: _composerController,
      focusNode: _composerFocusNode,
      inputMode: _inputMode,
      expressionOpen: _openPanel == ChatComposerPanel.expression,
      actionsOpen: _openPanel == ChatComposerPanel.actions,
      recording: _voiceState.recording,
      recordingDuration: _voiceState.duration,
      onToggleInputMode: _toggleInputMode,
      onToggleExpression: () => _togglePanel(ChatComposerPanel.expression),
      onToggleActions: () => _togglePanel(ChatComposerPanel.actions),
      onTextInputTap: _handleTextInputTap,
      onSendText: (text) => unawaited(_sendText(text)),
      onVoicePressStart: () => unawaited(_startVoiceRecording()),
      onVoicePressEnd: (cancel) => unawaited(_finishVoiceRecording(cancel)),
      panel: panel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.host.style;
    return Scaffold(
      backgroundColor: style.backgroundColor,
      appBar: AppBar(
        backgroundColor: style.surfaceColor,
        foregroundColor: style.textPrimaryColor,
        elevation: 0,
        titleSpacing: 0,
        title: widget.host.headerBuilder(
          context,
          ChatConversationHeader(
            peerUserId: widget.peerUserId,
            title: widget.title,
            isGroup: widget.isGroup,
          ),
        ),
        actions: [
          PopupMenuButton<_ChatMenuAction>(
            tooltip: '更多',
            icon: const Icon(Icons.more_vert_rounded),
            enabled: !_deleting,
            onSelected: (_) => unawaited(_deleteConversation()),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ChatMenuAction.deleteConversation,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('删除聊天记录'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ChatMessageListView(
        currentUserId: widget.currentUserId,
        chatController: _conversationController.chatController,
        onMessageSend: _sendText,
        resolveUser: (id) =>
            widget.host.resolveUser(id, widget.currentUserId, widget.isGroup),
        composerBuilder: _buildComposer,
        onDownloadAttachment: _downloadMedia,
        onMessagesChanged: _conversationController.reloadMessages,
        isGroup: widget.isGroup,
        loading: _conversationController.loading,
        error: _pageError ?? _conversationController.error,
        groupSenderBuilder: widget.isGroup
            ? widget.host.groupSenderBuilder
            : null,
        style: style,
      ),
    );
  }
}

enum _ChatMenuAction { deleteConversation }
