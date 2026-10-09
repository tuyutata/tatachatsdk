import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

import '../../chat_client.dart';
import '../../core/chat_content.dart';
import '../../core/chat_message.dart';
import '../../runtime/direct_flow.dart';
import '../../runtime/media_limit_policy.dart';
import '../../storage/records.dart';
import '../attachment/image_viewer_page.dart';
import '../attachment/video_player_page.dart';
import '../attachment/voice_message_player.dart';
import '../message_adapter.dart';
import '../sticker_pack.dart';
import '../style.dart';

typedef ChatMessageSnapshot = ({
  List<ChatStoredMessage> messages,
  int integrityFailureCount,
});
typedef ChatLoadMessageSnapshotCallback =
    Future<ChatMessageSnapshot> Function();
typedef ChatSendTextCallback = Future<void> Function(String text);
typedef ChatSendMediaCallback =
    Future<void> Function(
      ChatMediaDraft media, {
      ChatMediaLocalCommitNotifier? onLocalCommitted,
    });
typedef ChatSendStickerCallback =
    Future<void> Function(String packId, String stickerId);
typedef ChatSyncCallback = Future<int> Function();
typedef ChatStartRealtimeCallback =
    Future<Future<void> Function()?> Function({
      required Future<void> Function() onNotice,
      Future<void> Function()? onDisconnected,
    });
typedef ChatDownloadAttachmentCallback =
    Future<ChatDownloadedAttachment> Function(String controlPlaintext);
typedef ChatResolveMediaPathsCallback =
    Future<Map<String, String>> Function(List<ChatContent> contents);
typedef ChatMarkReadCallback = Future<void> Function(int readThroughMillis);
typedef ChatErrorMessageCallback = String Function(Object error);
typedef ChatControllerPauseCallback = Future<void> Function();

String _defaultChatErrorMessage(Object _) => '聊天操作失败，请稍后重试';

/// 单个会话的通用 UI 运行控制器。
///
/// 控制器只管理本地消息快照、乐观气泡、WSS 通知、轮询降级和前后台生命周期。
/// 完整会话页从同一 ChatSdk 生成这些运行回调；产品宿主只提供展示、发送资格和产品动作。
class ChatConversationController extends ChangeNotifier
    with WidgetsBindingObserver {
  ChatConversationController({
    required this.conversationId,
    required this.currentUserId,
    required this.loadSnapshot,
    required this.onSendText,
    required this.onSendMedia,
    required this.onSendSticker,
    required this.onSync,
    required this.onStartRealtime,
    required this.onDownloadAttachment,
    required this.onResolveMediaPaths,
    required this.onMarkRead,
    required this.isVisible,
    this.onPause,
    this.mediaLimits = const ChatUnlimitedMediaLimitPolicy(),
    this.errorMessage = _defaultChatErrorMessage,
  });

  static const _normalPollInterval = Duration(seconds: 8);
  static const _backoffPollInterval = Duration(seconds: 30);
  static const _heartbeatPollInterval = Duration(seconds: 20);

  final String conversationId;
  final String currentUserId;
  final ChatLoadMessageSnapshotCallback loadSnapshot;
  final ChatSendTextCallback? onSendText;
  final ChatSendMediaCallback? onSendMedia;
  final ChatSendStickerCallback? onSendSticker;
  final ChatSyncCallback? onSync;
  final ChatStartRealtimeCallback? onStartRealtime;
  final ChatDownloadAttachmentCallback? onDownloadAttachment;
  final ChatResolveMediaPathsCallback? onResolveMediaPaths;
  final ChatMarkReadCallback? onMarkRead;
  final bool Function() isVisible;
  final ChatControllerPauseCallback? onPause;
  final ChatMediaLimitPolicy mediaLimits;
  final ChatErrorMessageCallback errorMessage;

  final InMemoryChatController chatController = InMemoryChatController();
  final Map<String, String> _resolvedMediaPaths = <String, String>{};
  final Map<String, Message> _optimisticMessages = <String, Message>{};
  Timer? _pollTimer;
  Future<void> Function()? _stopRealtime;
  Future<void>? _openCoordinatorInFlight;
  bool _started = false;
  bool _disposed = false;
  bool _appResumed = false;
  bool _polling = false;
  bool _realtimeConnecting = false;
  bool _loading = true;
  bool _attachmentBusy = false;
  String? _error;
  int _messageReloadGeneration = 0;
  int? _renderedMessageFingerprint;
  int _optimisticMessageSequence = 0;

  bool get loading => _loading;
  bool get attachmentBusy => _attachmentBusy;
  String? get error => _error;
  int get optimisticMessageCount => _optimisticMessages.length;

  /// 启动一次控制器。重复调用不会重复注册生命周期或建立实时订阅。
  void start() {
    if (_started || _disposed) return;
    _started = true;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _requestOpenCoordinate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      _appResumed = true;
      _requestOpenCoordinate();
      return;
    }
    _appResumed = false;
    if (onPause != null) unawaited(onPause!());
    _pauseSync();
  }

  void showError(String? value) {
    if (_disposed || _error == value) return;
    _error = value;
    notifyListeners();
  }

  /// 主动暂停当前会话的计时器和实时订阅；再次进入前台时由生命周期统一恢复。
  void pause() {
    if (_disposed) return;
    if (onPause != null) unawaited(onPause!());
    _pauseSync();
  }

  void _requestOpenCoordinate() {
    if (_disposed || !_appResumed || _openCoordinatorInFlight != null) return;
    late final Future<void> created;
    created = _syncOnOpen().whenComplete(() {
      if (identical(_openCoordinatorInFlight, created)) {
        _openCoordinatorInFlight = null;
      }
    });
    _openCoordinatorInFlight = created;
    unawaited(created.catchError((_) {}));
  }

  /// 读取本地真值并原位刷新消息。网络通知只负责触发此方法。
  Future<void> reloadMessages() async {
    if (_disposed) return;
    final generation = ++_messageReloadGeneration;
    try {
      final batch = await loadSnapshot();
      if (_disposed || generation != _messageReloadGeneration) return;
      final messages = batch.messages;
      final fingerprint = Object.hashAll(
        messages.map(
          (message) => Object.hash(
            message.messageId,
            message.direction,
            message.messageKind,
            message.deliveryState,
            message.createdAtMillis,
            message.plaintext,
          ),
        ),
      );
      if (_renderedMessageFingerprint != fingerprint) {
        await chatController.setMessages(
          _visibleMessages(messages),
          animated: false,
        );
        if (_disposed || generation != _messageReloadGeneration) return;
        _renderedMessageFingerprint = fingerprint;
      }
      unawaited(_resolveAndApplyMediaPaths(messages, generation));
      _commitReloadState(
        generation,
        batch.integrityFailureCount == 0
            ? null
            : batch.messages.isEmpty
            ? '本机历史消息无法验证'
            : '部分本机历史消息无法验证，其他记录已正常显示',
      );
      unawaited(_markRead(messages, generation));
    } catch (error) {
      _commitReloadState(generation, errorMessage(error));
    }
  }

  Future<void> _markRead(
    List<ChatStoredMessage> messages,
    int generation,
  ) async {
    final callback = onMarkRead;
    if (callback == null || messages.isEmpty || !_appResumed || !isVisible()) {
      return;
    }
    final readThroughMillis = messages
        .map((message) => message.createdAtMillis)
        .reduce((left, right) => left > right ? left : right);
    try {
      await callback(readThroughMillis);
    } catch (_) {
      // 已读写入失败时保留未读数；下次当前页快照刷新会自然重试。
    }
    if (_disposed || generation != _messageReloadGeneration) return;
  }

  void _commitReloadState(int generation, String? nextError) {
    if (_disposed || generation != _messageReloadGeneration) return;
    if (!_loading && _error == nextError) return;
    _loading = false;
    _error = nextError;
    notifyListeners();
  }

  Future<void> _resolveAndApplyMediaPaths(
    List<ChatStoredMessage> messages,
    int generation,
  ) async {
    final resolver = onResolveMediaPaths;
    if (resolver == null) return;
    try {
      final contents = <ChatContent>[];
      for (final message in messages) {
        final content = ChatPayloadCodec.decode(message.plaintext ?? '');
        final attachmentId = content.attachmentId ?? '';
        if (!content.isMedia || attachmentId.isEmpty) continue;
        if (mediaLimits.exceedsForKind(content.kind, content.byteSize ?? 0)) {
          continue;
        }
        if (!_resolvedMediaPaths.containsKey(attachmentId)) {
          contents.add(content);
        }
      }
      if (contents.isEmpty) return;
      final paths = await resolver(contents);
      if (_disposed ||
          generation != _messageReloadGeneration ||
          paths.isEmpty) {
        return;
      }
      _resolvedMediaPaths.addAll(paths);
      await chatController.setMessages(
        _visibleMessages(messages),
        animated: false,
      );
    } catch (_) {
      // 媒体尚未到达时保留占位，不把附件缓存状态误报为正文读取失败。
    }
  }

  Future<void> _syncOnOpen() async {
    await reloadMessages();
    if (_disposed || onSync == null) return;
    final realtimeFuture = _startRealtime();
    await _syncOnly(silent: true);
    final realtimeReady = await realtimeFuture;
    if (!realtimeReady && !_disposed && onSync != null) {
      _schedulePoll(_normalPollInterval);
    }
  }

  Future<bool> _startRealtime() async {
    final starter = onStartRealtime;
    if (!_appResumed || starter == null || _disposed) return false;
    if (_stopRealtime != null || _realtimeConnecting) {
      return _stopRealtime != null;
    }
    _realtimeConnecting = true;
    try {
      final stop = await starter(
        onNotice: reloadMessages,
        onDisconnected: () async {
          if (_appResumed && !_disposed && onSync != null) {
            _schedulePoll(_backoffPollInterval);
          }
        },
      );
      if (_disposed || !_appResumed) {
        await stop?.call();
        return false;
      }
      _stopRealtime = stop;
      if (stop != null) _schedulePoll(_heartbeatPollInterval);
      return stop != null;
    } catch (_) {
      return false;
    } finally {
      _realtimeConnecting = false;
    }
  }

  Future<bool> _syncAndReload({required bool silent}) async {
    final ok = await _syncOnly(silent: silent);
    if (!ok) return false;
    await reloadMessages();
    return true;
  }

  Future<bool> _syncOnly({required bool silent}) async {
    final sync = onSync;
    if (sync == null) {
      if (!silent) showError('当前会话尚未绑定同步链路');
      return false;
    }
    try {
      await sync();
      return true;
    } catch (error) {
      if (!silent) showError(errorMessage(error));
      return false;
    }
  }

  void _schedulePoll(Duration delay) {
    if (!_appResumed || _disposed) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(delay, _runPoll);
  }

  void _pauseSync() {
    _pollTimer?.cancel();
    _pollTimer = null;
    final stop = _stopRealtime;
    _stopRealtime = null;
    if (stop != null) unawaited(stop());
  }

  Future<void> _runPoll() async {
    if (_disposed || !_appResumed || onSync == null) return;
    if (_polling) {
      _schedulePoll(_backoffPollInterval);
      return;
    }
    _polling = true;
    final ok = await _syncAndReload(silent: true);
    _polling = false;
    if (_disposed || !_appResumed || onSync == null) return;
    if (_stopRealtime != null) {
      _schedulePoll(_heartbeatPollInterval);
      return;
    }
    if (ok && await _startRealtime()) return;
    _schedulePoll(ok ? _normalPollInterval : _backoffPollInterval);
  }

  List<Message> _visibleMessages(List<ChatStoredMessage> storedMessages) {
    final messages = <Message>[
      ...storedMessagesToChatMessages(
        storedMessages,
        currentUserId: currentUserId,
        mediaLimits: mediaLimits,
        resolveLocalMediaPath: (content) =>
            _resolvedMediaPaths[content.attachmentId],
      ),
      ..._optimisticMessages.values,
    ];
    messages.sort((left, right) {
      final leftAt = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightAt = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return leftAt.compareTo(rightAt);
    });
    return messages;
  }

  String _nextOptimisticMessageId() {
    _optimisticMessageSequence += 1;
    return 'local:$conversationId:'
        '${DateTime.now().microsecondsSinceEpoch}:$_optimisticMessageSequence';
  }

  Map<String, dynamic> _optimisticMetadata(ChatMessageKind kind) =>
      <String, dynamic>{
        'conversation_id': conversationId,
        'direction': 'outgoing',
        'is_mine': true,
        'message_kind': kind.name,
        'optimistic': true,
      };

  Message _optimisticTextMessage(String text) => Message.text(
    id: _nextOptimisticMessageId(),
    authorId: currentUserId,
    createdAt: DateTime.now().toUtc(),
    text: text,
    metadata: _optimisticMetadata(ChatMessageKind.text),
  );

  Message _optimisticStickerMessage(String packId, String stickerId) =>
      Message.custom(
        id: _nextOptimisticMessageId(),
        authorId: currentUserId,
        createdAt: DateTime.now().toUtc(),
        metadata: <String, dynamic>{
          ..._optimisticMetadata(ChatMessageKind.sticker),
          'pack_id': packId,
          'sticker_id': stickerId,
        },
      );

  Message _optimisticMediaMessage(ChatMediaDraft draft) {
    final id = _nextOptimisticMessageId();
    final createdAt = DateTime.now().toUtc();
    final metadata = <String, dynamic>{
      ..._optimisticMetadata(draft.kind),
      'attachment_id': id,
      'file_name': draft.fileName,
    };
    return switch (draft.kind) {
      ChatMessageKind.image => Message.image(
        id: id,
        authorId: currentUserId,
        createdAt: createdAt,
        source: draft.sourcePath,
        width: draft.width?.toDouble(),
        height: draft.height?.toDouble(),
        size: draft.byteSize,
        metadata: metadata,
      ),
      ChatMessageKind.video => Message.video(
        id: id,
        authorId: currentUserId,
        createdAt: createdAt,
        source: draft.sourcePath,
        name: draft.fileName,
        width: draft.width?.toDouble(),
        height: draft.height?.toDouble(),
        size: draft.byteSize,
        metadata: metadata,
      ),
      ChatMessageKind.audio => Message.audio(
        id: id,
        authorId: currentUserId,
        createdAt: createdAt,
        source: draft.sourcePath,
        duration: Duration(milliseconds: draft.durationMs ?? 0),
        size: draft.byteSize,
        metadata: metadata,
      ),
      ChatMessageKind.file => Message.file(
        id: id,
        authorId: currentUserId,
        createdAt: createdAt,
        source: draft.sourcePath,
        name: draft.fileName,
        size: draft.byteSize,
        mimeType: draft.contentType,
        metadata: metadata,
      ),
      ChatMessageKind.text ||
      ChatMessageKind.sticker => throw StateError('文字和贴纸不能进入媒体乐观气泡'),
    };
  }

  Future<void> _insertOptimisticMessage(Message message) async {
    _optimisticMessages[message.id] = message;
    await chatController.insertMessage(message, animated: false);
    if (!_disposed) notifyListeners();
  }

  Future<void> _discardOptimisticMessages(Iterable<String> messageIds) async {
    var removed = false;
    for (final messageId in messageIds) {
      removed = _optimisticMessages.remove(messageId) != null || removed;
    }
    if (removed && !_disposed) await reloadMessages();
  }

  Future<void> sendText(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty || _disposed) return;
    final sender = onSendText;
    if (sender == null) {
      showError('当前会话尚未绑定发送链路');
      return;
    }
    final optimistic = _optimisticTextMessage(normalized);
    await _insertOptimisticMessage(optimistic);
    try {
      await sender(normalized);
      await _discardOptimisticMessages(<String>[optimistic.id]);
    } catch (error) {
      await _discardOptimisticMessages(<String>[optimistic.id]);
      showError(errorMessage(error));
    }
  }

  Future<void> sendMediaDrafts(Iterable<ChatMediaDraft> drafts) async {
    if (_attachmentBusy || _disposed) return;
    final sender = onSendMedia;
    if (sender == null) {
      showError('当前会话尚未绑定媒体发送链路');
      return;
    }
    final prepared = drafts.toList(growable: false);
    _attachmentBusy = true;
    _error = null;
    notifyListeners();
    final pending = <({ChatMediaDraft draft, Message message})>[];
    for (final draft in prepared) {
      final message = _optimisticMediaMessage(draft);
      pending.add((draft: draft, message: message));
      await _insertOptimisticMessage(message);
    }
    try {
      for (final item in pending) {
        var reconciled = false;
        await sender(
          item.draft,
          onLocalCommitted: () async {
            if (reconciled) return;
            reconciled = true;
            await _discardOptimisticMessages(<String>[item.message.id]);
          },
        );
        if (!reconciled) {
          await _discardOptimisticMessages(<String>[item.message.id]);
        }
      }
    } catch (error) {
      await _discardOptimisticMessages(pending.map((item) => item.message.id));
      showError(errorMessage(error));
    } finally {
      if (!_disposed) {
        _attachmentBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> sendSticker(String packId, String stickerId) async {
    if (_disposed) return;
    final sender = onSendSticker;
    if (sender == null) {
      showError('当前会话尚未绑定发送链路');
      return;
    }
    final optimistic = _optimisticStickerMessage(packId, stickerId);
    await _insertOptimisticMessage(optimistic);
    try {
      await sender(packId, stickerId);
      await _discardOptimisticMessages(<String>[optimistic.id]);
    } catch (error) {
      await _discardOptimisticMessages(<String>[optimistic.id]);
      showError(errorMessage(error));
    }
  }

  Future<ChatDownloadedAttachment?> downloadAttachment(
    String controlPlaintext,
  ) async {
    final downloader = onDownloadAttachment;
    if (downloader == null) {
      showError('当前会话尚未绑定附件下载链路');
      return null;
    }
    try {
      final downloaded = await downloader(controlPlaintext);
      await reloadMessages();
      return downloaded;
    } catch (error) {
      showError(errorMessage(error));
      return null;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _messageReloadGeneration += 1;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _pauseSync();
    chatController.dispose();
    super.dispose();
  }
}

typedef ChatConversationListCoordinateCallback = Future<void> Function();
typedef ChatConversationListRefreshCallback =
    Future<bool> Function(String scope);

/// 会话列表共用的生命周期、单飞协调、待发重试、WSS 订阅与轮询降级控制器。
///
/// 控制器直接持有同一 ChatSdk；产品列表只提供业务数据刷新，不接触具体实时连接入口。
class ChatConversationListController extends ChangeNotifier
    with WidgetsBindingObserver {
  ChatConversationListController({
    required ChatSdk sdk,
    required this.onCoordinate,
    required this.onRefresh,
  }) : _sdk = sdk;

  static const _normalPollInterval = Duration(seconds: 15);
  static const _backoffPollInterval = Duration(seconds: 30);

  final ChatSdk _sdk;
  final ChatConversationListCoordinateCallback onCoordinate;
  final ChatConversationListRefreshCallback onRefresh;
  Timer? _pollTimer;
  Future<void> Function()? _stopRealtime;
  Future<void>? _coordinatorInFlight;
  String? _scope;
  bool _started = false;
  bool _disposed = false;
  bool _visible = false;
  bool _appResumed = false;
  bool _polling = false;
  bool _realtimeConnecting = false;
  bool _realtimeConnected = false;
  int _refreshGeneration = 0;

  bool get isActive => !_disposed && _visible && _appResumed;

  void start({required bool visible}) {
    if (_started || _disposed) return;
    _started = true;
    _visible = visible;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void setVisible(bool visible) {
    if (_disposed || _visible == visible) return;
    _visible = visible;
    if (isActive) {
      requestCoordinate();
    } else {
      _stopSync(clearScope: false);
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    _appResumed = state == AppLifecycleState.resumed;
    if (isActive) {
      requestCoordinate();
    } else {
      _stopSync(clearScope: false);
    }
    notifyListeners();
  }

  void requestCoordinate() {
    if (!isActive || _coordinatorInFlight != null) return;
    late final Future<void> created;
    created = onCoordinate().whenComplete(() {
      if (identical(_coordinatorInFlight, created)) {
        _coordinatorInFlight = null;
      }
    });
    _coordinatorInFlight = created;
    unawaited(created.catchError((_) {}));
  }

  void configureScope(String scope) {
    final normalized = scope.trim();
    if (!isActive || normalized.isEmpty) {
      pause();
      return;
    }
    if (_scope != normalized) {
      _stopSync(clearScope: true);
      _scope = normalized;
    }
    if (_stopRealtime != null) return;
    _schedulePoll(_normalPollInterval);
    unawaited(_startRealtime(normalized));
  }

  /// 本地首屏完成后的首次静默收敛。补发、刷新和实时建连共享同一世代，
  /// 身份或页面状态变化后，旧任务不得重新启动计时器或订阅。
  void synchronizeScope(String scope) {
    final normalized = scope.trim();
    if (!isActive || normalized.isEmpty) {
      pause();
      return;
    }
    if (_scope != normalized) {
      _stopSync(clearScope: true);
      _scope = normalized;
    }
    final generation = ++_refreshGeneration;
    unawaited(_synchronizeAndConnect(normalized, generation));
  }

  Future<void> _synchronizeAndConnect(String scope, int generation) async {
    final ok = await _refresh(scope);
    if (!isActive || _scope != scope || generation != _refreshGeneration) {
      return;
    }
    if (ok && await _startRealtime(scope)) return;
    _schedulePoll(ok ? _normalPollInterval : _backoffPollInterval);
  }

  void pause() => _stopSync(clearScope: true);

  Future<bool> _startRealtime(String scope) async {
    if (!isActive || scope != _scope) return false;
    if (_stopRealtime != null || _realtimeConnecting) {
      return _realtimeConnected;
    }
    _realtimeConnecting = true;
    try {
      // 具体 WSS 入口只在 TataChatSDK 内使用；宿主列表页只接收刷新通知。
      final stop = await _sdk.startRealtimeSync(
        onNotice: () async {
          _realtimeConnected = true;
          _pollTimer?.cancel();
          _pollTimer = null;
          await _refresh(scope);
        },
        onDisconnected: () async {
          _realtimeConnected = false;
          if (isActive && _scope == scope) {
            _schedulePoll(_backoffPollInterval);
          }
        },
        retryOutgoingOnConnect: false,
      );
      if (!isActive || _scope != scope) {
        await stop?.call();
        return false;
      }
      _stopRealtime = stop;
      _realtimeConnected = stop != null;
      if (_realtimeConnected) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
      return _realtimeConnected;
    } catch (_) {
      return false;
    } finally {
      _realtimeConnecting = false;
    }
  }

  Future<bool> _refresh(String scope) async {
    if (!isActive || _scope != scope) return false;
    var outgoingReady = true;
    try {
      await _sdk.retryOutgoing();
    } catch (_) {
      outgoingReady = false;
    }
    try {
      return await onRefresh(scope) && outgoingReady;
    } catch (_) {
      return false;
    }
  }

  void _schedulePoll(Duration delay) {
    if (!isActive || _scope == null) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(delay, _runPoll);
  }

  Future<void> _runPoll() async {
    final scope = _scope;
    if (!isActive || scope == null) return;
    if (_polling) {
      _schedulePoll(_backoffPollInterval);
      return;
    }
    _polling = true;
    final ok = await _refresh(scope);
    _polling = false;
    if (!isActive || _scope != scope) return;
    if (_stopRealtime == null && ok && await _startRealtime(scope)) return;
    if (!_realtimeConnected) {
      _schedulePoll(ok ? _normalPollInterval : _backoffPollInterval);
    }
  }

  void _stopSync({required bool clearScope}) {
    _refreshGeneration += 1;
    _pollTimer?.cancel();
    _pollTimer = null;
    _realtimeConnected = false;
    final stop = _stopRealtime;
    _stopRealtime = null;
    if (clearScope) _scope = null;
    if (stop != null) unawaited(stop());
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _stopSync(clearScope: true);
    super.dispose();
  }
}

typedef ChatGroupSenderBuilder =
    Widget Function(BuildContext context, String userId);

/// Reusable direct/group message viewport, including all message categories.
class ChatMessageListView extends StatelessWidget {
  const ChatMessageListView({
    super.key,
    required this.currentUserId,
    required this.chatController,
    required this.onMessageSend,
    required this.resolveUser,
    required this.composerBuilder,
    required this.onDownloadAttachment,
    required this.onMessagesChanged,
    this.isGroup = false,
    this.loading = false,
    this.error,
    this.groupSenderBuilder,
    this.style = const ChatViewStyle(),
  });

  final String currentUserId;
  final ChatController chatController;
  final Future<void> Function(String text) onMessageSend;
  final Future<User> Function(String userId) resolveUser;
  final Widget Function(BuildContext context) composerBuilder;
  final Future<void> Function(String controlPlaintext) onDownloadAttachment;
  final Future<void> Function() onMessagesChanged;
  final bool isGroup;
  final bool loading;
  final String? error;
  final ChatGroupSenderBuilder? groupSenderBuilder;
  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: style.scale(context, 2),
          child: loading
              ? const LinearProgressIndicator(
                  key: ValueKey('chat-page-progress'),
                )
              : null,
        ),
        SizedBox(
          height: style.scale(context, 36),
          child: error == null
              ? const SizedBox.shrink()
              : Container(
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(
                    horizontal: style.scale(context, 16),
                  ),
                  color: style.error(context).withValues(alpha: 0.08),
                  child: Text(
                    error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: style.error(context),
                      fontSize: style.scale(context, 12),
                    ),
                  ),
                ),
        ),
        Expanded(
          child: Chat(
            currentUserId: currentUserId,
            chatController: chatController,
            onMessageSend: (text) => unawaited(onMessageSend(text)),
            backgroundColor: style.background(context),
            builders: Builders(
              textMessageBuilder: isGroup ? _buildGroupTextMessage : null,
              imageMessageBuilder: _buildImageMessage,
              videoMessageBuilder: _buildVideoMessage,
              fileMessageBuilder: _buildFileMessage,
              audioMessageBuilder: _buildAudioMessage,
              customMessageBuilder: _buildStickerMessage,
              composerBuilder: composerBuilder,
              emptyChatListBuilder: (context) =>
                  !shouldShowChatEmptyState(loading: loading, error: error)
                  ? const SizedBox.shrink()
                  : const Padding(
                      padding: EdgeInsets.only(bottom: 120),
                      child: Center(child: Text('暂无消息')),
                    ),
            ),
            resolveUser: resolveUser,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupTextMessage(
    BuildContext context,
    TextMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final showSender = !isSentByMe && (groupStatus?.isFirst ?? true);
    return SimpleTextMessage(
      message: message,
      index: index,
      topWidget: showSender ? _sender(context, message.authorId) : null,
    );
  }

  Widget _buildImageMessage(
    BuildContext context,
    ImageMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.62;
    final hasFile = message.source.isNotEmpty;
    final control =
        message.metadata?['attachment_control_plaintext']?.toString() ?? '';
    final ratio = _mediaAspectRatio(message.width, message.height);
    final cacheWidth = (maxWidth * MediaQuery.devicePixelRatioOf(context))
        .round();
    final Widget content = hasFile
        ? GestureDetector(
            onTap: () => _openImageViewer(context, message),
            child: Image.file(
              File(message.source),
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              errorBuilder: (_, _, _) => _mediaPlaceholder(
                context,
                icon: Icons.broken_image_rounded,
                label: '图片无法显示',
              ),
            ),
          )
        : GestureDetector(
            onTap: control.isEmpty
                ? null
                : () => unawaited(_downloadAndReload(control)),
            child: _blurhashOrPlaceholder(
              context,
              message.blurhash,
              '接收中…',
              key: const ValueKey('chat-image-blurhash'),
            ),
          );
    return _mediaAligned(
      context,
      isSentByMe,
      ClipRRect(
        borderRadius: BorderRadius.circular(style.scale(context, 14)),
        child: SizedBox(
          width: maxWidth,
          child: AspectRatio(aspectRatio: ratio, child: content),
        ),
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  Widget _buildVideoMessage(
    BuildContext context,
    VideoMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.62;
    final hasFile = message.source.isNotEmpty;
    final control =
        message.metadata?['attachment_control_plaintext']?.toString() ?? '';
    final hash = message.metadata?['blurhash']?.toString();
    return _mediaAligned(
      context,
      isSentByMe,
      GestureDetector(
        onTap: hasFile
            ? () => _openVideoPlayer(context, message)
            : control.isEmpty
            ? null
            : () => unawaited(_downloadAndReload(control)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(style.scale(context, 14)),
          child: SizedBox(
            width: maxWidth,
            child: AspectRatio(
              aspectRatio: _mediaAspectRatio(message.width, message.height),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hash != null && hash.isNotEmpty)
                    BlurHash(
                      key: const ValueKey('chat-video-blurhash'),
                      hash: hash,
                      imageFit: BoxFit.cover,
                    )
                  else
                    Container(color: style.surface(context)),
                  Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: style.scale(context, 44),
                      color: Colors.white70,
                    ),
                  ),
                  if (!hasFile)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: style.scale(context, 8),
                      child: Text(
                        '接收中…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: style.scale(context, 12),
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  Widget _buildFileMessage(
    BuildContext context,
    FileMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final control =
        message.metadata?['attachment_control_plaintext']?.toString() ?? '';
    return _mediaAligned(
      context,
      isSentByMe,
      GestureDetector(
        onTap: control.isEmpty
            ? null
            : () => unawaited(_downloadAndReload(control)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.7,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: style.scale(context, 14),
            vertical: style.scale(context, 12),
          ),
          decoration: BoxDecoration(
            color: style.surface(context),
            borderRadius: BorderRadius.circular(style.scale(context, 14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_rounded,
                size: style.scale(context, 28),
                color: style.textSecondary(context),
              ),
              SizedBox(width: style.scale(context, 10)),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: style.scale(context, 14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (message.size != null)
                      Text(
                        formatChatByteSize(message.size!),
                        style: TextStyle(
                          fontSize: style.scale(context, 11),
                          color: style.textSecondary(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  Widget _buildAudioMessage(
    BuildContext context,
    AudioMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final control =
        message.metadata?['attachment_control_plaintext']?.toString() ?? '';
    return _mediaAligned(
      context,
      isSentByMe,
      VoiceMessagePlayer(
        message: message,
        isSentByMe: isSentByMe,
        onRequestDownload: () => _downloadAndReload(control),
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  Widget _buildStickerMessage(
    BuildContext context,
    CustomMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final packId = message.metadata?['pack_id']?.toString() ?? '';
    final stickerId = message.metadata?['sticker_id']?.toString() ?? '';
    final known = StickerPack.isKnown(packId: packId, stickerId: stickerId);
    final content = known
        ? Image.asset(
            StickerPack.assetPath(stickerId),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _stickerFallback(context),
          )
        : _stickerFallback(context);
    return _mediaAligned(
      context,
      isSentByMe,
      SizedBox(
        key: ValueKey('chat-sticker-message-${message.id}'),
        width: 128,
        height: 128,
        child: content,
      ),
      senderId: message.authorId,
      groupStatus: groupStatus,
    );
  }

  Widget _mediaAligned(
    BuildContext context,
    bool isSentByMe,
    Widget child, {
    String? senderId,
    MessageGroupStatus? groupStatus,
  }) {
    final aligned = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: style.scale(context, 12),
        vertical: style.scale(context, 4),
      ),
      child: Align(
        alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
    final showSender =
        isGroup &&
        !isSentByMe &&
        senderId != null &&
        (groupStatus?.isFirst ?? true);
    if (!showSender) return aligned;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: style.scale(context, 16),
            top: style.scale(context, 4),
          ),
          child: _sender(context, senderId),
        ),
        aligned,
      ],
    );
  }

  Widget _sender(BuildContext context, String userId) {
    return groupSenderBuilder?.call(context, userId) ??
        Text(
          userId,
          style: TextStyle(
            fontSize: style.scale(context, 11),
            color: style.textSecondary(context),
          ),
        );
  }

  Widget _blurhashOrPlaceholder(
    BuildContext context,
    String? hash,
    String label, {
    Key? key,
  }) {
    if (hash != null && hash.isNotEmpty) {
      return Stack(
        key: key,
        fit: StackFit.expand,
        children: [
          BlurHash(hash: hash, imageFit: BoxFit.cover),
          Positioned(
            left: 0,
            right: 0,
            bottom: style.scale(context, 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: style.scale(context, 12),
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }
    return _mediaPlaceholder(context, icon: Icons.image_rounded, label: label);
  }

  Widget _mediaPlaceholder(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      color: style.surface(context),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: style.textSecondary(context),
            size: style.scale(context, 28),
          ),
          SizedBox(height: style.scale(context, 6)),
          Text(
            label,
            style: TextStyle(
              fontSize: style.scale(context, 12),
              color: style.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stickerFallback(BuildContext context) => _mediaPlaceholder(
    context,
    icon: Icons.emoji_emotions_outlined,
    label: '[贴纸]',
  );

  Future<void> _downloadAndReload(String control) async {
    if (control.isEmpty) return;
    await onDownloadAttachment(control);
    await onMessagesChanged();
  }

  void _openImageViewer(BuildContext context, ImageMessage message) {
    final fileName = message.metadata?['file_name']?.toString() ?? '图片';
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ImageViewerPage(filePath: message.source, fileName: fileName),
      ),
    );
  }

  void _openVideoPlayer(BuildContext context, VideoMessage message) {
    final fileName =
        message.metadata?['file_name']?.toString() ?? message.name ?? '视频';
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            VideoPlayerPage(filePath: message.source, fileName: fileName),
      ),
    );
  }
}

bool shouldShowChatEmptyState({
  required bool loading,
  required String? error,
}) => !loading && error == null;

double _mediaAspectRatio(double? width, double? height) {
  if (width != null && height != null && width > 0 && height > 0) {
    return (width / height).clamp(0.6, 1.9);
  }
  return 1;
}

String formatChatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
