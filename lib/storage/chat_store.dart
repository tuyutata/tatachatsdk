import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

import '../core/chat_content.dart';
import '../core/chat_message.dart';
import '../group/model.dart';
import '../protocol/message.dart';
import 'chat_isar.dart';
import 'flow_store.dart';
import 'models.dart';
import 'records.dart';

/// 宿主公开身份绑定；不包含密钥，不触发钱包访问。
class ChatBinding {
  const ChatBinding({
    required this.bindingScope,
    required this.userId,
    required this.bindingRevision,
    required this.accountId,
  });

  final String bindingScope;
  final String userId;
  final int bindingRevision;
  final String accountId;

  String get id => '$bindingScope|$userId|$bindingRevision|$accountId';

  Map<String, Object> toJson() => <String, Object>{
    'binding_scope': bindingScope,
    'user_id': userId,
    'binding_revision': bindingRevision,
    'account_id': accountId,
  };

  factory ChatBinding.fromJson(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference(const <String>{
          'binding_scope',
          'user_id',
          'binding_revision',
          'account_id',
        }).isNotEmpty ||
        value.length != 4 ||
        value['binding_scope'] is! String ||
        value['user_id'] is! String ||
        value['binding_revision'] is! int ||
        value['account_id'] is! String) {
      throw const FormatException('聊天公开绑定格式无效');
    }
    final binding = ChatBinding(
      bindingScope: value['binding_scope'] as String,
      userId: value['user_id'] as String,
      bindingRevision: value['binding_revision'] as int,
      accountId: value['account_id'] as String,
    );
    binding.validate();
    return binding;
  }

  void validate() {
    if (bindingScope.trim().isEmpty ||
        userId.trim().isEmpty ||
        bindingRevision <= 0 ||
        accountId.trim().isEmpty) {
      throw StateError('聊天公开绑定不完整');
    }
  }
}

/// Chat 路由缓存记录。
class ChatRouteRecord {
  const ChatRouteRecord({
    required this.peerUserId,
    required this.routeDisplayName,
    required this.deviceId,
    required this.safetyNumber,
    this.nearbyPeerHint,
    this.note,
    this.createdAtMillis,
    this.updatedAtMillis,
  });

  final String peerUserId;
  final String routeDisplayName;
  final String deviceId;
  final String safetyNumber;
  final String? nearbyPeerHint;
  final String? note;
  final int? createdAtMillis;
  final int? updatedAtMillis;
}

/// 单次 Chat 运行上下文持有的不可变持久门闩快照。
///
/// token 不含秘密；它只把 user ID、finalized binding 与单调 generation 绑定在一起。
/// 所有写事务必须精确复核，禁止旧 isolate 在换绑、隔离或清除后晚写。
@immutable
class ChatBindingFenceToken {
  const ChatBindingFenceToken({
    required this.ownerUserId,
    required this.bindingRevision,
    required this.accountId,
    required this.bindingScope,
    required this.generation,
  });

  final String ownerUserId;
  final int bindingRevision;
  final String accountId;
  final String bindingScope;
  final int generation;
}

/// 同一 isolate 内保留调用顺序；跨 isolate 的最终授权由持久 fence CAS 负责。
class _ChatBindingMutationGate {
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
          // 前一个操作失败不能毒化同一 user ID 的后续队列。
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

/// 宿主用户 Chat 的 Isar 持久化仓库。
///
/// 本仓库只保存手机本地状态。聊天服务模块瞬时转发和近场 transport 只拿到完整
/// Protobuf message bytes，不会接触 [plaintext]。
class ChatStore implements ChatFlowStore<ChatBindingFenceToken> {
  ChatStore({ChatIsar? chatIsar})
    : this._(
        chatIsar: chatIsar ?? ChatIsar.instance,
        bindingMutationGate: _processBindingMutationGate,
      );

  ChatStore._({
    required ChatIsar chatIsar,
    required _ChatBindingMutationGate bindingMutationGate,
  }) : _chatIsar = chatIsar,
       _bindingMutationGate = bindingMutationGate;

  /// 在同一 Flutter 测试 isolate 内模拟另一 isolate 的独立静态 gate。
  /// 两个 Store 仍共享 ChatIsar，底层事务顺序与生产环境保持一致。
  @visibleForTesting
  factory ChatStore.withIndependentBindingGateForTest({ChatIsar? chatIsar}) {
    return ChatStore._(
      chatIsar: chatIsar ?? ChatIsar.instance,
      bindingMutationGate: _ChatBindingMutationGate(),
    );
  }

  final ChatIsar _chatIsar;

  /// 本地数据仅由 SDK 系统文件保护边界保护，不派生应用数据密钥。
  final _ChatBindingMutationGate _bindingMutationGate;

  /// 同一 user ID 的本地写入与公开绑定变更必须按调用先后串行。
  ///
  /// 消息载荷先在事务外校验；在最终事务内再复核持久代次，拒绝旧绑定晚写。
  /// 这里只串行 Chat 域内同一 user ID 的绑定
  /// 变更，不接入 WalletIsar，也不阻塞其它 user ID。
  static final _ChatBindingMutationGate _processBindingMutationGate =
      _ChatBindingMutationGate();

  static const String _fenceActive = 'active';
  static const String _fenceCleared = 'cleared';
  static const int _maxFenceGeneration = 0x7fffffffffffffff;
  static final RegExp _bindingScopePattern = RegExp(r'^0x[0-9a-f]{64}$');

  Future<T> _serializeBindingMutation<T>(
    String userId,
    Future<T> Function() action,
  ) => _bindingMutationGate.run(userId, action);

  /// 首次激活一个 user ID 的 Chat 写入门闩。
  ///
  /// 普通读写绝不隐式创建 fence；只有 finalized binding 收敛入口可以显式调用。
  /// 已存在的 cleared/其它 binding 也不得由本入口悄悄恢复。
  Future<ChatBindingFenceToken> activateBindingFence(
    ChatBinding binding,
  ) async {
    binding.validate();
    return _serializeBindingMutation(binding.userId, () {
      return _chatIsar.writeTxn((isar) async {
        final existing = await isar.chatBindingFenceEntitys.getByOwnerUserId(
          binding.userId,
        );
        if (existing == null) {
          final row = ChatBindingFenceEntity()
            ..ownerUserId = binding.userId
            ..bindingRevision = binding.bindingRevision
            ..accountId = binding.accountId
            ..bindingScope = binding.bindingScope
            ..generation = 1
            ..fenceState = _fenceActive;
          await isar.chatBindingFenceEntitys.putByOwnerUserId(row);
          return _tokenFromFence(row, binding);
        }
        _validateFence(existing);
        if (!_isActiveCurrentFence(existing, binding)) {
          throw StateError('Chat 写入门闩已经绑定到其它状态，禁止重复激活');
        }
        return _tokenFromFence(existing, binding);
      });
    });
  }

  /// 收敛链上 finalized 公开绑定；同 CID 历史保留，旧代次队列在同一事务清除。
  Future<ChatBindingFenceToken> convergeFinalizedBinding(
    ChatBinding current,
  ) async {
    current.validate();
    return _serializeBindingMutation(current.userId, () {
      return _chatIsar.writeTxn((isar) async {
        final row = await isar.chatBindingFenceEntitys.getByOwnerUserId(
          current.userId,
        );
        if (row == null) {
          final created = ChatBindingFenceEntity()
            ..ownerUserId = current.userId
            ..bindingRevision = current.bindingRevision
            ..accountId = current.accountId
            ..bindingScope = current.bindingScope
            ..generation = 1
            ..fenceState = _fenceActive;
          await isar.chatBindingFenceEntitys.putByOwnerUserId(created);
          return _tokenFromFence(created, current);
        }
        _validateFence(row);
        if (_isActiveCurrentFence(row, current)) {
          return _tokenFromFence(row, current);
        }
        if (row.fenceState == _fenceActive &&
            row.bindingRevision! >= current.bindingRevision) {
          throw StateError('finalized Chat binding 版本不得回退或同版本换账户');
        }
        await _clearTransientChatStateInTxn(isar, current.userId);
        final conversations = await isar.chatConversationEntitys
            .filter()
            .ownerUserIdEqualTo(current.userId)
            .findAll();
        for (final item in conversations) {
          item
            ..bindingRevision = current.bindingRevision
            ..accountId = current.accountId;
          await isar.chatConversationEntitys.put(item);
        }
        final messages = await isar.chatMessageEntitys
            .filter()
            .ownerUserIdEqualTo(current.userId)
            .findAll();
        for (final item in messages) {
          item
            ..bindingRevision = current.bindingRevision
            ..accountId = current.accountId;
          await isar.chatMessageEntitys.put(item);
        }
        row
          ..bindingRevision = current.bindingRevision
          ..accountId = current.accountId
          ..bindingScope = current.bindingScope
          ..generation = _nextFenceGeneration(row.generation)
          ..fenceState = _fenceActive;
        await isar.chatBindingFenceEntitys.put(row);
        return _tokenFromFence(row, current);
      });
    });
  }

  /// 捕获不可变公开绑定与持久 generation，防止旧上下文晚写。
  Future<ChatBindingFenceToken> captureBindingFenceToken(
    ChatBinding binding,
  ) async {
    binding.validate();
    return _chatIsar.read((isar) async {
      final row = await isar.chatBindingFenceEntitys.getByOwnerUserId(
        binding.userId,
      );
      if (row == null) {
        throw StateError('Chat 写入门闩尚未显式激活');
      }
      _validateFence(row);
      if (!_isActiveCurrentFence(row, binding)) {
        throw StateError('Chat binding 与持久写入门闩不一致');
      }
      return _tokenFromFence(row, binding);
    });
  }

  /// 文件与 OpenMLS 边界在进入/退出跨 isolate 临界区时复核同一持久 token。
  Future<void> validateBindingFenceToken(ChatBindingFenceToken bindingToken) {
    return _chatIsar.read((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
    });
  }

  static ChatBindingFenceToken _tokenFromFence(
    ChatBindingFenceEntity row,
    ChatBinding binding,
  ) => ChatBindingFenceToken(
    ownerUserId: binding.userId,
    bindingRevision: binding.bindingRevision,
    accountId: binding.accountId,
    bindingScope: binding.bindingScope,
    generation: row.generation,
  );

  static int _nextFenceGeneration(int generation) {
    if (generation <= 0 || generation >= _maxFenceGeneration) {
      throw StateError('Chat 写入门闩 generation 已损坏或耗尽');
    }
    return generation + 1;
  }

  static bool _isCurrentFenceBinding(
    ChatBindingFenceEntity row,
    ChatBinding binding,
  ) =>
      row.ownerUserId == binding.userId &&
      row.bindingRevision == binding.bindingRevision &&
      row.accountId == binding.accountId &&
      row.bindingScope == binding.bindingScope;

  static bool _isActiveCurrentFence(
    ChatBindingFenceEntity row,
    ChatBinding binding,
  ) => row.fenceState == _fenceActive && _isCurrentFenceBinding(row, binding);

  static void _validateFence(ChatBindingFenceEntity row) {
    final present = <Object?>[
      row.bindingRevision,
      row.accountId,
      row.bindingScope,
    ].where((value) => value != null).length;
    if (row.ownerUserId.isEmpty ||
        row.generation <= 0 ||
        row.generation > _maxFenceGeneration ||
        (present != 0 && present != 3) ||
        (row.fenceState != _fenceActive && row.fenceState != _fenceCleared) ||
        (row.fenceState == _fenceActive && present != 3) ||
        (present == 3 &&
            (row.bindingRevision! <= 0 ||
                row.accountId!.isEmpty ||
                !_bindingScopePattern.hasMatch(row.bindingScope!)))) {
      throw const FormatException('Chat 持久绑定门闩结构损坏');
    }
  }

  static Future<ChatBindingFenceEntity> _requireBindingTokenInTxn(
    Isar isar,
    ChatBindingFenceToken token,
  ) async {
    final row = await isar.chatBindingFenceEntitys.getByOwnerUserId(
      token.ownerUserId,
    );
    if (row == null) throw StateError('Chat 持久绑定门闩缺失');
    _validateFence(row);
    if (row.fenceState != _fenceActive ||
        row.generation != token.generation ||
        row.bindingRevision != token.bindingRevision ||
        row.accountId != token.accountId ||
        row.bindingScope != token.bindingScope) {
      throw StateError('Chat 绑定 token 已过期');
    }
    return row;
  }

  Future<ChatBinding> _resolveBinding({
    required String ownerUserId,
    required String currentAccountId,
    String? expectedBindingScope,
  }) => _chatIsar.read((isar) async {
    final row = await isar.chatBindingFenceEntitys.getByOwnerUserId(
      ownerUserId,
    );
    if (row == null) throw StateError('Chat 公开绑定尚未激活');
    _validateFence(row);
    if (row.fenceState != _fenceActive ||
        row.accountId != currentAccountId ||
        (expectedBindingScope != null &&
            row.bindingScope != expectedBindingScope)) {
      throw StateError('Chat 公开绑定已变化');
    }
    return ChatBinding(
      bindingScope: row.bindingScope!,
      userId: ownerUserId,
      bindingRevision: row.bindingRevision!,
      accountId: row.accountId!,
    );
  });

  static void _requireWriterContext({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    String? currentAccountId,
  }) {
    if (bindingToken.ownerUserId != ownerUserId ||
        (currentAccountId != null &&
            bindingToken.accountId != currentAccountId)) {
      throw StateError('Chat 写入参数与 binding token 不一致');
    }
  }

  static void _requireResolvedBinding({
    required ChatBindingFenceToken bindingToken,
    required ChatBinding binding,
  }) {
    if (bindingToken.bindingRevision != binding.bindingRevision ||
        bindingToken.accountId != binding.accountId ||
        bindingToken.bindingScope != binding.bindingScope) {
      throw StateError('Chat 公开 binding 与持久 token 不一致');
    }
  }

  /// 正文按唯一目标载荷保存于系统保护数据库，搜索索引只保存去重 bigram。
  Future<_StoredMessageContent> _prepareMessage({
    required String ownerUserId,
    required String currentAccountId,
    required String messageId,
    required String? plaintext,
    required ChatBinding binding,
  }) async {
    if (plaintext == null || plaintext.isEmpty) {
      return const _StoredMessageContent(payload: null, tokens: <String>[]);
    }
    return _StoredMessageContent(
      payload: plaintext,
      tokens: _searchTokens(_messageSummary(plaintext)),
    );
  }

  Future<String> _prepareSummary({
    required String ownerUserId,
    required String currentAccountId,
    required String conversationId,
    required String? plaintext,
    required ChatBinding binding,
  }) async => _messageSummary(plaintext);

  Future<List<ChatConversationPreview>> readConversationPreviews({
    required String ownerUserId,
    required String currentAccountId,
  }) async {
    // 空会话库是新用户的正常状态。先只读 ChatIsar；本 user ID 没有任何行时
    // 直接返回，不启动任何钱包或网络操作。
    final candidates = await _chatIsar.read((isar) async {
      final rows = await isar.chatConversationEntitys
          .filter()
          .idGreaterThan(0, include: true)
          .findAll();
      return rows
          .where((row) => row.ownerUserId == ownerUserId)
          .toList(growable: false);
    });
    if (candidates.isEmpty) {
      return const <ChatConversationPreview>[];
    }
    final binding = await _resolveBinding(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
    final readToken = await captureBindingFenceToken(binding);
    final rows = candidates
        .where(
          (row) =>
              row.bindingRevision == binding.bindingRevision &&
              row.accountId == binding.accountId,
        )
        .toList(growable: false);
    if (rows.isEmpty) {
      return const <ChatConversationPreview>[];
    }
    rows.sort((a, b) => b.lastUpdatedAtMillis.compareTo(a.lastUpdatedAtMillis));

    final out = <ChatConversationPreview>[];
    for (final row in rows) {
      out.add(_conversationPreviewFromEntity(row, row.lastMessageSummary));
    }
    await validateBindingFenceToken(readToken);
    return List<ChatConversationPreview>.unmodifiable(out);
  }

  Future<List<ChatRouteRecord>> readRouteRecords(String ownerUserId) {
    return _chatIsar.read((isar) async {
      final rows = await isar.chatRouteCacheEntitys
          .filter()
          .idGreaterThan(0, include: true)
          .findAll();
      final owned =
          rows
              .where((row) => row.ownerUserId == ownerUserId)
              .toList(growable: false)
            ..sort((a, b) => a.routeDisplayName.compareTo(b.routeDisplayName));
      return owned.map(_routeFromEntity).toList(growable: false);
    });
  }

  Future<ChatRouteRecord?> getRouteRecord(
    String ownerUserId,
    String peerUserId,
  ) {
    return _chatIsar.read((isar) async {
      final row = await isar.chatRouteCacheEntitys.getByOwnerUserIdPeerUserId(
        ownerUserId,
        peerUserId,
      );
      return row == null ? null : _routeFromEntity(row);
    });
  }

  Future<void> upsertRouteRecord(
    String ownerUserId,
    ChatRouteRecord route, {
    required ChatBindingFenceToken bindingToken,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      final now = DateTime.now().millisecondsSinceEpoch;
      final existing = await isar.chatRouteCacheEntitys
          .getByOwnerUserIdPeerUserId(ownerUserId, route.peerUserId);
      final entity = existing ?? ChatRouteCacheEntity();
      entity
        ..ownerUserId = ownerUserId
        ..peerUserId = route.peerUserId
        ..routeDisplayName = route.routeDisplayName
        ..deviceId = route.deviceId
        ..safetyNumber = route.safetyNumber
        ..nearbyPeerHint = route.nearbyPeerHint
        ..note = route.note
        ..createdAtMillis =
            existing?.createdAtMillis ?? route.createdAtMillis ?? now
        ..updatedAtMillis = route.updatedAtMillis ?? now;
      await isar.chatRouteCacheEntitys.putByOwnerUserIdPeerUserId(entity);
    });
  }

  Future<List<ChatStoredMessage>> readMessages({
    required String ownerUserId,
    required String currentAccountId,
    required String conversationId,
  }) async {
    // 先用现有 conversationId 索引复制当前会话记录快照；禁止每次打开会话都扫描
    // 整张消息表。空会话在这里直接结束，也不触发钱包或网络操作。
    final conversationRows = await _chatIsar.read((isar) async {
      final rows = await isar.chatMessageEntitys
          .where()
          .conversationIdEqualTo(conversationId)
          .findAll();
      return rows
          .where((row) => row.ownerUserId == ownerUserId)
          .toList(growable: false);
    });
    if (conversationRows.isEmpty) return const <ChatStoredMessage>[];

    final binding = await _resolveBinding(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
    final readToken = await captureBindingFenceToken(binding);
    final rows =
        conversationRows
            .where(
              (row) =>
                  row.bindingRevision == binding.bindingRevision &&
                  row.accountId == binding.accountId,
            )
            .toList(growable: false)
          ..sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    if (rows.isEmpty) return const <ChatStoredMessage>[];

    final out = <ChatStoredMessage>[];
    for (final row in rows) {
      out.add(_messageFromEntity(row, row.payloadJson));
    }
    await validateBindingFenceToken(readToken);
    return List<ChatStoredMessage>.unmodifiable(out);
  }

  /// 展示读取逐行校验本地载荷，损坏行只隔离显示并计数，不伪造正文或删除记录。
  Future<ChatMessageDisplayBatch> readMessagesForDisplay({
    required String ownerUserId,
    required String currentAccountId,
    required String conversationId,
  }) async {
    // 展示读取只复制一次当前会话快照，再逐条校验。单条载荷或
    // 载荷异常不得触发第二次整批查询，也不得阻断同会话其余有效历史消息。
    final conversationRows = await _chatIsar.read((isar) async {
      final rows = await isar.chatMessageEntitys
          .where()
          .conversationIdEqualTo(conversationId)
          .findAll();
      return rows
          .where((row) => row.ownerUserId == ownerUserId)
          .toList(growable: false);
    });
    if (conversationRows.isEmpty) {
      return const ChatMessageDisplayBatch(
        messages: <ChatStoredMessage>[],
        integrityFailureCount: 0,
      );
    }

    final binding = await _resolveBinding(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
    final readToken = await captureBindingFenceToken(binding);
    final rows =
        conversationRows
            .where(
              (row) =>
                  row.bindingRevision == binding.bindingRevision &&
                  row.accountId == binding.accountId,
            )
            .toList(growable: false)
          ..sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    if (rows.isEmpty) {
      return const ChatMessageDisplayBatch(
        messages: <ChatStoredMessage>[],
        integrityFailureCount: 0,
      );
    }

    final storedMessages = <ChatStoredMessage>[];
    var integrityFailureCount = 0;
    for (final row in rows) {
      try {
        storedMessages.add(_messageFromEntity(row, row.payloadJson));
      } on FormatException catch (error) {
        // UTF-8、消息类型与投递状态都属于本机记录完整性边界；只隔离该行，
        // 禁止把未知枚举或畸形正文降级成普通文本。
        integrityFailureCount += 1;
        debugPrint(
          '[ChatStore] display_row_rejected message_id=${row.messageId} '
          'stage=stored_metadata error=${error.runtimeType}',
        );
      }
    }
    await validateBindingFenceToken(readToken);
    return filterChatMessagesForDisplay(
      storedMessages,
      initialIntegrityFailureCount: integrityFailureCount,
    );
  }

  /// 判断入站应用消息是否已经在当前绑定下落库。实时链路可能因设备确认丢失而
  /// 重投同一 message；必须在再次推进 MLS ratchet 前用稳定 ID 去重。
  Future<bool> hasIncomingMessage({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String messageId,
    required String senderUserId,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.read((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      final row = await isar.chatMessageEntitys.getByOwnerUserIdMessageId(
        ownerUserId,
        messageId,
      );
      return row != null &&
          row.bindingRevision == bindingToken.bindingRevision &&
          row.accountId == bindingToken.accountId &&
          row.direction == 'incoming' &&
          row.senderUserId == senderUserId;
    });
  }

  /// 搜索系统保护数据库的 bigram 索引，再复核实际子串顺序。
  Future<List<ChatStoredMessage>> searchMessages({
    required String ownerUserId,
    required String currentAccountId,
    required String keyword,
    int limit = 50,
  }) async {
    final needle = keyword.trim().toLowerCase();
    if (needle.isEmpty || ownerUserId.isEmpty || currentAccountId.isEmpty) {
      return const <ChatStoredMessage>[];
    }
    final binding = await _resolveBinding(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
    final readToken = await captureBindingFenceToken(binding);

    final tokens = _searchTokens(needle);
    final candidates = await _chatIsar.read((isar) async {
      List<ChatMessageEntity> candidates;
      if (tokens.isEmpty) {
        candidates = await isar.chatMessageEntitys
            .filter()
            .ownerUserIdEqualTo(ownerUserId)
            .findAll();
      } else {
        var query = isar.chatMessageEntitys
            .filter()
            .ownerUserIdEqualTo(ownerUserId)
            .and()
            .searchTokensElementEqualTo(tokens.first);
        for (final token in tokens.skip(1)) {
          query = query.and().searchTokensElementEqualTo(token);
        }
        candidates = await query.findAll();
      }
      candidates.sort((a, b) => b.createdAtMillis.compareTo(a.createdAtMillis));
      return candidates
          .where(
            (row) =>
                row.bindingRevision == binding.bindingRevision &&
                row.accountId == binding.accountId,
          )
          .toList(growable: false);
    });

    final hits = <ChatStoredMessage>[];
    for (final row in candidates) {
      if (hits.length >= limit) break;
      final plaintext = row.payloadJson;
      if (!_messageSummary(plaintext).toLowerCase().contains(needle)) {
        continue; // 索引假阳性，复验滤掉
      }
      hits.add(_messageFromEntity(row, plaintext));
    }
    await validateBindingFenceToken(readToken);
    return List<ChatStoredMessage>.unmodifiable(hits);
  }

  /// 当前页面成功展示到 [readThroughMillis] 后原子清零该会话未读数。
  ///
  /// 如果写事务开始前又有更新消息落库，则保留计数，等待页面展示更新快照后再次清零，
  /// 避免把用户尚未看到的消息错误标记为已读。
  Future<bool> markConversationRead({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String conversationId,
    required int readThroughMillis,
  }) {
    if (readThroughMillis < 0) {
      throw ArgumentError.value(readThroughMillis, 'readThroughMillis');
    }
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      final conversation = await isar.chatConversationEntitys
          .getByOwnerUserIdConversationId(ownerUserId, conversationId);
      if (conversation == null || conversation.unreadCount == 0) return true;
      if (conversation.lastUpdatedAtMillis > readThroughMillis) return false;
      conversation.unreadCount = 0;
      await isar.chatConversationEntitys.putByOwnerUserIdConversationId(
        conversation,
      );
      return true;
    });
  }

  /// 彻底删除本机会话记录。
  ///
  /// 聊天服务模块不保存聊天内容；用户删除聊天记录时，本地 Isar 是唯一
  /// 需要清理的聊天历史真源，附件缓存目录由运行态在同一操作中删除。
  Future<void> deleteConversation(
    String ownerUserId,
    String conversationId, {
    required ChatBindingFenceToken bindingToken,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      // 会话删除只命中目标 conversationId，并由 Isar 在事务内批量删除；禁止
      // 把五张全表复制到 Dart 后逐行过滤，使后台清理时间随全账户历史线性增长。
      await isar.chatMessageEntitys
          .where()
          .conversationIdEqualTo(conversationId)
          .filter()
          .ownerUserIdEqualTo(ownerUserId)
          .deleteAll();
      await isar.chatConversationEntitys
          .where()
          .ownerUserIdConversationIdEqualTo(ownerUserId, conversationId)
          .deleteAll();
      await isar.chatOutboundQueueEntitys
          .where()
          .conversationIdEqualTo(conversationId)
          .filter()
          .ownerUserIdEqualTo(ownerUserId)
          .deleteAll();
      await isar.chatPendingInboundEntitys
          .where()
          .conversationIdEqualTo(conversationId)
          .filter()
          .ownerUserIdEqualTo(ownerUserId)
          .deleteAll();
      await isar.chatOutgoingMediaEntitys
          .filter()
          .ownerUserIdEqualTo(ownerUserId)
          .conversationIdEqualTo(conversationId)
          .deleteAll();
    });
  }

  /// 注销用户：清除该 user ID 在本机的全部 Chat 历史与队列。
  ///
  /// 聊天服务模块端 A 的系统唤醒端点由 Worker purge 删除；本地 Isar 是 A 私信密文与
  /// 本地队列的唯一残留处，须一并清空以做到零残留。
  Future<void> clearAllForUserId(String userId) {
    return _serializeBindingMutation(userId, () async {
      await _chatIsar.writeTxn((isar) async {
        await _clearAllChatStateInTxn(isar, userId);
        final existing = await isar.chatBindingFenceEntitys.getByOwnerUserId(
          userId,
        );
        if (existing == null) {
          await isar.chatBindingFenceEntitys.putByOwnerUserId(
            ChatBindingFenceEntity()
              ..ownerUserId = userId
              ..bindingRevision = null
              ..accountId = null
              ..bindingScope = null
              ..generation = 1
              ..fenceState = _fenceCleared,
          );
          return;
        }
        _validateFence(existing);
        existing
          ..generation = _nextFenceGeneration(existing.generation)
          ..fenceState = _fenceCleared;
        await isar.chatBindingFenceEntitys.put(existing);
      });
    });
  }

  static Future<void> _clearAllChatStateInTxn(Isar isar, String userId) async {
    final conversations = await isar.chatConversationEntitys
        .filter()
        .ownerUserIdEqualTo(userId)
        .findAll();
    for (final row in conversations) {
      await isar.chatConversationEntitys.delete(row.id);
    }
    final messages = await isar.chatMessageEntitys
        .filter()
        .ownerUserIdEqualTo(userId)
        .findAll();
    for (final row in messages) {
      await isar.chatMessageEntitys.delete(row.id);
    }
    await _clearTransientChatStateInTxn(isar, userId);
  }

  static Future<void> _clearTransientChatStateInTxn(
    Isar isar,
    String userId,
  ) async {
    final outbound = await isar.chatOutboundQueueEntitys
        .filter()
        .ownerUserIdEqualTo(userId)
        .findAll();
    for (final row in outbound) {
      await isar.chatOutboundQueueEntitys.delete(row.id);
    }
    final pending = await isar.chatPendingInboundEntitys
        .filter()
        .ownerUserIdEqualTo(userId)
        .findAll();
    for (final row in pending) {
      await isar.chatPendingInboundEntitys.delete(row.id);
    }
    final outgoingMedia = await isar.chatOutgoingMediaEntitys
        .filter()
        .ownerUserIdEqualTo(userId)
        .findAll();
    for (final row in outgoingMedia) {
      await isar.chatOutgoingMediaEntitys.delete(row.id);
    }
    final routes = await isar.chatRouteCacheEntitys
        .filter()
        .ownerUserIdEqualTo(userId)
        .findAll();
    for (final row in routes) {
      await isar.chatRouteCacheEntitys.delete(row.id);
    }
    final groups = await isar.chatGroupEntitys
        .filter()
        .ownerUserIdEqualTo(userId)
        .findAll();
    for (final row in groups) {
      await isar.chatGroupEntitys.delete(row.id);
    }
    final members = await isar.chatGroupMemberEntitys
        .filter()
        .ownerUserIdEqualTo(userId)
        .findAll();
    for (final row in members) {
      await isar.chatGroupMemberEntitys.delete(row.id);
    }
    final commits = await isar.chatGroupPendingCommitEntitys
        .filter()
        .ownerUserIdEqualTo(userId)
        .findAll();
    for (final row in commits) {
      await isar.chatGroupPendingCommitEntitys.delete(row.id);
    }
  }

  /// 先把用户操作保存为本机密文消息，再异步取得接收设备 KeyPackage 并生成 MLS 消息。
  ///
  /// 本行已经是会话与消息列表的真值，不是 UI 临时气泡。`messageBytesHex` 为空
  /// 明确表示“尚未转换为 MLS Message”；正文保存于系统保护数据库，
  /// 聊天服务模块与系统推送均看不到本行。
  Future<void> savePendingOutgoingMessage({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    required String localMessageId,
    required String conversationId,
    required String recipientUserId,
    required ChatMessageKind messageKind,
    required String payload,
    required int createdAtMillis,
  }) async {
    _requireWriterContext(
      bindingToken: bindingToken,
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
    if (!localMessageId.startsWith('pending:')) {
      throw const FormatException('Chat 本地待发送消息 ID 不合法');
    }
    ChatPayloadCodec.decode(payload);
    await _serializeBindingMutation(ownerUserId, () async {
      final binding = await _resolveBinding(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        expectedBindingScope: bindingToken.bindingScope,
      );
      _requireResolvedBinding(bindingToken: bindingToken, binding: binding);
      final prepared = await _prepareMessage(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        messageId: localMessageId,
        plaintext: payload,
        binding: binding,
      );
      final summary = await _prepareSummary(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        conversationId: conversationId,
        plaintext: payload,
        binding: binding,
      );
      await _chatIsar.writeTxn((isar) async {
        await _requireBindingTokenInTxn(isar, bindingToken);
        await _putConversationInTxn(
          isar: isar,
          ownerUserId: ownerUserId,
          bindingRevision: binding.bindingRevision,
          accountId: binding.accountId,
          conversationId: conversationId,
          peerUserId: recipientUserId,
          title: recipientUserId,
          lastMessageSummary: summary,
          lastUpdatedAtMillis: createdAtMillis,
          unreadDelta: 0,
          deliveryState: ChatMessageDeliveryState.queued,
        );
        await isar.chatMessageEntitys.putByOwnerUserIdMessageId(
          ChatMessageEntity()
            ..ownerUserId = ownerUserId
            ..bindingRevision = binding.bindingRevision
            ..accountId = binding.accountId
            ..messageId = localMessageId
            ..conversationId = conversationId
            ..direction = 'outgoing'
            ..senderUserId = ownerUserId
            ..recipientUserId = recipientUserId
            ..senderDeviceId = ''
            ..messageKind = messageKind.name
            ..deliveryState = ChatMessageDeliveryState.queued.name
            ..payloadJson = prepared.payload
            ..searchTokens = prepared.tokens
            ..messageBytesHex = ''
            ..createdAtMillis = createdAtMillis,
        );
      });
    });
  }

  /// 按创建顺序读取本机待加密消息；失败必须保留原行，禁止跳过前一条推进同会话
  /// MLS ratchet。可选过滤只用于当前聊天窗口的定向补发。
  Future<List<ChatPendingOutgoingMessage>> readPendingOutgoingMessages({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    String? recipientUserId,
    String? conversationId,
  }) async {
    _requireWriterContext(
      bindingToken: bindingToken,
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
    final rows = await _chatIsar.read((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      final candidates = await isar.chatMessageEntitys
          .filter()
          .ownerUserIdEqualTo(ownerUserId)
          .findAll();
      return candidates
          .where(
            (row) =>
                row.bindingRevision == bindingToken.bindingRevision &&
                row.accountId == bindingToken.accountId &&
                row.direction == 'outgoing' &&
                row.messageId.startsWith('pending:') &&
                row.deliveryState != ChatMessageDeliveryState.failed.name &&
                row.messageBytesHex.isEmpty &&
                (recipientUserId == null ||
                    row.recipientUserId == recipientUserId) &&
                (conversationId == null ||
                    row.conversationId == conversationId),
          )
          .toList(growable: false)
        ..sort(
          (left, right) =>
              left.createdAtMillis.compareTo(right.createdAtMillis),
        );
    });
    if (rows.isEmpty) return const <ChatPendingOutgoingMessage>[];
    final binding = await _resolveBinding(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      expectedBindingScope: bindingToken.bindingScope,
    );
    _requireResolvedBinding(bindingToken: bindingToken, binding: binding);

    final pending = <ChatPendingOutgoingMessage>[];
    for (final row in rows) {
      final payload = row.payloadJson;
      if (payload == null || payload.isEmpty) {
        throw StateError('Chat 本地待发送消息正文缺失');
      }
      ChatPayloadCodec.decode(payload);
      pending.add(
        ChatPendingOutgoingMessage(
          localMessageId: row.messageId,
          conversationId: row.conversationId,
          recipientUserId: row.recipientUserId,
          messageKind: _messageKindFromName(row.messageKind),
          createdAtMillis: row.createdAtMillis,
          payload: payload,
        ),
      );
    }
    await validateBindingFenceToken(bindingToken);
    return List<ChatPendingOutgoingMessage>.unmodifiable(pending);
  }

  /// 本机待发消息超过云端统一 7 天存活期后保留为失败历史，但不再进入补发队列。
  Future<void> markPendingOutgoingFailed({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String localMessageId,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      final pending = await isar.chatMessageEntitys.getByOwnerUserIdMessageId(
        ownerUserId,
        localMessageId,
      );
      if (pending == null ||
          pending.direction != 'outgoing' ||
          !pending.messageId.startsWith('pending:') ||
          pending.messageBytesHex.isNotEmpty) {
        return;
      }
      pending.deliveryState = ChatMessageDeliveryState.failed.name;
      await isar.chatMessageEntitys.putByOwnerUserIdMessageId(pending);
    });
  }

  @override
  Future<void> saveOutgoingMessage({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    required EncryptedMessage message,
    required List<int> messageBytes,
    required String recipientUserId,
    required ChatMessageKind messageKind,
    required ChatMessageDeliveryState deliveryState,
    String? plaintext,
    String? pendingLocalMessageId,
    ChatPendingMedia? pendingMedia,
  }) async {
    _requireWriterContext(
      bindingToken: bindingToken,
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
    await _serializeBindingMutation(ownerUserId, () async {
      final binding = await _resolveBinding(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        expectedBindingScope: bindingToken.bindingScope,
      );
      _requireResolvedBinding(bindingToken: bindingToken, binding: binding);
      // 载荷校验在事务外完成，最终写入仍须复核持久绑定代次。
      final prepared = await _prepareMessage(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        messageId: message.messageId,
        plaintext: plaintext,
        binding: binding,
      );
      final summary = await _prepareSummary(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        conversationId: message.conversationId,
        plaintext: plaintext,
        binding: binding,
      );
      await _chatIsar.writeTxn((isar) async {
        await _requireBindingTokenInTxn(isar, bindingToken);
        var conversationUpdatedAtMillis = message.createdAtMillis.toInt();
        if (pendingLocalMessageId != null) {
          if (!pendingLocalMessageId.startsWith('pending:')) {
            throw const FormatException('Chat 待转换消息 ID 不合法');
          }
          final pending = await isar.chatMessageEntitys
              .getByOwnerUserIdMessageId(ownerUserId, pendingLocalMessageId);
          if (pending == null ||
              pending.bindingRevision != binding.bindingRevision ||
              pending.accountId != binding.accountId ||
              pending.direction != 'outgoing' ||
              pending.conversationId != message.conversationId ||
              pending.recipientUserId != recipientUserId ||
              pending.messageKind != messageKind.name ||
              pending.messageBytesHex.isNotEmpty) {
            throw StateError('Chat 待转换消息与正式 Message 上下文不一致');
          }
          conversationUpdatedAtMillis = pending.createdAtMillis;
        }
        await _putConversationInTxn(
          isar: isar,
          ownerUserId: ownerUserId,
          bindingRevision: binding.bindingRevision,
          accountId: binding.accountId,
          conversationId: message.conversationId,
          peerUserId: message.recipientUserId,
          title: message.recipientUserId,
          lastMessageSummary: summary,
          lastUpdatedAtMillis: conversationUpdatedAtMillis,
          unreadDelta: 0,
          deliveryState: deliveryState,
        );
        await isar.chatMessageEntitys.putByOwnerUserIdMessageId(
          _messageEntity(
            ownerUserId: ownerUserId,
            bindingRevision: binding.bindingRevision,
            accountId: binding.accountId,
            message: message,
            messageBytes: messageBytes,
            direction: 'outgoing',
            messageKind: messageKind,
            deliveryState: deliveryState,
            payloadJson: prepared.payload,
            searchTokens: prepared.tokens,
          ),
        );
        await isar.chatOutboundQueueEntitys.putByOwnerUserIdMessageId(
          ChatOutboundQueueEntity()
            ..ownerUserId = ownerUserId
            ..messageId = message.messageId
            ..conversationId = message.conversationId
            ..recipientUserId = recipientUserId
            ..messageBytesHex = _bytesToHex(messageBytes)
            ..deliveryState = deliveryState.name
            ..attemptCount = 0
            ..lastError = null
            ..updatedAtMillis = DateTime.now().millisecondsSinceEpoch,
        );
        if (pendingMedia != null) {
          final isMediaMessage = switch (messageKind) {
            ChatMessageKind.image ||
            ChatMessageKind.video ||
            ChatMessageKind.file ||
            ChatMessageKind.audio => true,
            ChatMessageKind.text || ChatMessageKind.sticker => false,
          };
          if (!isMediaMessage ||
              pendingMedia.conversationId != message.conversationId ||
              pendingMedia.recipientUserId != recipientUserId ||
              pendingMedia.attachmentId.isEmpty ||
              pendingMedia.fileName.isEmpty ||
              pendingMedia.contentType.isEmpty ||
              pendingMedia.byteSize <= 0) {
            throw StateError('Chat 待投递媒体与正式 Message 上下文不一致');
          }
          // 媒体控制消息、待发送 Message、附件投递事实与旧 pending 删除必须
          // 原子成立。掉电后不能只剩媒体气泡却没有对应附件投递事实。
          await isar.chatOutgoingMediaEntitys.putByOwnerUserIdPendingKey(
            ChatOutgoingMediaEntity()
              ..ownerUserId = ownerUserId
              ..pendingKey = '${pendingMedia.attachmentId}|$recipientUserId'
              ..attachmentId = pendingMedia.attachmentId
              ..recipientUserId = recipientUserId
              ..conversationId = message.conversationId
              ..fileName = pendingMedia.fileName
              ..contentType = pendingMedia.contentType
              ..byteSize = pendingMedia.byteSize
              ..createdAtMillis = conversationUpdatedAtMillis,
          );
        }
        if (pendingLocalMessageId != null) {
          // 正式应用消息、出站队列和待加密行替换必须处于同一 Isar 事务；
          // 崩溃后只能看到旧待发送行或完整正式 Message，不能出现 UI 消息丢失。
          await isar.chatMessageEntitys.deleteByOwnerUserIdMessageId(
            ownerUserId,
            pendingLocalMessageId,
          );
        }
      });
    });
  }

  @override
  Future<void> queueOutgoingMessage({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required EncryptedMessage message,
    required List<int> messageBytes,
    required String recipientUserId,
    required ChatMessageDeliveryState deliveryState,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      await isar.chatOutboundQueueEntitys.putByOwnerUserIdMessageId(
        ChatOutboundQueueEntity()
          ..ownerUserId = ownerUserId
          ..messageId = message.messageId
          ..conversationId = message.conversationId
          ..recipientUserId = recipientUserId
          ..messageBytesHex = _bytesToHex(messageBytes)
          ..deliveryState = deliveryState.name
          ..attemptCount = 0
          ..lastError = null
          ..updatedAtMillis = DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  /// 本机事务成功返回后，调用方才可确认原生MLS处理结果及服务端接收。
  @override
  Future<void> saveIncomingMessage({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    required EncryptedMessage message,
    required List<int> messageBytes,
    required ChatMessageKind messageKind,
    required String plaintext,
  }) async {
    _requireWriterContext(
      bindingToken: bindingToken,
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
    await _serializeBindingMutation(ownerUserId, () async {
      final binding = await _resolveBinding(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        expectedBindingScope: bindingToken.bindingScope,
      );
      _requireResolvedBinding(bindingToken: bindingToken, binding: binding);
      final prepared = await _prepareMessage(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        messageId: message.messageId,
        plaintext: plaintext,
        binding: binding,
      );
      final summary = await _prepareSummary(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        conversationId: message.conversationId,
        plaintext: plaintext,
        binding: binding,
      );
      await _chatIsar.writeTxn((isar) async {
        await _requireBindingTokenInTxn(isar, bindingToken);
        final existing = await isar.chatMessageEntitys
            .getByOwnerUserIdMessageId(ownerUserId, message.messageId);
        // WSS 与七天邮箱可能送达同一 Message；重复项只由运行态继续 ACK，
        // 不能再次推进会话未读数或覆盖最后消息时间。
        if (existing != null) {
          if (existing.direction == 'incoming') return;
          throw StateError('Chat Message ID 与本机出站记录冲突');
        }
        await _putConversationInTxn(
          isar: isar,
          ownerUserId: ownerUserId,
          bindingRevision: binding.bindingRevision,
          accountId: binding.accountId,
          conversationId: message.conversationId,
          peerUserId: message.senderUserId,
          title: message.senderUserId,
          lastMessageSummary: summary,
          lastUpdatedAtMillis: message.createdAtMillis.toInt(),
          unreadDelta: 1,
          deliveryState: ChatMessageDeliveryState.receivedByDevice,
        );
        await isar.chatMessageEntitys.putByOwnerUserIdMessageId(
          _messageEntity(
            ownerUserId: ownerUserId,
            bindingRevision: binding.bindingRevision,
            accountId: binding.accountId,
            message: message,
            messageBytes: messageBytes,
            direction: 'incoming',
            messageKind: messageKind,
            deliveryState: ChatMessageDeliveryState.receivedByDevice,
            payloadJson: prepared.payload,
            searchTokens: prepared.tokens,
          ),
        );
      });
    });
  }

  @override
  Future<void> markOutgoingDelivery({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String messageId,
    required ChatMessageDeliveryState state,
    String? errorMessage,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      final terminalMessageFailure =
          errorMessage == 'chat_message_expired' ||
          errorMessage == 'chat_message_invalid';
      final effectiveState = terminalMessageFailure
          ? ChatMessageDeliveryState.failed
          : state;
      final queue = await isar.chatOutboundQueueEntitys
          .getByOwnerUserIdMessageId(ownerUserId, messageId);
      if (queue != null) {
        if (effectiveState == ChatMessageDeliveryState.receivedByDevice ||
            effectiveState == ChatMessageDeliveryState.sent ||
            terminalMessageFailure) {
          await isar.chatOutboundQueueEntitys.delete(queue.id);
        } else {
          queue
            ..deliveryState = effectiveState.name
            ..attemptCount = queue.attemptCount + 1
            ..lastError = errorMessage
            ..updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
          await isar.chatOutboundQueueEntitys.putByOwnerUserIdMessageId(queue);
        }
      }
      final message = await isar.chatMessageEntitys.getByOwnerUserIdMessageId(
        ownerUserId,
        messageId,
      );
      if (message != null) {
        message.deliveryState = effectiveState.name;
        await isar.chatMessageEntitys.putByOwnerUserIdMessageId(message);
        final conversation = await isar.chatConversationEntitys
            .getByOwnerUserIdConversationId(
              ownerUserId,
              message.conversationId,
            );
        if (conversation != null) {
          conversation.lastDeliveryState = effectiveState.name;
          await isar.chatConversationEntitys.putByOwnerUserIdConversationId(
            conversation,
          );
        }
      }
    });
  }

  @override
  Future<void> savePendingInbound({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required EncryptedMessage message,
    required List<int> messageBytes,
    required String reason,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      await isar.chatPendingInboundEntitys.putByOwnerUserIdMessageId(
        ChatPendingInboundEntity()
          ..ownerUserId = ownerUserId
          ..messageId = message.messageId
          ..conversationId = message.conversationId
          ..messageBytesHex = _bytesToHex(messageBytes)
          ..reason = reason
          ..createdAtMillis = DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  @override
  Future<List<EncryptedMessage>> takePendingInbound(
    String ownerUserId,
    String conversationId, {
    required ChatBindingFenceToken bindingToken,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      final rows = await isar.chatPendingInboundEntitys
          .filter()
          .idGreaterThan(0, include: true)
          .findAll();
      final matched =
          rows
              .where(
                (row) =>
                    row.ownerUserId == ownerUserId &&
                    row.conversationId == conversationId,
              )
              .toList(growable: false)
            ..sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
      for (final row in matched) {
        await isar.chatPendingInboundEntitys.delete(row.id);
      }
      return matched
          .map(
            (row) =>
                EncryptedMessage.fromBuffer(_hexToBytes(row.messageBytesHex)),
          )
          .toList(growable: false);
    });
  }

  Future<int> pendingInboundCount(String ownerUserId) {
    return _chatIsar.read((isar) async {
      final rows = await isar.chatPendingInboundEntitys
          .filter()
          .idGreaterThan(0, include: true)
          .findAll();
      return rows.where((row) => row.ownerUserId == ownerUserId).length;
    });
  }

  Future<int> outboundQueueCount(String ownerUserId) {
    return _chatIsar.read((isar) async {
      final rows = await isar.chatOutboundQueueEntitys
          .filter()
          .idGreaterThan(0, include: true)
          .findAll();
      return rows.where((row) => row.ownerUserId == ownerUserId).length;
    });
  }

  /// 读取发送设备上尚未被 聊天服务模块持久接收的待重试密文。
  Future<List<ChatQueuedMessage>> readQueuedMessages({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    String? recipientUserId,
    String? conversationId,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.read((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      // 页面重试只读取当前 conversationId 索引范围；账户级后台任务没有会话
      // 过滤时才遍历本账户队列，避免打开一个窗口就驱动无关会话的网络副作用。
      final rows = conversationId == null
          ? await isar.chatOutboundQueueEntitys
                .filter()
                .idGreaterThan(0, include: true)
                .findAll()
          : await isar.chatOutboundQueueEntitys
                .where()
                .conversationIdEqualTo(conversationId)
                .findAll();
      final owned = rows
          .where((row) => row.ownerUserId == ownerUserId)
          .toList();
      final matched = recipientUserId == null
          ? owned
          : owned
                .where((row) => row.recipientUserId == recipientUserId)
                .toList(growable: false);
      matched.sort((a, b) {
        final byCreatedAt = _queuedMessageCreatedAt(a)
            .compareTo(_queuedMessageCreatedAt(b));
        return byCreatedAt != 0 ? byCreatedAt : a.id.compareTo(b.id);
      });
      return matched
          .map(
            (row) => ChatQueuedMessage(
              messageId: row.messageId,
              recipientUserId: row.recipientUserId,
              messageBytes: _hexToBytes(row.messageBytesHex),
            ),
          )
          .toList(growable: false);
    });
  }

  /// 登记一条逐收件人附件控制投递事实。
  Future<void> recordOutgoingMedia({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String attachmentId,
    required String recipientUserId,
    required String conversationId,
    required String fileName,
    required String contentType,
    required int byteSize,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      await isar.chatOutgoingMediaEntitys.putByOwnerUserIdPendingKey(
        ChatOutgoingMediaEntity()
          ..ownerUserId = ownerUserId
          ..pendingKey = '$attachmentId|$recipientUserId'
          ..attachmentId = attachmentId
          ..recipientUserId = recipientUserId
          ..conversationId = conversationId
          ..fileName = fileName
          ..contentType = contentType
          ..byteSize = byteSize
          ..createdAtMillis = DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  /// 当前收件人的附件投递完成后删除该 (媒体, 成员) 事实。
  Future<void> deleteOutgoingMedia(
    String ownerUserId,
    String attachmentId,
    String recipientUserId, {
    required ChatBindingFenceToken bindingToken,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      await isar.chatOutgoingMediaEntitys.deleteByOwnerUserIdPendingKey(
        ownerUserId,
        '$attachmentId|$recipientUserId',
      );
    });
  }

  /// 读取待完成的附件控制投递事实，可按收件人过滤。
  Future<List<ChatPendingMedia>> readPendingOutgoingMedia({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    String? recipientUserId,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.read((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      final rows = await isar.chatOutgoingMediaEntitys
          .filter()
          .idGreaterThan(0, include: true)
          .findAll();
      final owned = rows
          .where((row) => row.ownerUserId == ownerUserId)
          .toList();
      final matched = recipientUserId == null
          ? owned
          : owned
                .where((row) => row.recipientUserId == recipientUserId)
                .toList(growable: false);
      matched.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
      return matched
          .map(
            (row) => ChatPendingMedia(
              attachmentId: row.attachmentId,
              recipientUserId: row.recipientUserId,
              conversationId: row.conversationId,
              fileName: row.fileName,
              contentType: row.contentType,
              byteSize: row.byteSize,
            ),
          )
          .toList(growable: false);
    });
  }

  Future<int> outgoingMediaCount(String ownerUserId) {
    return _chatIsar.read((isar) async {
      final rows = await isar.chatOutgoingMediaEntitys
          .filter()
          .idGreaterThan(0, include: true)
          .findAll();
      return rows.where((row) => row.ownerUserId == ownerUserId).length;
    });
  }

  // ==== 私密小群 ====

  /// 建群/入群时落群会话壳 + 群会话记录(conversationKind=group,title=群名)。
  @override
  Future<void> upsertGroupShell({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    required String groupId,
    required String groupName,
    required String creatorUserId,
    required int epoch,
  }) async {
    _requireWriterContext(
      bindingToken: bindingToken,
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
    await _serializeBindingMutation(ownerUserId, () async {
      final binding = await _resolveBinding(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        expectedBindingScope: bindingToken.bindingScope,
      );
      _requireResolvedBinding(bindingToken: bindingToken, binding: binding);
      await _chatIsar.writeTxn((isar) async {
        await _requireBindingTokenInTxn(isar, bindingToken);
        final now = DateTime.now().millisecondsSinceEpoch;
        final existing = await isar.chatGroupEntitys.getByOwnerUserIdGroupId(
          ownerUserId,
          groupId,
        );
        final entity = existing ?? ChatGroupEntity();
        entity
          ..ownerUserId = ownerUserId
          ..groupId = groupId
          ..groupName = groupName
          ..creatorUserId = creatorUserId
          ..epoch = epoch
          ..memberCount = existing?.memberCount ?? 1
          ..leftLocally = existing?.leftLocally ?? false
          ..createdAtMillis = existing?.createdAtMillis ?? now
          ..updatedAtMillis = now;
        await isar.chatGroupEntitys.putByOwnerUserIdGroupId(entity);

        final conversation = await isar.chatConversationEntitys
            .getByOwnerUserIdConversationId(ownerUserId, groupId);
        final shell = conversation ?? ChatConversationEntity();
        shell
          ..ownerUserId = ownerUserId
          ..bindingRevision = binding.bindingRevision
          ..accountId = binding.accountId
          ..conversationId = groupId
          ..peerUserId = creatorUserId
          ..title = groupName
          ..conversationKind = 'group'
          ..lastMessageSummary = conversation?.lastMessageSummary ?? ''
          ..lastUpdatedAtMillis = conversation?.lastUpdatedAtMillis ?? now
          ..unreadCount = conversation?.unreadCount ?? 0
          ..lastDeliveryState =
              conversation?.lastDeliveryState ??
              ChatMessageDeliveryState.queued.name;
        await isar.chatConversationEntitys.putByOwnerUserIdConversationId(
          shell,
        );
      });
    });
  }

  /// 按 MLS 名册（user ID→角色）覆盖群成员镜像，并更新 epoch/人数。
  @override
  Future<void> reconcileGroupRoster({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String groupId,
    required Map<String, GroupMemberRole> members,
    required int epoch,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      final now = DateTime.now().millisecondsSinceEpoch;
      final existing = await isar.chatGroupMemberEntitys
          .filter()
          .ownerUserIdEqualTo(ownerUserId)
          .and()
          .groupIdEqualTo(groupId)
          .findAll();
      final joinedAt = <String, int>{
        for (final row in existing) row.memberUserId: row.joinedAtMillis,
      };
      for (final row in existing) {
        await isar.chatGroupMemberEntitys.delete(row.id);
      }
      for (final entry in members.entries) {
        await isar.chatGroupMemberEntitys.putByOwnerUserIdMemberKey(
          ChatGroupMemberEntity()
            ..ownerUserId = ownerUserId
            ..memberKey = '$groupId|${entry.key}'
            ..groupId = groupId
            ..memberUserId = entry.key
            ..role = entry.value.wireName
            ..joinedAtMillis = joinedAt[entry.key] ?? now,
        );
      }
      final group = await isar.chatGroupEntitys.getByOwnerUserIdGroupId(
        ownerUserId,
        groupId,
      );
      if (group != null) {
        group
          ..epoch = epoch
          ..memberCount = members.length
          ..updatedAtMillis = now;
        await isar.chatGroupEntitys.putByOwnerUserIdGroupId(group);
      }
    });
  }

  @override
  Future<ChatGroup?> readGroup(String ownerUserId, String groupId) {
    return _chatIsar.read((isar) async {
      final group = await isar.chatGroupEntitys.getByOwnerUserIdGroupId(
        ownerUserId,
        groupId,
      );
      if (group == null) return null;
      final members = await isar.chatGroupMemberEntitys
          .filter()
          .ownerUserIdEqualTo(ownerUserId)
          .and()
          .groupIdEqualTo(groupId)
          .findAll();
      return _groupFromEntities(group, members);
    });
  }

  Future<List<ChatGroup>> readGroups(String ownerUserId) {
    return _chatIsar.read((isar) async {
      final groups = await isar.chatGroupEntitys
          .filter()
          .idGreaterThan(0, include: true)
          .findAll();
      final filtered = groups
          .where((row) => row.ownerUserId == ownerUserId)
          .toList(growable: false);
      final result = <ChatGroup>[];
      for (final group in filtered) {
        final members = await isar.chatGroupMemberEntitys
            .filter()
            .ownerUserIdEqualTo(ownerUserId)
            .and()
            .groupIdEqualTo(group.groupId)
            .findAll();
        result.add(_groupFromEntities(group, members));
      }
      return result;
    });
  }

  /// 退群/被移除:本机标记已退,停止参与。
  @override
  Future<void> markGroupLeft(
    String ownerUserId,
    String groupId, {
    required ChatBindingFenceToken bindingToken,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      final group = await isar.chatGroupEntitys.getByOwnerUserIdGroupId(
        ownerUserId,
        groupId,
      );
      if (group != null) {
        group
          ..leftLocally = true
          ..updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
        await isar.chatGroupEntitys.putByOwnerUserIdGroupId(group);
      }
    });
  }

  /// 改群名(群记录 + 群会话 title 同步)。空名忽略。
  @override
  Future<void> renameGroup(
    String ownerUserId,
    String groupId,
    String name, {
    required ChatBindingFenceToken bindingToken,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return Future<void>.value();
    }
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      final now = DateTime.now().millisecondsSinceEpoch;
      final group = await isar.chatGroupEntitys.getByOwnerUserIdGroupId(
        ownerUserId,
        groupId,
      );
      if (group != null) {
        group
          ..groupName = trimmed
          ..updatedAtMillis = now;
        await isar.chatGroupEntitys.putByOwnerUserIdGroupId(group);
      }
      final conversation = await isar.chatConversationEntitys
          .getByOwnerUserIdConversationId(ownerUserId, groupId);
      if (conversation != null) {
        conversation.title = trimmed;
        await isar.chatConversationEntitys.putByOwnerUserIdConversationId(
          conversation,
        );
      }
    });
  }

  /// 缓冲一条乱序群 Commit(键 groupId+messageEpoch)。
  @override
  Future<void> bufferGroupCommit({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String groupId,
    required int messageEpoch,
    required EncryptedMessage message,
    required List<int> messageBytes,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      await isar.chatGroupPendingCommitEntitys.putByOwnerUserIdMessageId(
        ChatGroupPendingCommitEntity()
          ..ownerUserId = ownerUserId
          ..messageId = message.messageId
          ..groupId = groupId
          ..messageEpoch = messageEpoch
          ..messageBytesHex = _bytesToHex(messageBytes)
          ..createdAtMillis = DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  /// 取出并删除某 (groupId, messageEpoch) 下最早的一条缓冲;无则 null。
  @override
  Future<EncryptedMessage?> takeGroupPendingCommit(
    String ownerUserId,
    String groupId,
    int messageEpoch, {
    required ChatBindingFenceToken bindingToken,
  }) {
    _requireWriterContext(bindingToken: bindingToken, ownerUserId: ownerUserId);
    return _chatIsar.writeTxn((isar) async {
      await _requireBindingTokenInTxn(isar, bindingToken);
      final rows = await isar.chatGroupPendingCommitEntitys
          .filter()
          .ownerUserIdEqualTo(ownerUserId)
          .and()
          .groupIdEqualTo(groupId)
          .messageEpochEqualTo(messageEpoch)
          .findAll();
      if (rows.isEmpty) return null;
      rows.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
      final row = rows.first;
      await isar.chatGroupPendingCommitEntitys.delete(row.id);
      return EncryptedMessage.fromBuffer(_hexToBytes(row.messageBytesHex));
    });
  }

  /// 群发出:一条逻辑消息 + N 条按收件人的出站队列(投递/重试复用 1:1 路径)。
  ///
  /// [recipientUserByUserId] 固定按成员 user ID 建立队列路由；账户不进入群消息身份。
  @override
  Future<void> saveOutgoingGroupMessage({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    required String groupId,
    required String senderUserId,
    required String senderDeviceId,
    required String logicalMessageId,
    required ChatMessageKind messageKind,
    required String payload,
    required int createdAtMillis,
    required List<EncryptedMessage> messages,
    required Map<String, String> recipientUserByUserId,
    String? pendingLocalMessageId,
  }) async {
    _requireWriterContext(
      bindingToken: bindingToken,
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
    await _serializeBindingMutation(ownerUserId, () async {
      final binding = await _resolveBinding(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        expectedBindingScope: bindingToken.bindingScope,
      );
      _requireResolvedBinding(bindingToken: bindingToken, binding: binding);
      final prepared = await _prepareMessage(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        messageId: logicalMessageId,
        plaintext: payload,
        binding: binding,
      );
      final summary = await _prepareSummary(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        conversationId: groupId,
        plaintext: payload,
        binding: binding,
      );
      await _chatIsar.writeTxn((isar) async {
        await _requireBindingTokenInTxn(isar, bindingToken);
        if (pendingLocalMessageId != null) {
          if (!pendingLocalMessageId.startsWith('pending:')) {
            throw StateError('Chat 群待发送消息编号不合法');
          }
          final pending = await isar.chatMessageEntitys
              .getByOwnerUserIdMessageId(ownerUserId, pendingLocalMessageId);
          if (pending == null ||
              pending.bindingRevision != binding.bindingRevision ||
              pending.accountId != binding.accountId ||
              pending.direction != 'outgoing' ||
              pending.conversationId != groupId ||
              pending.recipientUserId != groupId ||
              pending.messageKind != messageKind.name ||
              pending.messageBytesHex.isNotEmpty) {
            throw StateError('Chat 群待发送消息已变化或不存在');
          }
          await isar.chatMessageEntitys.delete(pending.id);
        }
        await _touchGroupConversationInTxn(
          isar: isar,
          ownerUserId: ownerUserId,
          bindingRevision: binding.bindingRevision,
          accountId: binding.accountId,
          groupId: groupId,
          lastMessageSummary: summary,
          lastUpdatedAtMillis: createdAtMillis,
          unreadDelta: 0,
          deliveryState: ChatMessageDeliveryState.queued,
        );
        await isar.chatMessageEntitys.putByOwnerUserIdMessageId(
          ChatMessageEntity()
            ..ownerUserId = ownerUserId
            ..bindingRevision = binding.bindingRevision
            ..accountId = binding.accountId
            ..messageId = logicalMessageId
            ..conversationId = groupId
            ..direction = 'outgoing'
            ..senderUserId = senderUserId
            ..recipientUserId = groupId
            ..senderDeviceId = senderDeviceId
            ..messageKind = messageKind.name
            ..deliveryState = ChatMessageDeliveryState.queued.name
            ..payloadJson = prepared.payload
            ..searchTokens = prepared.tokens
            ..messageBytesHex = ''
            ..createdAtMillis = createdAtMillis,
        );
        for (final message in messages) {
          final recipientUserId =
              recipientUserByUserId[message.recipientUserId];
          if (recipientUserId == null || recipientUserId.isEmpty) {
            throw StateError(
              '群出站队列缺少收件人 user ID 映射: ${message.recipientUserId}',
            );
          }
          await isar.chatOutboundQueueEntitys.putByOwnerUserIdMessageId(
            ChatOutboundQueueEntity()
              ..ownerUserId = ownerUserId
              ..messageId = message.messageId
              ..conversationId = groupId
              ..recipientUserId = recipientUserId
              ..messageBytesHex = _bytesToHex(message.writeToBuffer())
              ..deliveryState = ChatMessageDeliveryState.queued.name
              ..attemptCount = 0
              ..lastError = null
              ..updatedAtMillis = DateTime.now().millisecondsSinceEpoch,
          );
        }
      });
    });
  }

  /// 群收到:一条入站逻辑消息(该成员就收到一封)。会话保持群名,不被发送方覆盖。
  @override
  Future<void> saveIncomingGroupMessage({
    required ChatBindingFenceToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    required EncryptedMessage message,
    required List<int> messageBytes,
    required ChatMessageKind messageKind,
    required String plaintext,
  }) async {
    _requireWriterContext(
      bindingToken: bindingToken,
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
    await _serializeBindingMutation(ownerUserId, () async {
      final binding = await _resolveBinding(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        expectedBindingScope: bindingToken.bindingScope,
      );
      _requireResolvedBinding(bindingToken: bindingToken, binding: binding);
      final prepared = await _prepareMessage(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        messageId: message.messageId,
        plaintext: plaintext,
        binding: binding,
      );
      final summary = await _prepareSummary(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        conversationId: message.conversationId,
        plaintext: plaintext,
        binding: binding,
      );
      await _chatIsar.writeTxn((isar) async {
        await _requireBindingTokenInTxn(isar, bindingToken);
        final existing = await isar.chatMessageEntitys
            .getByOwnerUserIdMessageId(ownerUserId, message.messageId);
        if (existing != null) {
          if (existing.direction == 'incoming') return;
          throw StateError('Chat Message ID 与本机出站记录冲突');
        }
        await _touchGroupConversationInTxn(
          isar: isar,
          ownerUserId: ownerUserId,
          bindingRevision: binding.bindingRevision,
          accountId: binding.accountId,
          groupId: message.conversationId,
          lastMessageSummary: summary,
          lastUpdatedAtMillis: message.createdAtMillis.toInt(),
          unreadDelta: 1,
          deliveryState: ChatMessageDeliveryState.receivedByDevice,
        );
        await isar.chatMessageEntitys.putByOwnerUserIdMessageId(
          _messageEntity(
            ownerUserId: ownerUserId,
            bindingRevision: binding.bindingRevision,
            accountId: binding.accountId,
            message: message,
            messageBytes: messageBytes,
            direction: 'incoming',
            messageKind: messageKind,
            deliveryState: ChatMessageDeliveryState.receivedByDevice,
            payloadJson: prepared.payload,
            searchTokens: prepared.tokens,
          ),
        );
      });
    });
  }

  /// 更新群会话的 lastMessage/未读/投递态,但保留群名 title 与 conversationKind。
  Future<void> _touchGroupConversationInTxn({
    required Isar isar,
    required String ownerUserId,
    required int bindingRevision,
    required String accountId,
    required String groupId,
    required String lastMessageSummary,
    required int lastUpdatedAtMillis,
    required int unreadDelta,
    required ChatMessageDeliveryState deliveryState,
  }) async {
    final existing = await isar.chatConversationEntitys
        .getByOwnerUserIdConversationId(ownerUserId, groupId);
    final group = await isar.chatGroupEntitys.getByOwnerUserIdGroupId(
      ownerUserId,
      groupId,
    );
    final entity = existing ?? ChatConversationEntity();
    final replacesLatest =
        existing == null || lastUpdatedAtMillis >= existing.lastUpdatedAtMillis;
    entity
      ..ownerUserId = ownerUserId
      ..bindingRevision = bindingRevision
      ..accountId = accountId
      ..conversationId = groupId
      ..peerUserId = existing?.peerUserId ?? (group?.creatorUserId ?? '')
      ..title = group?.groupName ?? existing?.title ?? groupId
      ..conversationKind = 'group'
      ..lastMessageSummary = replacesLatest
          ? lastMessageSummary
          : existing.lastMessageSummary
      ..lastUpdatedAtMillis = replacesLatest
          ? lastUpdatedAtMillis
          : existing.lastUpdatedAtMillis
      ..unreadCount = (existing?.unreadCount ?? 0) + unreadDelta
      ..lastDeliveryState = replacesLatest
          ? deliveryState.name
          : existing.lastDeliveryState;
    await isar.chatConversationEntitys.putByOwnerUserIdConversationId(entity);
  }

  ChatGroup _groupFromEntities(
    ChatGroupEntity group,
    List<ChatGroupMemberEntity> members,
  ) {
    return ChatGroup(
      groupId: group.groupId,
      name: group.groupName,
      creatorUserId: group.creatorUserId,
      epoch: group.epoch,
      leftLocally: group.leftLocally,
      roster: members
          .map(
            (row) => GroupMember(
              userId: row.memberUserId,
              role: GroupMemberRole.fromName(row.role),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _putConversationInTxn({
    required Isar isar,
    required String ownerUserId,
    required int bindingRevision,
    required String accountId,
    required String conversationId,
    required String peerUserId,
    required String title,
    required String lastMessageSummary,
    required int lastUpdatedAtMillis,
    required int unreadDelta,
    required ChatMessageDeliveryState deliveryState,
  }) async {
    final existing = await isar.chatConversationEntitys
        .getByOwnerUserIdConversationId(ownerUserId, conversationId);
    final entity = existing ?? ChatConversationEntity();
    // 待发送行按创建顺序转换为正式 Message。转换较早消息时，不能把已经由
    // 后续待发送消息推进的会话摘要和排序时间回退，否则下一条暂时失败会让列表
    // 长期显示旧消息。相同时间允许正式状态替换本地 queued 状态。
    final replacesLatest =
        existing == null || lastUpdatedAtMillis >= existing.lastUpdatedAtMillis;
    entity
      ..ownerUserId = ownerUserId
      ..bindingRevision = bindingRevision
      ..accountId = accountId
      ..conversationId = conversationId
      ..peerUserId = peerUserId
      ..title = title
      ..lastMessageSummary = replacesLatest
          ? lastMessageSummary
          : existing.lastMessageSummary
      ..lastUpdatedAtMillis = replacesLatest
          ? lastUpdatedAtMillis
          : existing.lastUpdatedAtMillis
      ..unreadCount = (existing?.unreadCount ?? 0) + unreadDelta
      ..lastDeliveryState = replacesLatest
          ? deliveryState.name
          : existing.lastDeliveryState;
    await isar.chatConversationEntitys.putByOwnerUserIdConversationId(entity);
  }
}

/// 对已经通过本机密文认证的正文继续执行目标载荷验真。严格协议不接受旧格式、
/// 别名或额外字段；展示边界只隔离异常行，不迁移、不改写、更不删除原始密文。
ChatMessageDisplayBatch filterChatMessagesForDisplay(
  Iterable<ChatStoredMessage> messages, {
  int initialIntegrityFailureCount = 0,
}) {
  final accepted = <ChatStoredMessage>[];
  var integrityFailureCount = initialIntegrityFailureCount;
  for (final message in messages) {
    try {
      final content = ChatPayloadCodec.decode(message.plaintext ?? '');
      if (content.kind != message.messageKind) {
        throw const FormatException('消息记录类型与端到端载荷类型不一致');
      }
      accepted.add(message);
    } on FormatException catch (error) {
      integrityFailureCount += 1;
      debugPrint(
        '[ChatStore] display_row_rejected message_id=${message.messageId} '
        'stage=payload error=${error.runtimeType}',
      );
    }
  }
  debugPrint(
    '[ChatStore] display_batch accepted=${accepted.length} '
    'rejected=$integrityFailureCount',
  );
  return ChatMessageDisplayBatch(
    messages: List<ChatStoredMessage>.unmodifiable(accepted),
    integrityFailureCount: integrityFailureCount,
  );
}

/// [lastMessage] 来自当前CID所属的系统保护记录。
ChatConversationPreview _conversationPreviewFromEntity(
  ChatConversationEntity row,
  String lastMessage,
) {
  return ChatConversationPreview(
    conversationId: row.conversationId,
    title: row.title,
    peerUserId: row.peerUserId,
    lastMessage: lastMessage,
    lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(row.lastUpdatedAtMillis),
    unreadCount: row.unreadCount,
    deliveryState: _deliveryStateFromName(row.lastDeliveryState),
    conversationKind: row.conversationKind ?? 'dm',
  );
}

/// [plaintext] 是MLS接收后保存在当前CID所属系统保护记录中的消息内容。
ChatStoredMessage _messageFromEntity(ChatMessageEntity row, String? plaintext) {
  return ChatStoredMessage(
    messageId: row.messageId,
    conversationId: row.conversationId,
    direction: row.direction,
    senderUserId: row.senderUserId,
    recipientUserId: row.recipientUserId,
    messageKind: _messageKindFromName(row.messageKind),
    deliveryState: _deliveryStateFromName(row.deliveryState),
    createdAtMillis: row.createdAtMillis,
    plaintext: plaintext,
  );
}

/// 重试必须沿用 message 创建顺序，尤其要保证 Welcome 先于紧随其后的
/// Application；`updatedAtMillis` 会在每次尝试时变化，不能承担 MLS 排序。
int _queuedMessageCreatedAt(ChatOutboundQueueEntity row) {
  try {
    return EncryptedMessage.fromBuffer(_hexToBytes(row.messageBytesHex))
        .createdAtMillis
        .toInt();
  } on Exception {
    return row.updatedAtMillis;
  }
}

ChatRouteRecord _routeFromEntity(ChatRouteCacheEntity row) {
  return ChatRouteRecord(
    peerUserId: row.peerUserId,
    routeDisplayName: row.routeDisplayName,
    deviceId: row.deviceId,
    safetyNumber: row.safetyNumber,
    nearbyPeerHint: row.nearbyPeerHint,
    note: row.note,
    createdAtMillis: row.createdAtMillis,
    updatedAtMillis: row.updatedAtMillis,
  );
}

ChatMessageEntity _messageEntity({
  required String ownerUserId,
  required int bindingRevision,
  required String accountId,
  required EncryptedMessage message,
  required List<int> messageBytes,
  required String direction,
  required ChatMessageKind messageKind,
  required ChatMessageDeliveryState deliveryState,
  String? payloadJson,
  List<String> searchTokens = const <String>[],
}) {
  return ChatMessageEntity()
    ..ownerUserId = ownerUserId
    ..bindingRevision = bindingRevision
    ..accountId = accountId
    ..messageId = message.messageId
    ..conversationId = message.conversationId
    ..direction = direction
    ..senderUserId = message.senderUserId
    ..recipientUserId = message.recipientUserId
    ..senderDeviceId = message.senderDeviceId
    ..messageKind = messageKind.name
    ..deliveryState = deliveryState.name
    ..payloadJson = payloadJson
    ..searchTokens = searchTokens
    ..messageBytesHex = _bytesToHex(messageBytes)
    ..createdAtMillis = message.createdAtMillis.toInt();
}

String _messageSummary(String? plaintext) {
  // 摘要一律从唯一目标载荷解码：文本取正文，媒体/贴纸取类型化占位
  // ([图片]/[视频]/[文件] 名/[贴纸])；缺失或异常结构失败关闭。
  if (plaintext == null) {
    throw const FormatException('Chat 消息缺失目标载荷');
  }
  return ChatPayloadCodec.decode(plaintext).summary;
}

ChatMessageDeliveryState _deliveryStateFromName(String value) {
  for (final state in ChatMessageDeliveryState.values) {
    if (state.name == value) return state;
  }
  throw FormatException('Chat 投递状态未知：$value');
}

ChatMessageKind _messageKindFromName(String value) {
  for (final kind in ChatMessageKind.values) {
    if (kind.name == value) return kind;
  }
  throw FormatException('Chat 消息类型未知：$value');
}

String _bytesToHex(List<int> bytes) {
  return bytes.map((item) => item.toRadixString(16).padLeft(2, '0')).join();
}

List<int> _hexToBytes(String value) {
  final normalized = value.startsWith('0x') ? value.substring(2) : value;
  if (normalized.length.isOdd) {
    throw const FormatException('Chat message hex 长度必须为偶数');
  }
  final bytes = <int>[];
  for (var i = 0; i < normalized.length; i += 2) {
    bytes.add(int.parse(normalized.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

/// 一条消息的系统保护存储正文与明文索引。
class _StoredMessageContent {
  const _StoredMessageContent({required this.payload, required this.tokens});
  final String? payload;
  final List<String> tokens;
}

List<String> _searchTokens(String text) {
  final runes = text.trim().toLowerCase().runes.toList(growable: false);
  final tokens = <String>{};
  for (var index = 0; index + 2 <= runes.length; index += 1) {
    tokens.add(String.fromCharCodes(runes.sublist(index, index + 2)));
  }
  return tokens.toList(growable: false);
}
