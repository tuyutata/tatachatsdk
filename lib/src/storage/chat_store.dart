import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

import '../core/chat_content.dart';
import '../core/chat_message.dart';
import '../group/model.dart';
import '../protocol/message.dart';
import 'chat_crypto.dart';
import 'chat_isar.dart';
import 'flow_store.dart';
import 'models.dart';
import 'records.dart';

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
    required this.keyDomain,
    required this.generation,
  });

  final String ownerUserId;
  final int bindingRevision;
  final String accountId;
  final String keyDomain;
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
/// 本仓库只保存手机本地状态。TataChatServer 瞬时转发和近场 transport 只拿到完整
/// Protobuf message bytes，不会接触 [plaintext]。
class ChatStore implements ChatFlowStore<ChatBindingFenceToken> {
  ChatStore({ChatIsar? chatIsar, ChatCrypto? crypto})
    : this._(
        chatIsar: chatIsar ?? ChatIsar.instance,
        crypto: crypto ?? ChatCrypto(),
        bindingMutationGate: _processBindingMutationGate,
      );

  ChatStore._({
    required ChatIsar chatIsar,
    required ChatCrypto crypto,
    required _ChatBindingMutationGate bindingMutationGate,
  }) : _chatIsar = chatIsar,
       _crypto = crypto,
       _bindingMutationGate = bindingMutationGate;

  /// 在同一 Flutter 测试 isolate 内模拟另一 isolate 的独立静态 gate。
  /// 两个 Store 仍共享 ChatIsar，底层事务顺序与生产环境保持一致。
  @visibleForTesting
  factory ChatStore.withIndependentBindingGateForTest({
    ChatIsar? chatIsar,
    ChatCrypto? crypto,
  }) {
    return ChatStore._(
      chatIsar: chatIsar ?? ChatIsar.instance,
      crypto: crypto ?? ChatCrypto(),
      bindingMutationGate: _ChatBindingMutationGate(),
    );
  }

  final ChatIsar _chatIsar;

  /// 聊天本地密文的唯一加解密边界。加解密一律在 Isar 事务**之外**完成,
  /// 不让密码学运算占住写事务。
  final ChatCrypto _crypto;

  final _ChatBindingMutationGate _bindingMutationGate;

  /// 同一 user ID 的密文写入与账户交接必须按调用先后串行。
  ///
  /// Chat 密文先在 Isar 事务外准备；如果只依赖 ChatIsar 队列，已经开始加密但尚未
  /// 入库的旧绑定消息可能排到交接提交之后。这里仅串行 Chat 域内同一 user ID 的绑定
  /// 变更，不接入 WalletIsar，也不阻塞其它 user ID。
  static final _ChatBindingMutationGate _processBindingMutationGate =
      _ChatBindingMutationGate();

  static const int _handoverCommitMaxAttempts = 4;
  static const String _fenceActive = 'active';
  static const String _fenceCleared = 'cleared';
  static const int _maxFenceGeneration = 0x7fffffffffffffff;
  static const String _handoverManifestMacDomain =
      'tatachat_sdk.local/chat-handover-manifest|';
  static final RegExp _handoverDigestPattern = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp _keyDomainPattern = RegExp(r'^0x[0-9a-f]{64}$');

  Future<T> _serializeBindingMutation<T>(
    String userId,
    Future<T> Function() action,
  ) => _bindingMutationGate.run(userId, action);

  /// 首次激活一个 user ID 的 Chat 写入门闩。
  ///
  /// 普通读写绝不隐式创建 fence；只有 finalized binding 收敛入口可以显式调用。
  /// 已存在的 cleared/其它 binding 也不得由本入口悄悄恢复。
  Future<ChatBindingFenceToken> activateBindingFence(
    ChatDataBinding binding,
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
            ..keyDomain = binding.keyDomain
            ..generation = 1
            ..fenceState = _fenceActive
            ..pendingBindingRevision = null
            ..pendingAccountId = null
            ..pendingKeyDomain = null;
          await isar.chatBindingFenceEntitys.putByOwnerUserId(row);
          return _tokenFromFence(row, binding);
        }
        _validateFence(existing);
        if (!_isActiveCurrentFence(existing, binding) ||
            _hasPendingFence(existing)) {
          throw StateError('Chat 写入门闩已经绑定到其它状态，禁止重复激活');
        }
        return _tokenFromFence(existing, binding);
      });
    });
  }

  /// 把持久门闩收敛到链上 finalized binding。
  ///
  /// 这是 crash recovery 与 cleared 后重新激活的唯一入口。存在 staged handover 时
  /// 必须完成带签名的 commit，不能用 finalized 观察结果绕过密文交接。
  Future<ChatBindingFenceToken> convergeFinalizedBinding(
    ChatDataBinding current,
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
            ..keyDomain = current.keyDomain
            ..generation = 1
            ..fenceState = _fenceActive
            ..pendingBindingRevision = null
            ..pendingAccountId = null
            ..pendingKeyDomain = null;
          await isar.chatBindingFenceEntitys.putByOwnerUserId(created);
          return _tokenFromFence(created, current);
        }
        _validateFence(row);
        if (_hasPendingFence(row)) {
          throw StateError('Chat 存在待提交的账户交接，禁止绕过 commit 收敛绑定');
        }
        if (_isActiveCurrentFence(row, current)) {
          return _tokenFromFence(row, current);
        }
        if (row.fenceState == _fenceActive &&
            row.bindingRevision! >= current.bindingRevision) {
          throw StateError('finalized Chat binding 版本不得回退或同版本换账户');
        }
        await _clearTransientChatStateInTxn(isar, current.userId);
        _clearCompletedHandoverReceipt(row);
        row
          ..bindingRevision = current.bindingRevision
          ..accountId = current.accountId
          ..keyDomain = current.keyDomain
          ..generation = _nextFenceGeneration(row.generation)
          ..fenceState = _fenceActive
          ..pendingBindingRevision = null
          ..pendingAccountId = null
          ..pendingKeyDomain = null;
        await isar.chatBindingFenceEntitys.put(row);
        return _tokenFromFence(row, current);
      });
    });
  }

  /// 捕获本次运行上下文的不可变持久 token。
  ///
  /// transition pending 时普通上下文一律不能捕获 token；handover 只能走专属
  /// staged/completed fence 校验，不能借 source 或 target token 绕过持久阻断。
  Future<ChatBindingFenceToken> captureBindingFenceToken(
    ChatDataBinding binding,
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
      if (!_isActiveCurrentFence(row, binding) || _hasPendingFence(row)) {
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

  /// handover 内部专属能力：只接受精确 source/current + pending target。
  /// 普通 writer 在 pending 期间一律 fail-closed，不能借 source token 继续写。
  Future<void> validateStagedAccountHandoverFence({
    required ChatDataBinding source,
    required ChatDataBinding target,
    required ChatBindingFenceToken sourceToken,
  }) {
    _validateHandover(source, target);
    return _chatIsar.read((isar) async {
      await _requireStagedFenceInTxn(
        isar,
        sourceToken: sourceToken,
        source: source,
        target: target,
      );
    });
  }

  /// handover 重复 commit 专属能力：必须命中 commit 同事务写入的精确收据。
  Future<void> validateCompletedAccountHandoverFence({
    required ChatDataBinding source,
    required ChatDataBinding target,
    required ChatBindingFenceToken targetToken,
  }) {
    _validateHandover(source, target);
    return _chatIsar.read((isar) async {
      await _requireCompletedFenceInTxn(
        isar,
        targetToken: targetToken,
        source: source,
        target: target,
      );
    });
  }

  /// handover admin 在普通 token 被 pending 阻断后捕获 source generation。
  /// 该 token 只能交给 staged 专属校验，不能通过普通 writer CAS。
  Future<ChatBindingFenceToken> captureStagedAccountHandoverFenceToken({
    required ChatDataBinding source,
    required ChatDataBinding target,
  }) async {
    _validateHandover(source, target);
    return _captureStagedFenceToken(source: source, target: target);
  }

  /// 重复 commit 只在精确 completion receipt 存在时返回 target token。
  Future<ChatBindingFenceToken> captureCompletedAccountHandoverFenceToken({
    required ChatDataBinding source,
    required ChatDataBinding target,
  }) async {
    _validateHandover(source, target);
    return _chatIsar.read((isar) async {
      final row = await isar.chatBindingFenceEntitys.getByOwnerUserId(
        target.userId,
      );
      if (row == null) throw StateError('Chat 持久写入门闩缺失');
      _validateFence(row);
      if (!_isActiveCurrentFence(row, target) ||
          _hasPendingFence(row) ||
          !_matchesCompletedHandoverReceipt(
            row,
            source: source,
            target: target,
          )) {
        throw StateError('Chat 换绑完成 fence 缺少精确 completion receipt');
      }
      return _tokenFromFence(row, target);
    });
  }

  Future<ChatBindingFenceToken> _captureCurrentFenceToken(
    ChatDataBinding binding, {
    required bool requireNoPending,
  }) {
    return _chatIsar.read((isar) async {
      final row = await isar.chatBindingFenceEntitys.getByOwnerUserId(
        binding.userId,
      );
      if (row == null) throw StateError('Chat 持久写入门闩缺失');
      _validateFence(row);
      if (!_isActiveCurrentFence(row, binding) ||
          (requireNoPending && _hasPendingFence(row))) {
        throw StateError('Chat 当前 binding fence 与操作上下文不一致');
      }
      return _tokenFromFence(row, binding);
    });
  }

  Future<ChatBindingFenceToken> _captureStagedFenceToken({
    required ChatDataBinding source,
    required ChatDataBinding target,
  }) {
    return _chatIsar.read((isar) async {
      final row = await isar.chatBindingFenceEntitys.getByOwnerUserId(
        source.userId,
      );
      if (row == null) throw StateError('Chat 持久写入门闩缺失');
      _validateFence(row);
      if (!_isActiveCurrentFence(row, source) ||
          !_isPendingFenceBinding(row, target)) {
        throw StateError('Chat 换绑 fence 尚未 stage 或已变化');
      }
      return _tokenFromFence(row, source);
    });
  }

  static ChatBindingFenceToken _tokenFromFence(
    ChatBindingFenceEntity row,
    ChatDataBinding binding,
  ) => ChatBindingFenceToken(
    ownerUserId: binding.userId,
    bindingRevision: binding.bindingRevision,
    accountId: binding.accountId,
    keyDomain: binding.keyDomain,
    generation: row.generation,
  );

  static int _nextFenceGeneration(int generation) {
    if (generation <= 0 || generation >= _maxFenceGeneration) {
      throw StateError('Chat 写入门闩 generation 已损坏或耗尽');
    }
    return generation + 1;
  }

  static bool _hasPendingFence(ChatBindingFenceEntity row) =>
      row.pendingBindingRevision != null;

  static void _clearCompletedHandoverReceipt(ChatBindingFenceEntity row) {
    row
      ..completedSourceBindingRevision = null
      ..completedSourceAccountId = null
      ..completedSourceKeyDomain = null
      ..completedTargetBindingRevision = null
      ..completedTargetAccountId = null
      ..completedTargetKeyDomain = null
      ..completedGeneration = null;
  }

  static bool _matchesCompletedHandoverReceipt(
    ChatBindingFenceEntity row, {
    required ChatDataBinding source,
    required ChatDataBinding target,
  }) =>
      row.completedSourceBindingRevision == source.bindingRevision &&
      row.completedSourceAccountId == source.accountId &&
      row.completedSourceKeyDomain == source.keyDomain &&
      row.completedTargetBindingRevision == target.bindingRevision &&
      row.completedTargetAccountId == target.accountId &&
      row.completedTargetKeyDomain == target.keyDomain &&
      row.completedGeneration == row.generation;

  static bool _isCurrentFenceBinding(
    ChatBindingFenceEntity row,
    ChatDataBinding binding,
  ) =>
      row.ownerUserId == binding.userId &&
      row.bindingRevision == binding.bindingRevision &&
      row.accountId == binding.accountId &&
      row.keyDomain == binding.keyDomain;

  static bool _isPendingFenceBinding(
    ChatBindingFenceEntity row,
    ChatDataBinding binding,
  ) =>
      row.ownerUserId == binding.userId &&
      row.pendingBindingRevision == binding.bindingRevision &&
      row.pendingAccountId == binding.accountId &&
      row.pendingKeyDomain == binding.keyDomain;

  static bool _isActiveCurrentFence(
    ChatBindingFenceEntity row,
    ChatDataBinding binding,
  ) => row.fenceState == _fenceActive && _isCurrentFenceBinding(row, binding);

  static void _validateFence(ChatBindingFenceEntity row) {
    final hasCurrentRevision = row.bindingRevision != null;
    final hasCurrentAccount = row.accountId != null;
    final hasCurrentKeyDomain = row.keyDomain != null;
    final hasPendingRevision = row.pendingBindingRevision != null;
    final hasPendingAccount = row.pendingAccountId != null;
    final hasPendingKeyDomain = row.pendingKeyDomain != null;
    final completedFields = <Object?>[
      row.completedSourceBindingRevision,
      row.completedSourceAccountId,
      row.completedSourceKeyDomain,
      row.completedTargetBindingRevision,
      row.completedTargetAccountId,
      row.completedTargetKeyDomain,
      row.completedGeneration,
    ];
    final completedFieldCount = completedFields
        .where((value) => value != null)
        .length;
    if (row.ownerUserId.isEmpty ||
        row.generation <= 0 ||
        row.generation > _maxFenceGeneration ||
        hasCurrentRevision != hasCurrentAccount ||
        hasCurrentRevision != hasCurrentKeyDomain ||
        hasPendingRevision != hasPendingAccount ||
        hasPendingRevision != hasPendingKeyDomain ||
        (completedFieldCount != 0 &&
            completedFieldCount != completedFields.length) ||
        (hasCurrentRevision &&
            (row.bindingRevision! <= 0 ||
                row.accountId!.isEmpty ||
                !_keyDomainPattern.hasMatch(row.keyDomain!))) ||
        (hasPendingRevision &&
            (row.pendingBindingRevision! <= 0 ||
                row.pendingAccountId!.isEmpty ||
                !_keyDomainPattern.hasMatch(row.pendingKeyDomain!))) ||
        (row.fenceState != _fenceActive && row.fenceState != _fenceCleared) ||
        (row.fenceState == _fenceActive && !hasCurrentRevision) ||
        (row.fenceState == _fenceCleared && hasPendingRevision) ||
        (row.fenceState == _fenceCleared && completedFieldCount != 0) ||
        (hasPendingRevision &&
            row.pendingBindingRevision! <= row.bindingRevision!) ||
        (completedFieldCount != 0 &&
            (row.completedSourceBindingRevision! <= 0 ||
                row.completedTargetBindingRevision! != row.bindingRevision ||
                row.completedTargetAccountId != row.accountId ||
                row.completedTargetKeyDomain != row.keyDomain ||
                row.completedSourceKeyDomain != row.completedTargetKeyDomain ||
                !_keyDomainPattern.hasMatch(row.completedSourceKeyDomain!) ||
                !_keyDomainPattern.hasMatch(row.completedTargetKeyDomain!) ||
                row.completedTargetBindingRevision! <=
                    row.completedSourceBindingRevision! ||
                row.completedGeneration != row.generation))) {
      throw const FormatException('Chat 持久写入门闩结构损坏');
    }
  }

  static Future<ChatBindingFenceEntity> _requireBindingTokenInTxn(
    Isar isar,
    ChatBindingFenceToken token,
  ) async {
    final row = await isar.chatBindingFenceEntitys.getByOwnerUserId(
      token.ownerUserId,
    );
    if (row == null) throw StateError('Chat 持久写入门闩缺失');
    _validateFence(row);
    final matchesCurrent =
        row.bindingRevision == token.bindingRevision &&
        row.accountId == token.accountId &&
        row.keyDomain == token.keyDomain;
    final matchesPending =
        row.pendingBindingRevision == token.bindingRevision &&
        row.pendingAccountId == token.accountId &&
        row.pendingKeyDomain == token.keyDomain;
    if (row.fenceState != _fenceActive ||
        row.generation != token.generation ||
        _hasPendingFence(row) ||
        (!matchesCurrent && !matchesPending)) {
      throw StateError('Chat 写入 token 已过期或 binding 不匹配');
    }
    return row;
  }

  static Future<ChatBindingFenceEntity> _requireCurrentFenceInTxn(
    Isar isar, {
    required ChatBindingFenceToken token,
    required ChatDataBinding current,
    bool allowPending = false,
  }) async {
    final row = allowPending
        ? await isar.chatBindingFenceEntitys.getByOwnerUserId(token.ownerUserId)
        : await _requireBindingTokenInTxn(isar, token);
    if (row == null) throw StateError('Chat 持久写入门闩缺失');
    _validateFence(row);
    if (!_isActiveCurrentFence(row, current) ||
        row.generation != token.generation ||
        token.bindingRevision != current.bindingRevision ||
        token.accountId != current.accountId ||
        token.keyDomain != current.keyDomain) {
      throw StateError('Chat 当前 binding fence 已变化');
    }
    return row;
  }

  static Future<ChatBindingFenceEntity> _requireStagedFenceInTxn(
    Isar isar, {
    required ChatBindingFenceToken sourceToken,
    required ChatDataBinding source,
    required ChatDataBinding target,
  }) async {
    final row = await isar.chatBindingFenceEntitys.getByOwnerUserId(
      sourceToken.ownerUserId,
    );
    if (row == null) throw StateError('Chat 持久写入门闩缺失');
    _validateFence(row);
    if (!_isActiveCurrentFence(row, source) ||
        row.generation != sourceToken.generation ||
        sourceToken.bindingRevision != source.bindingRevision ||
        sourceToken.accountId != source.accountId ||
        sourceToken.keyDomain != source.keyDomain) {
      throw StateError('Chat 换绑来源 fence 已变化');
    }
    if (!_isPendingFenceBinding(row, target)) {
      throw StateError('Chat 换绑目标 fence 缺失或已变化');
    }
    return row;
  }

  static Future<ChatBindingFenceEntity> _requireCompletedFenceInTxn(
    Isar isar, {
    required ChatBindingFenceToken targetToken,
    required ChatDataBinding source,
    required ChatDataBinding target,
  }) async {
    final row = await _requireCurrentFenceInTxn(
      isar,
      token: targetToken,
      current: target,
    );
    if (_hasPendingFence(row) ||
        !_matchesCompletedHandoverReceipt(
          row,
          source: source,
          target: target,
        )) {
      throw StateError('Chat 换绑完成 fence 缺少精确 completion receipt');
    }
    return row;
  }

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
    required ChatCipherBinding binding,
  }) {
    if (bindingToken.bindingRevision != binding.bindingRevision ||
        bindingToken.accountId != binding.accountId ||
        bindingToken.keyDomain != binding.keyDomain) {
      throw StateError('Chat 加密 binding 与持久 token 不一致');
    }
  }

  /// 把正文加密成密文 + 搜索索引;正文为空时返回空密文与空索引。
  Future<_SealedMessage> _sealMessage({
    required String ownerUserId,
    required String currentAccountId,
    required String messageId,
    required String? plaintext,
    required ChatCipherBinding binding,
  }) async {
    if (plaintext == null || plaintext.isEmpty) {
      return const _SealedMessage(cipher: null, tokens: <String>[]);
    }
    return _SealedMessage(
      cipher: await _crypto.encryptText(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        recordId: messageId,
        plaintext: plaintext,
        binding: binding,
      ),
      // 索引建在**摘要**上,与搜索时的匹配口径一致(媒体/贴纸取类型化占位)。
      tokens: await _crypto.buildSearchTokens(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        text: _messageSummary(plaintext),
        binding: binding,
      ),
    );
  }

  Future<String> _sealSummary({
    required String ownerUserId,
    required String currentAccountId,
    required String conversationId,
    required String? plaintext,
    required ChatCipherBinding binding,
  }) => _crypto.encryptText(
    ownerUserId: ownerUserId,
    currentAccountId: currentAccountId,
    recordId: conversationId,
    plaintext: _messageSummary(plaintext),
    binding: binding,
  );

  /// 换绑交易提交前，把全部聊天正文、会话摘要和搜索索引预演成目标账户密文。
  ///
  /// 正式聊天行不改动；暂存清单只含绑定事实、稳定记录标识、记录 ID、来源密文指纹
  /// 与目标子钥 MAC，不保存明文、随机目标密文或搜索 token。
  /// 任一此前密文认证失败都会整体中止，禁止带着半套历史记录继续换绑。
  Future<void> stageAccountHandover({
    required ChatDataBinding source,
    required ChatDataBinding target,
  }) async {
    _validateHandover(source, target);
    await _serializeBindingMutation(source.userId, () async {
      final sourceToken = await _captureCurrentFenceToken(
        source,
        requireNoPending: false,
      );
      final sourceKeys = await _crypto.handoverKeys(source);
      try {
        final targetKeys = await _crypto.handoverKeys(target);
        try {
          final snapshot = await _readHandoverBindingSnapshot(source);
          // stage 仍完整预演来源解密、目标重加密与回读，但随机目标密文只活在内存中。
          await _prepareHandoverSnapshot(
            source: source,
            target: target,
            sourceKeys: sourceKeys,
            targetKeys: targetKeys,
            snapshot: snapshot,
          );
          final key = _handoverKey(target);
          final value = _encodeHandoverManifest(
            source: source,
            target: target,
            snapshot: snapshot,
            macKey: targetKeys.index,
          );
          await _chatIsar.writeTxn((isar) async {
            final fence = await _requireCurrentFenceInTxn(
              isar,
              token: sourceToken,
              current: source,
              allowPending: true,
            );
            if (_hasPendingFence(fence) &&
                !_isPendingFenceBinding(fence, target)) {
              throw StateError('Chat 已存在其它待提交的换绑目标');
            }
            final row =
                await isar.chatAccountHandoverEntitys.getByHandoverKey(key) ??
                ChatAccountHandoverEntity();
            row
              ..handoverKey = key
              ..ownerUserId = target.userId
              ..sourceBindingRevision = source.bindingRevision
              ..sourceAccountId = source.accountId
              ..targetBindingRevision = target.bindingRevision
              ..targetAccountId = target.accountId
              ..manifestJson = value;
            await isar.chatAccountHandoverEntitys.putByHandoverKey(row);
            fence
              ..pendingBindingRevision = target.bindingRevision
              ..pendingAccountId = target.accountId
              ..pendingKeyDomain = target.keyDomain;
            _clearCompletedHandoverReceipt(fence);
            await isar.chatBindingFenceEntitys.put(fence);
          });
        } finally {
          targetKeys.dispose();
        }
      } finally {
        sourceKeys.dispose();
      }
    });
  }

  /// finalized 后重取当前来源绑定快照，事务外重加密，再用严格 CAS
  /// 一次切换全部聊天密文。任何并发变化都整体重做，禁止提交半套记录。
  Future<void> commitAccountHandover({
    required ChatDataBinding source,
    required ChatDataBinding target,
  }) async {
    _validateHandover(source, target);
    await _serializeBindingMutation(source.userId, () async {
      final key = _handoverKey(target);
      final sourceKeys = await _crypto.handoverKeys(source);
      try {
        final targetKeys = await _crypto.handoverKeys(target);
        try {
          for (
            var attempt = 0;
            attempt < _handoverCommitMaxAttempts;
            attempt += 1
          ) {
            final manifest = await _readValidatedHandoverManifest(
              key: key,
              source: source,
              target: target,
              macKey: targetKeys.index,
            );

            if (manifest == null) {
              final targetToken = await _captureCurrentFenceToken(
                target,
                requireNoPending: true,
              );
              final snapshot = await _readHandoverBindingSnapshot(source);
              final targetSnapshot = await _readHandoverBindingSnapshot(target);
              if (!_isEmptyHandoverBindingSnapshot(snapshot)) {
                throw StateError('聊天换绑交接清单缺失且来源绑定仍有聊天密文');
              }
              // marker 只允许在已经完整提交后缺失：目标行必须全部通过目标子钥认证，
              // 随后再在事务内确认 marker、来源与目标快照都没有变化。
              await _validateHandoverTargetSnapshot(
                target: target,
                targetKeys: targetKeys,
                snapshot: targetSnapshot,
              );
              final completed = await _chatIsar.writeTxn((isar) async {
                await _requireCompletedFenceInTxn(
                  isar,
                  targetToken: targetToken,
                  source: source,
                  target: target,
                );
                final currentManifest = await isar.chatAccountHandoverEntitys
                    .getByHandoverKey(key);
                if (currentManifest != null) return false;
                final currentSnapshot = await _readHandoverBindingSnapshotInTxn(
                  isar,
                  source,
                );
                final currentTargetSnapshot =
                    await _readHandoverBindingSnapshotInTxn(isar, target);
                return _isEmptyHandoverBindingSnapshot(currentSnapshot) &&
                    _sameHandoverBindingSnapshot(
                      targetSnapshot,
                      currentTargetSnapshot,
                    );
              });
              if (completed) return;
              continue;
            }

            final sourceToken = await _captureStagedFenceToken(
              source: source,
              target: target,
            );
            final snapshot = await _readHandoverBindingSnapshot(source);
            final targetSnapshot = await _readHandoverBindingSnapshot(target);
            await _chatIsar.read(
              (isar) => _validateHandoverManifestRowsInTxn(
                isar,
                manifest.identity,
                source: source,
                target: target,
              ),
            );
            final prepared = await _prepareHandoverSnapshot(
              source: source,
              target: target,
              sourceKeys: sourceKeys,
              targetKeys: targetKeys,
              snapshot: snapshot,
            );
            await _validateHandoverTargetSnapshot(
              target: target,
              targetKeys: targetKeys,
              snapshot: targetSnapshot,
            );
            final committed = await _chatIsar.writeTxn((isar) async {
              final fence = await _requireStagedFenceInTxn(
                isar,
                sourceToken: sourceToken,
                source: source,
                target: target,
              );
              final currentManifest = await isar.chatAccountHandoverEntitys
                  .getByHandoverKey(key);
              if (!_sameHandoverManifestRecord(currentManifest, manifest)) {
                return false;
              }
              final currentSnapshot = await _readHandoverBindingSnapshotInTxn(
                isar,
                source,
              );
              final currentTargetSnapshot =
                  await _readHandoverBindingSnapshotInTxn(isar, target);
              if (!_sameHandoverBindingSnapshot(snapshot, currentSnapshot) ||
                  !_sameHandoverBindingSnapshot(
                    targetSnapshot,
                    currentTargetSnapshot,
                  )) {
                return false;
              }
              await _validateHandoverManifestRowsInTxn(
                isar,
                manifest.identity,
                source: source,
                target: target,
              );

              final conversationsToCommit =
                  <({ChatConversationEntity row, String targetCipher})>[];
              for (final item in prepared.conversations) {
                final row = await isar.chatConversationEntitys.get(
                  item.source.id,
                );
                if (row == null ||
                    !_sameConversationSource(item.source, row, source)) {
                  return false;
                }
                conversationsToCommit.add((
                  row: row,
                  targetCipher: item.targetCipher,
                ));
              }
              final messagesToCommit =
                  <
                    ({
                      ChatMessageEntity row,
                      String? targetCipher,
                      List<String> targetTokens,
                    })
                  >[];
              for (final item in prepared.messages) {
                final row = await isar.chatMessageEntitys.get(item.source.id);
                if (row == null ||
                    !_sameMessageSource(item.source, row, source)) {
                  return false;
                }
                messagesToCommit.add((
                  row: row,
                  targetCipher: item.targetCipher,
                  targetTokens: item.targetTokens,
                ));
              }

              // 全部 CAS 检查通过后才开始改行，任何 false 都不会提交半套迁移。
              for (final item in conversationsToCommit) {
                item.row
                  ..bindingRevision = target.bindingRevision
                  ..accountId = target.accountId
                  ..lastMessageCipher = item.targetCipher;
                await isar.chatConversationEntitys
                    .putByOwnerUserIdConversationId(item.row);
              }
              for (final item in messagesToCommit) {
                item.row
                  ..bindingRevision = target.bindingRevision
                  ..accountId = target.accountId
                  ..plaintextCipher = item.targetCipher
                  ..searchTokens = item.targetTokens;
                await isar.chatMessageEntitys.putByOwnerUserIdMessageId(
                  item.row,
                );
              }
              final completedGeneration = _nextFenceGeneration(
                fence.generation,
              );
              fence
                ..bindingRevision = target.bindingRevision
                ..accountId = target.accountId
                ..keyDomain = target.keyDomain
                ..generation = completedGeneration
                ..fenceState = _fenceActive
                ..pendingBindingRevision = null
                ..pendingAccountId = null
                ..pendingKeyDomain = null
                ..completedSourceBindingRevision = source.bindingRevision
                ..completedSourceAccountId = source.accountId
                ..completedSourceKeyDomain = source.keyDomain
                ..completedTargetBindingRevision = target.bindingRevision
                ..completedTargetAccountId = target.accountId
                ..completedTargetKeyDomain = target.keyDomain
                ..completedGeneration = completedGeneration;
              await isar.chatBindingFenceEntitys.put(fence);
              await isar.chatAccountHandoverEntitys.delete(currentManifest!.id);
              return true;
            });
            if (committed) return;
          }
          throw StateError('聊天换绑提交期间数据持续变化，交接清单已保留请重试');
        } finally {
          targetKeys.dispose();
        }
      } finally {
        sourceKeys.dispose();
      }
    });
  }

  Future<void> discardAccountHandover(ChatDataBinding target) async {
    target.validate();
    await _serializeBindingMutation(target.userId, () async {
      final key = _handoverKey(target);
      await _chatIsar.writeTxn((isar) async {
        final fence = await isar.chatBindingFenceEntitys.getByOwnerUserId(
          target.userId,
        );
        if (fence == null) throw StateError('Chat 持久写入门闩缺失');
        _validateFence(fence);
        final row = await isar.chatAccountHandoverEntitys.getByHandoverKey(key);
        if (row == null && !_hasPendingFence(fence)) return;
        if (fence.fenceState != _fenceActive ||
            !_isPendingFenceBinding(fence, target) ||
            (row != null &&
                (row.ownerUserId != target.userId ||
                    row.targetBindingRevision != target.bindingRevision ||
                    row.targetAccountId != target.accountId))) {
          throw StateError('Chat 待丢弃交接与持久 fence 不一致');
        }
        if (row != null) {
          await isar.chatAccountHandoverEntitys.delete(row.id);
        }
        fence
          ..pendingBindingRevision = null
          ..pendingAccountId = null
          ..pendingKeyDomain = null;
        await isar.chatBindingFenceEntitys.put(fence);
      });
    });
  }

  Future<_HandoverBindingSnapshot> _readHandoverBindingSnapshot(
    ChatDataBinding binding,
  ) => _chatIsar.read(
    (isar) => _readHandoverBindingSnapshotInTxn(isar, binding),
  );

  static Future<_HandoverBindingSnapshot> _readHandoverBindingSnapshotInTxn(
    Isar isar,
    ChatDataBinding binding,
  ) async {
    final conversationRows =
        (await isar.chatConversationEntitys
                .filter()
                .idGreaterThan(0, include: true)
                .findAll())
            .where(
              (row) =>
                  row.ownerUserId == binding.userId &&
                  row.bindingRevision == binding.bindingRevision &&
                  row.accountId == binding.accountId,
            )
            .toList(growable: false);
    final messageRows =
        (await isar.chatMessageEntitys
                .filter()
                .idGreaterThan(0, include: true)
                .findAll())
            .where(
              (row) =>
                  row.ownerUserId == binding.userId &&
                  row.bindingRevision == binding.bindingRevision &&
                  row.accountId == binding.accountId,
            )
            .toList(growable: false);
    final conversations =
        conversationRows
            .map(
              (row) => _HandoverConversationSource(
                id: row.id,
                conversationId: row.conversationId,
                cipher: row.lastMessageCipher,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.id.compareTo(right.id));
    final messages =
        messageRows
            .map(
              (row) => _HandoverMessageSource(
                id: row.id,
                messageId: row.messageId,
                cipher: row.plaintextCipher,
                tokens: List<String>.unmodifiable(row.searchTokens),
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.id.compareTo(right.id));
    return _HandoverBindingSnapshot(
      conversations: List<_HandoverConversationSource>.unmodifiable(
        conversations,
      ),
      messages: List<_HandoverMessageSource>.unmodifiable(messages),
    );
  }

  static bool _isEmptyHandoverBindingSnapshot(
    _HandoverBindingSnapshot snapshot,
  ) => snapshot.conversations.isEmpty && snapshot.messages.isEmpty;

  /// 清单覆盖的旧行按 Isar 主键验真，不能只按当前 source/target 过滤结果判断。
  ///
  /// 主键行不存在才是交接窗口内的合法物理删除；仍存在的行必须保有清单里的稳定键，
  /// 且精确属于本次 source 或 target。这样 owner、bindingRevision 或 accountId 被改到
  /// 第三状态时不会从两份过滤快照中消失后被误当作删除。该检查在密码学准备前与最终
  /// 写事务内各执行一次，事务内版本组成提交 CAS 的一部分。
  static Future<void> _validateHandoverManifestRowsInTxn(
    Isar isar,
    _HandoverManifestIdentity manifest, {
    required ChatDataBinding source,
    required ChatDataBinding target,
  }) async {
    for (final identity in manifest.conversations) {
      var row = await isar.chatConversationEntitys.get(identity.id);
      row ??= await isar.chatConversationEntitys.getByOwnerUserIdConversationId(
        source.userId,
        identity.conversationId,
      );
      if (row == null) continue;
      if (row.conversationId != identity.conversationId) {
        throw const FormatException('聊天换绑清单会话主键与稳定键不一致');
      }
      final belongsToSource = _conversationBelongsToBinding(row, source);
      final belongsToTarget = _conversationBelongsToBinding(row, target);
      if (!belongsToSource && !belongsToTarget) {
        throw const FormatException('聊天换绑清单会话已落入第三绑定状态');
      }
      final hasCipher = row.lastMessageCipher.isNotEmpty;
      if (identity.sourceHasCipher && !hasCipher) {
        throw const FormatException('聊天换绑清单中的非空会话摘要密文不得降级为空');
      }
    }
    for (final identity in manifest.messages) {
      var row = await isar.chatMessageEntitys.get(identity.id);
      row ??= await isar.chatMessageEntitys.getByOwnerUserIdMessageId(
        source.userId,
        identity.messageId,
      );
      if (row == null) continue;
      if (row.messageId != identity.messageId) {
        throw const FormatException('聊天换绑清单消息主键与稳定键不一致');
      }
      final belongsToSource = _messageBelongsToBinding(row, source);
      final belongsToTarget = _messageBelongsToBinding(row, target);
      if (!belongsToSource && !belongsToTarget) {
        throw const FormatException('聊天换绑清单消息已落入第三绑定状态');
      }
      final hasCipher = row.plaintextCipher?.isNotEmpty ?? false;
      if (identity.sourceHasCipher && !hasCipher) {
        throw const FormatException('聊天换绑清单中的非空正文密文不得降级为空');
      }
    }
  }

  Future<_PreparedHandoverSnapshot> _prepareHandoverSnapshot({
    required ChatDataBinding source,
    required ChatDataBinding target,
    required ChatHandoverKeys sourceKeys,
    required ChatHandoverKeys targetKeys,
    required _HandoverBindingSnapshot snapshot,
  }) async {
    final conversations = <_PreparedHandoverConversation>[];
    for (final row in snapshot.conversations) {
      final plaintext = await _crypto.decryptForHandover(
        binding: source,
        keys: sourceKeys,
        recordId: row.conversationId,
        blob: row.cipher,
      );
      final targetCipher = await _crypto.encryptForHandover(
        binding: target,
        keys: targetKeys,
        recordId: row.conversationId,
        plaintext: plaintext,
      );
      final verified = await _crypto.decryptForHandover(
        binding: target,
        keys: targetKeys,
        recordId: row.conversationId,
        blob: targetCipher,
      );
      if (verified != plaintext) {
        throw StateError('聊天会话摘要新账户密文回读不一致');
      }
      conversations.add(
        _PreparedHandoverConversation(source: row, targetCipher: targetCipher),
      );
    }

    final messages = <_PreparedHandoverMessage>[];
    for (final row in snapshot.messages) {
      final blob = row.cipher;
      if (blob == null || blob.isEmpty) {
        if (row.tokens.isNotEmpty) {
          throw const FormatException('无正文的来源绑定聊天消息不得携带搜索 token');
        }
        messages.add(
          _PreparedHandoverMessage(
            source: row,
            targetCipher: null,
            targetTokens: const <String>[],
          ),
        );
        continue;
      }
      final plaintext = await _crypto.decryptForHandover(
        binding: source,
        keys: sourceKeys,
        recordId: row.messageId,
        blob: blob,
      );
      final expectedSourceTokens = await _crypto.searchTokensForHandover(
        keys: sourceKeys,
        text: _messageSummary(plaintext),
      );
      if (!_sameStringList(expectedSourceTokens, row.tokens)) {
        throw const FormatException('来源绑定聊天消息搜索 token 与正文不一致');
      }
      final targetCipher = await _crypto.encryptForHandover(
        binding: target,
        keys: targetKeys,
        recordId: row.messageId,
        plaintext: plaintext,
      );
      final verified = await _crypto.decryptForHandover(
        binding: target,
        keys: targetKeys,
        recordId: row.messageId,
        blob: targetCipher,
      );
      if (verified != plaintext) {
        throw StateError('聊天正文新账户密文回读不一致');
      }
      messages.add(
        _PreparedHandoverMessage(
          source: row,
          targetCipher: targetCipher,
          targetTokens: await _crypto.searchTokensForHandover(
            keys: targetKeys,
            text: _messageSummary(plaintext),
          ),
        ),
      );
    }
    return _PreparedHandoverSnapshot(
      conversations: List<_PreparedHandoverConversation>.unmodifiable(
        conversations,
      ),
      messages: List<_PreparedHandoverMessage>.unmodifiable(messages),
    );
  }

  /// finalized 后可能已有新消息直接写入目标绑定；提交前同样认证其密文与搜索索引，
  /// 禁止把伪造 binding 字段的损坏行当成已完成迁移后删除清单。
  Future<void> _validateHandoverTargetSnapshot({
    required ChatDataBinding target,
    required ChatHandoverKeys targetKeys,
    required _HandoverBindingSnapshot snapshot,
  }) async {
    for (final row in snapshot.conversations) {
      await _crypto.decryptForHandover(
        binding: target,
        keys: targetKeys,
        recordId: row.conversationId,
        blob: row.cipher,
      );
    }
    for (final row in snapshot.messages) {
      final cipher = row.cipher;
      if (cipher == null || cipher.isEmpty) {
        if (row.tokens.isNotEmpty) {
          throw const FormatException('无正文的目标绑定聊天消息不得携带搜索 token');
        }
        continue;
      }
      final plaintext = await _crypto.decryptForHandover(
        binding: target,
        keys: targetKeys,
        recordId: row.messageId,
        blob: cipher,
      );
      final expectedTokens = await _crypto.searchTokensForHandover(
        keys: targetKeys,
        text: _messageSummary(plaintext),
      );
      if (!_sameStringList(expectedTokens, row.tokens)) {
        throw const FormatException('目标绑定聊天消息搜索 token 与正文不一致');
      }
    }
  }

  static String _encodeHandoverManifest({
    required ChatDataBinding source,
    required ChatDataBinding target,
    required _HandoverBindingSnapshot snapshot,
    required List<int> macKey,
  }) {
    final payloadJson = jsonEncode(<String, Object?>{
      'source': source.toJson(),
      'target': target.toJson(),
      'conversations': <Map<String, Object?>>[
        for (final row in snapshot.conversations)
          <String, Object?>{
            'id': row.id,
            'conversation_id': row.conversationId,
            'source_fingerprint': _conversationSourceFingerprint(row),
            'source_has_cipher': row.cipher.isNotEmpty,
          },
      ],
      'messages': <Map<String, Object?>>[
        for (final row in snapshot.messages)
          <String, Object?>{
            'id': row.id,
            'message_id': row.messageId,
            'source_fingerprint': _messageSourceFingerprint(row),
            'source_has_cipher': row.cipher != null && row.cipher!.isNotEmpty,
          },
      ],
    });
    return jsonEncode(<String, Object>{
      'payload_json': payloadJson,
      'mac': _handoverManifestMac(payloadJson, macKey),
    });
  }

  Future<_HandoverManifestRecord?> _readValidatedHandoverManifest({
    required String key,
    required ChatDataBinding source,
    required ChatDataBinding target,
    required List<int> macKey,
  }) async {
    final row = await _chatIsar.read(
      (isar) async => isar.chatAccountHandoverEntitys.getByHandoverKey(key),
    );
    if (row == null) return null;
    if (row.ownerUserId != target.userId ||
        row.sourceBindingRevision != source.bindingRevision ||
        row.sourceAccountId != source.accountId ||
        row.targetBindingRevision != target.bindingRevision ||
        row.targetAccountId != target.accountId) {
      throw const FormatException('聊天换绑交接清单与当前绑定不一致');
    }
    final identity = _validateHandoverManifestJson(
      row.manifestJson,
      source: source,
      target: target,
      macKey: macKey,
    );
    return _HandoverManifestRecord(
      id: row.id,
      handoverKey: row.handoverKey,
      ownerUserId: row.ownerUserId,
      sourceBindingRevision: row.sourceBindingRevision,
      sourceAccountId: row.sourceAccountId,
      targetBindingRevision: row.targetBindingRevision,
      targetAccountId: row.targetAccountId,
      manifestJson: row.manifestJson,
      identity: identity,
    );
  }

  static _HandoverManifestIdentity _validateHandoverManifestJson(
    String raw, {
    required ChatDataBinding source,
    required ChatDataBinding target,
    required List<int> macKey,
  }) {
    final outer = jsonDecode(raw);
    if (outer is! Map<String, dynamic> ||
        !_hasExactKeys(outer, const <String>{'payload_json', 'mac'})) {
      throw const FormatException('聊天换绑交接清单顶层结构损坏');
    }
    final payloadJson = outer['payload_json'];
    final mac = outer['mac'];
    if (payloadJson is! String ||
        payloadJson.isEmpty ||
        mac is! String ||
        !_handoverDigestPattern.hasMatch(mac) ||
        !_constantTimeEquals(mac, _handoverManifestMac(payloadJson, macKey))) {
      throw const FormatException('聊天换绑交接清单认证失败');
    }
    final value = jsonDecode(payloadJson);
    if (value is! Map<String, dynamic> ||
        !_hasExactKeys(value, const <String>{
          'source',
          'target',
          'conversations',
          'messages',
        })) {
      throw const FormatException('聊天换绑交接清单载荷结构损坏');
    }
    final sourceValue = value['source'];
    final targetValue = value['target'];
    const bindingKeys = <String>{
      'key_domain',
      'user_id',
      'binding_revision',
      'account_id',
    };
    if (sourceValue is! Map<String, dynamic> ||
        targetValue is! Map<String, dynamic> ||
        !_hasExactKeys(sourceValue, bindingKeys) ||
        !_hasExactKeys(targetValue, bindingKeys)) {
      throw const FormatException('聊天换绑交接清单绑定结构损坏');
    }
    final storedSource = ChatDataBinding.fromJson(jsonEncode(sourceValue));
    final storedTarget = ChatDataBinding.fromJson(jsonEncode(targetValue));
    if (!_sameBinding(storedSource, source) ||
        !_sameBinding(storedTarget, target)) {
      throw const FormatException('聊天换绑交接清单绑定事实损坏');
    }

    final conversationValues = value['conversations'];
    final messageValues = value['messages'];
    if (conversationValues is! List || messageValues is! List) {
      throw const FormatException('聊天换绑交接清单记录列表损坏');
    }
    final conversationIds = <int>{};
    final conversationStableIds = <String>{};
    final conversations = <_HandoverManifestConversationIdentity>[];
    for (final item in conversationValues) {
      if (item is! Map<String, dynamic> ||
          !_hasExactKeys(item, const <String>{
            'id',
            'conversation_id',
            'source_fingerprint',
            'source_has_cipher',
          })) {
        throw const FormatException('聊天会话交接项结构损坏');
      }
      final id = item['id'];
      final conversationId = item['conversation_id'];
      final sourceFingerprint = item['source_fingerprint'];
      final sourceHasCipher = item['source_has_cipher'];
      if (id is! int ||
          id <= 0 ||
          !conversationIds.add(id) ||
          conversationId is! String ||
          conversationId.isEmpty ||
          !conversationStableIds.add(conversationId) ||
          sourceFingerprint is! String ||
          !_handoverDigestPattern.hasMatch(sourceFingerprint) ||
          sourceHasCipher is! bool) {
        throw const FormatException('聊天会话交接项损坏');
      }
      if (!sourceHasCipher &&
          sourceFingerprint !=
              _conversationSourceFingerprint(
                _HandoverConversationSource(
                  id: id,
                  conversationId: conversationId,
                  cipher: '',
                ),
              )) {
        throw const FormatException('聊天会话交接项空密文指纹损坏');
      }
      conversations.add(
        _HandoverManifestConversationIdentity(
          id: id,
          conversationId: conversationId,
          sourceFingerprint: sourceFingerprint,
          sourceHasCipher: sourceHasCipher,
        ),
      );
    }

    final messageIds = <int>{};
    final messageStableIds = <String>{};
    final messages = <_HandoverManifestMessageIdentity>[];
    for (final item in messageValues) {
      if (item is! Map<String, dynamic> ||
          !_hasExactKeys(item, const <String>{
            'id',
            'message_id',
            'source_fingerprint',
            'source_has_cipher',
          })) {
        throw const FormatException('聊天消息交接项结构损坏');
      }
      final id = item['id'];
      final messageId = item['message_id'];
      final sourceFingerprint = item['source_fingerprint'];
      final sourceHasCipher = item['source_has_cipher'];
      if (id is! int ||
          id <= 0 ||
          !messageIds.add(id) ||
          messageId is! String ||
          messageId.isEmpty ||
          !messageStableIds.add(messageId) ||
          sourceFingerprint is! String ||
          !_handoverDigestPattern.hasMatch(sourceFingerprint) ||
          sourceHasCipher is! bool) {
        throw const FormatException('聊天消息交接项损坏');
      }
      if (!sourceHasCipher &&
          sourceFingerprint !=
              _messageSourceFingerprint(
                _HandoverMessageSource(
                  id: id,
                  messageId: messageId,
                  cipher: null,
                  tokens: const <String>[],
                ),
              )) {
        throw const FormatException('聊天消息交接项空密文指纹损坏');
      }
      messages.add(
        _HandoverManifestMessageIdentity(
          id: id,
          messageId: messageId,
          sourceFingerprint: sourceFingerprint,
          sourceHasCipher: sourceHasCipher,
        ),
      );
    }
    return _HandoverManifestIdentity(
      conversations: List<_HandoverManifestConversationIdentity>.unmodifiable(
        conversations,
      ),
      messages: List<_HandoverManifestMessageIdentity>.unmodifiable(messages),
    );
  }

  static String _handoverManifestMac(String payloadJson, List<int> key) =>
      crypto.Hmac(crypto.sha256, key)
          .convert(utf8.encode('$_handoverManifestMacDomain$payloadJson'))
          .toString();

  static String _conversationSourceFingerprint(
    _HandoverConversationSource row,
  ) => crypto.sha256
      .convert(
        utf8.encode(
          jsonEncode(<String, Object>{
            'conversation_id': row.conversationId,
            'cipher': row.cipher,
          }),
        ),
      )
      .toString();

  static String _messageSourceFingerprint(_HandoverMessageSource row) => crypto
      .sha256
      .convert(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'message_id': row.messageId,
            // null 与空串都是“无正文”，清单只保留一份规范化缺席指纹。
            'cipher': row.cipher == null || row.cipher!.isEmpty
                ? null
                : row.cipher,
            'tokens': row.tokens,
          }),
        ),
      )
      .toString();

  static bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i += 1) {
      difference |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return difference == 0;
  }

  static bool _hasExactKeys(Map<String, dynamic> value, Set<String> expected) =>
      value.length == expected.length &&
      value.keys.toSet().containsAll(expected);

  static bool _sameHandoverManifestRecord(
    ChatAccountHandoverEntity? row,
    _HandoverManifestRecord expected,
  ) =>
      row != null &&
      row.id == expected.id &&
      row.handoverKey == expected.handoverKey &&
      row.ownerUserId == expected.ownerUserId &&
      row.sourceBindingRevision == expected.sourceBindingRevision &&
      row.sourceAccountId == expected.sourceAccountId &&
      row.targetBindingRevision == expected.targetBindingRevision &&
      row.targetAccountId == expected.targetAccountId &&
      row.manifestJson == expected.manifestJson;

  static bool _sameHandoverBindingSnapshot(
    _HandoverBindingSnapshot left,
    _HandoverBindingSnapshot right,
  ) {
    if (left.conversations.length != right.conversations.length ||
        left.messages.length != right.messages.length) {
      return false;
    }
    for (var i = 0; i < left.conversations.length; i += 1) {
      final expected = left.conversations[i];
      final actual = right.conversations[i];
      if (expected.id != actual.id ||
          expected.conversationId != actual.conversationId ||
          expected.cipher != actual.cipher) {
        return false;
      }
    }
    for (var i = 0; i < left.messages.length; i += 1) {
      final expected = left.messages[i];
      final actual = right.messages[i];
      if (expected.id != actual.id ||
          expected.messageId != actual.messageId ||
          expected.cipher != actual.cipher ||
          !_sameStringList(expected.tokens, actual.tokens)) {
        return false;
      }
    }
    return true;
  }

  static bool _sameConversationSource(
    _HandoverConversationSource expected,
    ChatConversationEntity actual,
    ChatDataBinding binding,
  ) =>
      actual.id == expected.id &&
      actual.conversationId == expected.conversationId &&
      actual.lastMessageCipher == expected.cipher &&
      _conversationBelongsToBinding(actual, binding);

  static bool _sameMessageSource(
    _HandoverMessageSource expected,
    ChatMessageEntity actual,
    ChatDataBinding binding,
  ) =>
      actual.id == expected.id &&
      actual.messageId == expected.messageId &&
      actual.plaintextCipher == expected.cipher &&
      _sameStringList(expected.tokens, actual.searchTokens) &&
      _messageBelongsToBinding(actual, binding);

  static bool _conversationBelongsToBinding(
    ChatConversationEntity row,
    ChatDataBinding binding,
  ) =>
      row.ownerUserId == binding.userId &&
      row.bindingRevision == binding.bindingRevision &&
      row.accountId == binding.accountId;

  static bool _messageBelongsToBinding(
    ChatMessageEntity row,
    ChatDataBinding binding,
  ) =>
      row.ownerUserId == binding.userId &&
      row.bindingRevision == binding.bindingRevision &&
      row.accountId == binding.accountId;

  static bool _sameStringList(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i += 1) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  static bool _sameBinding(ChatDataBinding? actual, ChatDataBinding expected) =>
      actual != null &&
      actual.keyDomain == expected.keyDomain &&
      actual.userId == expected.userId &&
      actual.bindingRevision == expected.bindingRevision &&
      actual.accountId == expected.accountId;

  static void _validateHandover(
    ChatDataBinding source,
    ChatDataBinding target,
  ) {
    source.validate();
    target.validate();
    if (source.keyDomain != target.keyDomain ||
        source.userId != target.userId ||
        target.bindingRevision != source.bindingRevision + 1 ||
        source.accountId == target.accountId) {
      throw const FormatException('聊天换绑交接上下文不合法');
    }
  }

  static String _handoverKey(ChatDataBinding target) =>
      '${target.userId}:${target.bindingRevision}:${target.accountId}';

  Future<String?> _openMessage(
    ChatMessageEntity row,
    ChatCipherSession session,
  ) async {
    final cipher = row.plaintextCipher;
    if (cipher == null || cipher.isEmpty) return null;
    return session.decryptText(recordId: row.messageId, blob: cipher);
  }

  Future<String> _openSummary(
    ChatConversationEntity row,
    ChatCipherSession session,
  ) => session.decryptText(
    recordId: row.conversationId,
    blob: row.lastMessageCipher,
  );

  Future<List<ChatConversationPreview>> readConversationPreviews({
    required String ownerUserId,
    required String currentAccountId,
  }) async {
    // 空会话库是新用户的正常状态。先只读 ChatIsar；本 user ID 没有任何行时
    // 直接返回，禁止为一个空列表启动 WalletIsar、硬件用途钥或解密会话。
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
    final binding = await _crypto.resolveCipherBinding(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
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
    final session = await _crypto.openCipherSession(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      binding: binding,
    );
    try {
      final out = <ChatConversationPreview>[];
      for (final row in rows) {
        out.add(
          _conversationPreviewFromEntity(row, await _openSummary(row, session)),
        );
      }
      return List<ChatConversationPreview>.unmodifiable(out);
    } finally {
      session.dispose();
    }
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
    // 先用现有 conversationId 索引复制当前会话密文快照；禁止每次打开会话都扫描
    // 整张消息表。空会话在这里直接结束，也不触碰钱包绑定或设备用途钥。
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

    final binding = await _crypto.resolveCipherBinding(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
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

    final session = await _crypto.openCipherSession(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      binding: binding,
    );
    try {
      final out = <ChatStoredMessage>[];
      for (final row in rows) {
        out.add(_messageFromEntity(row, await _openMessage(row, session)));
      }
      return List<ChatStoredMessage>.unmodifiable(out);
    } finally {
      session.dispose();
    }
  }

  /// 聊天窗口专用读取：严格接口首次发现认证失败后，仅隔离损坏行并继续返回其余
  /// 已通过认证的记录。密文不会降级解密、不会伪造明文，也不会自动删除本机数据。
  Future<ChatMessageDisplayBatch> readMessagesForDisplay({
    required String ownerUserId,
    required String currentAccountId,
    required String conversationId,
  }) async {
    // 展示读取只复制一次当前会话快照、打开一次用途钥，再逐条验真。单条密文或
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

    final binding = await _crypto.resolveCipherBinding(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
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
    final session = await _crypto.openCipherSession(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      binding: binding,
    );
    try {
      final decrypted = <ChatStoredMessage>[];
      var integrityFailureCount = 0;
      for (final row in rows) {
        try {
          decrypted.add(
            _messageFromEntity(row, await _openMessage(row, session)),
          );
        } on ChatLocalCipherException catch (error) {
          integrityFailureCount += 1;
          debugPrint(
            '[ChatStore] display_row_rejected message_id=${row.messageId} '
            'stage=local_cipher error=${error.runtimeType}',
          );
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
      return filterChatMessagesForDisplay(
        decrypted,
        initialIntegrityFailureCount: integrityFailureCount,
      );
    } finally {
      session.dispose();
    }
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

  /// 跨会话搜索本机聊天记录（聊天搜索页的「聊天记录」段）。
  ///
  /// 正文已在磁盘上加密，无法再做明文子串匹配，改为**两段式**：
  /// 1. 用 `ChatStorageKeyPurpose.chatIndex` 子钥把查询串切成 HMAC bigram token，
  ///    经 `searchTokens` 多值索引取出**同时命中全部 token** 的候选；
  /// 2. 只对候选解密，再验一次真实子串。
  ///
  /// 第 2 步不可省：token 是 HMAC **截断值**，存在假阳性；且 bigram 命中不等于
  /// 原串顺序命中（查 "abc" 会命中含 "ab"、"bc" 但实为 "bcab" 的记录）。
  /// 复验保证结果与此前明文 `contains` 语义完全一致。
  ///
  /// 匹配口径仍是**摘要**（文本取正文，媒体/贴纸取类型化占位），与建索引时一致；
  /// 大小写不敏感。查询不足 2 字符时无 bigram 可用，回落到按属主 user ID 收窄后
  /// 解密扫描——单字符查询在中文里很常见，不能直接拒绝。
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
    final binding = await _crypto.resolveCipherBinding(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
    );
    final tokenSession = await _crypto.openCipherSession(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      binding: binding,
    );
    late final List<String> tokens;
    try {
      tokens = await tokenSession.buildSearchTokens(needle);
    } finally {
      tokenSession.dispose();
    }
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
    final session = await _crypto.openCipherSession(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      binding: binding,
    );
    try {
      final hits = <ChatStoredMessage>[];
      for (final row in candidates) {
        if (hits.length >= limit) break;
        final plaintext = await _openMessage(row, session);
        if (!_messageSummary(plaintext).toLowerCase().contains(needle)) {
          continue; // 索引假阳性，复验滤掉
        }
        hits.add(_messageFromEntity(row, plaintext));
      }
      return List<ChatStoredMessage>.unmodifiable(hits);
    } finally {
      session.dispose();
    }
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
  /// TataChatServer 不保存聊天内容；用户删除聊天记录时，本地 Isar 是唯一
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
  /// TataChatServer 端 A 的系统唤醒端点由 Worker purge 删除；本地 Isar 是 A 私信密文与
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
              ..keyDomain = null
              ..generation = 1
              ..fenceState = _fenceCleared
              ..pendingBindingRevision = null
              ..pendingAccountId = null
              ..pendingKeyDomain = null,
          );
          return;
        }
        _validateFence(existing);
        existing
          ..generation = _nextFenceGeneration(existing.generation)
          ..fenceState = _fenceCleared
          ..pendingBindingRevision = null
          ..pendingAccountId = null
          ..pendingKeyDomain = null;
        _clearCompletedHandoverReceipt(existing);
        await isar.chatBindingFenceEntitys.put(existing);
      });
    });
  }

  /// 无私有数据交接的新绑定只清理不可安全续用的瞬时/派生状态。
  ///
  /// 聊天正文与会话摘要密文继续保留在 Isar，读取时由当前账户认证失败而保持不可见；
  /// 出站队列、入站乱序缓冲、媒体补发、路由和群镜像必须清理，禁止新账户自动发送或
  /// 继续处理此前 MLS 上下文产生的任务。
  Future<void> isolateInaccessibleBinding({
    required ChatDataBinding previous,
    required ChatDataBinding current,
  }) {
    _validateHandover(previous, current);
    return _serializeBindingMutation(previous.userId, () async {
      await _chatIsar.writeTxn((isar) async {
        final fence = await isar.chatBindingFenceEntitys.getByOwnerUserId(
          previous.userId,
        );
        if (fence == null) throw StateError('Chat 持久写入门闩缺失');
        _validateFence(fence);
        if (fence.fenceState == _fenceCleared) return;
        if (_isActiveCurrentFence(fence, current) && !_hasPendingFence(fence)) {
          return;
        }
        if (!_isActiveCurrentFence(fence, previous) ||
            _hasPendingFence(fence)) {
          throw StateError('Chat 隔离来源 binding 与持久 fence 不一致');
        }
        await _clearTransientChatStateInTxn(isar, previous.userId);
        _clearCompletedHandoverReceipt(fence);
        fence
          ..bindingRevision = current.bindingRevision
          ..accountId = current.accountId
          ..keyDomain = current.keyDomain
          ..generation = _nextFenceGeneration(fence.generation)
          ..fenceState = _fenceActive
          ..pendingBindingRevision = null
          ..pendingAccountId = null
          ..pendingKeyDomain = null;
        await isar.chatBindingFenceEntitys.put(fence);
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
    final handovers = await isar.chatAccountHandoverEntitys
        .filter()
        .ownerUserIdEqualTo(userId)
        .findAll();
    for (final row in handovers) {
      await isar.chatAccountHandoverEntitys.delete(row.id);
    }
  }

  /// 先把用户操作保存为本机密文消息，再异步取得接收设备 KeyPackage 并生成 MLS 消息。
  ///
  /// 本行已经是会话与消息列表的真值，不是 UI 临时气泡。`messageBytesHex` 为空
  /// 明确表示“尚未转换为 MLS Message”；正文继续使用现有 chat/chatIndex 用途钥，
  /// TataChatServer 与系统推送均看不到本行。
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
      final binding = await _crypto.resolveCipherBinding(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        expectedKeyDomain: bindingToken.keyDomain,
      );
      _requireResolvedBinding(bindingToken: bindingToken, binding: binding);
      final sealed = await _sealMessage(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        messageId: localMessageId,
        plaintext: payload,
        binding: binding,
      );
      final summaryCipher = await _sealSummary(
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
          lastMessageCipher: summaryCipher,
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
            ..plaintextCipher = sealed.cipher
            ..searchTokens = sealed.tokens
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
    final binding = await _crypto.resolveCipherBinding(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      expectedKeyDomain: bindingToken.keyDomain,
    );
    _requireResolvedBinding(bindingToken: bindingToken, binding: binding);
    final session = await _crypto.openCipherSession(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      binding: binding,
    );
    try {
      final pending = <ChatPendingOutgoingMessage>[];
      for (final row in rows) {
        final payload = await _openMessage(row, session);
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
      return List<ChatPendingOutgoingMessage>.unmodifiable(pending);
    } finally {
      session.dispose();
    }
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
      final binding = await _crypto.resolveCipherBinding(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        expectedKeyDomain: bindingToken.keyDomain,
      );
      _requireResolvedBinding(bindingToken: bindingToken, binding: binding);
      // 加解密在事务外完成，避免密码学运算占住 Isar 写事务。
      final sealed = await _sealMessage(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        messageId: message.messageId,
        plaintext: plaintext,
        binding: binding,
      );
      final summaryCipher = await _sealSummary(
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
          lastMessageCipher: summaryCipher,
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
            plaintextCipher: sealed.cipher,
            searchTokens: sealed.tokens,
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
      final binding = await _crypto.resolveCipherBinding(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        expectedKeyDomain: bindingToken.keyDomain,
      );
      _requireResolvedBinding(bindingToken: bindingToken, binding: binding);
      final sealed = await _sealMessage(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        messageId: message.messageId,
        plaintext: plaintext,
        binding: binding,
      );
      final summaryCipher = await _sealSummary(
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
          lastMessageCipher: summaryCipher,
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
            plaintextCipher: sealed.cipher,
            searchTokens: sealed.tokens,
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

  /// 读取发送设备上尚未被 TataChatServer 持久接收的待重试密文。
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
        final byCreatedAt = _queuedMessageCreatedAt(
          a,
        ).compareTo(_queuedMessageCreatedAt(b));
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
      final binding = await _crypto.resolveCipherBinding(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        expectedKeyDomain: bindingToken.keyDomain,
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
          ..lastMessageCipher = conversation?.lastMessageCipher ?? ''
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
      final binding = await _crypto.resolveCipherBinding(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        expectedKeyDomain: bindingToken.keyDomain,
      );
      _requireResolvedBinding(bindingToken: bindingToken, binding: binding);
      final sealed = await _sealMessage(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        messageId: logicalMessageId,
        plaintext: payload,
        binding: binding,
      );
      final summaryCipher = await _sealSummary(
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
          lastMessageCipher: summaryCipher,
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
            ..plaintextCipher = sealed.cipher
            ..searchTokens = sealed.tokens
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
      final binding = await _crypto.resolveCipherBinding(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        expectedKeyDomain: bindingToken.keyDomain,
      );
      _requireResolvedBinding(bindingToken: bindingToken, binding: binding);
      final sealed = await _sealMessage(
        ownerUserId: ownerUserId,
        currentAccountId: currentAccountId,
        messageId: message.messageId,
        plaintext: plaintext,
        binding: binding,
      );
      final summaryCipher = await _sealSummary(
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
          lastMessageCipher: summaryCipher,
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
            plaintextCipher: sealed.cipher,
            searchTokens: sealed.tokens,
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
    required String lastMessageCipher,
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
      ..lastMessageCipher = replacesLatest
          ? lastMessageCipher
          : existing.lastMessageCipher
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
    required String lastMessageCipher,
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
      ..lastMessageCipher = replacesLatest
          ? lastMessageCipher
          : existing.lastMessageCipher
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

/// [lastMessage] 由 `ChatStore` 解密后传入——本函数不接触密钥。
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

/// [plaintext] 由 `ChatStore` 解密后传入——本函数不接触密钥。
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
    return EncryptedMessage.fromBuffer(
      _hexToBytes(row.messageBytesHex),
    ).createdAtMillis.toInt();
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
  String? plaintextCipher,
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
    ..plaintextCipher = plaintextCipher
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

/// 一条消息落盘所需的密文与搜索索引。
class _SealedMessage {
  const _SealedMessage({required this.cipher, required this.tokens});

  /// 正文密文；正文为空时为 null。
  final String? cipher;

  /// HMAC 分词索引（去重后的 bigram token）。
  final List<String> tokens;
}

/// 一次交接 CAS 使用的来源会话密文指纹。
class _HandoverConversationSource {
  const _HandoverConversationSource({
    required this.id,
    required this.conversationId,
    required this.cipher,
  });

  final int id;
  final String conversationId;
  final String cipher;
}

/// 一次交接 CAS 使用的来源消息密文与索引指纹。
class _HandoverMessageSource {
  const _HandoverMessageSource({
    required this.id,
    required this.messageId,
    required this.cipher,
    required this.tokens,
  });

  final int id;
  final String messageId;
  final String? cipher;
  final List<String> tokens;
}

class _HandoverBindingSnapshot {
  const _HandoverBindingSnapshot({
    required this.conversations,
    required this.messages,
  });

  final List<_HandoverConversationSource> conversations;
  final List<_HandoverMessageSource> messages;
}

class _PreparedHandoverConversation {
  const _PreparedHandoverConversation({
    required this.source,
    required this.targetCipher,
  });

  final _HandoverConversationSource source;
  final String targetCipher;
}

class _PreparedHandoverMessage {
  const _PreparedHandoverMessage({
    required this.source,
    required this.targetCipher,
    required this.targetTokens,
  });

  final _HandoverMessageSource source;
  final String? targetCipher;
  final List<String> targetTokens;
}

class _PreparedHandoverSnapshot {
  const _PreparedHandoverSnapshot({
    required this.conversations,
    required this.messages,
  });

  final List<_PreparedHandoverConversation> conversations;
  final List<_PreparedHandoverMessage> messages;
}

/// 清单行的不可变副本；CAS 必须确认读取后没有被另一轮 stage 替换。
class _HandoverManifestRecord {
  const _HandoverManifestRecord({
    required this.id,
    required this.handoverKey,
    required this.ownerUserId,
    required this.sourceBindingRevision,
    required this.sourceAccountId,
    required this.targetBindingRevision,
    required this.targetAccountId,
    required this.manifestJson,
    required this.identity,
  });

  final int id;
  final String handoverKey;
  final String ownerUserId;
  final int sourceBindingRevision;
  final String sourceAccountId;
  final int targetBindingRevision;
  final String targetAccountId;
  final String manifestJson;
  final _HandoverManifestIdentity identity;
}

class _HandoverManifestConversationIdentity {
  const _HandoverManifestConversationIdentity({
    required this.id,
    required this.conversationId,
    required this.sourceFingerprint,
    required this.sourceHasCipher,
  });

  final int id;
  final String conversationId;
  final String sourceFingerprint;
  final bool sourceHasCipher;
}

class _HandoverManifestMessageIdentity {
  const _HandoverManifestMessageIdentity({
    required this.id,
    required this.messageId,
    required this.sourceFingerprint,
    required this.sourceHasCipher,
  });

  final int id;
  final String messageId;
  final String sourceFingerprint;
  final bool sourceHasCipher;
}

class _HandoverManifestIdentity {
  const _HandoverManifestIdentity({
    required this.conversations,
    required this.messages,
  });

  final List<_HandoverManifestConversationIdentity> conversations;
  final List<_HandoverManifestMessageIdentity> messages;
}
