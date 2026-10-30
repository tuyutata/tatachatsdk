import 'dart:async';
import 'package:isar_community/isar.dart';
import 'isar_core_bootstrap.dart';
import 'system_protected_storage.dart';

part 'chat_isar.g.dart';

/// Chat 会话本地索引。
///
/// 永久聊天历史只允许在宿主用户手机本地保存；聊天服务模块只接收七天 OpenMLS Envelope，WebRTC 与近场
/// transport 只在设备间承载密文。本表负责会话列表首屏，不参与链上状态。
@Name('conversation')
@collection
class ChatConversationEntity {
  @Name('id')
  Id id = Isar.autoIncrement;

  /// 本机聊天数据的永久属主 user ID；与会话 ID 组成复合唯一键。
  @Index(
    composite: [CompositeIndex('conversationId')],
    unique: true,
    replace: true,
  )
  @Name('owner_id')
  late String ownerUserId;

  /// 标识当前 finalized 授权绑定版本，不参与会话归属或唯一键。
  @Name('bind_rev')
  late int bindingRevision;

  /// 当前 user ID 链上绑定的账户；不是聊天身份主键。
  @Name('account_id')
  late String accountId;

  /// 会话 ID，对应 MLS group id。
  @Name('conversation_id')
  late String conversationId;

  /// 对方永久身份主键；换绑不改变会话归属或会话 ID。
  @Index()
  @Name('peer_id')
  late String peerUserId;

  /// 私聊标题；群名只归group记录。
  @Name('title')
  String? title;

  /// 系统保护数据库内的会话摘要，不另设应用加密密钥。
  @Name('summary')
  late String lastMessageSummary;

  @Index()
  @Name('updated_at')
  late int updatedAtMillis;

  @Name('unread_count')
  late int unreadCount;
  @Name('delivery_state')
  late String lastDeliveryState;

  /// 会话类型:null/"dm"=私聊,"group"=私密小群。免每次 join 群表判定。
  @Name('kind')
  String? conversationKind;
}

/// Chat 消息本地记录。正文及索引保存于 SDK 系统保护数据库；网络仅传 MLS 密文。
/// pending 行在发送前保存真实载荷，正式 MLS 消息和重试队列在同一事务提交。
@Name('message')
@collection
class ChatMessageEntity {
  @Name('id')
  Id id = Isar.autoIncrement;

  /// 本机聊天数据的永久属主 user ID；与 message ID 组成复合唯一键。
  @Index(composite: [CompositeIndex('messageId')], unique: true, replace: true)
  @Name('owner_id')
  late String ownerUserId;

  /// 标识当前 finalized 授权绑定版本，不参与消息归属或唯一键。
  @Name('bind_rev')
  late int bindingRevision;

  /// 当前 user ID 链上绑定的账户；不是聊天身份主键。
  @Name('account_id')
  late String accountId;

  @Name('message_id')
  late String messageId;

  @Index()
  @Name('conversation_id')
  late String conversationId;

  @Name('direction')
  late String direction;
  @Name('sender_id')
  late String senderUserId;
  @Name('recipient_id')
  late String recipientUserId;
  @Name('kind')
  late String messageKind;
  @Name('delivery_state')
  late String deliveryState;

  /// 唯一目标载荷 JSON，由系统文件保护边界保护。
  @Name('payload_json')
  String? payloadJson;

  /// 去重字符 bigram；命中后必须复核真实子串顺序。
  @Index(type: IndexType.value)
  @Name('search_tokens')
  List<String> searchTokens = const <String>[];

  @Name('message_bytes')
  late String messageBytesHex;

  @Index()
  @Name('created_at')
  late int createdAtMillis;
}

/// Chat 出站队列。
///
/// 投递失败时只重试完整 message bytes，不重新加密，避免破坏
/// MLS 会话状态和消息顺序。
@Name('outbound')
@collection
class ChatOutboundQueueEntity {
  @Name('id')
  Id id = Isar.autoIncrement;

  /// 本机出站队列的永久属主 user ID。
  @Index(composite: [CompositeIndex('messageId')], unique: true, replace: true)
  @Name('owner_id')
  late String ownerUserId;

  @Name('message_id')
  late String messageId;

  @Index()
  @Name('conversation_id')
  late String conversationId;

  /// 收件人身份主键 user ID，也是信封、MLS 名册和 Worker 的唯一投递键。
  @Name('recipient_id')
  late String recipientUserId;
  @Name('message_bytes')
  late String messageBytesHex;

  @Index()
  @Name('updated_at')
  late int updatedAtMillis;
}

/// Chat 逐收件人附件控制投递事实。
///
/// 附件密文统一经 HTTPS 上传私有 R2，WebRTC 只用于实时语音/视频通话。本行只保存
/// 稳定标识和元数据，不保存容器绝对路径；当前收件人的附件投递完成后删除。
@Name('media')
@collection
class ChatOutgoingMediaEntity {
  @Name('id')
  Id id = Isar.autoIncrement;

  /// 本机待投递媒体的永久属主 user ID。
  @Index(
    composite: [
      CompositeIndex('attachmentId'),
      CompositeIndex('recipientUserId'),
    ],
    unique: true,
    replace: true,
  )
  @Name('owner_id')
  late String ownerUserId;

  @Index()
  @Name('attachment_id')
  late String attachmentId;

  /// 收件人身份主键 user ID 号，用于约束附件访问与控制信封投递。
  @Index()
  @Name('recipient_id')
  late String recipientUserId;

  @Name('conversation_id')
  late String conversationId;
  @Name('file_name')
  late String fileName;
  @Name('content_type')
  late String contentType;
  @Name('byte_size')
  late int byteSize;
  @Name('created_at')
  late int createdAtMillis;
}

/// Chat 待处理入站消息。
///
/// application 早于 Welcome 到达时先落这里；处理 Welcome 后再
/// 重放同会话 pending，避免因为网络乱序丢消息。
@Name('inbound')
@collection
class ChatPendingInboundEntity {
  @Name('id')
  Id id = Isar.autoIncrement;

  /// 本机入站缓冲的永久属主 user ID。
  @Index(composite: [CompositeIndex('messageId')], unique: true, replace: true)
  @Name('owner_id')
  late String ownerUserId;

  @Name('message_id')
  late String messageId;

  @Index()
  @Name('conversation_id')
  late String conversationId;

  @Name('message_bytes')
  late String messageBytesHex;

  @Index()
  @Name('created_at')
  late int createdAtMillis;
}

/// Chat 路由缓存记录。
///
/// Chat 路由缓存只保存在宿主用户手机本地，用于把联系人 user ID 映射到
/// OpenMLS 设备和近场提示；用户联系人仍以“我的通讯录”为准。
@Name('route')
@collection
class ChatRouteCacheEntity {
  @Name('id')
  Id id = Isar.autoIncrement;

  /// 本机路由缓存的永久属主 user ID；与对方 user ID 组成复合唯一键。
  @Index(composite: [CompositeIndex('peerUserId')], unique: true, replace: true)
  @Name('owner_id')
  late String ownerUserId;

  /// 对方永久身份主键；钱包换绑不修改路由身份。
  @Name('peer_id')
  late String peerUserId;

  /// Chat 路由显示名，只用于联系人路由列表，不承载机构全称或简称。
  @Name('route_name')
  late String routeDisplayName;
  @Name('device_id')
  late String deviceId;
  @Name('safety_number')
  late String safetyNumber;
  @Name('nearby_hint')
  String? nearbyPeerHint;
  @Name('route_note')
  String? note;
  @Name('created_at')
  late int createdAtMillis;
  @Name('updated_at')
  late int updatedAtMillis;
}

/// 私密小群会话镜像。名册以 MLS `group_state` 为真源,本表为镜像视图。
@Name('group')
@collection
class ChatGroupEntity {
  @Name('id')
  Id id = Isar.autoIncrement;

  /// 本机群聊镜像的永久属主 user ID。
  @Index(composite: [CompositeIndex('groupId')], unique: true, replace: true)
  @Name('owner_id')
  late String ownerUserId;

  /// 群 ID = conversation_id,形如 `grp:<creator>:<nonce>`。
  @Name('group_id')
  late String groupId;

  @Name('group_name')
  late String groupName;
  @Name('creator_id')
  late String creatorUserId;

  /// MLS 当前 epoch 的本地镜像。
  @Name('group_epoch')
  late int epoch;

  /// 本机是否已退群/被移除。
  @Name('has_left')
  late bool leftLocally;
}

/// 群成员镜像（一条 = 群内一个 user ID）。每次 Commit 后按 MLS 名册对账覆盖。
@Name('member')
@collection
class ChatGroupMemberEntity {
  @Name('id')
  Id id = Isar.autoIncrement;

  /// 本机群成员镜像的永久属主 user ID。
  @Index(
    composite: [CompositeIndex('groupId'), CompositeIndex('memberUserId')],
    unique: true,
    replace: true,
  )
  @Name('owner_id')
  late String ownerUserId;

  @Index()
  @Name('group_id')
  late String groupId;

  @Name('member_id')
  late String memberUserId;

  /// 角色:admin | member。
  @Name('member_role')
  late String role;
}

/// 群乱序 Commit 缓冲(键:groupId + messageEpoch)。epoch 补齐后按序回放。
@Name('commit')
@collection
class ChatGroupPendingCommitEntity {
  @Name('id')
  Id id = Isar.autoIncrement;

  /// 本机乱序 Commit 缓冲的永久属主 user ID。
  @Index(composite: [CompositeIndex('messageId')], unique: true, replace: true)
  @Name('owner_id')
  late String ownerUserId;

  @Name('message_id')
  late String messageId;

  @Index()
  @Name('group_id')
  late String groupId;

  @Index()
  @Name('message_epoch')
  late int messageEpoch;

  @Name('message_bytes')
  late String messageBytesHex;
  @Name('created_at')
  late int createdAtMillis;
}

/// Chat 当前 finalized 绑定的持久写入门闩。
///
/// 本表只保存公开绑定事实和单调代次，不保存任何私钥、明文或密文。所有 Chat 写入都必须
/// 在事务外捕获不可变 token，并在最终写事务内精确复核本表；因此另一个 Dart isolate
/// 已经开始但尚未落盘的旧绑定操作，不能越过换绑、隔离或清除边界。
@Name('fence')
@collection
class ChatBindingFenceEntity {
  @Name('id')
  Id id = Isar.autoIncrement;

  /// 本机 Chat 数据永久属主 user ID。安全门闩禁止 replace，更新必须保留原行与 generation。
  @Index(unique: true)
  @Name('owner_id')
  late String ownerUserId;

  /// 当前 active binding；cleared 且从未激活时允许为空。
  @Name('bind_rev')
  int? bindingRevision;
  @Name('account_id')
  String? accountId;
  @Name('bind_scope')
  String? bindingScope;

  /// 单调代次。任何 binding 切换或终态清除都必须在同一事务内推进。
  @Name('fence_rev')
  late int generation;

  /// `active` 或 `cleared`。普通写入只接受 active。
  @Name('fence_state')
  late String fenceState;
}

enum _ChatIsarLifecycle { active, closing, closed }

/// 数据库打开期间收到关闭请求时使用的内部终止信号。
class _ChatOpeningCancelled implements Exception {
  const _ChatOpeningCancelled([this.cleanupError]);

  final Object? cleanupError;
}

/// Chat 域独立数据库。
///
/// Chat 与 App、广场、用户和钱包数据库没有存储活性依赖。本类拥有自己的数据库、打开
/// 生命周期和串行操作队列；一次 Chat 操作阻塞时，不得占用其它四个业务数据库队列。
class ChatIsar {
  ChatIsar._();

  static final ChatIsar instance = ChatIsar._();

  static final Object _operationZoneKey = Object();

  Isar? _isar;
  Future<Isar>? _opening;
  Future<bool>? _deleteInFlight;
  Future<void>? _closing;
  Future<void> _operationTail = Future<void>.value();
  bool _operationActive = false;
  _ChatIsarLifecycle _lifecycle = _ChatIsarLifecycle.active;
  int _generation = 0;

  static const Duration _gracefulDrainTimeout = Duration(milliseconds: 250);
  static const Duration _openingSettleTimeout = Duration(seconds: 2);
  static const Duration _forcedDeleteTimeout = Duration(seconds: 2);

  static const List<Duration> _busyRetryDelays = <Duration>[
    Duration(milliseconds: 80),
    Duration(milliseconds: 160),
    Duration(milliseconds: 320),
    Duration(milliseconds: 640),
    Duration(milliseconds: 1200),
    Duration(milliseconds: 2400),
    Duration(milliseconds: 3600),
    Duration(milliseconds: 5000),
  ];

  /// Chat 域的唯一 schema 清单；正常打开与终态擦除必须使用同一真源。
  static const List<CollectionSchema<dynamic>> _schemas =
      <CollectionSchema<dynamic>>[
        ChatConversationEntitySchema,
        ChatMessageEntitySchema,
        ChatOutboundQueueEntitySchema,
        ChatOutgoingMediaEntitySchema,
        ChatPendingInboundEntitySchema,
        ChatRouteCacheEntitySchema,
        ChatGroupEntitySchema,
        ChatGroupMemberEntitySchema,
        ChatGroupPendingCommitEntitySchema,
        ChatBindingFenceEntitySchema,
      ];

  bool get hasActiveOperation => _operationActive;

  /// 仅负责打开 Chat 数据库。业务读写必须使用 [read] 或 [writeTxn]。
  Future<Isar> db() async {
    _ensureActive();

    final current = _isar;
    if (current != null && current.isOpen) return current;

    final opening = _opening;
    if (opening != null) return opening;

    final generation = _generation;
    final task = _openForGeneration(generation);
    _opening = task;
    try {
      final opened = await task;
      if (_lifecycle != _ChatIsarLifecycle.active ||
          generation != _generation) {
        throw const _ChatOpeningCancelled();
      }
      _isar = opened;
      return opened;
    } finally {
      if (identical(_opening, task)) {
        _opening = null;
      }
    }
  }

  /// Chat 读操作入口。
  ///
  /// 回调内只允许读取 ChatIsar，并须先返回脱离事务的快照；禁止在回调内访问钱包、
  /// 平台、网络、文件、硬件密钥或执行加解密。
  Future<T> read<T>(Future<T> Function(Isar isar) action) {
    return _enqueue(() async {
      final isar = await db();
      await _verifySystemProtection();
      return action(isar);
    });
  }

  /// Chat 写操作入口。
  ///
  /// 所有加解密、网络和跨域计算必须在进入事务前完成，事务回调只落盘已准备的数据。
  Future<T> writeTxn<T>(Future<T> Function(Isar isar) action) {
    return _enqueue(() async {
      final isar = await db();
      await _verifySystemProtection();
      final result = await isar.writeTxn<T>(() => action(isar));
      await _verifySystemProtection();
      return result;
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    if (identical(Zone.current[_operationZoneKey], this)) {
      throw StateError('禁止在 ChatIsar 操作回调内再次进入 ChatIsar；请先返回快照，再执行后续工作。');
    }

    _ensureActive();

    final generation = _generation;
    final previous = _operationTail;
    final completer = Completer<T>();
    _operationTail = completer.future.then<void>((_) {}, onError: (_) {});

    () async {
      try {
        await previous.catchError((_) {});
        if (_lifecycle != _ChatIsarLifecycle.active ||
            generation != _generation) {
          throw StateError('ChatIsar 已关闭，禁止继续执行或重新打开数据库。');
        }
        _operationActive = true;
        final result = await runZoned(
          () => _runWithBusyRetry(action),
          zoneValues: <Object?, Object?>{_operationZoneKey: this},
        );
        if (_lifecycle != _ChatIsarLifecycle.active ||
            generation != _generation) {
          throw StateError('ChatIsar 已关闭，旧操作结果已取消。');
        }
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        if (generation == _generation) {
          _operationActive = false;
        }
      }
    }();

    return completer.future;
  }

  Future<T> _runWithBusyRetry<T>(Future<T> Function() action) async {
    for (var attempt = 0; attempt <= _busyRetryDelays.length; attempt++) {
      try {
        return await action();
      } catch (error) {
        if (!_isBusyError(error) || attempt == _busyRetryDelays.length) {
          rethrow;
        }
        await Future<void>.delayed(_busyRetryDelays[attempt]);
      }
    }
    throw StateError('unreachable');
  }

  bool _isBusyError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('mdbxerror (11)') ||
        raw.contains('try again') ||
        raw.contains('active transaction');
  }

  void _ensureActive() {
    if (_lifecycle != _ChatIsarLifecycle.active) {
      throw StateError('ChatIsar 已关闭，禁止继续执行或重新打开数据库。');
    }
  }

  Future<Isar> _openForGeneration(int generation) async {
    final opened = await _open();
    if (_lifecycle == _ChatIsarLifecycle.active && generation == _generation) {
      return opened;
    }

    try {
      final deleted = await _deleteInstance(
        opened,
      ).timeout(_forcedDeleteTimeout);
      if (!deleted) {
        throw StateError('Chat 数据库仍被其它实例持有，未实际关闭并删除。');
      }
      throw const _ChatOpeningCancelled();
    } catch (error) {
      if (error is _ChatOpeningCancelled) rethrow;
      throw _ChatOpeningCancelled(error);
    }
  }

  Future<bool> _deleteInstance(Isar isar) {
    final deleting = _deleteInFlight;
    if (deleting != null) return deleting;
    if (!isar.isOpen) return Future<bool>.value(true);

    final task = isar.close(deleteFromDisk: true);
    _deleteInFlight = task;
    task.then<void>(
      (_) {
        if (identical(_deleteInFlight, task)) _deleteInFlight = null;
      },
      onError: (Object _, StackTrace _) {
        if (identical(_deleteInFlight, task)) _deleteInFlight = null;
      },
    );
    return task;
  }

  Future<Isar> _open() async {
    await IsarCoreBootstrap.ensureTestCoreInitialized();

    final directory = IsarCoreBootstrap.isFlutterTest
        ? await IsarCoreBootstrap.resolveDirectory()
        : (await ChatSystemProtectedStorage.prepare()).path;
    final existing = Isar.getInstance('tatachatsdk_chat');
    if (existing != null && existing.isOpen) {
      try {
        existing.chatConversationEntitys;
        existing.chatMessageEntitys;
        existing.chatOutboundQueueEntitys;
        existing.chatOutgoingMediaEntitys;
        existing.chatPendingInboundEntitys;
        existing.chatRouteCacheEntitys;
        existing.chatGroupEntitys;
        existing.chatGroupMemberEntitys;
        existing.chatGroupPendingCommitEntitys;
        existing.chatBindingFenceEntitys;
      } catch (error) {
        // 同名实例只能来自当前目标 schema。禁止关闭后重开来掩盖不完整集合，
        // 否则其它持有者仍可能继续使用另一套 collection 视图。
        throw StateError('已打开的 ChatIsar 不是当前完整 schema：$error');
      }
      await _verifySystemProtection();
      return existing;
    }

    // Isar 3.3.2 异步开库共用 FFI 输出指针；同一 isolate 内同步取得句柄，避免跨域串用。
    // 仅句柄创建同步执行，系统保护回读与本域生命周期继续沿用原有异步路径。
    final opened = Isar.openSync(
      _schemas,
      name: 'tatachatsdk_chat',
      directory: directory,
    );
    try {
      // Isar文件创建后由SDK自有iOS插件设置并回读备份排除属性；宿主不注册该方法。
      // 失败时不能把
      // 可能进入 iCloud Backup 的数据库作为可用 Chat 状态返回。
      await _verifySystemProtection();
      return opened;
    } catch (_) {
      await opened.close();
      rethrow;
    }
  }

  static Future<void> _verifySystemProtection() async {
    if (IsarCoreBootstrap.isFlutterTest) return;
    await ChatSystemProtectedStorage.prepare();
  }

  Future<void> resetForTest() async {
    if (!IsarCoreBootstrap.isFlutterTest) return;

    // 必须先完成同一套有界关闭；失败时保持终态，禁止带着晚到的打开任务复活测试库。
    await closeAndDeleteFromDisk();
    _isar = null;
    _opening = null;
    _deleteInFlight = null;
    _closing = null;
    _operationTail = Future<void>.value();
    _operationActive = false;
    _generation += 1;
    _lifecycle = _ChatIsarLifecycle.active;
  }

  /// 应用锁清空本机数据时删除 Chat 域数据库，不串入钱包数据库队列。
  ///
  /// 关闭意图在本方法返回 Future 前同步生效；此前已排队但尚未开始的操作会拒绝执行。
  /// 活动操作只获得短暂排空窗口，之后直接关闭数据库，避免永久挂起阻塞全 App 擦除。
  Future<void> closeAndDeleteFromDisk() {
    final inFlight = _closing;
    if (_lifecycle == _ChatIsarLifecycle.closing && inFlight != null) {
      return inFlight;
    }

    _lifecycle = _ChatIsarLifecycle.closing;
    _generation += 1;
    late final Future<void> task;
    task = _closeAndDeleteInternal().whenComplete(() {
      _lifecycle = _ChatIsarLifecycle.closed;
      if (identical(_closing, task)) _closing = null;
    });
    _closing = task;
    return task;
  }

  Future<void> _closeAndDeleteInternal() async {
    final failures = <String>[];
    final tailAtClose = _operationTail;
    var deleteWasAttempted = false;

    try {
      await tailAtClose.timeout(_gracefulDrainTimeout);
    } on TimeoutException {
      // 活动回调可能永久等待外部资源；超时后继续强制关闭本数据库。
    } catch (error) {
      failures.add('等待 Chat 操作队列失败：$error');
    }

    final openingAtClose = _opening;
    if (openingAtClose != null) {
      try {
        await openingAtClose.timeout(_openingSettleTimeout);
      } on _ChatOpeningCancelled catch (error) {
        if (error.cleanupError != null) {
          failures.add('取消 Chat 数据库打开后的删除失败：${error.cleanupError}');
        }
      } catch (error) {
        failures.add('等待 Chat 数据库打开任务失败：$error');
      }
    }

    final candidates = <Isar>[];
    final tracked = _isar;
    final registered = Isar.getInstance('tatachatsdk_chat');
    if (tracked != null) candidates.add(tracked);
    if (registered != null && !identical(registered, tracked)) {
      candidates.add(registered);
    }
    for (final candidate in candidates) {
      if (!candidate.isOpen) continue;
      deleteWasAttempted = true;
      try {
        final deleted = await _deleteInstance(
          candidate,
        ).timeout(_forcedDeleteTimeout);
        if (!deleted) {
          failures.add('Chat 数据库仍被其它实例持有，未实际关闭并删除。');
        }
      } catch (error) {
        failures.add('强制删除 Chat 数据库失败：$error');
      }
    }

    final deleting = _deleteInFlight;
    if (deleting != null) {
      deleteWasAttempted = true;
      try {
        final deleted = await deleting.timeout(_forcedDeleteTimeout);
        if (!deleted) {
          failures.add('Chat 数据库仍被其它实例持有，删除没有落盘。');
        }
      } catch (error) {
        failures.add('等待 Chat 数据库删除落盘失败：$error');
      }
    }

    if (!deleteWasAttempted) {
      try {
        // 上一进程留下的冷库在本进程没有注册实例；仍须真实打开后删除。
        final coldDatabase = await _open().timeout(_openingSettleTimeout);
        final deleted = await coldDatabase
            .close(deleteFromDisk: true)
            .timeout(_forcedDeleteTimeout);
        if (!deleted) {
          failures.add('Chat 冷数据库仍被其它实例持有，删除没有落盘。');
        }
      } catch (error) {
        failures.add('打开并删除 Chat 冷数据库失败：$error');
      }
    }

    if ((_isar?.isOpen ?? false) == false) _isar = null;
    if (failures.isNotEmpty) {
      throw StateError(failures.join('\n'));
    }
  }
}
