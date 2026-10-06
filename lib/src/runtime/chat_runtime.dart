import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../attachment/vault.dart';
import '../core/chat_content.dart';
import '../core/chat_message.dart';
import '../core/chat_scope.dart';
import '../group/model.dart';
import '../mls/mls_attachment.dart';
import '../mls/mls_boundary.dart';
import '../mls/mls_contact_sync.dart';
import '../mls/mls_group_boundary.dart';
import '../mls/mls_native.dart';
import '../mls/mls_state_store.dart';
import '../protocol/message.dart';
import '../storage/chat_store.dart';
import '../storage/models.dart';
import '../storage/records.dart';
import '../storage/system_protected_storage.dart';
import '../transport/chat_server_connection.dart';
import '../transport/chat_service_transport.dart';
import '../transport/chat_transport.dart';
import 'direct_flow.dart';
import 'group_flow.dart';
import 'media_limit_policy.dart';

typedef MlsStateStoreFactory = Future<MlsStateStore> Function(String userId);

enum ChatPersistentWipeState { none, pending, complete }

/// 原附件受众失效是本次动作终态，不进入网络重试或重新加密。
class _AttachmentAudienceChanged implements Exception {
  const _AttachmentAudienceChanged();
}

/// TataChatSDK 使用的中性宿主账户快照。
class ChatRuntimeAccount {
  const ChatRuntimeAccount({
    required this.hostIndex,
    required this.bindingScope,
    required this.userId,
    required this.bindingRevision,
    required this.accountId,
    required this.displayName,
  });

  final int hostIndex;
  final String bindingScope;
  final String userId;
  final int bindingRevision;
  final String accountId;
  final String displayName;
}

/// 宿主只注入公开身份、权益、平台推送和短期 TataChatServer 凭证。
abstract interface class ChatRuntimeHost {
  ChatPushBridge get push;
  ChatMediaLimitPolicy get mediaLimits;

  Future<bool> canSend(String userId);

  Future<ChatRuntimeAccount?> currentAccount({String? expectedAccountId});

  Future<TataChatServerAccess> requestTataChatServerAccess({
    required ChatRuntimeAccount account,
    required ChatDevice identity,
  });

  Future<void> invalidateAccount(String accountId);
}

class _RetryableAsyncDisposer {
  _RetryableAsyncDisposer(this._operation);

  final Future<void> Function() _operation;
  Future<void>? _running;

  Future<void> dispose() {
    final running = _running;
    if (running != null) return running;

    late final Future<void> source;
    try {
      source = _operation();
    } catch (error, stackTrace) {
      return Future<void>.error(error, stackTrace);
    }
    late final Future<void> task;
    task = source.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_running, task)) _running = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    _running = task;
    return task;
  }
}

/// 一次实时同步持有的全部可关闭资源。
///
/// 初始化尚未完成时收到 AppLock 擦除也必须等待初始化收口；后续才出现的 socket 或
/// subscription 会被同一 disposer 接管。每个子资源独立记忆成功、独立重试失败，
/// 避免某一 cancel 失败后重复打开或遗漏其它资源。
class _ChatRealtimeSession {
  _ChatRealtimeSession({this.accountId, this.ownerUserId});

  final String? accountId;
  final String? ownerUserId;
  final Completer<void> _initializationDone = Completer<void>();
  _RetryableAsyncDisposer? _socketDisposer;
  _RetryableAsyncDisposer? _wakeSubscriptionDisposer;
  _RetryableAsyncDisposer? _tokenSubscriptionDisposer;
  final Set<Future<void>> _callbacks = <Future<void>>{};
  Future<void> _callbackTail = Future<void>.value();
  bool _acceptingCallbacks = true;
  late final _RetryableAsyncDisposer _disposer = _RetryableAsyncDisposer(
    _dispose,
  );

  void attachSocket(Future<void> Function() stopSocket) {
    if (_socketDisposer != null) {
      throw StateError('Chat 实时 socket 已登记');
    }
    _socketDisposer = _RetryableAsyncDisposer(stopSocket);
  }

  void attachWakeSubscription(Future<void> Function() cancel) {
    if (_wakeSubscriptionDisposer != null) {
      throw StateError('Chat 唤醒订阅已登记');
    }
    _wakeSubscriptionDisposer = _RetryableAsyncDisposer(cancel);
  }

  void attachTokenSubscription(Future<void> Function() cancel) {
    if (_tokenSubscriptionDisposer != null) {
      throw StateError('Chat Token 订阅已登记');
    }
    _tokenSubscriptionDisposer = _RetryableAsyncDisposer(cancel);
  }

  void markInitializationDone() {
    if (!_initializationDone.isCompleted) _initializationDone.complete();
  }

  bool belongsToAccount(String value) => accountId == value;

  void ensureOpen() {
    if (!_acceptingCallbacks) {
      throw StateError('Chat 实时会话已停止接收新回调');
    }
  }

  Future<void> runCallback(Future<void> Function() operation) {
    if (!_acceptingCallbacks) return Future<void>.value();
    // WebSocket 可能在上一个 callback 尚未完成时继续推送 Welcome/Application；
    // MLS ratchet 必须严格按到达顺序推进，因此所有实时来源共用一条串行尾链。
    final previous = _callbackTail;
    final running = previous.then<void>(
      (_) => operation(),
      onError: (Object _, StackTrace _) => operation(),
    );
    _callbacks.add(running);
    _callbackTail = running.then<void>((_) {}, onError: (_, _) {});
    return running.whenComplete(() => _callbacks.remove(running));
  }

  Future<void> dispose() {
    // 必须在任何 await 前同步拒绝 transport/stream 新回调。
    _acceptingCallbacks = false;
    return _disposer.dispose();
  }

  Future<void> _dispose() async {
    await _initializationDone.future;
    final failures = <String>[];
    await Future.wait<void>(<Future<void>>[
      if (_wakeSubscriptionDisposer != null)
        _captureFailure(
          '取消 Chat 唤醒订阅',
          _wakeSubscriptionDisposer!.dispose,
          failures,
        ),
      if (_tokenSubscriptionDisposer != null)
        _captureFailure(
          '取消 Chat Token 订阅',
          _tokenSubscriptionDisposer!.dispose,
          failures,
        ),
      if (_socketDisposer != null)
        _captureFailure(
          '关闭 Chat 实时 socket',
          _socketDisposer!.dispose,
          failures,
        ),
    ]);
    while (_callbacks.isNotEmpty) {
      await Future.wait<void>(_callbacks.toList(growable: false));
    }
    if (failures.isNotEmpty) throw StateError(failures.join('\n'));
  }

  static Future<void> _captureFailure(
    String label,
    Future<void> Function() action,
    List<String> failures,
  ) async {
    try {
      await action();
    } catch (error) {
      failures.add('$label：$error');
    }
  }
}

class _ChatRealtimeListener {
  const _ChatRealtimeListener({
    required this.onNotice,
    required this.onDisconnected,
  });

  final Future<void> Function() onNotice;
  final Future<void> Function()? onDisconnected;
}

/// 一个账户在当前 isolate 内唯一的前台实时通道。聊天 Tab、私聊页和群聊页只
/// 增减监听者，不再各自创建 WebSocket；物理断线由本通道退避重连。
class _ChatRealtimeHub {
  _ChatRealtimeHub(this.account);

  final ChatRuntimeAccount account;
  final Set<_ChatRealtimeListener> listeners = <_ChatRealtimeListener>{};
  Future<bool>? connecting;
  Future<void> Function()? stopPhysical;
  ChatServiceTransport? transport;
  Timer? reconnectTimer;
  int reconnectAttempt = 0;
  bool retryOutgoingOnConnect = false;
  bool closed = false;
}

class _ChatRealtimePhysical {
  const _ChatRealtimePhysical({required this.stop, required this.transport});

  final Future<void> Function() stop;
  final ChatServiceTransport transport;
}

/// FlutterFire Android 后台消息运行在独立 Dart isolate，静态集合无法跨
/// isolate 阻止擦除后晚写。因此用 Documents 根目录直属 marker + lease
/// 双检协议协调：后台任务全程持有独占创建的 lease，擦除先落盘
/// marker，再等待当前进程的全部 lease 消失。
class _ChatCrossIsolateCoordinator {
  static const String _pendingMarkerName = '.tatachat_sdk_data_wipe.pending';
  static const String _pendingMarkerPayload = 'pending\n';
  static const String _completeMarkerName = '.tatachat_sdk_data_wipe.complete';
  static const String _completeMarkerPayload = 'complete\n';
  static const String _leasePrefix = '.tatachat_sdk_chat_lease_';
  static const String _leaseSuffix = '.lease';
  static const String _userMutationLeasePrefix = '.tatachat_sdk_chat_user_';
  static const String _userMutationLeaseSuffix = '.mutation_lease';
  static const String _userMutationStaleSuffix = '.stale';
  static const String _startupBarrierName =
      '.tatachat_sdk_chat_startup.barrier';
  static const Duration _leaseDrainTimeout = Duration(seconds: 5);
  static const Duration _leasePollInterval = Duration(milliseconds: 20);
  static const Duration _leaseStaleAfter = Duration(seconds: 30);
  static const Duration _leaseHeartbeatInterval = Duration(seconds: 3);
  static const Duration _userMutationAcquireTimeout = Duration(seconds: 8);
  static const Duration _userMutationStaleAfter = Duration(seconds: 30);
  static const Duration _userMutationHeartbeatInterval = Duration(seconds: 3);
  static final String _userMutationProcessGeneration = _newNonce();
  static final String _backgroundProcessGeneration = _newNonce();

  static String get _currentLeasePrefix => '$_leasePrefix${pid}_';

  static Future<_ChatUserMutationLease> acquireUserMutationLease(
    Directory documentsRoot,
    String userId,
  ) async {
    if (userId.isEmpty) throw StateError('Chat user ID 文件协调键不能为空');
    await _throwIfCurrentProcessWipeRequested(documentsRoot);
    final digest = crypto_hash.sha256.convert(utf8.encode(userId)).toString();
    final leaseFile = _directFile(
      documentsRoot,
      '$_userMutationLeasePrefix$digest$_userMutationLeaseSuffix',
    );
    final deadline = DateTime.now().add(_userMutationAcquireTimeout);
    while (true) {
      final nonce = _newNonce();
      try {
        await leaseFile.create(exclusive: true);
        final owner = _ChatUserLeaseOwner(
          processId: pid,
          processGeneration: _userMutationProcessGeneration,
          nonce: nonce,
        );
        try {
          await leaseFile.writeAsString(owner.encode(), flush: true);
          await _throwIfCurrentProcessWipeRequested(documentsRoot);
          return _ChatUserMutationLease(
            file: leaseFile,
            owner: owner,
            heartbeatInterval: _userMutationHeartbeatInterval,
          );
        } catch (_) {
          await _deleteOwnedUserLeaseFile(leaseFile, owner);
          rethrow;
        }
      } on FileSystemException {
        final type = await FileSystemEntity.type(
          leaseFile.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.notFound) {
          rethrow;
        }
        if (type != FileSystemEntityType.file) {
          throw StateError('Chat user ID 文件协调 lease 类型异常');
        }
        if (await _reapExpiredUserMutationLease(leaseFile)) {
          continue;
        }
        if (!DateTime.now().isBefore(deadline)) {
          throw StateError('同一 user ID 的 Chat 文件操作持续占用，请重试');
        }
        await Future<void>.delayed(_leasePollInterval);
      }
    }
  }

  static Future<Directory> resolveDocumentsRoot(
    Future<Directory> Function() provider,
  ) async {
    final root = (await provider()).absolute;
    if (root.path == root.parent.path) {
      throw StateError('Chat 跨 isolate 协调目录不能是文件系统根目录');
    }
    var type = await FileSystemEntity.type(root.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await root.create(recursive: true);
      type = await FileSystemEntity.type(root.path, followLinks: false);
    }
    if (type != FileSystemEntityType.directory) {
      throw StateError('Chat 跨 isolate 协调目录不是真实目录');
    }
    return root;
  }

  static Future<_ChatCrossIsolateLease> acquireBackgroundLease(
    Directory documentsRoot,
  ) async {
    final deadline = DateTime.now().add(_leaseDrainTimeout);
    while (true) {
      await _waitForStartupBarrier(documentsRoot, deadline: deadline);
      await _removeArtifactsFromOtherProcesses(documentsRoot);
      await _throwIfCurrentProcessWipeRequested(documentsRoot);

      final nonce = _newNonce();
      final leaseFile = _directFile(
        documentsRoot,
        '$_currentLeasePrefix$nonce$_leaseSuffix',
      );
      final owner = _ChatUserLeaseOwner(
        processId: pid,
        processGeneration: _backgroundProcessGeneration,
        nonce: nonce,
      );
      try {
        await leaseFile.create(exclusive: true);
        await leaseFile.writeAsString(owner.encode(), flush: true);
        // 二次检查封住“首检后、lease 创建前”的 startup/wipe 竞态窗口。
        if (await _hasStartupBarrier(documentsRoot)) {
          await _deleteOwnedLeaseFile(leaseFile, owner);
          if (!DateTime.now().isBefore(deadline)) {
            throw StateError('Chat 启动预检持续占用，后台任务拒绝进入');
          }
          continue;
        }
        await _throwIfCurrentProcessWipeRequested(documentsRoot);
        return _ChatCrossIsolateLease(
          file: leaseFile,
          owner: owner,
          heartbeatInterval: _leaseHeartbeatInterval,
        );
      } catch (_) {
        await _deleteOwnedLeaseFile(leaseFile, owner, allowMissing: true);
        rethrow;
      }
    }
  }

  static Future<void> ensureWipePending(Directory documentsRoot) async {
    await _removeArtifactsFromOtherProcesses(
      documentsRoot,
      removeStagedComplete: true,
    );
    final marker = _directFile(documentsRoot, _pendingMarkerName);
    final type = await FileSystemEntity.type(marker.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      try {
        await marker.create(exclusive: true);
      } on FileSystemException {
        // 另一个当前进程擦除调用可能已经创建，下面按真实类型验真。
      }
    }
    if (await FileSystemEntity.type(marker.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('本机数据擦除 pending marker 不是真实文件');
    }
    // 文件存在就是 fail-closed pending 状态；固定载荷 + flush 让目录项
    // 与 inode 在平台存储清理前尽快落盘，崩溃后仍可无鉴权恢复。
    final handle = await marker.open(mode: FileMode.write);
    try {
      await handle.writeString(_pendingMarkerPayload);
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  static Future<void> drainBackgroundLeases(Directory documentsRoot) async {
    final deadline = DateTime.now().add(_leaseDrainTimeout);
    while (await _hasCurrentProcessLease(documentsRoot)) {
      if (!DateTime.now().isBefore(deadline)) {
        throw StateError('Chat 后台 isolate 未在有界时间内收口');
      }
      await Future<void>.delayed(_leasePollInterval);
    }
  }

  static Future<void> _drainAllBackgroundLeases(Directory documentsRoot) async {
    final deadline = DateTime.now().add(_leaseDrainTimeout);
    while (await _hasLiveBackgroundLease(documentsRoot)) {
      if (!DateTime.now().isBefore(deadline)) {
        throw StateError('Chat 后台 isolate 未在启动预检前有界收口');
      }
      await Future<void>.delayed(_leasePollInterval);
    }
  }

  static Future<bool> _hasLiveBackgroundLease(Directory documentsRoot) async {
    await for (final entity in documentsRoot.list(followLinks: false)) {
      final name = _basename(entity.path);
      if (!name.startsWith(_leasePrefix) || !name.endsWith(_leaseSuffix)) {
        continue;
      }
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file) {
        throw StateError('Chat 后台 lease 类型异常');
      }
      if (!await _reapExpiredOwnedLease(
        File(entity.path),
        allowSameProcess: false,
      )) {
        return true;
      }
    }
    return false;
  }

  static Future<void> beginWipe(Directory documentsRoot) async {
    await ensureWipePending(documentsRoot);
    await drainBackgroundLeases(documentsRoot);
  }

  static Future<void> resetForTest(
    Future<Directory> Function() provider,
  ) async {
    final root = await resolveDocumentsRoot(provider);
    await for (final entity in root.list(followLinks: false)) {
      final name = _basename(entity.path);
      if (name == _pendingMarkerName ||
          name == _completeMarkerName ||
          name == _startupBarrierName ||
          name.startsWith('.$_completeMarkerName.') ||
          (name.startsWith(_leasePrefix) && name.endsWith(_leaseSuffix)) ||
          (name.startsWith(_userMutationLeasePrefix) &&
              (name.endsWith(_userMutationLeaseSuffix) ||
                  name.endsWith(_userMutationStaleSuffix)))) {
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.file ||
            type == FileSystemEntityType.link) {
          try {
            await entity.delete();
          } on FileSystemException {
            // 并发 finally 已经删除即等价于 reset 成功。
          }
        }
      }
    }
  }

  /// 启动预检持有 Documents 直属 barrier：新后台任务在建 lease 前后双检，已有
  /// 后台任务必须先收口；只有确认无生产者后才清上一进程 user ID artifact。
  static Future<T> runStartupPreflight<T>(
    Directory documentsRoot,
    Future<T> Function() operation,
  ) async {
    final barrier = await _acquireStartupBarrier(documentsRoot);
    try {
      await _drainAllBackgroundLeases(documentsRoot);
      await _clearUserMutationLeasesWhileStartupBarrierHeld(documentsRoot);
      return await operation();
    } finally {
      await barrier.release();
    }
  }

  static Future<void> _clearUserMutationLeasesWhileStartupBarrierHeld(
    Directory documentsRoot,
  ) async {
    final activePattern = RegExp(
      '^${RegExp.escape(_userMutationLeasePrefix)}[0-9a-f]{64}'
      '${RegExp.escape(_userMutationLeaseSuffix)}\$',
    );
    final stalePattern = RegExp(
      '^${RegExp.escape(_userMutationLeasePrefix)}[0-9a-f]{64}'
      '${RegExp.escape(_userMutationLeaseSuffix)}\\.[0-9]+\\.[0-9a-f]+'
      '${RegExp.escape(_userMutationStaleSuffix)}\$',
    );
    await for (final entity in documentsRoot.list(followLinks: false)) {
      final name = _basename(entity.path);
      if (!activePattern.hasMatch(name) && !stalePattern.hasMatch(name)) {
        continue;
      }
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.link) {
        throw StateError('Chat 启动预检发现异常 user ID lease 类型');
      }
      if (type == FileSystemEntityType.file && activePattern.hasMatch(name)) {
        final owner = await _readUserLeaseOwner(File(entity.path));
        if (owner == null) {
          throw StateError('Chat 启动预检发现损坏的 user ID lease owner');
        }
        if (owner.processGeneration == _userMutationProcessGeneration) {
          throw StateError('Chat 启动预检发现当前进程仍持有 user ID lease');
        }
        // 两端产品都没有承载 Chat writer 的第二 OS 进程：Android 未声明
        // android:process，iOS 也没有运行本协调器的 App Extension。main 又在注册
        // 后台入口和构造 ChatRuntimeCore 前执行本预检，因此不同 PID，或 PID 被系统复用但
        // generation 不同的合法 lease，只可能属于已经退出的上一应用进程。这里按 owner
        // 二次验真后原子退役，不能复用运行态“30 秒判旧”规则把覆盖安装锁死在启动页。
        await _retireStartupOrphanUserMutationLease(File(entity.path), owner);
        continue;
      }
      await entity.delete();
    }
  }

  static Future<bool> _hasStartupBarrier(Directory documentsRoot) async {
    final barrier = _directFile(documentsRoot, _startupBarrierName);
    final type = await FileSystemEntity.type(barrier.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return false;
    if (type != FileSystemEntityType.file) {
      throw StateError('Chat 启动 barrier 类型异常');
    }
    return true;
  }

  static Future<void> _waitForStartupBarrier(
    Directory documentsRoot, {
    required DateTime deadline,
  }) async {
    while (await _hasStartupBarrier(documentsRoot)) {
      if (!DateTime.now().isBefore(deadline)) {
        throw StateError('Chat 启动预检持续占用');
      }
      await Future<void>.delayed(_leasePollInterval);
    }
  }

  static Future<_ChatCrossIsolateLease> _acquireStartupBarrier(
    Directory documentsRoot,
  ) async {
    final file = _directFile(documentsRoot, _startupBarrierName);
    final deadline = DateTime.now().add(_leaseDrainTimeout);
    while (true) {
      final owner = _ChatUserLeaseOwner(
        processId: pid,
        processGeneration: _backgroundProcessGeneration,
        nonce: _newNonce(),
      );
      try {
        await file.create(exclusive: true);
        await file.writeAsString(owner.encode(), flush: true);
        return _ChatCrossIsolateLease(
          file: file,
          owner: owner,
          heartbeatInterval: _leaseHeartbeatInterval,
        );
      } on FileSystemException {
        if (await _reapExpiredOwnedLease(file, allowSameProcess: false)) {
          continue;
        }
        if (!DateTime.now().isBefore(deadline)) {
          throw StateError('Chat 启动 barrier 被其它预检持续占用');
        }
        await Future<void>.delayed(_leasePollInterval);
      }
    }
  }

  static Future<void> _throwIfCurrentProcessWipeRequested(
    Directory documentsRoot,
  ) async {
    for (final name in <String>[_pendingMarkerName, _completeMarkerName]) {
      final marker = _directFile(documentsRoot, name);
      final type = await FileSystemEntity.type(marker.path, followLinks: false);
      if (type != FileSystemEntityType.notFound) {
        throw StateError('Chat 已进入跨 isolate 擦除终态');
      }
    }
  }

  static Future<ChatPersistentWipeState> readPersistentWipeState(
    Directory documentsRoot,
  ) async {
    final pending = _directFile(documentsRoot, _pendingMarkerName);
    final complete = _directFile(documentsRoot, _completeMarkerName);
    final completeType = await FileSystemEntity.type(
      complete.path,
      followLinks: false,
    );
    if (completeType == FileSystemEntityType.file) {
      try {
        if (await complete.readAsString() == _completeMarkerPayload) {
          return ChatPersistentWipeState.complete;
        }
      } catch (_) {
        return ChatPersistentWipeState.pending;
      }
    } else if (completeType != FileSystemEntityType.notFound) {
      return ChatPersistentWipeState.pending;
    }
    final pendingType = await FileSystemEntity.type(
      pending.path,
      followLinks: false,
    );
    return pendingType == FileSystemEntityType.notFound
        ? ChatPersistentWipeState.none
        : ChatPersistentWipeState.pending;
  }

  static Future<void> markWipeComplete(Directory documentsRoot) async {
    final state = await readPersistentWipeState(documentsRoot);
    if (state == ChatPersistentWipeState.none) {
      throw StateError('缺少 pending marker，禁止标记数据擦除完成');
    }
    if (state == ChatPersistentWipeState.complete) return;

    final complete = _directFile(documentsRoot, _completeMarkerName);
    final nonce = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final staged = _directFile(
      documentsRoot,
      '.$_completeMarkerName.$pid.$nonce',
    );
    try {
      await staged.create(exclusive: true);
      final handle = await staged.open(mode: FileMode.write);
      try {
        await handle.writeString(_completeMarkerPayload);
        await handle.flush();
      } finally {
        await handle.close();
      }
      if (await FileSystemEntity.type(complete.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('数据擦除 complete marker 目标已被占用');
      }
      await staged.rename(complete.path);
    } finally {
      if (await FileSystemEntity.type(staged.path, followLinks: false) ==
          FileSystemEntityType.file) {
        await staged.delete();
      }
    }
  }

  static Future<void> clearCompletedWipe(Directory documentsRoot) async {
    if (await readPersistentWipeState(documentsRoot) !=
        ChatPersistentWipeState.complete) {
      throw StateError('只有已完整擦除的 marker 才允许清理');
    }
    if (await _hasCurrentProcessLease(documentsRoot)) {
      throw StateError('Chat 当前进程仍有未收口 lease，禁止清理擦除门闩');
    }
    final complete = _directFile(documentsRoot, _completeMarkerName);
    final pending = _directFile(documentsRoot, _pendingMarkerName);
    // 先删 complete：中途崩溃会留 pending 并重试擦除，不会误放行。
    await complete.delete();
    if (await FileSystemEntity.type(pending.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('数据擦除 pending marker 类型异常');
    }
    await pending.delete();
    await _removeArtifactsFromOtherProcesses(
      documentsRoot,
      removeStagedComplete: true,
    );
  }

  static Future<bool> _hasCurrentProcessLease(Directory documentsRoot) async {
    await for (final entity in documentsRoot.list(followLinks: false)) {
      final name = _basename(entity.path);
      if (name.startsWith(_leasePrefix) && name.endsWith(_leaseSuffix)) {
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type != FileSystemEntityType.file) return true;
        if (!await _reapExpiredOwnedLease(
          File(entity.path),
          allowSameProcess: false,
        )) {
          return true;
        }
      }
      if (name.startsWith(_userMutationLeasePrefix) &&
          name.endsWith(_userMutationLeaseSuffix)) {
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type != FileSystemEntityType.file) return true;
        if (!await _reapExpiredUserMutationLease(File(entity.path))) {
          return true;
        }
      }
    }
    return false;
  }

  static Future<void> _removeArtifactsFromOtherProcesses(
    Directory documentsRoot, {
    bool removeStagedComplete = false,
  }) async {
    await for (final entity in documentsRoot.list(followLinks: false)) {
      final name = _basename(entity.path);
      final isProtocolArtifact =
          (name.startsWith(_leasePrefix) && name.endsWith(_leaseSuffix)) ||
          (removeStagedComplete && name.startsWith('.$_completeMarkerName.'));
      final belongsToCurrentProcess = name.startsWith(_currentLeasePrefix);
      if (!isProtocolArtifact || belongsToCurrentProcess) continue;
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (name.startsWith(_leasePrefix) && name.endsWith(_leaseSuffix)) {
        if (type != FileSystemEntityType.file) {
          throw StateError('Chat 后台 lease 类型异常');
        }
        // 活跃的其它 pid 后台动作只能等待/超时，绝不能因进程号不同直接偷锁。
        await _reapExpiredOwnedLease(
          File(entity.path),
          allowSameProcess: false,
        );
      } else if (type == FileSystemEntityType.file ||
          type == FileSystemEntityType.link) {
        try {
          await entity.delete();
        } on FileSystemException {
          // 被并发清理时已不存在即可；仍存在时下次协议会继续清理。
        }
      }
    }
  }

  static Future<_ChatUserLeaseOwner?> _readLeaseOwner(File leaseFile) async {
    try {
      return _ChatUserLeaseOwner.decode(await leaseFile.readAsString());
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static Future<bool> _reapExpiredOwnedLease(
    File leaseFile, {
    required bool allowSameProcess,
  }) async {
    final firstType = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (firstType == FileSystemEntityType.notFound) return true;
    if (firstType != FileSystemEntityType.file) {
      throw StateError('Chat 跨 isolate lease 类型异常');
    }
    final firstStat = await leaseFile.stat();
    if (DateTime.now().difference(firstStat.modified) <= _leaseStaleAfter) {
      return false;
    }
    final firstOwner = await _readLeaseOwner(leaseFile);
    if (firstOwner == null ||
        (!allowSameProcess && firstOwner.processId == pid)) {
      return false;
    }
    await Future<void>.delayed(_leaseHeartbeatInterval + _leasePollInterval);
    final secondType = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (secondType == FileSystemEntityType.notFound) return true;
    if (secondType != FileSystemEntityType.file) {
      throw StateError('Chat 跨 isolate lease 类型异常');
    }
    final secondStat = await leaseFile.stat();
    final secondOwner = await _readLeaseOwner(leaseFile);
    if (secondOwner?.encode() != firstOwner.encode() ||
        secondStat.modified.millisecondsSinceEpoch !=
            firstStat.modified.millisecondsSinceEpoch ||
        DateTime.now().difference(secondStat.modified) <= _leaseStaleAfter) {
      return false;
    }
    final stale = _directFile(
      leaseFile.parent,
      '${_basename(leaseFile.path)}.$pid.${_newNonce()}.stale',
    );
    try {
      final renamed = await leaseFile.rename(stale.path);
      await renamed.delete();
      return true;
    } on FileSystemException {
      return await FileSystemEntity.type(leaseFile.path, followLinks: false) ==
          FileSystemEntityType.notFound;
    }
  }

  static Future<void> _deleteOwnedLeaseFile(
    File leaseFile,
    _ChatUserLeaseOwner owner, {
    bool allowMissing = false,
  }) async {
    final type = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound && allowMissing) return;
    if (type != FileSystemEntityType.file) {
      throw StateError('Chat 跨 isolate lease 已丢失或类型异常');
    }
    final actual = await _readLeaseOwner(leaseFile);
    if (actual?.encode() != owner.encode()) {
      throw StateError('Chat 跨 isolate lease 所有权已变化');
    }
    await leaseFile.delete();
    if (await FileSystemEntity.type(leaseFile.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('Chat 跨 isolate lease 释放失败');
    }
  }

  static Future<bool> _reapExpiredUserMutationLease(File leaseFile) async {
    final firstType = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (firstType == FileSystemEntityType.notFound) return true;
    if (firstType != FileSystemEntityType.file) {
      throw StateError('Chat user ID 文件协调 lease 类型异常');
    }
    final firstStat = await leaseFile.stat();
    if (DateTime.now().difference(firstStat.modified) <=
        _userMutationStaleAfter) {
      return false;
    }
    final firstOwner = await _readUserLeaseOwner(leaseFile);
    // native/OpenMLS 或大文件同步调用可能阻塞 owner isolate 的事件循环超过 stale
    // 阈值。同一 pid 的任何 lease 都必须视为仍可能存活，运行中绝不偷锁；同 pid
    // isolate 崩溃残留只在下一次 main 启动 preflight、确认旧动作不存在后清理。
    if (firstOwner?.processId == pid) {
      return false;
    }

    // stale 判定后再跨过一个完整 heartbeat 周期复核，封住 owner 正在续租的竞态。
    await Future<void>.delayed(
      _userMutationHeartbeatInterval + _leasePollInterval,
    );
    final secondType = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (secondType == FileSystemEntityType.notFound) return true;
    if (secondType != FileSystemEntityType.file) {
      throw StateError('Chat user ID 文件协调 lease 类型异常');
    }
    final secondStat = await leaseFile.stat();
    final secondOwner = await _readUserLeaseOwner(leaseFile);
    if (secondOwner?.encode() != firstOwner?.encode() ||
        secondStat.modified.millisecondsSinceEpoch !=
            firstStat.modified.millisecondsSinceEpoch ||
        DateTime.now().difference(secondStat.modified) <=
            _userMutationStaleAfter) {
      return false;
    }

    final stale = _directFile(
      leaseFile.parent,
      '${_basename(leaseFile.path)}.$pid.${_newNonce()}'
      '$_userMutationStaleSuffix',
    );
    try {
      final renamed = await leaseFile.rename(stale.path);
      await renamed.delete();
      return true;
    } on FileSystemException {
      return await FileSystemEntity.type(leaseFile.path, followLinks: false) ==
          FileSystemEntityType.notFound;
    }
  }

  static Future<void> _retireStartupOrphanUserMutationLease(
    File leaseFile,
    _ChatUserLeaseOwner expectedOwner,
  ) async {
    final type = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file) {
      throw StateError('Chat 启动预检发现异常 user ID lease 类型');
    }
    final actualOwner = await _readUserLeaseOwner(leaseFile);
    if (actualOwner?.encode() != expectedOwner.encode()) {
      throw StateError('Chat 启动预检期间 user ID lease 所有权已变化');
    }
    if (actualOwner!.processGeneration == _userMutationProcessGeneration) {
      throw StateError('Chat 启动预检拒绝退役当前进程 user ID lease');
    }

    // rename 是退役的原子边界；若进程在 delete 前退出，下一次预检会按 .stale
    // artifact 继续删除，不会把半清理文件重新解释为活跃 lease。
    final stale = _directFile(
      leaseFile.parent,
      '${_basename(leaseFile.path)}.$pid.${_newNonce()}'
      '$_userMutationStaleSuffix',
    );
    try {
      final retired = await leaseFile.rename(stale.path);
      await retired.delete();
    } on FileSystemException {
      if (await FileSystemEntity.type(leaseFile.path, followLinks: false) ==
          FileSystemEntityType.notFound) {
        return;
      }
      rethrow;
    }
  }

  static Future<_ChatUserLeaseOwner?> _readUserLeaseOwner(
    File leaseFile,
  ) async {
    try {
      return _ChatUserLeaseOwner.decode(await leaseFile.readAsString());
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static Future<void> _deleteOwnedUserLeaseFile(
    File leaseFile,
    _ChatUserLeaseOwner owner, {
    bool allowMissing = false,
  }) async {
    final type = await FileSystemEntity.type(
      leaseFile.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound && allowMissing) return;
    if (type != FileSystemEntityType.file) {
      throw StateError('Chat user ID 文件协调 lease 已丢失或类型异常');
    }
    final actual = await _readUserLeaseOwner(leaseFile);
    if (actual?.encode() != owner.encode()) {
      throw StateError('Chat user ID 文件协调 lease 所有权已变化');
    }
    await leaseFile.delete();
    if (await FileSystemEntity.type(leaseFile.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('Chat user ID 文件协调 lease 释放失败');
    }
  }

  static File _directFile(Directory root, String name) {
    if (name.contains(Platform.pathSeparator)) {
      throw StateError('Chat 跨 isolate 协调文件名不合法');
    }
    final file = File('${root.path}${Platform.pathSeparator}$name').absolute;
    if (file.parent.path != root.path) {
      throw StateError('Chat 跨 isolate 协调文件越过 Documents 根目录');
    }
    return file;
  }

  static String _basename(String path) =>
      path.split(Platform.pathSeparator).last;
}

class _ChatUserLeaseOwner {
  const _ChatUserLeaseOwner({
    required this.processId,
    required this.processGeneration,
    required this.nonce,
  });

  final int processId;
  final String processGeneration;
  final String nonce;

  String encode() => '$processId\n$processGeneration\n$nonce\n';

  static _ChatUserLeaseOwner? decode(String raw) {
    final lines = raw.split('\n');
    if (lines.length != 4 || lines.last.isNotEmpty) return null;
    final processId = int.tryParse(lines[0]);
    if (processId == null ||
        processId <= 0 ||
        lines[1].isEmpty ||
        lines[2].isEmpty) {
      return null;
    }
    return _ChatUserLeaseOwner(
      processId: processId,
      processGeneration: lines[1],
      nonce: lines[2],
    );
  }
}

class _ChatUserMutationLease {
  _ChatUserMutationLease({
    required File file,
    required _ChatUserLeaseOwner owner,
    required Duration heartbeatInterval,
  }) : _file = file,
       _owner = owner {
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _scheduleHeartbeat());
  }

  final File _file;
  final _ChatUserLeaseOwner _owner;
  late final Timer _heartbeat;
  Future<void> _heartbeatTail = Future<void>.value();
  Object? _heartbeatError;
  StackTrace? _heartbeatStackTrace;
  bool _released = false;

  void _scheduleHeartbeat() {
    if (_released || _heartbeatError != null) return;
    _heartbeatTail = _heartbeatTail
        .then<void>((_) async {
          if (_released || _heartbeatError != null) return;
          final actual = await _ChatCrossIsolateCoordinator._readUserLeaseOwner(
            _file,
          );
          if (actual?.encode() != _owner.encode()) {
            throw StateError('Chat user ID 文件协调 lease 所有权已变化');
          }
          await _file.setLastModified(DateTime.now());
        })
        .catchError((Object error, StackTrace stackTrace) {
          _heartbeatError = error;
          _heartbeatStackTrace = stackTrace;
        });
  }

  Future<void> validateHealthy() async {
    await _heartbeatTail;
    final error = _heartbeatError;
    if (error != null) {
      Error.throwWithStackTrace(
        error,
        _heartbeatStackTrace ?? StackTrace.current,
      );
    }
    final actual = await _ChatCrossIsolateCoordinator._readUserLeaseOwner(
      _file,
    );
    if (actual?.encode() != _owner.encode()) {
      throw StateError('Chat user ID 文件协调 lease 所有权已变化');
    }
  }

  Future<void> release() async {
    if (_released) return;
    _heartbeat.cancel();
    await _heartbeatTail;
    Object? healthError = _heartbeatError;
    StackTrace? healthStackTrace = _heartbeatStackTrace;
    try {
      await _ChatCrossIsolateCoordinator._deleteOwnedUserLeaseFile(
        _file,
        _owner,
      );
      _released = true;
    } catch (error, stackTrace) {
      healthError ??= error;
      healthStackTrace ??= stackTrace;
    }
    if (healthError != null) {
      Error.throwWithStackTrace(
        healthError,
        healthStackTrace ?? StackTrace.current,
      );
    }
  }
}

class _ChatUserMutationGate {
  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  Future<T> run<T>(String userId, Future<T> Function() action) {
    final previous = _tails[userId] ?? Future<void>.value();
    final completer = Completer<T>();
    final tail = completer.future.then<void>((_) {}, onError: (_) {});
    _tails[userId] = tail;

    unawaited(() async {
      try {
        try {
          await previous;
        } catch (_) {
          // 前一操作失败不能毒化同一 user ID 的后续本地队列。
        }
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        if (identical(_tails[userId], tail)) {
          final _ = _tails.remove(userId);
        }
      }
    }());
    return completer.future;
  }
}

class _ChatUserLeaseScope {
  _ChatUserLeaseScope(this.userId, this.bindingToken);

  final String userId;
  final ChatBindingFenceToken? bindingToken;
  bool _active = true;
  final Set<Future<void>> _nestedOperations = <Future<void>>{};

  bool get isActive => _active;

  Future<T> track<T>(Future<T> operation) {
    final drained = operation.then<void>((_) {}, onError: (_) {});
    _nestedOperations.add(drained);
    drained.whenComplete(() => _nestedOperations.remove(drained));
    return operation;
  }

  void stopAccepting() => _active = false;

  Future<void> drain() async {
    while (_nestedOperations.isNotEmpty) {
      await Future.wait<void>(_nestedOperations.toList(growable: false));
    }
  }
}

/// 把每一次 OpenMLS 状态读写都绑定到创建上下文时捕获的持久 fence。
///
/// Runtime 的上层流程仍会把“密码学状态推进 + Isar 最终 CAS”包在同一 user ID lease
/// 内；本代理是最后一道边界，避免后来新增的直接 crypto 调用绕过跨 isolate 协调。
class _ChatBindingFencedMlsCrypto
    implements MlsGroupCrypto, MlsPersistentCrypto {
  const _ChatBindingFencedMlsCrypto({
    required ChatRuntimeCore runtime,
    required ChatBindingFenceToken bindingToken,
    required MlsGroupCrypto delegate,
  }) : _runtime = runtime,
       _bindingToken = bindingToken,
       _delegate = delegate;

  final ChatRuntimeCore _runtime;
  final ChatBindingFenceToken _bindingToken;
  final MlsGroupCrypto _delegate;
  static final Object _messageGuardZoneKey = Object();

  Future<T> _run<T>(Future<T> Function() operation) =>
      _runtime._runBindingFileMutation(_bindingToken, operation);

  @override
  Future<T> withMessage<T>(String messageId, Future<T> Function() operation) =>
      runZoned(
        () => _delegate.withMessage(messageId, operation),
        zoneValues: {_messageGuardZoneKey: messageId},
      );
  @override
  Future<void> acknowledgeMessage(String messageId) =>
      _run(() => _delegate.acknowledgeMessage(messageId));
  @override
  Future<List<Map<String, dynamic>>> pendingMessageResults(String? messageId) =>
      _run(() => _delegate.pendingMessageResults(messageId));

  void dispose() {
    final delegate = _delegate;
    if (delegate is NativeMlsCrypto) delegate.dispose();
  }

  @override
  Future<MlsKeyPackage> createKeyPackage(
    ChatDevice identity, {
    bool lastResort = true,
  }) =>
      _run(() => _delegate.createKeyPackage(identity, lastResort: lastResort));

  @override
  Future<GroupCreated> createGroup(String groupId) =>
      _run(() => _delegate.createGroup(groupId));

  @override
  Future<GroupCommitBundle> addMembers(
    String groupId,
    List<MlsKeyPackage> keyPackages,
  ) => _run(() => _delegate.addMembers(groupId, keyPackages));

  @override
  Future<GroupCommitBundle> removeMembers(
    String groupId,
    List<String> memberIdentities,
  ) => _run(() => _delegate.removeMembers(groupId, memberIdentities));

  @override
  Future<MlsWireMessage> groupCreateMessage(
    String groupId,
    List<int> plaintext,
  ) => _run(() async {
    // 正常聊天媒体控制的名册复核与密文生成在同一当前绑定短屏障内。
    // 附件二进制块归独立组，不能把其头部当作普通聊天载荷解析。
    if (!groupId.startsWith('attachment:')) {
      ChatContent? content;
      try {
        content = ChatPayloadCodec.decode(utf8.decode(plaintext));
      } on FormatException {
        // 非聊天载荷不进入媒体控制名册检查，协议处理仍由OpenMLS负责。
      }
      if (content?.isMedia == true) {
        final id = Zone.current[_messageGuardZoneKey] as String?;
        if (id == null) throw StateError('附件控制缺少事务标识');
        final saved = await _delegate.pendingMessageResults(id);
        if (saved.any(
          (r) => (r['result'] as Map)['application_wire_hex'] is String,
        )) {
          return _delegate.groupCreateMessage(groupId, plaintext);
        }
        final state = await _delegate.groupState(groupId);
        if (state.epoch != content!.attachmentChatEpoch ||
            jsonEncode([...state.memberIdentities]..sort()) !=
                jsonEncode(content.attachmentMemberIdentities)) {
          throw const _AttachmentAudienceChanged();
        }
      }
    }
    return _delegate.groupCreateMessage(groupId, plaintext);
  });

  @override
  Future<GroupInbound> groupProcess(MlsWireMessage wire) =>
      _run(() => _delegate.groupProcess(wire));

  @override
  Future<GroupState> groupState(String groupId) =>
      _run(() => _delegate.groupState(groupId));
}

class _ChatCrossIsolateLease {
  _ChatCrossIsolateLease({
    required File file,
    required _ChatUserLeaseOwner owner,
    required Duration heartbeatInterval,
  }) : _file = file,
       _owner = owner {
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _scheduleHeartbeat());
  }

  final File _file;
  final _ChatUserLeaseOwner _owner;
  late final Timer _heartbeat;
  Future<void> _heartbeatTail = Future<void>.value();
  Object? _heartbeatError;
  StackTrace? _heartbeatStackTrace;
  bool _released = false;

  void _scheduleHeartbeat() {
    if (_released || _heartbeatError != null) return;
    _heartbeatTail = _heartbeatTail
        .then<void>((_) async {
          if (_released || _heartbeatError != null) return;
          final actual = await _ChatCrossIsolateCoordinator._readLeaseOwner(
            _file,
          );
          if (actual?.encode() != _owner.encode()) {
            throw StateError('Chat 跨 isolate lease 所有权已变化');
          }
          await _file.setLastModified(DateTime.now());
        })
        .catchError((Object error, StackTrace stackTrace) {
          _heartbeatError = error;
          _heartbeatStackTrace = stackTrace;
        });
  }

  Future<void> release() async {
    if (_released) return;
    _heartbeat.cancel();
    await _heartbeatTail;
    Object? error = _heartbeatError;
    StackTrace? stackTrace = _heartbeatStackTrace;
    try {
      await _ChatCrossIsolateCoordinator._deleteOwnedLeaseFile(_file, _owner);
      _released = true;
    } catch (caught, caughtStackTrace) {
      error ??= caught;
      stackTrace ??= caughtStackTrace;
    }
    if (error != null) {
      Error.throwWithStackTrace(error, stackTrace ?? StackTrace.current);
    }
  }
}

class ChatRuntimeAccountContext {
  ChatRuntimeAccountContext({
    required this.account,
    required this.bindingToken,
    required this.deviceId,
    required this.localKeyPackage,
    this.stateStore,
    required this.crypto,
    required this.transport,
  });

  final ChatRuntimeAccount account;
  final ChatBindingFenceToken bindingToken;
  final String deviceId;
  final MlsKeyPackage localKeyPackage;
  final MlsStateStore? stateStore;
  final MlsGroupCrypto crypto;
  final ChatServiceTransport transport;
  late final _RetryableAsyncDisposer _disposer = _RetryableAsyncDisposer(
    _dispose,
  );

  /// 当前绑定失效后关闭网络和MLS运行上下文，保留永久设备身份。
  Future<void> dispose() => _disposer.dispose();

  Future<void> _dispose() async {
    // 先停止会产生新附件/网络回调的资源并等待其 tail，再释放MLS运行资源；禁止
    // 正在执行的回调观察到已 dispose 的 crypto/stateStore。
    await transport.dispose();
    final currentCrypto = crypto;
    if (currentCrypto is _ChatBindingFencedMlsCrypto) {
      currentCrypto.dispose();
    } else if (currentCrypto is NativeMlsCrypto) {
      currentCrypto.dispose();
    }
  }

  ChatDevice get identity =>
      ChatDevice(userId: account.userId, deviceId: deviceId);
}

/// 前台常驻只持有账户、设备标识、会话与WSS传输，不打开ChatIsar或MLS。
class _ChatSignalContext {
  const _ChatSignalContext({
    required this.account,
    required this.identity,
    required this.transport,
  });

  final ChatRuntimeAccount account;
  final ChatDevice identity;
  final ChatServiceTransport transport;
}

/// 宿主用户 Chat 运行态编排服务。
///
/// 页面层不直接操作 OpenMLS、TataChatServer 瞬时转发、近场通道和 Isar。
/// 读取宿主账户事实，先离线准备SDK自有MLS身份，再建立聊天连接。
/// 连接时请求宿主短期服务凭证，本地文件由SDK自己的系统保护存储承载。
class ChatRuntimeCore {
  ChatRuntimeCore({
    required ChatRuntimeHost host,
    ChatStore? store,
    SharedPreferences? preferences,
    MlsStateStoreFactory? stateStoreFactory,
    MlsGroupCrypto Function(ChatDevice identity, MlsStateStore stateStore)?
    cryptoFactory,
    Future<Directory> Function()? documentsDirectoryProvider,
    ChatServiceTransportFactory? transportFactory,
    bool receiveOnly = false,
    @visibleForTesting bool debugUseIndependentUserMutationGate = false,
  }) : _host = host,
       _store = store ?? ChatStore(),
       _preferences = preferences,
       _stateStoreFactory = stateStoreFactory,
       _cryptoFactory = cryptoFactory,
       _transportFactory =
           transportFactory ??
           (({
             required ChatDevice identity,
             required TataChatServerAccessProvider accessProvider,
           }) => ChatServerConnection(
             identity: identity,
             accessProvider: accessProvider,
           )),
       _receiveOnly = receiveOnly,
       _userMutationGate = debugUseIndependentUserMutationGate
           ? _ChatUserMutationGate()
           : _sharedUserMutationGate,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? ChatSystemProtectedStorage.prepare {
    if ((stateStoreFactory != null || cryptoFactory != null) &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('MLS存储与密码替身仅允许合成测试');
    }
    if (debugUseIndependentUserMutationGate &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('仅 Flutter 测试允许使用独立 Chat user gate');
    }
    _ensureProcessActive();
    _liveInstances.removeWhere((reference) => reference.target == null);
    _liveInstances.add(WeakReference<ChatRuntimeCore>(this));
  }

  static const _kPushRegistrationPrefix = 'chat.push.registration';
  static const _pushEndpointTtl = Duration(days: 90);
  static const _pushEndpointRefreshSkewMillis = 24 * 60 * 60 * 1000;
  // 单会话只执行五次有界低频重试；之后由现有 WSS 重连、系统唤醒、前台恢复
  // 或下一条发送再次收敛，避免服务故障时无限请求宿主授权状态。
  static const _outboundRetryDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  /// 测试专用：并发提交实时 callback，验证内部仍按提交顺序串行完成。
  @visibleForTesting
  static Future<void> debugRunRealtimeCallbacksForTest(
    List<Future<void> Function()> callbacks,
  ) async {
    final session = _ChatRealtimeSession();
    await Future.wait<void>(callbacks.map(session.runCallback));
  }

  /// AppLock 擦除意图是进程级终态：一旦置位，现有和新建 ChatRuntimeCore 都不得再建立
  /// 网络、MLS 或文件上下文。正常恢复只能依赖进程重启，禁止在擦除后重新生成目录。
  static bool _processWipeRequested = false;
  static Future<void>? _localFileWipeInFlight;
  static final List<WeakReference<ChatRuntimeCore>> _liveInstances =
      <WeakReference<ChatRuntimeCore>>[];

  /// close 失败的 Runtime 必须被强引用到下一次 AppLock 重试；否则 UI 放弃最后一个
  /// 引用后 GC 会让 WeakReference 消失，仍存活的 native/socket 生产者可能被漏关。
  static final Set<ChatRuntimeCore> _instancesPendingClose =
      <ChatRuntimeCore>{};
  static final Set<Future<void>> _processOperations = <Future<void>>{};
  static final _ChatUserMutationGate _sharedUserMutationGate =
      _ChatUserMutationGate();
  static final Object _userMutationZoneKey = Object();

  bool _closed = false;
  final Set<Future<void>> _contextDisposals = <Future<void>>{};
  final Set<ChatRuntimeAccountContext> _contextsPendingDisposal =
      <ChatRuntimeAccountContext>{};
  final Set<Future<void>> _fileMutations = <Future<void>>{};
  final Set<Future<void>> _runtimeOperations = <Future<void>>{};
  final Set<Future<ChatRuntimeAccountContext>>
  _readyFlightsPendingInvalidation = <Future<ChatRuntimeAccountContext>>{};
  final Set<_ChatRealtimeSession> _realtimeSessions = <_ChatRealtimeSession>{};
  final Map<String, _ChatRealtimeHub> _realtimeHubs =
      <String, _ChatRealtimeHub>{};
  _RetryableAsyncDisposer? _debugContextDisposerForTest;

  final ChatRuntimeHost _host;
  final ChatStore _store;
  final SharedPreferences? _preferences;
  final MlsStateStoreFactory? _stateStoreFactory;
  final MlsGroupCrypto Function(ChatDevice identity, MlsStateStore stateStore)?
  _cryptoFactory;
  final ChatServiceTransportFactory _transportFactory;
  final bool _receiveOnly;
  final _ChatUserMutationGate _userMutationGate;
  final _ChatUserMutationGate _outboundDeliveryGate = _ChatUserMutationGate();
  final Future<Directory> Function() _documentsDirectoryProvider;

  /// 正在经 HTTPS 上传 encrypted object storage 密文的媒体 attachmentId（初始发送或补发中），用于去重：
  /// 启动、恢复前台或推送触发的补发不得对在途媒体再整块重传。
  // Chat 列表、会话页和后台同步可能各持有 ChatRuntimeCore；附件网络状态必须进程
  // 唯一，否则多个实例会同时为同一 attachmentId prepare/abort 并耗尽 D1。
  static final Set<String> _mediaBytesInFlight = {};
  static bool _mediaUploadBusy = false;
  static final Map<String, int> _mediaUploadFailures = <String, int>{};
  static final Map<String, DateTime> _mediaUploadRetryAt = <String, DateTime>{};

  /// 正在下载的入站 encrypted object storage 密文附件。相同账户、会话和 attachmentId 共用一个 Future，
  /// WSS、邮箱补拉、页面恢复和用户点击不得并发重复下载整块密文。
  final Map<String, Future<void>> _incomingAttachmentDownloads = {};

  /// WSS 在线帧与连接后补拉可能命中同一密文；进程内先按既有 message_id 去重，
  /// 本机处理成功后只重试云端 ACK，不得再次推进同一个 OpenMLS 控制消息。
  final Set<String> _mailboxMessageReceipts = <String>{};
  final Set<String> _outgoingRetryInFlight = <String>{};
  final Set<String> _keyPackagePublications = <String>{};
  final Map<String, Timer> _outboundRetryTimers = <String, Timer>{};
  final Map<String, int> _outboundRetryAttempts = <String, int>{};

  /// 同一账户/设备只允许一条初始化链。成功上下文复用到 session 临近过期；
  /// 失败只释放命中的 future，不得误删后来创建的新初始化。
  final Map<String, Future<ChatRuntimeAccountContext>> _readyFlights = {};
  final Map<String, ChatRuntimeAccountContext> _readyContexts = {};
  final Map<String, String> _accountContextKeys = {};
  final Map<String, int> _accountGenerations = {};
  final Set<String> _blockedAccountIds = <String>{};

  /// AppLock 在触碰任何业务存储前先落盘 pending marker。
  ///
  /// 本 isolate 终态在返回 Future 前生效；marker 保留到全域成功后的
  /// complete 状态，部分失败跨重启仍无鉴权继续擦除。
  static Future<void> beginPersistentAppDataWipe({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) {
    _processWipeRequested = true;
    return _resolveWipeDocumentsRoot(
      documentsDirectoryProvider,
    ).then(_ChatCrossIsolateCoordinator.ensureWipePending);
  }

  static Future<ChatPersistentWipeState> readPersistentAppDataWipeState({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final root = await _resolveWipeDocumentsRoot(documentsDirectoryProvider);
    return _ChatCrossIsolateCoordinator.readPersistentWipeState(root);
  }

  /// main 在构造任何 ChatRuntimeCore 或启动后台操作前调用一次。
  static Future<void> recoverStartupArtifacts({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    // 这是普通 Chat 文件维护，不是数据擦除门禁。首帧后等待正在运行的
    // FCM/APNs 收件自然结束并重试，失败不得阻断 宿主应用 其它功能。
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        await runStartupPreflight(
          operation: () async {},
          documentsDirectoryProvider: documentsDirectoryProvider,
        );
        return;
      } catch (_) {
        if (attempt == 2) rethrow;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// 持有当前进程 generation 的真实 user ID lease，验证启动预检不会误删活锁。
  /// 仅供 Flutter 测试使用；生产启动仍只能从 [runStartupPreflight] 进入。
  @visibleForTesting
  static Future<T> debugRunUserMutationLeaseForTest<T>({
    required String userId,
    required Future<T> Function() operation,
    required Future<Directory> Function() documentsDirectoryProvider,
  }) async {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('仅 Flutter 测试允许持有 Chat user ID lease');
    }
    final root = await _ChatCrossIsolateCoordinator.resolveDocumentsRoot(
      documentsDirectoryProvider,
    );
    final lease = await _ChatCrossIsolateCoordinator.acquireUserMutationLease(
      root,
      userId,
    );
    try {
      return await operation();
    } finally {
      await lease.release();
    }
  }

  /// AppLock 整段启动恢复都持有 startup barrier；不能只在 user ID artifact 清理时短持，
  /// 否则 marker 读取/恢复 wipe 的间隙仍可能有后台 isolate 进入。
  static Future<T> runStartupPreflight<T>({
    required Future<T> Function() operation,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final root = await _resolveWipeDocumentsRoot(documentsDirectoryProvider);
    return _ChatCrossIsolateCoordinator.runStartupPreflight(root, operation);
  }

  /// 启动与退后台只按 Chat 文件域结构清除短命明文，不构造 Runtime、不读取默认账户、
  /// WalletIsar 或任何密钥。每个物理 user ID 分区仍取得同一跨 isolate lease。
  static Future<void> purgePlainAttachmentsWithoutAccount({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    _ensureProcessActive();
    final documentsRoot = await _resolveWipeDocumentsRoot(
      documentsDirectoryProvider,
    );
    final byUser = Directory(
      '${documentsRoot.path}${Platform.pathSeparator}chat'
      '${Platform.pathSeparator}by_user',
    );
    final byUserType = await FileSystemEntity.type(
      byUser.path,
      followLinks: false,
    );
    if (byUserType == FileSystemEntityType.notFound) return;
    if (byUserType != FileSystemEntityType.directory) {
      throw StateError('Chat 明文清扫根路径类型异常');
    }
    await for (final userEntity in byUser.list(followLinks: false)) {
      final userType = await FileSystemEntity.type(
        userEntity.path,
        followLinks: false,
      );
      if (userType != FileSystemEntityType.directory) {
        throw StateError('Chat 明文清扫发现非目录 user ID 分区');
      }
      final userDirectory = Directory(userEntity.path);
      final userPathKey = userDirectory.path.split(Platform.pathSeparator).last;
      if (userPathKey.isEmpty) throw StateError('Chat 明文清扫 user ID 分区名为空');
      final lease = await _ChatCrossIsolateCoordinator.acquireUserMutationLease(
        documentsRoot,
        userPathKey,
      );
      try {
        await _purgePlainAttachmentsInUserDirectory(userDirectory);
        await lease.validateHealthy();
      } finally {
        await lease.release();
      }
    }
  }

  static Future<void> _purgePlainAttachmentsInUserDirectory(
    Directory userDirectory,
  ) async {
    final plain = Directory(
      '${userDirectory.path}${Platform.pathSeparator}attachments'
      '${Platform.pathSeparator}${AttachmentVault.plainDirName}',
    );
    final type = await FileSystemEntity.type(plain.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.directory ||
        await plain.resolveSymbolicLinks() != plain.absolute.path) {
      throw StateError('Chat 临时附件路径类型异常');
    }
    await plain.delete(recursive: true);
    if (await FileSystemEntity.type(plain.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('Chat 临时附件目录清除失败');
    }
  }

  static Future<void> markPersistentAppDataWipeComplete({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final root = await _resolveWipeDocumentsRoot(documentsDirectoryProvider);
    await _ChatCrossIsolateCoordinator.markWipeComplete(root);
  }

  /// 只有新前台进程在启动预检确认 complete 后才能清理门闩。
  static Future<void> clearCompletedPersistentAppDataWipe({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final root = await _resolveWipeDocumentsRoot(documentsDirectoryProvider);
    await _ChatCrossIsolateCoordinator.clearCompletedWipe(root);
  }

  static Future<Directory> _resolveWipeDocumentsRoot(
    Future<Directory> Function()? documentsDirectoryProvider,
  ) {
    return _ChatCrossIsolateCoordinator.resolveDocumentsRoot(
      documentsDirectoryProvider ?? ChatSystemProtectedStorage.prepare,
    );
  }

  /// 让 AppLock 把整个 `${documentsRoot}/chat` 作为一个独立擦除域。
  ///
  /// 终态在本方法返回 Future 前同步生效。先关闭已建立上下文并等待已有 ready flight
  /// 收口，再删除唯一 Chat 根目录；任一步失败都上抛给 AppLock 聚合，绝不扩大删除目标。
  static Future<void> closeAndDeleteLocalFiles({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) {
    _processWipeRequested = true;
    final running = _localFileWipeInFlight;
    if (running != null) return running;

    final provider =
        documentsDirectoryProvider ?? ChatSystemProtectedStorage.prepare;
    final instances = <ChatRuntimeCore>[];
    for (final reference in _liveInstances) {
      final instance = reference.target;
      if (instance != null) {
        _instancesPendingClose.add(instance);
      }
    }
    _liveInstances.removeWhere((reference) => reference.target == null);
    instances.addAll(_instancesPendingClose);

    late final Future<void> task;
    task = _closeInstancesAndDeleteRoot(instances, provider).whenComplete(() {
      if (identical(_localFileWipeInFlight, task)) {
        _localFileWipeInFlight = null;
      }
    });
    _localFileWipeInFlight = task;
    return task;
  }

  static Future<void> _closeInstancesAndDeleteRoot(
    List<ChatRuntimeCore> instances,
    Future<Directory> Function() documentsDirectoryProvider,
  ) async {
    final failures = <String>[];
    Directory? documentsRoot;
    try {
      documentsRoot = await _ChatCrossIsolateCoordinator.resolveDocumentsRoot(
        documentsDirectoryProvider,
      );
      await _ChatCrossIsolateCoordinator.beginWipe(documentsRoot);
    } catch (error) {
      failures.add('Chat 跨 isolate 生产者收口失败：$error');
    }
    final processOperations = _processOperations.toList(growable: false);
    await Future.wait<void>(<Future<void>>[
      for (final operation in processOperations)
        _captureCleanupFailure('等待 Chat 后台进程操作', () => operation, failures),
      for (final instance in instances)
        _closeInstanceForWipe(instance, failures),
    ]);

    // 任一运行态关闭失败时不得先删文件树；否则旧上下文可能续写并复活目录。
    if (failures.isEmpty && documentsRoot != null) {
      try {
        if (documentsRoot.path == documentsRoot.parent.path) {
          throw StateError('Chat 文档根目录不能是文件系统根目录');
        }
        await MlsStateStore.erase();
        final chatRoot = Directory(
          '${documentsRoot.path}${Platform.pathSeparator}chat',
        ).absolute;
        if (chatRoot.parent.path != documentsRoot.path) {
          throw StateError('Chat 擦除目录越过文档根目录');
        }
        final chatRootType = await FileSystemEntity.type(
          chatRoot.path,
          followLinks: false,
        );
        if (chatRootType == FileSystemEntityType.link) {
          // 目录位被符号链接占用时只删除链接本身，禁止跟随到文档根目录之外。
          await Link(chatRoot.path).delete();
        } else if (chatRootType != FileSystemEntityType.notFound) {
          await chatRoot.delete(recursive: true);
        }
      } catch (error) {
        failures.add('删除 Chat 文件树失败：$error');
      }
    }

    if (failures.isNotEmpty) {
      throw StateError(failures.join('\n'));
    }
  }

  static Future<void> _captureCleanupFailure(
    String label,
    Future<void> Function() action,
    List<String> failures,
  ) async {
    try {
      await action();
    } catch (error) {
      failures.add('$label：$error');
    }
  }

  static Future<void> _closeInstanceForWipe(
    ChatRuntimeCore instance,
    List<String> failures,
  ) async {
    try {
      await instance.close();
      _instancesPendingClose.remove(instance);
    } catch (error) {
      // 保持强引用，下一次 AppLock 擦除必须继续关闭同一个失败实例。
      _instancesPendingClose.add(instance);
      failures.add('关闭 ChatRuntimeCore：$error');
    }
  }

  @visibleForTesting
  static int get debugPendingCloseInstanceCount =>
      _instancesPendingClose.length;

  @visibleForTesting
  static int get debugLiveInstanceCount {
    _liveInstances.removeWhere((reference) => reference.target == null);
    return _liveInstances
        .map((reference) => reference.target)
        .whereType<ChatRuntimeCore>()
        .toSet()
        .union(_instancesPendingClose)
        .length;
  }

  /// Flutter 测试在同一进程内运行多条用例，只能显式模拟“进程重启”。旧 runtime
  /// 实例仍保持终态，重置后只允许新实例参与下一条测试。
  @visibleForTesting
  static Future<void> debugResetProcessWipeForTest({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('仅 Flutter 测试允许重置 ChatRuntimeCore 擦除终态');
    }
    final running = _localFileWipeInFlight;
    if (running != null) {
      try {
        await running;
      } catch (_) {
        // 上一用例已经断言错误；这里只模拟新进程，不吞生产路径错误。
      }
    }
    _localFileWipeInFlight = null;
    _liveInstances.clear();
    _instancesPendingClose.clear();
    _processWipeRequested = false;
    final provider = documentsDirectoryProvider;
    if (provider != null) {
      await _ChatCrossIsolateCoordinator.resetForTest(provider);
    }
  }

  static void _ensureProcessActive() {
    if (_processWipeRequested) {
      throw StateError('ChatRuntimeCore 已进入本机数据擦除终态，进程重启前禁止恢复。');
    }
  }

  static Future<T> _runCrossIsolateBackgroundOperation<T>(
    Future<T> Function() operation, {
    required Future<Directory> Function() documentsDirectoryProvider,
    required bool checkLocalTerminal,
  }) async {
    final root = await _ChatCrossIsolateCoordinator.resolveDocumentsRoot(
      documentsDirectoryProvider,
    );
    final lease = await _ChatCrossIsolateCoordinator.acquireBackgroundLease(
      root,
    );
    if (checkLocalTerminal) _ensureProcessActive();
    // operation 必须把业务错误内部收敛，只在所有 runtime/push 清理成功
    // 后返回。任何 cleanup 异常均故意保留 lease，禁止 wipe 误报成功。
    final result = await operation();
    await lease.release();
    return result;
  }

  /// 用同一 isolate 模拟 FlutterFire 独立 isolate，故敏感地绕过本 isolate
  /// 的静态终态，只依赖 marker + lease 协议。
  @visibleForTesting
  static Future<T> debugRunBackgroundLeaseForTest<T>(
    Future<T> Function() operation, {
    required Future<Directory> Function() documentsDirectoryProvider,
  }) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future<T>.error(
        UnsupportedError('仅 Flutter 测试允许模拟 Chat 后台 isolate'),
      );
    }
    return _runCrossIsolateBackgroundOperation(
      operation,
      documentsDirectoryProvider: documentsDirectoryProvider,
      checkLocalTerminal: false,
    );
  }

  void _ensureActive() {
    _ensureProcessActive();
    if (_closed) {
      throw StateError('ChatRuntimeCore 已关闭，禁止重新建立聊天运行态。');
    }
  }

  /// 网络回调和不直接改文件的 Chat 操作同样属于擦除前生产者；平台存储最终清理前
  /// 必须等它们收口，防止 ready/push 操作在 clear 之后重新写入偏好值。
  Future<T> _runRuntimeOperation<T>(Future<T> Function() operation) {
    try {
      _ensureActive();
    } catch (error, stackTrace) {
      return Future<T>.error(error, stackTrace);
    }

    final drained = Completer<void>();
    final token = drained.future;
    _runtimeOperations.add(token);

    void release() {
      _runtimeOperations.remove(token);
      if (!drained.isCompleted) drained.complete();
    }

    late final Future<T> running;
    try {
      running = operation();
    } catch (error, stackTrace) {
      release();
      return Future<T>.error(error, stackTrace);
    }
    return running.whenComplete(release);
  }

  late final _RetryableAsyncDisposer _closeDisposer = _RetryableAsyncDisposer(
    _close,
  );

  /// 关闭当前实例的运行资源，不设置进程级擦除状态，不删除本机消息或文件。
  Future<void> close() {
    _closed = true;
    return _closeDisposer.dispose();
  }

  Future<void> _close() async {
    _closed = true;
    for (final timer in _outboundRetryTimers.values) {
      timer.cancel();
    }
    _outboundRetryTimers.clear();
    _outboundRetryAttempts.clear();
    final accountIds = <String>{
      ..._accountGenerations.keys,
      ..._accountContextKeys.keys,
    };
    for (final accountId in accountIds) {
      _accountGenerations[accountId] =
          (_accountGenerations[accountId] ?? 0) + 1;
    }

    final realtimeHubs = _realtimeHubs.values.toList(growable: false);
    for (final hub in realtimeHubs) {
      try {
        await _closeRealtimeHub(hub);
      } catch (_) {
        // 物理 session 仍在下方统一快照中，终态清理会再次收口并报告失败。
      }
    }

    final flights = <Future<ChatRuntimeAccountContext>>{
      ..._readyFlights.values,
      ..._readyFlightsPendingInvalidation,
    }.toList(growable: false);
    final initialContexts = <ChatRuntimeAccountContext>{
      ..._readyContexts.values,
      ..._contextsPendingDisposal,
    };
    final realtimeSessions = _realtimeSessions.toList(growable: false);
    _readyContexts.clear();
    _readyFlights.clear();
    _accountContextKeys.clear();
    _mediaBytesInFlight.clear();
    _mediaUploadBusy = false;
    _mediaUploadFailures.clear();
    _mediaUploadRetryAt.clear();
    _incomingAttachmentDownloads.clear();
    _mailboxMessageReceipts.clear();
    _outgoingRetryInFlight.clear();
    _keyPackagePublications.clear();

    final failures = <String>[];
    // 第一阶段只停止所有实时生产源。session 会同步拒绝新 callback，关闭
    // socket/subscription，并等待已经登记的 callback；此时绝不 dispose crypto。
    await Future.wait<void>(<Future<void>>[
      for (final session in realtimeSessions)
        _captureCleanupFailure(
          '关闭 Chat 实时会话',
          () => _disposeRealtimeSession(session),
          failures,
        ),
    ]);

    // 第二阶段等待所有已登记 action/build 收口。终态已经同步置位，session 也已
    // 拒绝新 callback，所以这份快照之后不会再合法产生新的业务生产者。
    final fileMutations = _fileMutations.toList(growable: false);
    final runtimeOperations = _runtimeOperations.toList(growable: false);
    final earlierDisposals = _contextDisposals.toList(growable: false);
    await Future.wait<void>(<Future<void>>[
      for (final mutation in fileMutations)
        _captureCleanupFailure('等待 Chat 文件改写', () => mutation, failures),
      for (final operation in runtimeOperations)
        _captureCleanupFailure('等待 Chat 运行操作', () => operation, failures),
      for (final flight in flights)
        _captureCleanupFailure(
          '失效 Chat 初始化任务',
          () => _settleReadyFlightForWipe(flight),
          failures,
        ),
      for (final disposal in earlierDisposals)
        _captureCleanupFailure('等待此前 Chat 上下文关闭', () => disposal, failures),
    ]);

    // 第三阶段才关闭 context：此时没有 action 会继续使用 NativeMlsCrypto、
    // 运行资源。flight 晚到 context 与此前失败的 pending 一并重试。
    final contexts = <ChatRuntimeAccountContext>{
      ...initialContexts,
      ..._contextsPendingDisposal,
    }.toList(growable: false);
    await Future.wait<void>(<Future<void>>[
      for (final context in contexts)
        _captureCleanupFailure(
          '关闭 Chat 上下文',
          () => _disposeContext(context),
          failures,
        ),
      if (_debugContextDisposerForTest != null)
        _captureCleanupFailure(
          '关闭 Chat 测试上下文',
          _debugContextDisposerForTest!.dispose,
          failures,
        ),
    ]);
    if (failures.isNotEmpty) {
      throw StateError(failures.join('\n'));
    }
  }

  Future<void> _settleReadyFlightForWipe(
    Future<ChatRuntimeAccountContext> flight,
  ) async {
    try {
      final context = await flight;
      await _disposeContext(context);
    } catch (_) {
      // 初始化自身失败时没有可复用上下文；若失败发生在 dispose，context 会留在
      // _contextsPendingDisposal，并由调用方的第二轮快照显式重试和验真。
    }
  }

  Future<void> _disposeContext(ChatRuntimeAccountContext context) {
    _contextsPendingDisposal.add(context);
    final disposal = context.dispose();
    _contextDisposals.add(disposal);
    disposal.then<void>(
      (_) {
        _contextDisposals.remove(disposal);
        _contextsPendingDisposal.remove(context);
      },
      onError: (Object _, StackTrace _) {
        _contextDisposals.remove(disposal);
      },
    );
    return disposal;
  }

  Future<void> _disposeRealtimeSession(_ChatRealtimeSession session) async {
    await session.dispose();
    _realtimeSessions.remove(session);
  }

  /// 文件改写在调用者拿到 Future 前就登记，与 AppLock 终态之间不留窗口。
  ///
  /// 已登记的改写可以收口，擦除会等它们结束后才删除 `Documents/chat`；
  /// 终态置位后的新改写直接返回失败 Future，禁止复活目录。
  Future<T> _runFileMutation<T>(Future<T> Function() operation) {
    try {
      _ensureActive();
    } catch (error, stackTrace) {
      return Future<T>.error(error, stackTrace);
    }

    final drained = Completer<void>();
    final token = drained.future;
    _fileMutations.add(token);

    void release() {
      _fileMutations.remove(token);
      if (!drained.isCompleted) drained.complete();
    }

    late final Future<T> running;
    try {
      running = operation();
    } catch (error, stackTrace) {
      release();
      return Future<T>.error(error, stackTrace);
    }
    return running.whenComplete(release);
  }

  Future<T> _runBindingFileMutation<T>(
    ChatBindingFenceToken bindingToken,
    Future<T> Function() operation,
  ) {
    return _runFileMutation(
      () => _runUserMutation(
        userId: bindingToken.ownerUserId,
        bindingToken: bindingToken,
        operation: operation,
      ),
    );
  }

  Future<T> _runUserFileMutation<T>({
    required String userId,
    required Future<T> Function() operation,
    ChatBindingFenceToken? bindingToken,
    bool validateTokenAfter = true,
  }) {
    return _runFileMutation(
      () => _runUserMutation(
        userId: userId,
        bindingToken: bindingToken,
        validateTokenAfter: validateTokenAfter,
        operation: operation,
      ),
    );
  }

  Future<T> _runUserMutation<T>({
    required String userId,
    required Future<T> Function() operation,
    ChatBindingFenceToken? bindingToken,
    bool validateTokenAfter = true,
  }) {
    final existing = Zone.current[_userMutationZoneKey];
    if (existing is _ChatUserLeaseScope &&
        existing.isActive &&
        existing.userId == userId) {
      final outerToken = existing.bindingToken;
      final sameNullability = (outerToken == null) == (bindingToken == null);
      if (!sameNullability ||
          (outerToken != null &&
              !_sameBindingToken(outerToken, bindingToken!))) {
        return Future<T>.error(
          StateError('同一 user ID 的嵌套文件操作必须复用完全相同的 binding token'),
        );
      }
      try {
        return existing.track(operation());
      } catch (error, stackTrace) {
        return Future<T>.error(error, stackTrace);
      }
    }
    return _userMutationGate.run(userId, () async {
      final documentsRoot =
          await _ChatCrossIsolateCoordinator.resolveDocumentsRoot(
            _documentsDirectoryProvider,
          );
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        await ChatSystemProtectedStorage.verify(documentsRoot);
      }
      final lease = await _ChatCrossIsolateCoordinator.acquireUserMutationLease(
        documentsRoot,
        // 文件目录本身按 CID 的 UTF-8 十六进制分区；跨 isolate lease 必须使用同一物理分区键，
        // 否则启动静态清扫无法从目录名恢复原 user ID，也无法与运行态互斥。
        _ownerPath(userId),
      );
      final scope = _ChatUserLeaseScope(userId, bindingToken);
      try {
        if (bindingToken != null) {
          await _store.validateBindingFenceToken(bindingToken);
        }
        final result = await runZoned<Future<T>>(
          operation,
          zoneValues: <Object, Object>{_userMutationZoneKey: scope},
        );
        // 保持 fast path 到已登记 nested action 全部完成，避免 nested callback 后半段
        // 再进入同 user ID wrapper 时排到 outer 后面自锁；集合排空后的同步 continuation
        // 立即封口，后来才触发的旧 Zone 回调会重新取得正式 lease。
        await scope.drain();
        scope.stopAccepting();
        if (bindingToken != null && validateTokenAfter) {
          await _store.validateBindingFenceToken(bindingToken);
        }
        if (!Platform.environment.containsKey('FLUTTER_TEST')) {
          await ChatSystemProtectedStorage.verify(documentsRoot);
        }
        await lease.validateHealthy();
        return result;
      } finally {
        // 异步回调会继承注册时 Zone；先让 scope 失效，避免 lease 释放后长寿命
        // 回调继续命中嵌套 fast path 而永久绕过下一次跨 isolate 协调。
        scope.stopAccepting();
        // 释放失败必须上抛；遗留 lease 由下一进程启动 preflight 恢复。
        await lease.release();
      }
    });
  }

  static bool _sameBindingToken(
    ChatBindingFenceToken left,
    ChatBindingFenceToken right,
  ) =>
      left.ownerUserId == right.ownerUserId &&
      left.bindingRevision == right.bindingRevision &&
      left.accountId == right.accountId &&
      left.bindingScope == right.bindingScope &&
      left.generation == right.generation;

  Future<ChatBindingFenceToken> _convergeBindingFence(
    ChatRuntimeAccount account,
  ) {
    return _runUserFileMutation(
      userId: account.userId,
      operation: () async {
        final token = await _store.convergeFinalizedBinding(
          _bindingForAccount(account),
        );
        await _store.validateBindingFenceToken(token);
        return token;
      },
    );
  }

  Future<T> _runWithReadyBinding<T>(
    Future<T> Function(ChatRuntimeAccountContext context) operation,
  ) async {
    final context = await _readyContext(await _readAccount());
    return _runBindingFileMutation(
      context.bindingToken,
      () => operation(context),
    );
  }

  /// 发送只要求账户上下文在动作期间保持存活；MLS 与附件文件改写已经在各自
  /// 边界取得 user ID lease。网络投递绝不能再被外层文件锁包住。
  Future<T> _runWithReadyContext<T>(
    Future<T> Function(ChatRuntimeAccountContext context) operation,
  ) {
    return _runRuntimeOperation(() async {
      final context = await _readyContext(await _readAccount());
      return operation(context);
    });
  }

  /// 已可靠落盘的密文按“当前绑定 + 会话”保序后台投递。页面和 user ID 文件锁
  /// 均不等待网络；失败时本地出站队列继续保留，交由既有重试链路收敛。
  void _scheduleOutboundDelivery(
    ChatRuntimeAccountContext context,
    String conversationId,
    Future<void> Function() delivery,
  ) {
    final key = '${context.bindingToken.accountId}|$conversationId';
    unawaited(
      _runRuntimeOperation(
        () => _outboundDeliveryGate.run(key, delivery),
      ).catchError((Object _) {
        // 静默后台投递失败不覆盖本地消息；队列事实仍在，下次重试继续发送。
      }),
    );
  }

  /// 仅用于验证 AppLock 与已在途文件改写的时序，生产代码不得调用。
  @visibleForTesting
  Future<T> debugRunFileMutationForTest<T>(Future<T> Function() operation) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future<T>.error(UnsupportedError('仅 Flutter 测试允许注入 Chat 文件改写'));
    }
    return _runFileMutation(operation);
  }

  /// 验证终态会拒绝新的实时回调，仅用于 Flutter 测试。
  @visibleForTesting
  Future<T> debugRunRuntimeOperationForTest<T>(Future<T> Function() operation) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future<T>.error(UnsupportedError('仅 Flutter 测试允许注入 Chat 运行回调'));
    }
    return _runRuntimeOperation(operation);
  }

  /// 模拟后台 handler 在释放 lease 前对已触发回调执行实例级 drain。
  @visibleForTesting
  Future<void> debugDrainBackgroundRuntimeForTest() {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future<void>.error(
        UnsupportedError('仅 Flutter 测试允许收口 Chat 后台运行态'),
      );
    }
    return close();
  }

  /// 注入一组完整实时资源，验证 socket 与两个订阅的可重试关闭。
  @visibleForTesting
  Future<void> Function() debugRegisterRealtimeSessionForTest({
    required Future<void> Function() stopSocket,
    required Future<void> Function() cancelWakeSubscription,
    required Future<void> Function() cancelTokenSubscription,
  }) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('仅 Flutter 测试允许注入 Chat 实时资源');
    }
    _ensureActive();
    final session = _ChatRealtimeSession()
      ..attachSocket(stopSocket)
      ..attachWakeSubscription(cancelWakeSubscription)
      ..attachTokenSubscription(cancelTokenSubscription)
      ..markInitializationDone();
    _realtimeSessions.add(session);
    return () => _disposeRealtimeSession(session);
  }

  /// 把可控关闭操作注入真实 runtime 擦除链，仅用于验证失败后重试。
  @visibleForTesting
  void debugRegisterContextDisposerForTest(Future<void> Function() operation) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('仅 Flutter 测试允许注入 Chat 上下文关闭操作');
    }
    _ensureActive();
    if (_debugContextDisposerForTest != null) {
      throw StateError('Chat 测试上下文关闭操作已注入');
    }
    _debugContextDisposerForTest = _RetryableAsyncDisposer(operation);
  }

  /// 注入一个尚未完成的 ready flight，验证账户失效后 AppLock 仍能追踪它。
  @visibleForTesting
  void debugRegisterReadyFlightForTest(
    String accountId,
    Future<void> operation,
  ) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('仅 Flutter 测试允许注入 Chat 初始化任务');
    }
    _ensureActive();
    final key = 'debug-ready-flight|$accountId';
    if (_readyFlights.containsKey(key)) {
      throw StateError('Chat 测试初始化任务已注入');
    }
    _readyFlights[key] = operation.then<ChatRuntimeAccountContext>(
      (_) => throw StateError('Chat 测试初始化任务不生成真实上下文'),
    );
  }

  Future<SharedPreferences> get _prefs async {
    _ensureActive();
    final provided = _preferences;
    if (provided != null) {
      return provided;
    }
    return SharedPreferences.getInstance();
  }

  Future<ChatInboxOverview> readOverview({
    String? userId,
    required int pendingOutgoing,
    required int unreadCount,
  }) async {
    _ensureActive();
    final resolvedUserId = userId ?? await readUserId();
    return ChatInboxOverview(
      userId: resolvedUserId,
      pendingOutgoing: pendingOutgoing,
      unreadCount: unreadCount,
    );
  }

  /// 页面成功展示当前会话后，经 finalized 绑定门禁清零当前设备的本地未读数。
  Future<void> markConversationRead({
    required String conversationId,
    required int readThroughMillis,
  }) {
    return _runWithReadyBinding((context) async {
      final cleared = await _store.markConversationRead(
        bindingToken: context.bindingToken,
        ownerUserId: context.account.userId,
        conversationId: conversationId,
        readThroughMillis: readThroughMillis,
      );
      // 本机未读真源已经原子清零后，再按同一 conversation_id 清理系统通知。
      // 原生通知清理失败不能撤销已读事实，也不能误清其它会话或广场通知。
      if (cleared) {
        await _host.push
            .clearConversationNotifications(conversationId)
            .catchError((Object _) {});
      }
    });
  }

  Future<String?> readAccountId() async {
    _ensureActive();
    return (await _host.currentAccount())?.accountId;
  }

  Future<String?> readUserId() async {
    final userId = (await readCurrentUser()).userId;
    return userId.isEmpty ? null : userId;
  }

  /// SDK 完整页面只能复用当前运行实例的仓库，禁止自行创建第二个运行实例。
  ChatStore get chatStore => _store;

  /// 读取宿主当前明确选择的聊天身份，不扫描其它账户或建立第二条身份真源。
  Future<({String accountId, String userId})> readCurrentUser() {
    return _runRuntimeOperation(_readCurrentUser);
  }

  Future<({String accountId, String userId})> _readCurrentUser() async {
    _ensureActive();
    final account = await _host.currentAccount();
    if (account == null) return (accountId: '', userId: '');
    return (accountId: account.accountId, userId: account.userId);
  }

  /// 系统保护的短命明文工作目录；最终缓存位于同CID附件目录。
  Future<Directory> _plainDirectoryForBinding(
    ChatBindingFenceToken bindingToken,
  ) async {
    final attachmentDirectory = await _attachmentDirectoryForToken(
      bindingToken,
    );
    return Directory(
      '${attachmentDirectory.path}/${AttachmentVault.plainDirName}',
    );
  }

  /// 系统保护附件缓存只归当前user_id；公开绑定围栏复核文件读写，不重加密。
  Future<Directory> _attachmentDirectoryForToken(
    ChatBindingFenceToken bindingToken,
  ) {
    return _attachmentDirectoryForBinding(
      userId: bindingToken.ownerUserId,
      bindingRevision: bindingToken.bindingRevision,
      accountId: bindingToken.accountId,
    );
  }

  Future<Directory> _attachmentDirectoryForBinding({
    required String userId,
    required int bindingRevision,
    required String accountId,
  }) async {
    final bindingDirectory = await _bindingDirectory(
      userId: userId,
      bindingRevision: bindingRevision,
      accountId: accountId,
    );
    return Directory('${bindingDirectory.path}/attachments');
  }

  /// 清空短命明文附件。
  ///
  /// 明文按「**只在前台存活**」管理：App 启动、退到后台、删会话/退出账户三处
  /// 各 purge 一次。不做逐处所有权交接——UI 侧预览/播放/打开/转发路径太多，
  /// 漏一处这份明文就永久留在盘上。
  Future<void> purgePlainAttachments() async {
    final account = await _readAccount();
    final bindingToken = await _convergeBindingFence(account);
    return _runBindingFileMutation(
      bindingToken,
      () async => AttachmentVault.purgePlainDirectory(
        await _plainDirectoryForBinding(bindingToken),
      ),
    );
  }

  /// finalized 后收口旧账户上下文，推进公开绑定代次并保留同CID历史。
  /// MLS身份与状态不因账户换绑而重建，附件文件继续归同一CID。
  Future<void> convergeFinalizedBinding(ChatBinding current) async {
    current.validate();
    final accountIds = <String>{
      current.accountId,
      ..._accountContextKeys.keys,
      ..._blockedAccountIds,
      for (final context in _contextsPendingDisposal) context.account.accountId,
    };
    for (final accountId in accountIds) {
      await _invalidateAccountContext(accountId);
    }
    await _runUserFileMutation(
      userId: current.userId,
      operation: () async {
        _ensureActive();
        final token = await _store.convergeFinalizedBinding(current);
        await _store.validateBindingFenceToken(token);
        _blockedAccountIds.remove(current.accountId);
      },
    );
  }

  Future<Directory> _bindingDirectory({
    required String userId,
    required int bindingRevision,
    required String accountId,
  }) async {
    _ensureActive();
    final root = await _documentsDirectoryProvider();
    _ensureActive();
    return Directory('${root.path}/chat/by_user/${_ownerPath(userId)}');
  }

  /// 页面、轮询、WebSocket 和发送入口共享的唯一就绪入口。
  Future<void> ensureReady(String accountId) async {
    _ensureActive();
    final account = await _readAccount(expectedAccountId: accountId);
    await _readyContext(account);
  }

  /// 默认账户切换或本机 Chat 数据清理时精确失效该账户上下文。
  Future<void> invalidateAccount(String accountId) {
    _ensureActive();
    return _invalidateAccountContext(accountId, keepBlocked: false);
  }

  /// finalized 接管路径必须等此前网络与 MLS 上下文全部关闭后再建立新上下文。
  Future<void> _invalidateAccountContext(
    String accountId, {
    bool keepBlocked = true,
  }) async {
    _ensureActive();
    // 同步封住新 ready/realtime 入口，再开始任何 await；转换失败时保持 blocked，
    // 只能由明确的 converge/commit/discard 成功路径重新放行。
    _blockedAccountIds.add(accountId);
    _accountGenerations[accountId] = (_accountGenerations[accountId] ?? 0) + 1;
    final realtimeHub = _realtimeHubs[accountId];
    if (realtimeHub != null) await _closeRealtimeHub(realtimeHub);
    final invalidatedFlights = _readyFlights.entries
        .where((entry) => entry.key.endsWith('|$accountId'))
        .toList(growable: false);
    for (final entry in invalidatedFlights) {
      if (identical(_readyFlights[entry.key], entry.value)) {
        final _ = _readyFlights.remove(entry.key);
        _trackInvalidatedReadyFlight(entry.value);
      }
    }
    final sessions = _realtimeSessions
        .where((session) => session.belongsToAccount(accountId))
        .toList(growable: false);
    final contexts = <ChatRuntimeAccountContext>{
      for (final context in _readyContexts.values)
        if (context.account.accountId == accountId) context,
      for (final context in _contextsPendingDisposal)
        if (context.account.accountId == accountId) context,
    };
    final key = _accountContextKeys.remove(accountId);
    if (key != null) {
      final context = _readyContexts.remove(key);
      if (context != null) contexts.add(context);
    }
    final failures = <String>[];
    for (final session in sessions) {
      await _captureCleanupFailure(
        '关闭账户 Chat 实时会话',
        () => _disposeRealtimeSession(session),
        failures,
      );
    }
    // 这里尚未持有 user ID lease，等待旧 build 完成不会与它自锁；generation 会让
    // 完成结果在登记前自行 dispose，随后下面再复核 pending disposal。
    for (final entry in invalidatedFlights) {
      try {
        await entry.value;
      } catch (_) {
        // 初始化自身失败没有可复用上下文；dispose 失败会留在 pending 集合并重试。
      }
    }
    contexts.addAll(
      _contextsPendingDisposal.where(
        (context) => context.account.accountId == accountId,
      ),
    );
    final byUserId = <String, List<ChatRuntimeAccountContext>>{};
    for (final context in contexts) {
      byUserId
          .putIfAbsent(
            context.account.userId,
            () => <ChatRuntimeAccountContext>[],
          )
          .add(context);
    }
    for (final entry in byUserId.entries) {
      await _captureCleanupFailure(
        '排空账户 Chat 文件操作',
        () => _runUserFileMutation(userId: entry.key, operation: () async {}),
        failures,
      );
    }
    // barrier 已确认此前 flow/build/file action 全部离开；此时不持 user ID lease 关闭
    // 网络与 OpenMLS 操作已经排空，避免“持 admin lease 等待一个正在等同一
    // lease 的 tail”自锁。
    for (final context in contexts) {
      await _captureCleanupFailure(
        '关闭账户 Chat 上下文',
        () => _disposeContext(context),
        failures,
      );
    }
    await _host.invalidateAccount(accountId);
    if (failures.isNotEmpty) throw StateError(failures.join('\n'));
    if (!keepBlocked) _blockedAccountIds.remove(accountId);
  }

  void _trackInvalidatedReadyFlight(Future<ChatRuntimeAccountContext> flight) {
    if (!_readyFlightsPendingInvalidation.add(flight)) return;
    unawaited(
      flight.then<void>(
        (_) {
          _readyFlightsPendingInvalidation.remove(flight);
        },
        onError: (Object _, StackTrace _) {
          _readyFlightsPendingInvalidation.remove(flight);
        },
      ),
    );
  }

  static String directConversationId(String senderUserId, String peerUserId) {
    final members = [senderUserId, peerUserId]..sort();
    return 'dm:${members[0]}:${members[1]}';
  }

  Future<List<ChatDeliveryResult>> sendText({
    required String peerUserId,
    required String conversationId,
    required String text,
  }) async {
    final payload = ChatPayloadCodec.encode(ChatContent.text(text));
    await _savePendingDirectPayload(
      peerUserId: peerUserId,
      conversationId: conversationId,
      messageKind: ChatMessageKind.text,
      payload: payload,
    );
    return const <ChatDeliveryResult>[];
  }

  /// 用户点击发送后的第一持久边界。这里只依赖当前 finalized 账户和系统保护存储，
  /// 不等待 Firebase、Worker 登录、系统唤醒端点、设备公开钥或 WebSocket。
  Future<String> _savePendingDirectPayload({
    required String peerUserId,
    required String conversationId,
    required ChatMessageKind messageKind,
    required String payload,
    ChatMediaDraft? media,
    ChatMediaLocalCommitNotifier? onLocalCommitted,
    bool scheduleDelivery = true,
  }) async {
    _ensureActive();
    final account = await _readAccount();
    if (!await _host.canSend(account.userId)) {
      throw StateError('当前会话尚未通过宿主发送授权');
    }
    final bindingToken = await _convergeBindingFence(account);
    final createdAtMillis = DateTime.now().millisecondsSinceEpoch;
    final localMessageId = _newPendingMessageId(
      conversationId,
      createdAtMillis,
    );
    await _runBindingFileMutation(bindingToken, () async {
      if (media != null) {
        final content = ChatPayloadCodec.decode(payload);
        final attachmentId = content.attachmentId ?? '';
        if (!content.isMedia || attachmentId.isEmpty) {
          throw const FormatException('Chat 本地媒体待发送载荷无效');
        }
        await _copySentAttachmentToCacheMutation(
          bindingToken: bindingToken,
          conversationId: conversationId,
          attachmentId: attachmentId,
          fileName: media.fileName,
          contentType: media.contentType,
          sourcePath: media.sourcePath,
          byteSize: media.byteSize,
        );
      }
      await _store.savePendingOutgoingMessage(
        bindingToken: bindingToken,
        ownerUserId: account.userId,
        currentAccountId: account.accountId,
        localMessageId: localMessageId,
        conversationId: conversationId,
        recipientUserId: peerUserId,
        messageKind: messageKind,
        payload: payload,
        createdAtMillis: createdAtMillis,
      );
    });
    await onLocalCommitted?.call();
    if (scheduleDelivery) {
      _schedulePendingOutgoing(
        account: account,
        recipientUserId: peerUserId,
        conversationId: conversationId,
      );
    }
    return localMessageId;
  }

  /// 本地待发送行已经成立后，网络/MLS 转换在后台按账户+会话保序执行。失败不删除
  /// 本地消息；实时重连、轮询、网络恢复或推送唤醒都会再次进入同一收敛入口。
  void _schedulePendingOutgoing({
    required ChatRuntimeAccount account,
    String? recipientUserId,
    required String conversationId,
    bool resetBackoff = true,
  }) {
    final key = '${account.accountId}|$conversationId';
    _outboundRetryTimers.remove(key)?.cancel();
    if (resetBackoff) _outboundRetryAttempts.remove(key);
    unawaited(
      _runRuntimeOperation(
        () => _outboundDeliveryGate.run(key, () async {
          final current = await _readAccount(
            expectedAccountId: account.accountId,
          );
          final context = await _readyContext(current);
          final pendingConversionFailed = await _flushPendingOutgoing(
            context,
            recipientUserId: recipientUserId,
            conversationId: conversationId,
          );
          final delivery = await _retryQueuedMessages(
            context,
            recipientUserId: recipientUserId,
            conversationId: conversationId,
          );
          if (pendingConversionFailed || delivery.retryNeeded) {
            throw StateError('chat_outbound_retry_required');
          }
          _outboundRetryAttempts.remove(key);
        }),
      ).catchError((Object error) {
        debugPrint(
          '[ChatTrace] direction=outbound stage=context '
          'code=${chatSdkDiagnosticCode(error)}',
        );
        // 本机状态已经完成单次重建仍失败时停止盲重试；其它网络失败继续有界退避。
        _schedulePendingOutgoingRetry(
          key: key,
          account: account,
          recipientUserId: recipientUserId,
          conversationId: conversationId,
        );
      }),
    );
  }

  void _schedulePendingOutgoingRetry({
    required String key,
    required ChatRuntimeAccount account,
    required String? recipientUserId,
    required String conversationId,
  }) {
    if (_closed || _processWipeRequested) return;
    final attempt = _outboundRetryAttempts[key] ?? 0;
    if (attempt >= _outboundRetryDelays.length ||
        _outboundRetryTimers.containsKey(key)) {
      return;
    }
    _outboundRetryAttempts[key] = attempt + 1;
    late final Timer timer;
    timer = Timer(_outboundRetryDelays[attempt], () {
      if (!identical(_outboundRetryTimers[key], timer)) return;
      _outboundRetryTimers.remove(key);
      _schedulePendingOutgoing(
        account: account,
        recipientUserId: recipientUserId,
        conversationId: conversationId,
        resetBackoff: false,
      );
    });
    _outboundRetryTimers[key] = timer;
  }

  Future<List<ChatDeliveryResult>> sendMedia({
    required String peerUserId,
    required String conversationId,
    required ChatMediaDraft media,
    ChatMediaLocalCommitNotifier? onLocalCommitted,
  }) async {
    if (_host.mediaLimits.exceedsForKind(media.kind, media.byteSize)) {
      throw ChatMediaTooLargeException(
        byteSize: media.byteSize,
        limitBytes: _host.mediaLimits.limitForKind(media.kind),
        kind: media.kind,
      );
    }
    final attachmentId = _newPendingAttachmentId(
      conversationId,
      DateTime.now().millisecondsSinceEpoch,
    );
    final account = await _readAccount();
    final bindingToken = await _convergeBindingFence(account);
    final content = await _prepareEncryptedMedia(
      bindingToken: bindingToken,
      conversationId: conversationId,
      attachmentId: attachmentId,
      media: media,
      peerUserId: peerUserId,
    );
    try {
      await _savePendingDirectPayload(
        peerUserId: peerUserId,
        conversationId: conversationId,
        messageKind: media.kind,
        payload: ChatPayloadCodec.encode(content),
        media: media,
        onLocalCommitted: onLocalCommitted,
        scheduleDelivery: false,
      );
      // 本机消息和待上传密文均已持久成立；网络初始化、encrypted object storage multipart 与 MLS
      // 控制消息统一交给后台保序队列，上传失败只保留这一条待重试消息。
      _schedulePendingOutgoing(
        account: account,
        recipientUserId: peerUserId,
        conversationId: conversationId,
      );
      return const <ChatDeliveryResult>[];
    } catch (_) {
      final staged = await _pendingAttachmentUploadFile(
        bindingToken,
        conversationId,
        attachmentId,
      );
      await _runBindingFileMutation(bindingToken, () async {
        if (await staged.exists()) await staged.delete();
      });
      rethrow;
    }
  }

  /// 按当前聊天设备叶子建立独立附件组；MLS状态和每块文件持久化分开取得短屏障。
  Future<ChatContent> _prepareEncryptedMedia({
    required ChatBindingFenceToken bindingToken,
    required String conversationId,
    required String attachmentId,
    required ChatMediaDraft media,
    String? peerUserId,
  }) => _runRuntimeOperation(() async {
    final account = await _readAccount(
      expectedAccountId: bindingToken.accountId,
    );
    final context = await _readyContext(account);
    if (context.bindingToken != bindingToken) {
      await _runBindingFileMutation(bindingToken, () async {});
    }
    GroupState audience;
    if (conversationId.startsWith('grp:')) {
      audience = await context.crypto.groupState(conversationId);
    } else {
      final peer = peerUserId;
      if (peer == null) throw StateError('附件私聊收件人缺失');
      final packages = await _resolveKeyPackages(context, peer);
      audience = await _messageFlow(context).prepareAttachmentAudience(
        conversationId: conversationId,
        recipientUserId: peer,
        senderDeviceId: context.deviceId,
        keyPackages: packages,
        messageId: attachmentId,
      );
    }
    final roster = [...audience.memberIdentities]..sort();
    final self = '${context.account.userId}:${context.deviceId}';
    final packages = <MlsKeyPackage>[];
    for (final user in userIdsFromMemberIdentities(roster)) {
      final available = await _resolveKeyPackages(context, user);
      for (final member in roster.where(
        (m) => userIdFromMemberIdentity(m) == user && m != self,
      )) {
        final matching = available
            .where((p) => '${p.userId}:${p.deviceId}' == member)
            .toList();
        if (matching.length != 1 || !matching.single.lastResort) {
          throw StateError('附件当前设备资格已失效');
        }
        packages.add(matching.single);
      }
    }
    final engine = await _attachmentEngine(
      context,
      requireAudience: () async {
        final state = await context.crypto.groupState(conversationId);
        if (state.epoch != audience.epoch ||
            jsonEncode([...state.memberIdentities]..sort()) !=
                jsonEncode(roster)) {
          throw StateError('附件创建期间聊天名册已变化');
        }
      },
    );
    final target = await _pendingAttachmentUploadFile(
      bindingToken,
      conversationId,
      attachmentId,
    );
    try {
      return await engine.seal(
        attachmentId: attachmentId,
        byteSize: media.byteSize,
        source: File(media.sourcePath),
        target: target,
        members: roster,
        keyPackages: packages,
        contentBuilder: (d) => ChatContent.media(
          kind: media.kind,
          attachmentId: attachmentId,
          fileName: media.fileName,
          mime: media.contentType,
          byteSize: media.byteSize,
          width: media.width,
          height: media.height,
          durationMs: media.durationMs,
          blurhash: media.blurhash,
          attachmentChatEpoch: audience.epoch,
          attachmentGroupId: d.groupId,
          attachmentWelcome: base64UrlEncode(d.welcome).replaceAll('=', ''),
          attachmentMemberIdentities: d.members,
          attachmentSenderMemberIdentity: d.sender,
          attachmentChunkCount: d.chunkCount,
          plainSha256: d.plainSha256,
          cipherByteSize: d.cipherByteSize,
          cipherSha256: d.cipherSha256,
        ),
      );
    } catch (error, stackTrace) {
      // 名册失效后的清理只复核当前绑定，不再要求已经失效的原聊天名册。
      // 身份失效则禁止旧令牌写入，准确协议状态仍受七天过期清理约束。
      try {
        final cleanup = await _attachmentEngine(context);
        await cleanup.abort(MlsAttachment.groupId(self, attachmentId));
      } catch (_) {
        debugPrint(
          '[ChatTrace] direction=attachment stage=cleanup code=attachment_cleanup_deferred',
        );
      }
      try {
        await _runBindingFileMutation(bindingToken, () async {
          if (await target.exists()) await target.delete();
        });
      } catch (_) {
        debugPrint(
          '[ChatTrace] direction=attachment stage=cleanup code=attachment_cleanup_deferred',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  });

  Future<MlsAttachment> _attachmentEngine(
    ChatRuntimeAccountContext context, {
    Future<void> Function()? requireAudience,
  }) async => MlsAttachment(
    crypto: context.crypto,
    store: context.stateStore ?? (throw StateError('附件MLS存储缺失')),
    identity: context.identity,
    protectedRoot: await _attachmentDirectoryForToken(context.bindingToken),
    mutate: <T>(operation) =>
        _runBindingFileMutation<T>(context.bindingToken, operation),
    requireCurrent: () async {
      _ensureActive();
      await _runBindingFileMutation(context.bindingToken, () async {});
      await requireAudience?.call();
    },
  );

  /// 上传后和发送控制前复核原聊天epoch/名册与当前设备资格，不扩大原附件收件集合。
  Future<void> _requireAttachmentAudience(
    ChatRuntimeAccountContext context,
    String conversationId,
    ChatContent content,
  ) async {
    await _runBindingFileMutation(context.bindingToken, () async {});
    final state = await context.crypto.groupState(conversationId);
    final members = [...state.memberIdentities]..sort();
    if (state.epoch != content.attachmentChatEpoch ||
        jsonEncode(members) != jsonEncode(content.attachmentMemberIdentities) ||
        content.attachmentSenderMemberIdentity !=
            '${context.account.userId}:${context.deviceId}') {
      throw const _AttachmentAudienceChanged();
    }
    final self = '${context.account.userId}:${context.deviceId}';
    for (final user in userIdsFromMemberIdentities(members)) {
      final packages = await _resolveKeyPackages(context, user);
      for (final member in members.where(
        (m) => m != self && userIdFromMemberIdentity(m) == user,
      )) {
        if (packages
                .where(
                  (p) => '${p.userId}:${p.deviceId}' == member && p.lastResort,
                )
                .length !=
            1) {
          throw const _AttachmentAudienceChanged();
        }
      }
    }
    await _runBindingFileMutation(context.bindingToken, () async {});
  }

  /// 当前绑定内只丢弃准确待发附件；远端清理不持有本机文件屏障。
  Future<void> _discardPendingAttachment(
    ChatRuntimeAccountContext context,
    ChatPendingOutgoingMessage pending,
  ) async {
    final content = ChatPayloadCodec.decode(pending.payload);
    if (!content.isMedia) throw StateError('只能终结准确附件操作');
    final id = content.attachmentId!;
    await _store.markPendingOutgoingFailed(
      bindingToken: context.bindingToken,
      ownerUserId: context.account.userId,
      localMessageId: pending.localMessageId,
    );
    await _runBindingFileMutation(context.bindingToken, () async {
      final cipher = await _pendingAttachmentUploadFile(
        context.bindingToken,
        pending.conversationId,
        id,
      );
      final marker = await _pendingAttachmentUploadedMarker(
        context.bindingToken,
        pending.conversationId,
        id,
      );
      if (await cipher.exists()) await cipher.delete();
      if (await marker.exists()) await marker.delete();
    });
    try {
      await context.transport.abortAttachment(id);
    } catch (_) {
      // 本机已明确失败且不会重发；远端不透明对象继续受既有七天期限约束。
      debugPrint(
        '[ChatTrace] direction=attachment stage=cleanup code=attachment_cleanup_deferred',
      );
    }
  }

  Future<File> _pendingAttachmentUploadFile(
    ChatBindingFenceToken bindingToken,
    String conversationId,
    String attachmentId,
  ) async => File(
    '${(await _attachmentDirectoryForToken(bindingToken)).path}'
    '/${_safePath(conversationId)}/.pending_upload/'
    '${_safePath(attachmentId)}.cipher',
  );

  Future<File> _pendingAttachmentUploadedMarker(
    ChatBindingFenceToken bindingToken,
    String conversationId,
    String attachmentId,
  ) async => File(
    '${(await _pendingAttachmentUploadFile(bindingToken, conversationId, attachmentId)).path}.uploaded',
  );

  /// 发送内置贴纸只走与文字相同的 OpenMLS 密文邮箱，不建立 WebRTC 连接。
  Future<List<ChatDeliveryResult>> sendSticker({
    required String peerUserId,
    required String conversationId,
    required String packId,
    required String stickerId,
  }) async {
    final payload = ChatPayloadCodec.encode(
      ChatContent.sticker(packId: packId, stickerId: stickerId),
    );
    await _savePendingDirectPayload(
      peerUserId: peerUserId,
      conversationId: conversationId,
      messageKind: ChatMessageKind.sticker,
      payload: payload,
    );
    return const <ChatDeliveryResult>[];
  }

  // ==== 私密小群 ====

  /// 建群：选联系人 user ID，读取其群聊公开包批量加入，创建者为 admin。
  Future<ChatGroup> createGroup({
    required String name,
    List<String> inviteeUserIds = const [],
  }) {
    return _runWithReadyBinding((context) async {
      final invitees = await _fetchInviteeKeyPackages(context, inviteeUserIds);
      final groupId = newGroupId(context.account.userId);
      return _groupFlow(context).createGroup(
        groupId: groupId,
        name: name,
        userId: context.account.userId,
        localDeviceId: context.deviceId,
        invitees: invitees,
      );
    });
  }

  /// 加人(仅 admin)。
  Future<void> addGroupMembers({
    required String groupId,
    required List<String> inviteeUserIds,
  }) {
    return _runWithReadyBinding((context) async {
      final invitees = await _fetchInviteeKeyPackages(context, inviteeUserIds);
      await _groupFlow(context).addMembers(
        groupId: groupId,
        actorUserId: context.account.userId,
        actorDeviceId: context.deviceId,
        invitees: invitees,
      );
    });
  }

  /// 删人（仅 admin，按 user ID）。
  Future<void> removeGroupMembers({
    required String groupId,
    required List<String> targetUserIds,
  }) {
    return _runWithReadyBinding((context) async {
      await _groupFlow(context).removeMembers(
        groupId: groupId,
        actorUserId: context.account.userId,
        actorDeviceId: context.deviceId,
        targetUserIds: targetUserIds,
      );
    });
  }

  /// 退群(本机标记已退,并发退群请求让 admin 重钥)。
  Future<void> leaveGroup(String groupId) {
    return _runWithReadyBinding((context) async {
      await _groupFlow(context).leaveGroup(groupId);
    });
  }

  /// 改群名(仅 admin)。
  Future<void> renameGroup({required String groupId, required String name}) {
    return _runWithReadyBinding((context) async {
      await _groupFlow(context).renameGroup(groupId, name);
    });
  }

  /// 群发文本。
  Future<List<ChatDeliveryResult>> sendGroupText({
    required String groupId,
    required String text,
  }) {
    return _runWithReadyContext((context) async {
      if (!await _host.canSend(context.account.userId)) {
        throw StateError('当前会话尚未通过宿主发送授权');
      }
      return _groupFlow(context).sendGroupText(
        groupId: groupId,
        senderUserId: context.account.userId,
        senderDeviceId: context.deviceId,
        text: text,
      );
    });
  }

  /// 群发内置贴纸(零字节,收端本地渲染)。
  Future<List<ChatDeliveryResult>> sendGroupSticker({
    required String groupId,
    required String packId,
    required String stickerId,
  }) {
    return _runWithReadyContext((context) async {
      if (!await _host.canSend(context.account.userId)) {
        throw StateError('当前会话尚未通过宿主发送授权');
      }
      return _groupFlow(context).sendGroupSticker(
        groupId: groupId,
        senderUserId: context.account.userId,
        senderDeviceId: context.deviceId,
        packId: packId,
        stickerId: stickerId,
      );
    });
  }

  /// 群附件与直聊统一先落本机待发消息，再后台上传一次并扇出控制消息。
  Future<List<ChatDeliveryResult>> sendGroupAttachment({
    required String groupId,
    required ChatMediaDraft media,
    ChatMediaLocalCommitNotifier? onLocalCommitted,
  }) {
    if (_host.mediaLimits.exceedsForKind(media.kind, media.byteSize)) {
      throw ChatMediaTooLargeException(
        byteSize: media.byteSize,
        limitBytes: _host.mediaLimits.limitForKind(media.kind),
        kind: media.kind,
      );
    }
    return () async {
      final account = await _readAccount();
      if (!await _host.canSend(account.userId)) {
        throw StateError('当前会话尚未通过宿主发送授权');
      }
      final bindingToken = await _convergeBindingFence(account);
      final attachmentId = _newPendingAttachmentId(
        groupId,
        DateTime.now().millisecondsSinceEpoch,
      );
      final content = await _prepareEncryptedMedia(
        bindingToken: bindingToken,
        conversationId: groupId,
        attachmentId: attachmentId,
        media: media,
      );
      try {
        await _savePendingDirectPayload(
          peerUserId: groupId,
          conversationId: groupId,
          messageKind: media.kind,
          payload: ChatPayloadCodec.encode(content),
          media: media,
          onLocalCommitted: onLocalCommitted,
          scheduleDelivery: false,
        );
        _schedulePendingOutgoing(
          account: account,
          recipientUserId: groupId,
          conversationId: groupId,
        );
        return const <ChatDeliveryResult>[];
      } catch (_) {
        final staged = await _pendingAttachmentUploadFile(
          bindingToken,
          groupId,
          attachmentId,
        );
        if (await staged.exists()) await staged.delete();
        rethrow;
      }
    }();
  }

  /// 逐个读取被邀请 user ID 的 OpenMLS 群聊公开包；私聊绝不进入这里。
  Future<List<MlsKeyPackage>> _fetchInviteeKeyPackages(
    ChatRuntimeAccountContext context,
    List<String> inviteeUserIds,
  ) async {
    final packages = <MlsKeyPackage>[];
    for (final userId in inviteeUserIds) {
      final resolved = await _resolveKeyPackages(context, userId);
      for (final keyPackage in resolved) {
        if (keyPackage.userId != userId) {
          throw StateError('TataChatServer 返回的 KeyPackage user ID 与请求目标不一致');
        }
      }
      packages.addAll(resolved);
    }
    return packages;
  }

  Future<List<MlsKeyPackage>> _resolveKeyPackages(
    ChatRuntimeAccountContext context,
    String targetUserId,
  ) async {
    final resolved = await context.transport.resolveKeyPackages(targetUserId);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (resolved.isEmpty ||
        resolved.any(
          (keyPackage) =>
              keyPackage.userId != targetUserId ||
              keyPackage.notBeforeMillis >= now ||
              keyPackage.notAfterMillis <= now ||
              !keyPackage.lastResort,
        )) {
      throw StateError('TataChatServer 返回的 KeyPackage 当前不可用');
    }
    return resolved;
  }

  ChatGroupFlow<ChatBindingFenceToken> _groupFlow(
    ChatRuntimeAccountContext context,
  ) {
    return ChatGroupFlow<ChatBindingFenceToken>(
      crypto: context.crypto,
      store: _store,
      bindingToken: context.bindingToken,
      ownerUserId: context.account.userId,
      userId: context.account.userId,
      currentAccountId: context.account.accountId,
      localDeviceId: context.deviceId,
      deliveryScheduler: (conversationId, delivery) =>
          _scheduleOutboundDelivery(context, conversationId, delivery),
      afterIncomingStore: (message, content) async =>
          _scheduleIncomingCloudAttachment(
            context,
            message.conversationId,
            content,
          ),
      deliverer: (message, _, recipientUserId, recipientDeviceId) {
        return ChatFlow.deliverWithTransport(
          transport: context.transport,
          message: message,
          recipientUserId: recipientUserId,
        );
      },
    );
  }

  /// 批量解析媒体在本机缓存中的绝对路径。字节未到达时不入结果，由 UI 显示占位。
  /// 同一页面批次共用当前公开绑定和文件操作代次。
  Future<Map<String, String>> resolveCachedMediaPaths({
    required String conversationId,
    required List<ChatContent> contents,
  }) async {
    if (contents.isEmpty) return const <String, String>{};
    try {
      final account = await _readAccount();
      final context = await _readyContext(account);
      final bindingToken = context.bindingToken;
      final paths = await _runBindingFileMutation(bindingToken, () async {
        final cacheDirectory = await _attachmentDirectoryForToken(bindingToken);
        final plainDirectory = await _plainDirectoryForBinding(bindingToken);

        final paths = <String, String>{};
        // 每项只读系统保护缓存，复核当前公开绑定和明文大小。
        for (final content in contents) {
          final attachmentId = content.attachmentId ?? '';
          if (!content.isMedia || attachmentId.isEmpty) continue;
          try {
            final cached = await ChatFlow.readCachedAttachment(
              conversationId: conversationId,
              attachmentId: attachmentId,
              fileName: content.fileName ?? '',
              contentType: content.mime ?? 'application/octet-stream',
              clearByteSize: content.byteSize ?? 0,
              cacheDirectory: cacheDirectory,
              plainDirectory: plainDirectory,
            );
            final path = cached?.filePath;
            if (path != null && path.isNotEmpty) paths[attachmentId] = path;
          } catch (_) {
            // 单个缓存损坏或仍未完整到达时跳过该项，不能拖累同批其它媒体。
          }
        }
        return Map<String, String>.unmodifiable(paths);
      });
      // 控制消息已经是本机真值；缓存缺失的附件在独立任务中补取，不能挡住本次文字首屏。
      for (final content in contents) {
        final attachmentId = content.attachmentId ?? '';
        if (content.isMedia &&
            attachmentId.isNotEmpty &&
            !paths.containsKey(attachmentId)) {
          _scheduleIncomingCloudAttachment(context, conversationId, content);
        }
      }
      return paths;
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<ChatDownloadedAttachment> downloadAttachment({
    required String conversationId,
    required String controlPlaintext,
  }) {
    return _runWithReadyContext(
      (context) =>
          _downloadAttachment(context, conversationId, controlPlaintext),
    );
  }

  Future<ChatDownloadedAttachment> _downloadAttachment(
    ChatRuntimeAccountContext context,
    String conversationId,
    String controlPlaintext,
  ) async {
    final bindingToken = context.bindingToken;
    final content = ChatPayloadCodec.decode(controlPlaintext);
    if (content.isMedia) {
      await _downloadIncomingCloudAttachment(context, conversationId, content);
    }
    final cacheDirectory = await _attachmentDirectoryForToken(bindingToken);
    return ChatFlow.downloadAttachment(
      conversationId: conversationId,
      controlPlaintext: controlPlaintext,
      cacheDirectory: cacheDirectory,
      plainDirectory: await _plainDirectoryForBinding(bindingToken),
    );
  }

  Future<void> deleteLocalConversation(String conversationId) {
    return _runWithReadyBinding(
      (context) => _deleteLocalConversation(context, conversationId),
    );
  }

  /// 服务端账户注销成功后，协调关闭该 user ID 的 Chat 上下文并清除全部本机 Chat 数据。
  ///
  /// service 只调用本运行态边界，禁止直接绕过上下文/文件收口去删 ChatStore。
  Future<void> clearAllForUserId({
    required String userId,
    required String accountId,
  }) async {
    final accountIds = <String>{accountId};
    for (final context in <ChatRuntimeAccountContext>{
      ..._readyContexts.values,
      ..._contextsPendingDisposal,
    }) {
      if (context.account.userId == userId) {
        accountIds.add(context.account.accountId);
      }
    }
    for (final session in _realtimeSessions) {
      if (session.ownerUserId == userId && session.accountId != null) {
        accountIds.add(session.accountId!);
      }
    }
    for (final id in accountIds) {
      await _invalidateAccountContext(id);
    }
    return _runUserFileMutation(
      userId: userId,
      operation: () async {
        _ensureActive();
        await _store.clearAllForUserId(userId);
        await MlsStateStore.erase(userId: userId);

        final documentsRoot = (await _documentsDirectoryProvider()).absolute;
        final userDirectory = Directory(
          '${documentsRoot.path}${Platform.pathSeparator}chat'
          '${Platform.pathSeparator}by_user'
          '${Platform.pathSeparator}${_ownerPath(userId)}',
        ).absolute;
        if (userDirectory.path == userDirectory.parent.path ||
            !userDirectory.path.startsWith(
              '${documentsRoot.path}${Platform.pathSeparator}chat'
              '${Platform.pathSeparator}by_user${Platform.pathSeparator}',
            )) {
          throw StateError('Chat user ID 清理目录越过本机 Chat 边界');
        }
        final type = await FileSystemEntity.type(
          userDirectory.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.link) {
          await Link(userDirectory.path).delete();
        } else if (type != FileSystemEntityType.notFound) {
          await userDirectory.delete(recursive: true);
        }

        final prefs = await _prefs;
        final safeUser = _safePath(userId);
        final staleKeys = prefs.getKeys().where(
          (key) =>
              (key.startsWith('$_kPushRegistrationPrefix.') &&
              key.contains('.$safeUser.')),
        );
        for (final key in staleKeys.toList(growable: false)) {
          await prefs.remove(key);
        }
      },
    );
  }

  Future<void> _deleteLocalConversation(
    ChatRuntimeAccountContext context,
    String conversationId,
  ) async {
    final bindingToken = context.bindingToken;
    await _store.deleteConversation(
      context.account.userId,
      conversationId,
      bindingToken: bindingToken,
    );
    final attachmentDir = Directory(
      '${(await _attachmentDirectoryForToken(bindingToken)).path}/${_safePath(conversationId)}',
    );
    if (await attachmentDir.exists()) {
      await attachmentDir.delete(recursive: true);
    }
    // purge 点之三:删会话同时清掉可能已解密出来的短命明文。
    await AttachmentVault.purgePlainDirectory(
      await _plainDirectoryForBinding(bindingToken),
    );
  }

  /// 重试设备本机队列中的消息与附件上传。
  ///
  /// 媒体先完成私有 encrypted object storage 密文上传，再发送端到端加密控制消息；附件网络失败只保留
  /// 当前本机 pending，不得越过同会话顺序或阻塞其它会话。
  Future<int> retryOutgoing({String? recipientUserId, String? conversationId}) {
    return _runWithReadyBinding((context) async {
      await _flushPendingOutgoing(
        context,
        recipientUserId: recipientUserId,
        conversationId: conversationId,
      );
      final delivery = await _retryQueuedMessages(
        context,
        recipientUserId: recipientUserId,
        conversationId: conversationId,
      );
      return delivery.sent;
    });
  }

  /// 把本机系统保护存储中的待发送行按会话顺序转换为正式 MLS Message。
  ///
  /// 直聊附件的 encrypted object storage 上传不是 MLS 操作，必须先移出会话门闩独立执行；否则一张
  /// 上传缓慢的图片会把同会话后续文字、表情和贴纸全部堵在本机 pending。附件
  /// 上传完成后重新进入本方法生成控制 Message，所有 MLS 状态改写仍只发生在
  /// 会话门闩内。群聊保持严格顺序，不越过尚未上传的媒体。
  Future<bool> _flushPendingOutgoing(
    ChatRuntimeAccountContext context, {
    String? recipientUserId,
    String? conversationId,
  }) async {
    // FCM 后台 isolate 只补拉、验密、落库和通知；出站队列只属于前台主
    // isolate。禁止推送唤醒后重复 prepare/abort 同一附件。
    if (_receiveOnly) return false;
    final pending = await _store.readPendingOutgoingMessages(
      bindingToken: context.bindingToken,
      ownerUserId: context.account.userId,
      currentAccountId: context.account.accountId,
      recipientUserId: recipientUserId,
      conversationId: conversationId,
    );
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    for (final item in pending) {
      if (nowMillis - item.createdAtMillis >=
          chatSdkMessageRetention.inMilliseconds) {
        await _expirePendingOutgoing(context, item);
        continue;
      }
      final content = ChatPayloadCodec.decode(item.payload);
      if (!item.conversationId.startsWith('grp:') && content.isMedia) {
        final attachmentId = content.attachmentId ?? '';
        if (attachmentId.isEmpty) return true;
        final uploaded = await _pendingAttachmentUploadedMarker(
          context.bindingToken,
          item.conversationId,
          attachmentId,
        );
        if (!await uploaded.exists()) {
          _schedulePendingMediaUpload(context, item, content);
          // 直聊 Application 也是 OpenMLS 密文；附件上传不持有 MLS 门闩，后续
          // 消息可立即生成 Message，展示顺序仍由原始 createdAtMillis 恢复。
          continue;
        }
      }
      try {
        await _sendPendingOutgoing(context, item);
      } on Object catch (error) {
        if (error is _AttachmentAudienceChanged) {
          await _discardPendingAttachment(context, item);
          continue;
        }
        debugPrint(
          '[ChatTrace] direction=outbound stage=message '
          'code=${chatSdkDiagnosticCode(error)}',
        );
        return true;
      }
    }
    return false;
  }

  Future<void> _expirePendingOutgoing(
    ChatRuntimeAccountContext context,
    ChatPendingOutgoingMessage pending,
  ) async {
    await _store.markPendingOutgoingFailed(
      bindingToken: context.bindingToken,
      ownerUserId: context.account.userId,
      localMessageId: pending.localMessageId,
    );
    final content = ChatPayloadCodec.decode(pending.payload);
    final attachmentId = content.attachmentId ?? '';
    if (!content.isMedia || attachmentId.isEmpty) return;
    final staged = await _pendingAttachmentUploadFile(
      context.bindingToken,
      pending.conversationId,
      attachmentId,
    );
    final uploaded = await _pendingAttachmentUploadedMarker(
      context.bindingToken,
      pending.conversationId,
      attachmentId,
    );
    if (await uploaded.exists()) {
      await context.transport
          .abortAttachment(attachmentId)
          .catchError((Object _) {});
      try {
        await uploaded.delete();
      } catch (_) {
        // 过期状态已经落库；残留标记随会话本地清理收口。
      }
    }
    try {
      if (await staged.exists()) await staged.delete();
    } catch (_) {
      // 过期状态已经落库；残留密文随会话本地清理收口。
    }
  }

  /// 在会话门闩之外上传一条直聊附件。相同 attachmentId 全进程只允许一个上传
  /// Future；成功后重新调度原会话发送媒体控制消息，失败走既有有界退避。
  void _schedulePendingMediaUpload(
    ChatRuntimeAccountContext context,
    ChatPendingOutgoingMessage pending,
    ChatContent content,
  ) {
    final attachmentId = content.attachmentId ?? '';
    final retryAt = _mediaUploadRetryAt[attachmentId];
    if (retryAt != null && DateTime.now().isBefore(retryAt)) return;
    if (attachmentId.isEmpty ||
        _mediaUploadBusy ||
        !_mediaBytesInFlight.add(attachmentId)) {
      return;
    }
    _mediaUploadBusy = true;
    unawaited(
      _runRuntimeOperation(() async {
        try {
          await _uploadPendingDirectAttachment(context, pending, content);
          _mediaUploadFailures.remove(attachmentId);
          _mediaUploadRetryAt.remove(attachmentId);
        } finally {
          _mediaBytesInFlight.remove(attachmentId);
          _mediaUploadBusy = false;
        }
        _schedulePendingOutgoing(
          account: context.account,
          recipientUserId: pending.recipientUserId,
          conversationId: pending.conversationId,
        );
      }).catchError((Object error) async {
        _mediaBytesInFlight.remove(attachmentId);
        _mediaUploadBusy = false;
        if (error is _AttachmentAudienceChanged) {
          await _discardPendingAttachment(context, pending);
          return;
        }
        final failures = (_mediaUploadFailures[attachmentId] ?? 0) + 1;
        _mediaUploadFailures[attachmentId] = failures;
        final delay = switch (failures) {
          1 => const Duration(seconds: 5),
          2 => const Duration(seconds: 15),
          3 => const Duration(minutes: 1),
          _ => const Duration(minutes: 5),
        };
        _mediaUploadRetryAt[attachmentId] = DateTime.now().add(delay);
        // 每条附件独立有界退避，禁止同一会话中的多条失败附件每两秒共同
        // prepare/abort；普通文字、表情和贴纸不经过该等待。
        unawaited(
          Future<void>.delayed(
            delay,
            () => _schedulePendingOutgoing(
              account: context.account,
              recipientUserId: pending.recipientUserId,
              conversationId: pending.conversationId,
            ),
          ),
        );
        // 当前失败附件进入退避后立即调度下一条；单并发只限制附件字节，
        // 不限制普通消息，也不会让一条坏附件占住全队列。
        _schedulePendingOutgoing(
          account: context.account,
          recipientUserId: pending.recipientUserId,
          conversationId: pending.conversationId,
        );
      }),
    );
  }

  /// 对象授权取原附件成员，排除本设备；同CID其他设备仍需下载权限。
  List<String> _attachmentRecipientUserIds(ChatContent content) =>
      userIdsFromMemberIdentities(
        content.attachmentMemberIdentities!.where(
          (member) => member != content.attachmentSenderMemberIdentity,
        ),
      );

  Future<void> _uploadPendingDirectAttachment(
    ChatRuntimeAccountContext context,
    ChatPendingOutgoingMessage pending,
    ChatContent content,
  ) async {
    final attachmentId = content.attachmentId ?? '';
    final cipherByteSize = content.cipherByteSize ?? -1;
    final cipherSha256 = content.cipherSha256 ?? '';
    if (attachmentId.isEmpty || cipherByteSize < 1 || cipherSha256.isEmpty) {
      throw StateError('Chat 本地待发送附件密文元数据无效');
    }
    final staged = await _pendingAttachmentUploadFile(
      context.bindingToken,
      pending.conversationId,
      attachmentId,
    );
    final uploaded = await _pendingAttachmentUploadedMarker(
      context.bindingToken,
      pending.conversationId,
      attachmentId,
    );
    if (await uploaded.exists()) {
      await _requireAttachmentAudience(
        context,
        pending.conversationId,
        content,
      );
      return;
    }
    if (!await staged.exists() || await staged.length() != cipherByteSize) {
      throw StateError('Chat 本地待上传附件密文缺失');
    }
    try {
      await context.transport.uploadEncryptedAttachment(
        attachmentId: attachmentId,
        recipientUserIds: _attachmentRecipientUserIds(content),
        cipherFile: staged,
        cipherByteSize: cipherByteSize,
        cipherSha256: cipherSha256,
      );
      await _requireAttachmentAudience(
        context,
        pending.conversationId,
        content,
      );
      await _runBindingFileMutation(
        context.bindingToken,
        () => uploaded.writeAsString('uploaded', flush: true),
      );
    } catch (_) {
      // transport 是上传事务唯一所有者，失败时已完成一次 abort；运行态禁止
      // 再次中止同一 attachmentId，避免重复 encrypted object storage/D1 写入。
      rethrow;
    }
    try {
      await _runBindingFileMutation(
        context.bindingToken,
        () => staged.delete(),
      );
    } catch (_) {
      // 上传标记已持久成立；原帧文件残留由准确会话清理。
    }
  }

  Future<void> _sendPendingOutgoing(
    ChatRuntimeAccountContext context,
    ChatPendingOutgoingMessage pending,
  ) async {
    final content = ChatPayloadCodec.decode(pending.payload);
    if (content.kind != pending.messageKind) {
      throw StateError('Chat 本地待发送消息类型与载荷不一致');
    }
    if (pending.conversationId.startsWith('grp:')) {
      if (!content.isMedia) {
        throw StateError('Chat 群本地待发送载荷类型不合法');
      }
      await _sendPendingGroupAttachment(context, pending, content);
      return;
    }
    final flow = _messageFlow(context, scheduleDelivery: false);
    final recipientKeyPackages = content.isMedia
        ? const <MlsKeyPackage>[]
        : await context.transport.resolveKeyPackages(pending.recipientUserId);

    Future<void> send() async {
      switch (content.kind) {
        case ChatMessageKind.text:
          await flow.sendText(
            conversationId: pending.conversationId,
            senderUserId: context.account.userId,
            recipientUserId: pending.recipientUserId,
            senderDeviceId: context.deviceId,
            recipientKeyPackages: recipientKeyPackages,
            text: content.text ?? '',
            pendingLocalMessageId: pending.localMessageId,
            createdAtMillis: pending.createdAtMillis,
          );
        case ChatMessageKind.sticker:
          await flow.sendSticker(
            conversationId: pending.conversationId,
            senderUserId: context.account.userId,
            recipientUserId: pending.recipientUserId,
            senderDeviceId: context.deviceId,
            recipientKeyPackages: recipientKeyPackages,
            packId: content.packId ?? '',
            stickerId: content.stickerId ?? '',
            pendingLocalMessageId: pending.localMessageId,
            createdAtMillis: pending.createdAtMillis,
          );
        case ChatMessageKind.image:
        case ChatMessageKind.video:
        case ChatMessageKind.file:
        case ChatMessageKind.audio:
          await _sendPendingMedia(
            context: context,
            flow: flow,
            pending: pending,
            content: content,
          );
      }
    }

    await send();
  }

  Future<void> _sendPendingMedia({
    required ChatRuntimeAccountContext context,
    required ChatFlow<ChatBindingFenceToken> flow,
    required ChatPendingOutgoingMessage pending,
    required ChatContent content,
  }) async {
    final attachmentId = content.attachmentId ?? '';
    if (attachmentId.isEmpty) {
      throw StateError('Chat 本地待发送附件密文元数据无效');
    }
    final uploaded = await _pendingAttachmentUploadedMarker(
      context.bindingToken,
      pending.conversationId,
      attachmentId,
    );
    if (!await uploaded.exists()) {
      throw StateError('Chat 附件密文仍在后台上传');
    }
    if (!(await context.crypto.pendingMessageResults(
      pending.localMessageId,
    )).any((r) => (r['result'] as Map)['application_wire_hex'] is String)) {
      await _requireAttachmentAudience(
        context,
        pending.conversationId,
        content,
      );
    }
    await flow.sendMediaControl(
      conversationId: pending.conversationId,
      senderUserId: context.account.userId,
      recipientUserId: pending.recipientUserId,
      senderDeviceId: context.deviceId,
      media: content,
      pendingLocalMessageId: pending.localMessageId,
      createdAtMillis: pending.createdAtMillis,
    );
    await _runBindingFileMutation(context.bindingToken, () async {
      if (await uploaded.exists()) await uploaded.delete();
    });
  }

  Future<void> _sendPendingGroupAttachment(
    ChatRuntimeAccountContext context,
    ChatPendingOutgoingMessage pending,
    ChatContent content,
  ) async {
    final attachmentId = content.attachmentId ?? '';
    final cipherByteSize = content.cipherByteSize ?? -1;
    final cipherSha256 = content.cipherSha256 ?? '';
    if (attachmentId.isEmpty || cipherByteSize < 1 || cipherSha256.isEmpty) {
      throw StateError('Chat 群待发送附件密文元数据无效');
    }
    final flow = _groupFlow(context);
    final recipients = _attachmentRecipientUserIds(content);
    final staged = await _pendingAttachmentUploadFile(
      context.bindingToken,
      pending.conversationId,
      attachmentId,
    );
    final uploaded = await _pendingAttachmentUploadedMarker(
      context.bindingToken,
      pending.conversationId,
      attachmentId,
    );
    if (!await uploaded.exists()) {
      if (!await staged.exists() || await staged.length() != cipherByteSize) {
        throw StateError('Chat 群待上传附件密文缺失');
      }
      try {
        await context.transport.uploadEncryptedAttachment(
          attachmentId: attachmentId,
          recipientUserIds: recipients,
          cipherFile: staged,
          cipherByteSize: cipherByteSize,
          cipherSha256: cipherSha256,
        );
        await _requireAttachmentAudience(
          context,
          pending.conversationId,
          content,
        );
        await _runBindingFileMutation(
          context.bindingToken,
          () => uploaded.writeAsString('uploaded', flush: true),
        );
      } catch (_) {
        // 上传事务负责网络失败中止；受众变化由准确待发动作终结入口清理。
        rethrow;
      }
      try {
        await _runBindingFileMutation(
          context.bindingToken,
          () => staged.delete(),
        );
      } catch (_) {
        // 上传标记是远端成功真值，缓存清理留给会话删除统一收口。
      }
    }
    if (!(await context.crypto.pendingMessageResults(
      pending.localMessageId,
    )).any((r) => (r['result'] as Map)['application_wire_hex'] is String)) {
      await _requireAttachmentAudience(
        context,
        pending.conversationId,
        content,
      );
    }
    await flow.sendGroupAttachmentControl(
      groupId: pending.conversationId,
      senderUserId: context.account.userId,
      senderDeviceId: context.deviceId,
      content: content,
      pendingLocalMessageId: pending.localMessageId,
      createdAtMillis: pending.createdAtMillis,
    );
    await _runBindingFileMutation(context.bindingToken, () async {
      if (await uploaded.exists()) await uploaded.delete();
    });
  }

  Future<({int sent, bool retryNeeded})> _retryQueuedMessages(
    ChatRuntimeAccountContext context, {
    String? recipientUserId,
    String? conversationId,
  }) async {
    final queued = await _store.readQueuedMessages(
      bindingToken: context.bindingToken,
      ownerUserId: context.account.userId,
      recipientUserId: recipientUserId,
      conversationId: conversationId,
    );
    var sent = 0;
    var retryNeeded = false;
    for (final item in queued) {
      EncryptedMessage message;
      try {
        message = EncryptedMessage.fromBuffer(item.messageBytes);
      } catch (_) {
        await _store.markOutgoingDelivery(
          bindingToken: context.bindingToken,
          ownerUserId: context.account.userId,
          messageId: item.messageId,
          state: ChatMessageDeliveryState.failed,
          errorMessage: 'chat_message_invalid',
        );
        continue;
      }
      final result = await context.transport.sendEncryptedMessage(
        messageId: item.messageId,
        messageBytes: item.messageBytes,
        recipientUserId: item.recipientUserId,
        recipientDeviceId: message.recipientDeviceId,
      );
      await _store.markOutgoingDelivery(
        bindingToken: context.bindingToken,
        ownerUserId: context.account.userId,
        messageId: item.messageId,
        state: result.state,
        errorMessage: result.errorMessage,
      );
      if (result.state == ChatMessageDeliveryState.sent) {
        sent += 1;
      } else {
        retryNeeded = true;
      }
    }
    return (sent: sent, retryNeeded: retryNeeded);
  }

  /// 接收端完成MLS及摘要核验后，把明文流式写入当前CID系统保护缓存。
  Future<void> _saveReceivedAttachmentToCacheMutation({
    required ChatBindingFenceToken bindingToken,
    required String conversationId,
    required String attachmentId,
    required String fileName,
    required String contentType,
    required String filePath,
    required int byteSize,
  }) async {
    final cacheDirectory = await _attachmentDirectoryForToken(bindingToken);
    await ChatFlow.acceptReceivedMediaToCache(
      conversationId: conversationId,
      attachmentId: attachmentId,
      fileName: fileName,
      contentType: contentType,
      tempFilePath: filePath,
      byteSize: byteSize,
      maxByteSize: _host.mediaLimits.limitForMime(contentType),
      cacheDirectory: cacheDirectory,
      plainDirectory: await _plainDirectoryForBinding(bindingToken),
    );
  }

  Future<void> _copySentAttachmentToCacheMutation({
    required ChatBindingFenceToken bindingToken,
    required String conversationId,
    required String attachmentId,
    required String fileName,
    required String contentType,
    required String sourcePath,
    required int byteSize,
  }) async {
    final cacheDirectory = await _attachmentDirectoryForToken(bindingToken);
    await ChatFlow.importAttachmentFileToCache(
      conversationId: conversationId,
      attachmentId: attachmentId,
      fileName: fileName,
      contentType: contentType,
      sourcePath: sourcePath,
      byteSize: byteSize,
      moveSource: false,
      cacheDirectory: cacheDirectory,
      plainDirectory: await _plainDirectoryForBinding(bindingToken),
    );
  }

  Future<Future<void> Function()?> startRealtimeSync({
    required Future<void> Function() onNotice,
    Future<void> Function()? onDisconnected,
    bool retryOutgoingOnConnect = true,
  }) async {
    _ensureActive();
    final account = await _readAccount();
    // 宿主账户读取期间可能已经关闭实例，必须在登记 hub 前再次确认。
    _ensureActive();
    if (_blockedAccountIds.contains(account.accountId)) {
      throw StateError('Chat 账户上下文正在失效，禁止启动实时会话');
    }
    final hub = _realtimeHubs.putIfAbsent(
      account.accountId,
      () => _ChatRealtimeHub(account),
    );
    if (hub.account.userId != account.userId ||
        hub.account.bindingRevision != account.bindingRevision) {
      await _closeRealtimeHub(hub);
      return startRealtimeSync(
        onNotice: onNotice,
        onDisconnected: onDisconnected,
        retryOutgoingOnConnect: retryOutgoingOnConnect,
      );
    }
    final listener = _ChatRealtimeListener(
      onNotice: onNotice,
      onDisconnected: onDisconnected,
    );
    hub.listeners.add(listener);
    hub.retryOutgoingOnConnect =
        hub.retryOutgoingOnConnect || retryOutgoingOnConnect;
    try {
      if (!await _ensureRealtimeHubConnected(hub)) {
        // 初次网络失败也保留前台订阅，由同一Hub退避重连；禁止依赖下一次页面进入。
        _scheduleRealtimeHubReconnect(hub);
      }
    } catch (_) {
      // 会话刷新、设备证明或连接初始化的瞬时失败也必须保留订阅；否则某一平台
      // 首次启动失败后会在整个前台周期永久失去信令连接。
      _scheduleRealtimeHubReconnect(hub);
    }
    var active = true;
    return () async {
      if (!active) return;
      active = false;
      hub.listeners.remove(listener);
      if (hub.listeners.isEmpty) await _closeRealtimeHub(hub);
    };
  }

  /// 系统推送只表示邮箱可能变化；补拉后统一重试本机可靠待发队列。
  Future<void> handleWake() async {
    final account = await _readAccount();
    final context = await _readyContext(account);
    await _consumeMailboxBatch(
      account,
      context.transport,
      await context.transport.fetchMailbox(),
    );
    await retryOutgoing();
  }

  Future<bool> _ensureRealtimeHubConnected(_ChatRealtimeHub hub) {
    if (hub.closed || hub.listeners.isEmpty) return Future<bool>.value(false);
    if (hub.stopPhysical != null) return Future<bool>.value(true);
    final existing = hub.connecting;
    if (existing != null) return existing;
    late final Future<bool> created;
    created = _connectRealtimeHub(hub).whenComplete(() {
      if (identical(hub.connecting, created)) hub.connecting = null;
    });
    hub.connecting = created;
    return created;
  }

  Future<bool> _connectRealtimeHub(_ChatRealtimeHub hub) async {
    final session = _ChatRealtimeSession(
      accountId: hub.account.accountId,
      ownerUserId: hub.account.userId,
    );
    _realtimeSessions.add(session);
    final physical = await _startRealtimeSync(
      session: session,
      account: hub.account,
      onNotice: () => _notifyRealtimeHub(hub, disconnected: false),
      onDisconnected: () async {
        // 当前回调仍登记在 session 中，不能在这里同步 dispose 自己；放到下一个
        // microtask 后，session callback 先正常退出，再关闭旧资源并开始退避重连。
        scheduleMicrotask(() => unawaited(_handleRealtimeHubDisconnected(hub)));
      },
      retryOutgoingOnConnect: hub.retryOutgoingOnConnect,
      onTransportChanged: (transport) => hub.transport = transport,
    );
    if (physical == null) return false;
    if (hub.closed || hub.listeners.isEmpty) {
      hub.transport = null;
      await physical.stop();
      return false;
    }
    hub.transport = physical.transport;
    hub.stopPhysical = physical.stop;
    hub.reconnectAttempt = 0;
    return true;
  }

  Future<void> _notifyRealtimeHub(
    _ChatRealtimeHub hub, {
    required bool disconnected,
  }) async {
    final listeners = hub.listeners.toList(growable: false);
    for (final listener in listeners) {
      try {
        if (disconnected) {
          await listener.onDisconnected?.call();
        } else {
          await listener.onNotice();
        }
      } catch (_) {
        // 一个页面已销毁或刷新失败不得中断其它订阅者与物理连接。
      }
    }
  }

  Future<void> _handleRealtimeHubDisconnected(_ChatRealtimeHub hub) async {
    if (hub.closed || !identical(_realtimeHubs[hub.account.accountId], hub)) {
      return;
    }
    // 极短连接可能在 `_connectRealtimeHub` 交接 stop closure 前就触发 onDone；
    // 先等本次连接 Future 收口，避免漏关已经返回但尚未登记的物理 session。
    if (hub.stopPhysical == null && hub.connecting != null) {
      try {
        await hub.connecting;
      } catch (_) {
        // 清理失败不覆盖原始异常；所属状态仍由既有失败路径保留。
      }
    }
    final stop = hub.stopPhysical;
    hub.stopPhysical = null;
    hub.transport = null;
    if (stop != null) {
      try {
        await stop();
      } catch (_) {
        // 旧 socket 已经断开；清理失败由 Runtime 终态的 session 集合再次兜底。
      }
    }
    await _notifyRealtimeHub(hub, disconnected: true);
    _scheduleRealtimeHubReconnect(hub);
  }

  void _scheduleRealtimeHubReconnect(_ChatRealtimeHub hub) {
    if (hub.closed || hub.listeners.isEmpty || hub.reconnectTimer != null) {
      return;
    }
    final exponent = hub.reconnectAttempt.clamp(0, 5);
    final delay = Duration(seconds: 1 << exponent);
    hub.reconnectAttempt += 1;
    hub.reconnectTimer = Timer(delay, () {
      hub.reconnectTimer = null;
      unawaited(() async {
        try {
          if (!await _ensureRealtimeHubConnected(hub)) {
            _scheduleRealtimeHubReconnect(hub);
          }
        } catch (_) {
          _scheduleRealtimeHubReconnect(hub);
        }
      }());
    });
  }

  Future<void> _closeRealtimeHub(_ChatRealtimeHub hub) async {
    if (hub.closed) return;
    hub.closed = true;
    hub.reconnectTimer?.cancel();
    hub.reconnectTimer = null;
    hub.listeners.clear();
    if (identical(_realtimeHubs[hub.account.accountId], hub)) {
      _realtimeHubs.remove(hub.account.accountId);
    }
    try {
      await hub.connecting;
    } catch (_) {
      // connect 自身失败时 `_startRealtimeSync` 已回收尚未交接的 session。
    }
    final stop = hub.stopPhysical;
    hub.stopPhysical = null;
    hub.transport = null;
    if (stop != null) await stop();
  }

  Future<_ChatRealtimePhysical?> _startRealtimeSync({
    required _ChatRealtimeSession session,
    required ChatRuntimeAccount account,
    required Future<void> Function() onNotice,
    required Future<void> Function()? onDisconnected,
    required bool retryOutgoingOnConnect,
    required void Function(ChatServiceTransport? transport) onTransportChanged,
  }) async {
    var handedOff = false;
    try {
      // 接收消息依赖本机 Last Resort KeyPackage；新上下文登记一次，
      // 每次物理重连前再幂等确认一次，避免服务端目录清理后首次消息互锁。
      await _readyContext(account, republishKeyPackage: true);
      final signalContext = await _buildSignalContext(account);
      _ensureActive();
      session.ensureOpen();

      Future<void> handleEvent(ChatServiceEvent event) {
        return session.runCallback(() async {
          try {
            await _runRuntimeOperation(() async {
              if (event is ChatMessageAvailableEvent) {
                await _consumeMailboxBatch(
                  account,
                  signalContext.transport,
                  await signalContext.transport.fetchMailbox(),
                );
                await onNotice();
              }
            });
          } catch (_) {
            // socket 回调无上层 await 者；只记录安全阶段码，正文、user ID 与 SDP 均不入日志。
            signalContext.transport.lastRealtimeDiagnosticCode =
                'chat_signal_handle_failed';
          }
        });
      }

      Future<void> handleDisconnected() {
        return session.runCallback(() async {
          final callback = onDisconnected;
          if (callback == null) return;
          try {
            await _runRuntimeOperation(callback);
          } catch (_) {
            // 擦除终态后不再交付断开回调。
          }
        });
      }

      // 注册长寿命 socket callback 时不能处于 user ID Zone；每次 callback 由 session
      // registry 跟踪，并在其内部显式取得 binding lease。
      final stopSocket = await signalContext.transport.connectRealtime(
        onEvent: handleEvent,
        onDisconnected: onDisconnected == null ? null : handleDisconnected,
      );
      // disposer 必须在任何可能抛错的后验检查前同步接管新 socket。
      final signalTransport = signalContext.transport;
      session.attachSocket(stopSocket);
      onTransportChanged(signalTransport);
      _ensureActive();
      session.ensureOpen();

      // 必须先完成 WSS ready，再补拉可靠密文邮箱。建连后的新消息由 WSS
      // 立即交付，建连前的消息由本次补拉收敛，两者重叠时由 message_id
      // 和本机落库幂等去重；禁止留下“补拉结束、WSS 尚未建立”的丢失窗口。
      await _consumeMailboxBatch(
        account,
        signalContext.transport,
        await signalContext.transport.fetchMailbox(),
      );
      _ensureActive();
      session.ensureOpen();

      Future<void> refreshMailboxFromCallback() async {
        await session.runCallback(() async {
          try {
            await _runRuntimeOperation(() async {
              final context = await _readyContext(account);
              await _consumeMailboxBatch(
                account,
                context.transport,
                await context.transport.fetchMailbox(),
              );
              await retryOutgoing();
            });
          } catch (_) {
            // 未 ACK 密文仍在 TataChatServer；下次推送、启动或恢复前台继续补拉。
          }
        });
      }

      Future<void> refreshPushFromCallback() async {
        await session.runCallback(() async {
          try {
            await _runRuntimeOperation(
              () async => _ensurePushEndpointWithRetry(
                account: signalContext.account,
                identity: signalContext.identity,
                prefs: await _prefs,
                transport: signalContext.transport,
              ),
            );
          } catch (_) {
            // 终态不得回写 Token，普通失败等下次 token 变化。
          }
        });
      }

      final pushSubscription = _host.push.wakes.listen(
        (_) => unawaited(refreshMailboxFromCallback()),
      );
      session.attachWakeSubscription(pushSubscription.cancel);
      final pendingWake = await _host.push.takePendingWake();
      _ensureActive();
      if (pendingWake) {
        await refreshMailboxFromCallback();
      }
      final tokenSubscription = _host.push.tokenChanges.listen(
        (_) => unawaited(refreshPushFromCallback()),
      );
      session.attachTokenSubscription(tokenSubscription.cancel);
      // Chat Tab 与后台唤醒保留账户级补发；具体聊天窗口已经按 conversationId
      // 独立重试，建连时不得再次串行扫描并发送整个账户的队列。
      if (retryOutgoingOnConnect) {
        await retryOutgoing();
      }
      _ensureActive();
      session.ensureOpen();
      handedOff = true;
      return _ChatRealtimePhysical(
        stop: () => _disposeRealtimeSession(session),
        transport: signalTransport,
      );
    } finally {
      session.markInitializationDone();
      if (!handedOff) {
        onTransportChanged(null);
        await _disposeRealtimeSession(session);
      }
    }
  }

  Future<_ChatSignalContext> _buildSignalContext(
    ChatRuntimeAccount account,
  ) async {
    final context = await _readyContext(account);
    return _ChatSignalContext(
      account: account,
      identity: context.identity,
      transport: context.transport,
    );
  }

  Future<void> _consumeMailboxBatch(
    ChatRuntimeAccount account,
    ChatServiceTransport transport,
    List<ChatMailboxMessage> items,
  ) async {
    final acknowledgedMessageIds = <String>[];
    for (final item in items) {
      if (await _consumeMailboxMessage(account, transport, item)) {
        acknowledgedMessageIds.add(item.messageId);
      }
    }
    // 一批只发一次 ACK；单条失败不阻断同批其它密文，且失败条目不进入删除集合。
    await transport.acknowledgeMailbox(acknowledgedMessageIds);
  }

  Future<bool> _consumeMailboxMessage(
    ChatRuntimeAccount account,
    ChatServiceTransport transport,
    ChatMailboxMessage item,
  ) async {
    final receiptKey = '${account.accountId}|${item.messageId}';
    var processedNow = false;
    if (!_mailboxMessageReceipts.contains(receiptKey)) {
      try {
        final context = await _readyContext(account);
        await _runBindingFileMutation(
          context.bindingToken,
          () => _processMailboxMessage(
            context,
            item.senderUserId,
            item.messageBytes,
          ),
        );
        _mailboxMessageReceipts.add(receiptKey);
        processedNow = true;
        // 单邮箱最多 1000 条；保留四倍窗口足以覆盖 ACK 瞬时失败，同时限制内存。
        while (_mailboxMessageReceipts.length > 4000) {
          _mailboxMessageReceipts.remove(_mailboxMessageReceipts.first);
        }
      } catch (error) {
        _mailboxMessageReceipts.remove(receiptKey);
        // ACK 的唯一条件是密文已经成功验密并写入本机。格式、身份、OpenMLS、附件或
        // ChatIsar 任一失败都保留服务端副本到后续重试/七天 TTL；禁止永久丢消息。
        transport.lastRealtimeDiagnosticCode = 'chat_mailbox_message_retry';
        return false;
      }
    }
    if (processedNow) _scheduleOutgoingRetry(account, item.senderUserId);
    return true;
  }

  /// 新密文落盘后仅按发送方合并重试本机待发队列。普通消息不发送实时信令，
  /// 该任务不阻塞邮箱 ACK，重复 Message 只确认删除云端副本。
  void _scheduleOutgoingRetry(ChatRuntimeAccount account, String senderUserId) {
    if (senderUserId.isEmpty) return;
    final key = '${account.accountId}|$senderUserId';
    if (!_outgoingRetryInFlight.add(key)) return;
    unawaited(
      _runRuntimeOperation(() async {
            await _readAccount(expectedAccountId: account.accountId);
            await retryOutgoing(recipientUserId: senderUserId);
          })
          .catchError((Object _) {
            // 本机可靠队列保留到下一次推送、启动、恢复前台或发送调度。
          })
          .whenComplete(() {
            _outgoingRetryInFlight.remove(key);
          }),
    );
  }

  Future<ChatRuntimeAccountContext> _readyContext(
    ChatRuntimeAccount account, {
    bool republishKeyPackage = false,
  }) async {
    _ensureActive();
    if (_blockedAccountIds.contains(account.accountId)) {
      return Future<ChatRuntimeAccountContext>.error(
        StateError('Chat 账户上下文正在失效，禁止重新初始化'),
      );
    }
    final knownKey = _accountContextKeys[account.accountId];
    final cached = knownKey == null ? null : _readyContexts[knownKey];
    if (cached != null) {
      if (republishKeyPackage) {
        // 每次账户级 WSS 重连前幂等重发同一枚 Last Resort KeyPackage。
        await _publishCurrentKeyPackage(cached);
      }
      return cached;
    }
    final flightKey =
        '${account.userId}|${account.bindingRevision}|${account.accountId}';
    final existing = _readyFlights[flightKey];
    if (existing != null) {
      return existing;
    }

    final generation = _accountGenerations[account.accountId] ?? 0;
    late final Future<ChatRuntimeAccountContext> created;
    created = _buildAccountContext(account)
        .then((context) async {
          if (_processWipeRequested ||
              _closed ||
              (_accountGenerations[account.accountId] ?? 0) != generation) {
            await _disposeContext(context);
            throw StateError('user ID 当前绑定已切换，本次旧初始化结果已丢弃');
          }
          final contextKey = _contextKey(
            context.account,
            context.identity,
            context.bindingToken,
          );
          final previousKey = _accountContextKeys[account.accountId];
          if (previousKey != null && previousKey != contextKey) {
            final previous = _readyContexts.remove(previousKey);
            if (previous != null) await _disposeContext(previous);
          }
          _accountContextKeys[account.accountId] = contextKey;
          _readyContexts[contextKey] = context;
          return context;
        })
        .whenComplete(() {
          if (identical(_readyFlights[flightKey], created)) {
            _readyFlights.remove(flightKey);
          }
        });
    _readyFlights[flightKey] = created;
    return created;
  }

  Future<ChatRuntimeAccountContext> _buildAccountContext(
    ChatRuntimeAccount account,
  ) async {
    final bindingToken = await _convergeBindingFence(account);
    return _runBindingFileMutation(
      bindingToken,
      () => _buildAccountContextForBinding(account, bindingToken),
    );
  }

  Future<ChatRuntimeAccountContext> _buildAccountContextForBinding(
    ChatRuntimeAccount account,
    ChatBindingFenceToken bindingToken,
  ) async {
    final prefs = await _prefs;
    final stateStore = await _stateStore(account.userId);
    ChatServiceTransport? transport;
    var keepStateStore = false;
    try {
      final identity = stateStore.newlyCreated
          ? await stateStore.initializeIdentity()
          : await stateStore.readIdentity();
      final deviceId = identity.deviceId;
      final finalCrypto =
          _cryptoFactory?.call(identity, stateStore) ??
          NativeMlsCrypto(identity: identity, stateStore: stateStore);
      final fencedCrypto = _ChatBindingFencedMlsCrypto(
        runtime: this,
        bindingToken: bindingToken,
        delegate: finalCrypto,
      );
      final localKeyPackage = await fencedCrypto.createKeyPackage(
        identity,
        lastResort: true,
      );
      final service = await _ensureServiceReady(
        account: account,
        identity: identity,
        prefs: prefs,
      );
      transport = service.transport;
      final context = ChatRuntimeAccountContext(
        account: account,
        bindingToken: bindingToken,
        deviceId: deviceId,
        localKeyPackage: localKeyPackage,
        stateStore: stateStore,
        crypto: fencedCrypto,
        transport: transport,
      );
      // 私聊与群聊共用该包；登记失败必须阻止上下文就绪。
      await _publishCurrentKeyPackage(context);
      // 登记可能跨日；按实际包引用确认原提交，不能重新计算生成时的message_id。
      for (final entry in await finalCrypto.pendingMessageResults(null)) {
        final result = (entry['result'] as Map).cast<String, dynamic>();
        if (result['key_package_ref'] == localKeyPackage.keyPackageRef) {
          await finalCrypto.acknowledgeMessage(
            (entry['request'] as Map)['message_id'] as String,
          );
        }
      }
      keepStateStore = true;
      return context;
    } finally {
      if (!keepStateStore) {
        if (transport != null) await transport.dispose();
        stateStore.dispose();
      }
    }
  }

  Future<_ChatServiceContext> _ensureServiceReady({
    required ChatRuntimeAccount account,
    required ChatDevice identity,
    required SharedPreferences prefs,
  }) async {
    final transport = _transportFactory(
      identity: identity,
      accessProvider: () => _host.requestTataChatServerAccess(
        account: account,
        identity: identity,
      ),
    );
    await transport.connect();
    try {
      await _ensurePushEndpointWithRetry(
        account: account,
        identity: identity,
        prefs: prefs,
        transport: transport,
      );
    } catch (_) {
      // 推送端点暂时不可用不能破坏已经建立的端到端加密会话。
    }
    return _ChatServiceContext(transport: transport);
  }

  Future<void> _ensurePushEndpoint({
    required ChatRuntimeAccount account,
    required ChatDevice identity,
    required SharedPreferences prefs,
    required ChatServiceTransport transport,
  }) async {
    final pushCacheKey = _pushRegistrationCacheKey(account, identity);
    final expiresCacheKey = '$pushCacheKey.expires_at';
    final cachedExpiresAt = prefs.getInt(expiresCacheKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cachedPushRegistration = prefs.getString(pushCacheKey) ?? '';
    ChatPushToken? pushToken;
    if (cachedExpiresAt - _pushEndpointRefreshSkewMillis > now &&
        cachedPushRegistration.isNotEmpty) {
      try {
        pushToken = await _readPushToken();
      } catch (_) {
        // 已有未临期推送端点时，平台暂时取不到 Token 不能让整个 Chat 上下文失效。
        return;
      }
      // 本机缓存只能证明上一次输入相同，不能证明 TataChatServer 端点仍存在。
      // Token 可读时继续幂等登记，修复服务端删除失效端点后的永久失联。
      // Token 可读时始终继续幂等登记，不能用本机缓存推断服务端端点仍存在。
    }
    // 首次登记仍必须取得真实平台 Token；失败交由本地待发送
    // 队列保留消息并在下一次重连重试，禁止伪造占位 Token。
    pushToken ??= await _readPushToken();

    final expiresAt = DateTime.now().toUtc().add(_pushEndpointTtl);
    await transport.registerPushEndpoint(
      pushProvider: pushToken.provider,
      pushToken: pushToken.token,
      apnsEnvironment: pushToken.apnsEnvironment,
      expiresAtMillis: expiresAt.millisecondsSinceEpoch,
    );
    await prefs.setInt(expiresCacheKey, expiresAt.millisecondsSinceEpoch);
    await prefs.setString(pushCacheKey, pushToken.registrationCacheValue);
  }

  /// 启动、恢复和 Token 更新共用一次有界重试；平台 Token 尚未就绪不能永久跳过登记。
  Future<void> _ensurePushEndpointWithRetry({
    required ChatRuntimeAccount account,
    required ChatDevice identity,
    required SharedPreferences prefs,
    required ChatServiceTransport transport,
  }) async {
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        await _ensurePushEndpoint(
          account: account,
          identity: identity,
          prefs: prefs,
          transport: transport,
        );
        return;
      } catch (_) {
        if (attempt == 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 250 << attempt));
      }
    }
  }

  Future<ChatPushToken> _readPushToken() {
    return _host.push.initialize();
  }

  Future<ChatRuntimeAccount> _readAccount({String? expectedAccountId}) {
    return _runRuntimeOperation(
      () => _readAccountInternal(expectedAccountId: expectedAccountId),
    );
  }

  Future<ChatRuntimeAccount> _readAccountInternal({
    String? expectedAccountId,
  }) async {
    _ensureActive();
    final account = await _host.currentAccount(
      expectedAccountId: expectedAccountId,
    );
    if (account == null) {
      throw StateError('宿主尚未提供聊天账户');
    }
    if (expectedAccountId != null && account.accountId != expectedAccountId) {
      throw StateError('宿主聊天账户已切换');
    }
    return account;
  }

  static ChatBinding _bindingForAccount(ChatRuntimeAccount account) =>
      ChatBinding(
        bindingScope: account.bindingScope,
        userId: account.userId,
        bindingRevision: account.bindingRevision,
        accountId: account.accountId,
      );

  ChatFlow<ChatBindingFenceToken> _messageFlow(
    ChatRuntimeAccountContext context, {
    bool scheduleDelivery = true,
  }) {
    return ChatFlow<ChatBindingFenceToken>(
      crypto: context.crypto,
      store: _store,
      bindingToken: context.bindingToken,
      ownerUserId: context.account.userId,
      currentAccountId: context.account.accountId,
      mediaLimits: _host.mediaLimits,
      // 待加密行批量转换时先只完成本地正式队列，再由调用方统一扫描投递，
      // 避免同一 Message 被后台执行器和当前重试循环同时提交。
      deliveryScheduler: scheduleDelivery
          ? (conversationId, delivery) =>
                _scheduleOutboundDelivery(context, conversationId, delivery)
          : (conversationId, delivery) {},
      deliverer: (message, _, recipientUserId, recipientDeviceId) {
        return ChatFlow.deliverWithTransport(
          transport: context.transport,
          message: message,
          recipientUserId: recipientUserId,
        );
      },
      afterIncomingStore: (message, content) async =>
          _scheduleIncomingCloudAttachment(
            context,
            message.conversationId,
            content,
          ),
    );
  }

  void _scheduleIncomingCloudAttachment(
    ChatRuntimeAccountContext context,
    String conversationId,
    ChatContent content,
  ) {
    if (!content.isMedia || (content.attachmentId ?? '').isEmpty) return;
    unawaited(
      _downloadIncomingCloudAttachment(
        context,
        conversationId,
        content,
      ).catchError((Object _) {
        // 四次有界重试仍失败后保留本地控制消息；页面恢复或用户点击会再次补取。
      }),
    );
  }

  Future<void> _downloadIncomingCloudAttachment(
    ChatRuntimeAccountContext context,
    String conversationId,
    ChatContent content,
  ) {
    final attachmentId = content.attachmentId ?? '';
    final key = '${context.account.accountId}|$conversationId|$attachmentId';
    final existing = _incomingAttachmentDownloads[key];
    if (existing != null) return existing;

    late final Future<void> task;
    task =
        _runRuntimeOperation(() async {
          Object? lastError;
          for (var attempt = 0; attempt <= 4; attempt += 1) {
            if (attempt > 0) {
              await Future<void>.delayed(_outboundRetryDelays[attempt - 1]);
            }
            try {
              await _cacheIncomingCloudAttachment(
                context,
                conversationId,
                content,
              );
              final hub = _realtimeHubs[context.account.accountId];
              if (hub != null && !hub.closed) {
                await _notifyRealtimeHub(hub, disconnected: false);
              }
              return;
            } catch (error) {
              lastError = error;
            }
          }
          Error.throwWithStackTrace(
            lastError ?? StateError('chat_attachment_download_failed'),
            StackTrace.current,
          );
        }).whenComplete(() {
          if (identical(_incomingAttachmentDownloads[key], task)) {
            _incomingAttachmentDownloads.remove(key);
          }
        });
    _incomingAttachmentDownloads[key] = task;
    return task;
  }

  /// 下载的是不透明MLS帧文件；已消费块保留保护前缀，重试只能续用原结果。
  Future<void> _cacheIncomingCloudAttachment(
    ChatRuntimeAccountContext context,
    String conversationId,
    ChatContent content,
  ) async {
    if (!content.isMedia) return;
    final attachmentId = content.attachmentId!;
    final directory = await _attachmentDirectoryForToken(context.bindingToken);
    final cachePath = ChatFlow.attachmentCachePath(
      cacheDirectory: directory,
      conversationId: conversationId,
      attachmentId: attachmentId,
      fileName: content.fileName!,
    );
    final engine = await _attachmentEngine(context);
    if (await AttachmentVault.hasCache(cachePath)) {
      final file = File(cachePath);
      if (await file.length() != content.byteSize ||
          await MlsAttachment.digest(file) != content.plainSha256) {
        throw StateError('附件最终缓存损坏，不能重新推进接收链');
      }
      // 缓存提交后被中断时补终态；此动作幂等，不重新处理Welcome。
      await engine.finish(content.attachmentGroupId!);
      await context.transport.acknowledgeAttachment(attachmentId);
      return;
    }
    final temp = Directory('${directory.path}/.tmp');
    await _runBindingFileMutation(
      context.bindingToken,
      () => temp.create(recursive: true),
    );
    final cipher = File('${temp.path}/${_safePath(attachmentId)}.download');
    final plain = File('${temp.path}/${_safePath(attachmentId)}.plain');
    if (!await cipher.exists()) {
      await context.transport.downloadEncryptedAttachment(
        attachmentId: attachmentId,
        target: cipher,
        expectedByteSize: content.cipherByteSize!,
        expectedSha256: content.cipherSha256!,
      );
    }
    await engine.open(content: content, cipher: cipher, target: plain);
    await _runBindingFileMutation(
      context.bindingToken,
      () => _saveReceivedAttachmentToCacheMutation(
        bindingToken: context.bindingToken,
        conversationId: conversationId,
        attachmentId: attachmentId,
        fileName: content.fileName!,
        contentType: content.mime!,
        filePath: plain.path,
        byteSize: content.byteSize!,
      ),
    );

    await engine.finish(content.attachmentGroupId!);
    await _runBindingFileMutation(context.bindingToken, () async {
      if (await cipher.exists()) await cipher.delete();
      if (await plain.exists()) await plain.delete();
    });
    await context.transport.acknowledgeAttachment(attachmentId);
  }

  /// TataChatServer 邮箱的唯一入站 Message 边界；服务端路由身份与密文内身份必须一致。
  Future<List<String>> _processMailboxMessage(
    ChatRuntimeAccountContext context,
    String senderUserId,
    List<int> messageBytes,
  ) async {
    late final EncryptedMessage message;
    try {
      message = EncryptedMessage.fromBuffer(messageBytes);
    } catch (_) {
      throw const FormatException('Chat 邮箱 Message 无法解析');
    }
    if (message.senderUserId != senderUserId ||
        message.recipientUserId != context.account.userId ||
        message.recipientDeviceId != context.identity.deviceId) {
      throw const FormatException('Chat 邮箱路由与 Message 身份不一致');
    }
    final accepted = <EncryptedMessage>[];
    // 每次都复核原生精确请求收据；仅存在同message_id的业务行不能授权ACK。
    if (message.conversationId.startsWith('grp:')) {
      accepted.addAll(
        await _groupFlow(context).processIncomingGroupMessage(messageBytes),
      );
    } else {
      final result = await _messageFlow(
        context,
      ).processIncomingMessageBytes(messageBytes);
      accepted.addAll(result.acceptedMessages);
    }
    final hub = _realtimeHubs[context.account.accountId];
    if (hub != null && !hub.closed) {
      await _notifyRealtimeHub(hub, disconnected: false);
    }
    return accepted.map((item) => item.messageId).toList(growable: false);
  }

  /// 当前设备只发布由本机 OpenMLS 状态持有私有材料的同一枚 Last Resort KeyPackage。
  Future<void> _publishCurrentKeyPackage(
    ChatRuntimeAccountContext context,
  ) async {
    final publicationKey =
        '${context.account.userId}|${context.deviceId}|'
        '${context.localKeyPackage.keyPackageRef}';
    if (_keyPackagePublications.contains(publicationKey)) return;
    final lastResort = context.localKeyPackage;
    if (lastResort.userId != context.account.userId ||
        lastResort.deviceId != context.deviceId) {
      throw const MlsNativeException(
        MlsNativeErrorCode.invalidResponse,
        'OpenMLS KeyPackage 与当前本机 user ID 设备身份不一致',
      );
    }
    if (!lastResort.lastResort) {
      throw const MlsNativeException(
        MlsNativeErrorCode.invalidResponse,
        'OpenMLS Last Resort KeyPackage 不合法',
      );
    }
    await context.transport.publishKeyPackage(lastResort);
    _keyPackagePublications.add(publicationKey);
  }

  Future<MlsStateStore> _stateStore(String userId) async {
    final factory = _stateStoreFactory;
    if (factory != null) {
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        throw UnsupportedError('MLS存储替身仅用于测试');
      }
      return factory(userId);
    }
    return MlsStateStore.prepare(userId);
  }

  /// 公开离线身份入口不请求聊天网络或权益；宿主当前user_id是所有者事实。
  Future<ChatDevice> readLocalMlsIdentity() async {
    _ensureActive();
    final account = await _readAccount();
    return _runUserFileMutation(
      userId: account.userId,
      operation: () async {
        final store = await _stateStore(account.userId);
        return store.newlyCreated
            ? store.initializeIdentity()
            : store.readIdentity();
      },
    );
  }

  /// 通讯录复用同一已存在MLS身份，不启动聊天网络或请求会员权益。
  /// 仅协议与业务落库持当前绑定短屏障，网络交换不持文件锁；晚回结果不得跨绑定。
  Future<List<List<int>>> synchronizeContacts({
    required ContactMlsExchange exchange,
    required Future<List<List<int>>> Function() snapshots,
    required ContactMlsApply apply,
  }) => _runRuntimeOperation(() async {
    final account = await _readAccountInternal();
    final generation = _accountGenerations[account.accountId] ?? 0;
    final token = await _convergeBindingFence(account);
    Future<void> requireCurrent() async {
      final current = await _readAccountInternal(
        expectedAccountId: account.accountId,
      );
      _ensureActive();
      if (_blockedAccountIds.contains(account.accountId) ||
          (_accountGenerations[account.accountId] ?? 0) != generation ||
          current.userId != account.userId ||
          current.accountId != account.accountId ||
          current.bindingRevision != account.bindingRevision ||
          current.bindingScope != account.bindingScope ||
          current.hostIndex != account.hostIndex) {
        throw StateError('通讯录同步期间宿主账户已失效');
      }
      await _runBindingFileMutation(token, () async {});
    }

    await requireCurrent();
    final store = await _stateStore(account.userId);
    _ChatBindingFencedMlsCrypto? fenced;
    try {
      if (store.ownerUserId != account.userId) {
        throw StateError('通讯录MLS存储所有者不一致');
      }
      final identity = await _runBindingFileMutation(token, () async {
        await requireCurrent();
        return store.readIdentity();
      });
      await requireCurrent();
      fenced = _ChatBindingFencedMlsCrypto(
        runtime: this,
        bindingToken: token,
        delegate:
            _cryptoFactory?.call(identity, store) ??
            NativeMlsCrypto(identity: identity, stateStore: store),
      );
      final result =
          await MlsContactSync(
            identity: identity,
            crypto: fenced,
            exchange: exchange,
            requireCurrent: requireCurrent,
          ).synchronize(
            snapshots: () => _runBindingFileMutation(token, () async {
              await requireCurrent();
              final payloads = await snapshots();
              await requireCurrent();
              return payloads;
            }),
            apply: (payload) => _runBindingFileMutation(token, () async {
              await requireCurrent();
              await apply(payload);
              await requireCurrent();
            }),
          );
      await requireCurrent();
      return result;
    } finally {
      fenced?.dispose();
      store.dispose();
    }
  });

  /// 认证账户事实只来自宿主；不请求钱包、权益或聊天连接。
  ///
  /// 与本机擦除共用用户文件屏障，签名前后复核宿主事实及账户失效代次；
  /// 等待期间切换/换绑/关闭时丢弃证明，不自动补身份或回退旧设备签名。
  Future<MlsAuthenticationProof> createMlsAuthenticationProof(
    MlsAuthenticationRequest request,
  ) => _runRuntimeOperation(() async {
    request.validate();
    final account = await _readAccountInternal();
    _ensureActive();
    final generation = _accountGenerations[account.accountId] ?? 0;
    Future<void> requireCurrentAccount() async {
      final current = await _readAccountInternal(
        expectedAccountId: account.accountId,
      );
      _ensureActive();
      if (_blockedAccountIds.contains(account.accountId) ||
          (_accountGenerations[account.accountId] ?? 0) != generation ||
          current.userId != account.userId ||
          current.accountId != account.accountId ||
          current.bindingRevision != account.bindingRevision ||
          current.bindingScope != account.bindingScope ||
          current.hostIndex != account.hostIndex) {
        throw StateError('MLS认证期间宿主账户已失效');
      }
    }

    await requireCurrentAccount();
    final proof = await _runUserFileMutation(
      userId: account.userId,
      operation: () async {
        final store = await _stateStore(account.userId);
        if (store.ownerUserId != account.userId) {
          throw StateError('MLS认证存储所有者不一致');
        }
        await requireCurrentAccount();
        final proof = await store.signAuthentication(
          accountId: account.accountId,
          bindingRevision: account.bindingRevision,
          request: request,
        );
        await requireCurrentAccount();
        MlsAuthenticationRequest.validateExpiry(proof.expiresAtMillis);
        return proof;
      },
    );
    // 文件屏障退出仍有异步等待，必须在真正交付调用方前再次复核。
    await requireCurrentAccount();
    MlsAuthenticationRequest.validateExpiry(proof.expiresAtMillis);
    return proof;
  });
}

class _ChatServiceContext {
  const _ChatServiceContext({required this.transport});

  final ChatServiceTransport transport;
}

String _newPendingMessageId(String conversationId, int millis) =>
    'pending:${_safePath(conversationId)}:$millis:${_newNonce()}';

String _newPendingAttachmentId(String conversationId, int millis) =>
    'attachment:${_safePath(conversationId)}:$millis:${_newNonce()}';

String _newNonce() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((item) => item.toRadixString(16).padLeft(2, '0')).join();
}

String _ownerPath(String value) => utf8
    .encode(value)
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

String _safePath(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
}

String _contextKey(
  ChatRuntimeAccount account,
  ChatDevice identity,
  ChatBindingFenceToken bindingToken,
) {
  return '${account.userId}|${account.bindingRevision}|${account.accountId}|'
      '${bindingToken.bindingScope}|${bindingToken.generation}|'
      '${identity.deviceId}';
}

String _pushRegistrationCacheKey(
  ChatRuntimeAccount account,
  ChatDevice identity,
) {
  return '${ChatRuntimeCore._kPushRegistrationPrefix}.'
      '${_safePath(account.userId)}.${account.bindingRevision}.'
      '${_safePath(account.accountId)}.${_safePath(identity.deviceId)}';
}
