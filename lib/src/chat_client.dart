import 'runtime/chat_runtime.dart';
import 'storage/chat_store.dart';

/// 唯一公开生命周期入口；直接使用同一运行实例，不另建身份、权限或传输通道。
class ChatSdk extends ChatRuntimeCore {
  ChatSdk({
    required super.host,
    super.store,
    super.preferences,
    super.stateStoreFactory,
    super.cryptoFactory,
    super.documentsDirectoryProvider,
    super.transportFactory,
    super.receiveOnly,
  });

  Future<void>? _starting;
  Future<void>? _stopping;
  bool _running = false;
  bool _stopped = false;

  /// 表示同步生命周期已启动，不表示网络始终在线；断网由原有运行时负责重连。
  bool get isRunning => _running && !_stopped;

  /// 所有完整页面共用当前 SDK 实例持有的密文仓库。
  ChatStore get store => chatStore;

  static String directConversationId(String leftUserId, String rightUserId) =>
      ChatRuntimeCore.directConversationId(leftUserId, rightUserId);

  Future<void> start({
    Future<void> Function()? onNotice,
    Future<void> Function()? onDisconnected,
  }) async {
    if (_stopped) throw StateError('聊天实例已停止，请创建新实例');
    if (_running) return;
    final active = _starting;
    if (active != null) return active;
    final pending = _start(onNotice, onDisconnected);
    _starting = pending;
    try {
      await pending;
    } finally {
      if (identical(_starting, pending)) _starting = null;
    }
  }

  Future<void> _start(
    Future<void> Function()? onNotice,
    Future<void> Function()? onDisconnected,
  ) async {
    await startRealtimeSync(
      onNotice: onNotice ?? () async {},
      onDisconnected: onDisconnected,
    );
    if (_stopped) throw StateError('聊天实例已停止');
    _running = true;
  }

  /// 停止是实例终态：先封住新操作，再收口初始化、实时资源和 MLS 上下文，不删除历史。
  Future<void> stop() {
    _stopped = true;
    _running = false;
    final active = _stopping;
    if (active != null) return active;
    final starting = _starting;
    final pending = Future.wait<void>([
      if (starting != null)
        starting.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      super.close(),
    ]).then<void>((_) {});
    _stopping = pending;
    // 关闭失败仍允许重试清理，但绝不允许重启一个已停止的实例。
    pending.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {
        if (identical(_stopping, pending)) _stopping = null;
      },
    );
    return pending;
  }

  @override
  Future<void> close() => stop();
}
