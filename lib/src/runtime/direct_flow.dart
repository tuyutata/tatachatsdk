import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../attachment/vault.dart';
import '../core/chat_content.dart';
import '../core/chat_message.dart';
import '../mls/mls_boundary.dart';
import '../mls/mls_group_boundary.dart';
import '../protocol/message.dart';
import '../storage/flow_store.dart';
import '../transport/chat_transport.dart';
import 'media_limit_policy.dart';

/// 投递一个密文 Message。[recipientUserId] 是收件人唯一身份主键和路由键。

typedef EncryptedMessageDeliverer =
    Future<ChatDeliveryResult> Function(
      EncryptedMessage message,
      List<int> messageBytes,
      String recipientUserId,
      String recipientDeviceId,
    );

/// 本地可靠队列落盘后，把网络投递交给按会话保序的后台执行器。调用方不得
/// 在执行器内重新处理 MLS 或改写附件，只允许投递已持久化的密文消息并回写状态。
typedef EncryptedMessageDeliveryScheduler =
    void Function(String conversationId, Future<void> Function() delivery);

/// 媒体控制消息和发送方本地附件均已安全落盘，可以立即刷新本机聊天气泡。
typedef ChatMediaLocalCommitNotifier = Future<void> Function();

typedef ChatIncomingContentHandler =
    Future<void> Function(EncryptedMessage message, ChatContent content);

typedef ChatTraceSink = void Function(String message);

void discardChatTrace(String message) {}

final class _DirectWireTarget {
  const _DirectWireTarget({required this.wire, required this.recipient});

  final MlsWireMessage wire;
  final MlsMemberIdentity recipient;
}

bool _needsDirectWelcome(Object error) {
  final text = error.toString();
  return text.contains('MLS 群不存在') ||
      text.contains('群会话不存在') ||
      text.contains('需先处理 Welcome');
}

/// 待发送的本机明文媒体(图片 / 视频 / 文件 / 语音)。
///
/// 承载**源文件路径**而非整块字节:发送走流式读盘,支持最大 5GB 且不 OOM。
class ChatMediaDraft {
  const ChatMediaDraft({
    required this.kind,
    required this.fileName,
    required this.contentType,
    required this.sourcePath,
    required this.byteSize,
    this.width,
    this.height,
    this.durationMs,
    this.blurhash,
  });

  /// 媒体类型:image / video / file / audio。
  final ChatMessageKind kind;

  /// 用户本机可见文件名。该字段只会进入 OpenMLS 明文，不写入 Worker 明文表。
  final String fileName;

  /// 文件 MIME 类型。
  final String contentType;

  /// 本机源文件路径。字节从此路径流式读取,不整块载入内存。
  final String sourcePath;

  /// 源文件字节数(= File(sourcePath).length())。
  final int byteSize;

  /// image/video 像素宽高(可空;步骤2 采集时补齐)。
  final int? width;
  final int? height;

  /// video/audio 时长毫秒(可空)。
  final int? durationMs;

  /// image/video 低清占位串(blurhash，可空;步骤2 生成)。
  final String? blurhash;
}

/// 已在本机缓存就绪的媒体句柄。
///
/// 只返回路径与大小,**不返回整块字节**:5GB 媒体不允许载入内存,读取由调用方
/// 按需流式进行。
class ChatDownloadedAttachment {
  const ChatDownloadedAttachment({
    required this.attachmentId,
    required this.fileName,
    required this.contentType,
    required this.clearByteSize,
    required this.filePath,
  });

  /// OpenMLS 附件控制消息中的附件 ID。
  final String attachmentId;

  /// 用户可见文件名。
  final String fileName;

  /// 文件 MIME 类型。
  final String contentType;

  /// 明文字节数。
  final int clearByteSize;

  /// App 私有缓存中的保存路径。
  final String filePath;
}

/// Chat 入站处理结果。
class ChatIncomingProcessResult {
  const ChatIncomingProcessResult({
    required this.messageId,
    required this.accepted,
    required this.queuedPending,
    this.plaintext,
    this.acceptedMessages = const <EncryptedMessage>[],
  });

  final String messageId;
  final bool accepted;
  final bool queuedPending;
  final String? plaintext;

  /// 本次处理及 Welcome 回放中已经成功落库的应用 message；运行态据此发送
  /// 内部设备确认，不代表用户已读。
  final List<EncryptedMessage> acceptedMessages;
}

/// TataChatSDK 消息收发状态机。
///
/// 本类是聊天收发编排层。它不实现密码学，只负责把 native OpenMLS、
/// EncryptedMessage、本地 Isar 和正式 transport 串起来。
class ChatFlow<TBindingToken> {
  const ChatFlow({
    required MlsGroupCrypto crypto,
    required ChatFlowStore<TBindingToken> store,
    required EncryptedMessageDeliverer deliverer,
    required TBindingToken bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    this.deliveryScheduler,
    this.afterIncomingStore,
    this.mediaLimits = const ChatUnlimitedMediaLimitPolicy(),
    this.trace = discardChatTrace,
  }) : _crypto = crypto,
       _store = store,
       _deliverer = deliverer,
       _bindingToken = bindingToken,
       _ownerUserId = ownerUserId,
       _currentAccountId = currentAccountId;

  final MlsGroupCrypto _crypto;
  final ChatFlowStore<TBindingToken> _store;
  final EncryptedMessageDeliverer _deliverer;
  final TBindingToken _bindingToken;
  final String _ownerUserId;
  final String _currentAccountId;
  final EncryptedMessageDeliveryScheduler? deliveryScheduler;

  /// 应用消息已经安全落库后的独立后置任务。附件下载失败不得撤销消息或阻塞邮箱 ACK。
  final ChatIncomingContentHandler? afterIncomingStore;
  final ChatMediaLimitPolicy mediaLimits;
  final ChatTraceSink trace;

  Future<List<ChatDeliveryResult>> sendText({
    required String conversationId,
    required String senderUserId,
    required String recipientUserId,
    required String senderDeviceId,
    required List<MlsKeyPackage> recipientKeyPackages,
    required String text,
    String? pendingLocalMessageId,
    int? createdAtMillis,
  }) async {
    final now = createdAtMillis ?? DateTime.now().millisecondsSinceEpoch;
    final payload = ChatPayloadCodec.encode(ChatContent.text(text));
    final outbound = await _createDirectOutbound(
      conversationId: conversationId,
      recipientUserId: recipientUserId,
      senderDeviceId: senderDeviceId,
      recipientKeyPackages: recipientKeyPackages,
      plaintext: utf8.encode(payload),
    );
    return _deliverOutbound(
      outbound: outbound,
      conversationId: conversationId,
      senderUserId: senderUserId,
      recipientUserId: recipientUserId,
      senderDeviceId: senderDeviceId,
      nowMillis: now,
      messageKind: ChatMessageKind.text,
      payload: payload,
      pendingLocalMessageId: pendingLocalMessageId,
    );
  }

  /// 发送内置贴纸：只走控制消息(几十字节)，不经 WebRTC、不落缓存。
  Future<List<ChatDeliveryResult>> sendSticker({
    required String conversationId,
    required String senderUserId,
    required String recipientUserId,
    required String senderDeviceId,
    required List<MlsKeyPackage> recipientKeyPackages,
    required String packId,
    required String stickerId,
    String? pendingLocalMessageId,
    int? createdAtMillis,
  }) async {
    final now = createdAtMillis ?? DateTime.now().millisecondsSinceEpoch;
    final payload = ChatPayloadCodec.encode(
      ChatContent.sticker(packId: packId, stickerId: stickerId),
    );
    final outbound = await _createDirectOutbound(
      conversationId: conversationId,
      recipientUserId: recipientUserId,
      senderDeviceId: senderDeviceId,
      recipientKeyPackages: recipientKeyPackages,
      plaintext: utf8.encode(payload),
    );
    return _deliverOutbound(
      outbound: outbound,
      conversationId: conversationId,
      senderUserId: senderUserId,
      recipientUserId: recipientUserId,
      senderDeviceId: senderDeviceId,
      nowMillis: now,
      messageKind: ChatMessageKind.sticker,
      payload: payload,
      pendingLocalMessageId: pendingLocalMessageId,
    );
  }

  /// 附件密文已在 R2 ready 后，只把含传输密钥/摘要的控制消息放入 OpenMLS 消息。
  Future<List<ChatDeliveryResult>> sendMediaControl({
    required String conversationId,
    required String senderUserId,
    required String recipientUserId,
    required String senderDeviceId,
    required List<MlsKeyPackage> recipientKeyPackages,
    required ChatContent media,
    String? pendingLocalMessageId,
    int? createdAtMillis,
  }) async {
    if (!media.isMedia ||
        media.byteSize == null ||
        mediaLimits.exceedsForKind(media.kind, media.byteSize!)) {
      throw ChatMediaTooLargeException(
        byteSize: media.byteSize ?? 0,
        limitBytes: mediaLimits.limitForKind(media.kind),
        kind: media.kind,
      );
    }
    final now = createdAtMillis ?? DateTime.now().millisecondsSinceEpoch;
    final payload = ChatPayloadCodec.encode(media);
    final outbound = await _createDirectOutbound(
      conversationId: conversationId,
      recipientUserId: recipientUserId,
      senderDeviceId: senderDeviceId,
      recipientKeyPackages: recipientKeyPackages,
      plaintext: utf8.encode(payload),
    );
    return _deliverOutbound(
      outbound: outbound,
      conversationId: conversationId,
      senderUserId: senderUserId,
      recipientUserId: recipientUserId,
      senderDeviceId: senderDeviceId,
      nowMillis: now,
      messageKind: media.kind,
      payload: payload,
      pendingLocalMessageId: pendingLocalMessageId,
    );
  }

  /// 把加密结果逐条落库并投递。应用消息进消息表 + 出站队列，握手消息只进出站
  /// 队列；投递结果回写投递状态。sendText / sendMedia / sendSticker 共用。
  Future<List<ChatDeliveryResult>> _deliverOutbound({
    required List<_DirectWireTarget> outbound,
    required String conversationId,
    required String senderUserId,
    required String recipientUserId,
    required String senderDeviceId,
    required int nowMillis,
    required ChatMessageKind messageKind,
    required String payload,
    ChatMediaLocalCommitNotifier? onApplicationStored,
    String? pendingLocalMessageId,
  }) async {
    final queued = <({EncryptedMessage message, List<int> messageBytes})>[];
    var applicationStored = false;
    var index = 0;
    for (final target in outbound) {
      final wireMessage = target.wire;
      // 本机 pending 的 MLS 序号必须按语义固定，而不能取当前返回列表的下标。
      // 首次创建会话可能在只保存 Welcome 后中断；重试时 OpenMLS 已有会话，
      // 只返回 Application。固定 Welcome=0 / Application=1 可保证两者永不撞
      // Message ID，且队列始终先投递 Welcome、再投递 Application。
      final messageIndex = pendingLocalMessageId == null
          ? index
          : switch (wireMessage.messageKind) {
              MlsMessageKind.welcome => 0,
              MlsMessageKind.commit => 1,
              MlsMessageKind.application => 2,
              MlsMessageKind.unknown => 3,
            };
      final message = wireMessage.toEncryptedMessage(
        // 本地待发送行用稳定 ID 与语义序号做 seed；初始化或网络失败后重试
        // 仍得到同一 Message ID，Store/收端幂等去重。
        messageId: _newMessageId(
          pendingLocalMessageId ?? conversationId,
          nowMillis,
          messageIndex,
        ),
        senderUserId: senderUserId,
        recipientUserId: target.recipient.userId,
        senderDeviceId: senderDeviceId,
        recipientDeviceId: target.recipient.deviceId,
        createdAtMillis: nowMillis + messageIndex,
      );
      final messageBytes = message.writeToBuffer();
      final isApplication =
          wireMessage.messageKind == MlsMessageKind.application;
      if (isApplication && !applicationStored) {
        await _store.saveOutgoingMessage(
          bindingToken: _bindingToken,
          ownerUserId: _ownerUserId,
          currentAccountId: _currentAccountId,
          message: message,
          messageBytes: messageBytes,
          recipientUserId: target.recipient.userId,
          messageKind: messageKind,
          deliveryState: ChatMessageDeliveryState.queued,
          plaintext: payload,
          pendingLocalMessageId: pendingLocalMessageId,
        );
        applicationStored = true;
      } else {
        await _store.queueOutgoingMessage(
          bindingToken: _bindingToken,
          ownerUserId: _ownerUserId,
          message: message,
          messageBytes: messageBytes,
          recipientUserId: target.recipient.userId,
          deliveryState: ChatMessageDeliveryState.queued,
        );
      }
      queued.add((message: message, messageBytes: messageBytes));
      trace(
        '[ChatTrace] message.queued id=${message.messageId} '
        'wire=${wireMessage.messageKind.name} peer=$recipientUserId',
      );
      index += 1;
    }
    if (applicationStored) {
      await onApplicationStored?.call();
    }

    Future<List<ChatDeliveryResult>> deliverQueued() async {
      final results = <ChatDeliveryResult>[];
      for (final item in queued) {
        late final ChatDeliveryResult result;
        try {
          result = await _deliverer(
            item.message,
            item.messageBytes,
            item.message.recipientUserId,
            item.message.recipientDeviceId,
          );
        } on Object catch (error) {
          trace(
            '[ChatTrace] message.delivery_failed '
            'id=${item.message.messageId} code=${_safeTraceError(error)}',
          );
          rethrow;
        }
        await _store.markOutgoingDelivery(
          bindingToken: _bindingToken,
          ownerUserId: _ownerUserId,
          messageId: item.message.messageId,
          state: result.state,
          errorMessage: result.errorMessage,
        );
        trace(
          '[ChatTrace] message.delivery id=${item.message.messageId} '
          'transport=${result.transportType.name} state=${result.state.name} '
          'code=${result.errorMessage ?? '-'}',
        );
        results.add(result);
      }
      return results;
    }

    // Runtime 页面链路在本地可靠落盘后立即返回；网络投递在独立后台队列中
    // 按会话保序。低层测试未注入执行器时仍等待并返回真实投递结果。
    final scheduler = deliveryScheduler;
    if (scheduler != null) {
      scheduler(conversationId, () async {
        await deliverQueued();
      });
      return const <ChatDeliveryResult>[];
    }
    return deliverQueued();
  }

  Future<ChatIncomingProcessResult> processIncomingMessageBytes(
    List<int> messageBytes,
  ) async {
    final message = EncryptedMessage.fromBuffer(messageBytes);
    trace(
      '[ChatTrace] message.incoming id=${message.messageId} '
      'sender=${message.senderUserId}',
    );
    final wireMessage = mlsWireMessageFromEncryptedMessage(message);
    try {
      final inbound = await _crypto.groupProcess(wireMessage);
      if (inbound.status == GroupProcessStatus.outOfOrder) {
        await _store.savePendingInbound(
          bindingToken: _bindingToken,
          ownerUserId: _ownerUserId,
          message: message,
          messageBytes: messageBytes,
          reason: 'mls_out_of_order',
        );
        return ChatIncomingProcessResult(
          messageId: message.messageId,
          accepted: false,
          queuedPending: true,
        );
      }
      if (inbound.kind == GroupInboundKind.welcome) {
        final acceptedMessages = <EncryptedMessage>[];
        final pending = await _store.takePendingInbound(
          _ownerUserId,
          message.conversationId,
          bindingToken: _bindingToken,
        );
        for (final item in pending) {
          final replayed = await processIncomingMessageBytes(
            item.writeToBuffer(),
          );
          acceptedMessages.addAll(replayed.acceptedMessages);
        }
        return ChatIncomingProcessResult(
          messageId: message.messageId,
          accepted: true,
          queuedPending: false,
          acceptedMessages: List<EncryptedMessage>.unmodifiable(
            acceptedMessages,
          ),
        );
      }

      if (inbound.kind == GroupInboundKind.commit) {
        return ChatIncomingProcessResult(
          messageId: message.messageId,
          accepted: true,
          queuedPending: false,
          acceptedMessages: <EncryptedMessage>[message],
        );
      }
      if (inbound.kind != GroupInboundKind.application || !inbound.isApplied) {
        throw StateError('OpenMLS 未生成可接受的应用消息');
      }
      final plaintext = utf8.decode(inbound.plaintext ?? const []);
      final content = ChatPayloadCodec.decode(plaintext);
      await _store.saveIncomingMessage(
        bindingToken: _bindingToken,
        ownerUserId: _ownerUserId,
        currentAccountId: _currentAccountId,
        message: message,
        messageBytes: messageBytes,
        messageKind: content.kind,
        plaintext: plaintext,
      );
      final postStore = afterIncomingStore?.call(message, content);
      if (postStore != null) {
        unawaited(
          postStore.catchError((Object error) {
            // 附件是消息落库后的独立资源；失败只保留附件待重试，不能反向毒化邮箱。
            trace(
              '[ChatTrace] attachment.receive_deferred_failed '
              'id=${message.messageId} code=${_safeTraceError(error)}',
            );
          }),
        );
      }
      trace(
        '[ChatTrace] message.received id=${message.messageId} '
        'kind=${content.kind.name}',
      );
      return ChatIncomingProcessResult(
        messageId: message.messageId,
        accepted: true,
        queuedPending: false,
        plaintext: plaintext,
        acceptedMessages: <EncryptedMessage>[message],
      );
    } catch (error) {
      // Welcome 尚未到达时保留同一 Message；其他解密、载荷或存储失败上抛，
      // 让服务端邮箱继续保存密文，禁止错误 ACK。
      if (_needsDirectWelcome(error)) {
        await _store.savePendingInbound(
          bindingToken: _bindingToken,
          ownerUserId: _ownerUserId,
          message: message,
          messageBytes: messageBytes,
          reason: 'mls_welcome_required',
        );
        return ChatIncomingProcessResult(
          messageId: message.messageId,
          accepted: false,
          queuedPending: true,
        );
      }
      trace(
        '[ChatTrace] message.receive_failed '
        'id=${message.messageId} code=${_safeTraceError(error)}',
      );
      rethrow;
    }
  }

  static Future<ChatDeliveryResult> deliverWithTransport({
    required ChatTransport transport,
    required EncryptedMessage message,
    required String recipientUserId,
  }) {
    return transport.sendEncryptedMessage(
      messageId: message.messageId,
      messageBytes: message.writeToBuffer(),
      recipientUserId: recipientUserId,
      recipientDeviceId: message.recipientDeviceId,
    );
  }

  /// 私聊是仅含双方活跃设备的 MLS 群；新设备通过标准 Welcome 加入。
  Future<List<_DirectWireTarget>> _createDirectOutbound({
    required String conversationId,
    required String recipientUserId,
    required String senderDeviceId,
    required List<MlsKeyPackage> recipientKeyPackages,
    required List<int> plaintext,
  }) async {
    if (recipientKeyPackages.isEmpty) {
      throw StateError('接收方没有可用的 MLS KeyPackage');
    }
    final packages = [...recipientKeyPackages]
      ..sort((a, b) => a.deviceId.compareTo(b.deviceId));
    for (final keyPackage in packages) {
      if (keyPackage.userId != recipientUserId ||
          !keyPackage.lastResort ||
          keyPackage.deviceId.isEmpty) {
        throw StateError('接收方 MLS KeyPackage 身份不一致');
      }
    }

    GroupState state;
    try {
      state = await _crypto.groupState(conversationId);
    } catch (error) {
      if (!_needsDirectWelcome(error)) rethrow;
      await _crypto.createGroup(conversationId);
      state = await _crypto.groupState(conversationId);
    }

    final existing = membersFromMemberIdentities(state.memberIdentities);
    final existingWire = existing.map((member) => member.wireValue).toSet();
    final missing = packages
        .where(
          (keyPackage) => !existingWire.contains(
            MlsMemberIdentity(
              userId: keyPackage.userId,
              deviceId: keyPackage.deviceId,
            ).wireValue,
          ),
        )
        .toList(growable: false);
    final result = <_DirectWireTarget>[];
    if (missing.isNotEmpty) {
      final bundle = await _crypto.addMembers(conversationId, missing);
      final welcome = bundle.welcome;
      if (welcome == null) {
        throw StateError('OpenMLS 加入设备未生成 Welcome');
      }
      for (final keyPackage in missing) {
        result.add(
          _DirectWireTarget(
            wire: welcome,
            recipient: MlsMemberIdentity(
              userId: keyPackage.userId,
              deviceId: keyPackage.deviceId,
            ),
          ),
        );
      }
      for (final member in existing) {
        if (member.userId == _ownerUserId &&
            member.deviceId == senderDeviceId) {
          continue;
        }
        result.add(_DirectWireTarget(wire: bundle.commit, recipient: member));
      }
    }

    final current = membersFromMemberIdentities(
      (await _crypto.groupState(conversationId)).memberIdentities,
    );
    final application = await _crypto.groupCreateMessage(
      conversationId,
      plaintext,
    );
    for (final member in current) {
      if (member.userId == _ownerUserId && member.deviceId == senderDeviceId) {
        continue;
      }
      result.add(_DirectWireTarget(wire: application, recipient: member));
    }
    if (result.every(
      (target) => target.wire.messageKind != MlsMessageKind.application,
    )) {
      throw StateError('MLS 私聊没有可投递的接收设备');
    }
    return result;
  }

  static Future<ChatDownloadedAttachment> downloadAttachment({
    required String conversationId,
    required String controlPlaintext,
    required Directory cacheDirectory,
    required List<int> attachmentKey,
    required Directory plainDirectory,
  }) async {
    final content = ChatPayloadCodec.decode(controlPlaintext);
    final attachmentId = content.attachmentId ?? '';
    final fileName = content.fileName ?? '';
    if (!content.isMedia || attachmentId.isEmpty || fileName.isEmpty) {
      throw const FormatException('不是有效的 Chat 媒体控制消息');
    }
    final cached = await readCachedAttachment(
      conversationId: conversationId,
      attachmentId: attachmentId,
      fileName: fileName,
      contentType: content.mime ?? 'application/octet-stream',
      clearByteSize: content.byteSize ?? 0,
      cacheDirectory: cacheDirectory,
      attachmentKey: attachmentKey,
      plainDirectory: plainDirectory,
    );
    if (cached != null) return cached;
    throw StateError('附件尚未完成设备间传输');
  }

  /// 把一份本机文件导入 App 私有缓存(流式,零整块内存)。
  ///
  /// [moveSource]=true 用于接收端把 HTTPS 下载落盘的密文临时文件**移动**进缓存(同卷
  /// rename 零拷贝,跨卷回退流式复制后删源);=false 用于发送端把源文件**复制**
  /// 进缓存(保留源)。两者落到同一按 conversationId/attachmentId/fileName 派生
  /// 的缓存路径。
  static Future<ChatDownloadedAttachment> importAttachmentFileToCache({
    required String conversationId,
    required String attachmentId,
    required String fileName,
    required String contentType,
    required String sourcePath,
    required int byteSize,
    required bool moveSource,
    required Directory cacheDirectory,
    required List<int> attachmentKey,
    required Directory plainDirectory,
  }) async {
    final cachePath = attachmentCachePath(
      cacheDirectory: cacheDirectory,
      conversationId: conversationId,
      attachmentId: attachmentId,
      fileName: fileName,
    );
    // 长期缓存只落密文。moveSource=true(接收端临时文件)封存后删源；
    // =false(发送端用户原文件)保留源。
    await AttachmentVault.seal(
      plainSource: File(sourcePath),
      cachePath: cachePath,
      key: attachmentKey,
      deleteSource: moveSource,
    );
    // 返回给 UI 的是解密出来的**短命明文**，由前台生命周期统一 purge。
    final plain = await AttachmentVault.openPlain(
      cachePath: cachePath,
      key: attachmentKey,
      plainDirectory: plainDirectory,
    );
    return ChatDownloadedAttachment(
      attachmentId: attachmentId,
      fileName: fileName,
      contentType: contentType,
      clearByteSize: byteSize,
      filePath: plain.path,
    );
  }

  /// 门③:接收端把落盘的临时文件收入缓存前的**落盘二次门控**。
  ///
  /// 大小超出该 mime 上限 → 删临时、返回 null(不入缓存,纵深防御,即便传输层门②
  /// 被绕过);否则把临时文件移入缓存并返回句柄。cacheDirectory 注入以便单测。
  static Future<ChatDownloadedAttachment?> acceptReceivedMediaToCache({
    required String conversationId,
    required String attachmentId,
    required String fileName,
    required String contentType,
    required String tempFilePath,
    required int byteSize,
    required int maxByteSize,
    required Directory cacheDirectory,
    required List<int> attachmentKey,
    required Directory plainDirectory,
  }) async {
    if (byteSize > maxByteSize) {
      final temp = File(tempFilePath);
      if (await temp.exists()) {
        await temp.delete();
      }
      return null;
    }
    return importAttachmentFileToCache(
      conversationId: conversationId,
      attachmentId: attachmentId,
      fileName: fileName,
      contentType: contentType,
      sourcePath: tempFilePath,
      byteSize: byteSize,
      moveSource: true,
      attachmentKey: attachmentKey,
      plainDirectory: plainDirectory,
      cacheDirectory: cacheDirectory,
    );
  }

  /// 媒体在本机缓存中的确定路径(离线补发时按当前 Documents 目录重算)。
  static String attachmentCachePath({
    required Directory cacheDirectory,
    required String conversationId,
    required String attachmentId,
    required String fileName,
  }) {
    return _attachmentCacheFile(
      cacheDirectory: cacheDirectory,
      conversationId: conversationId,
      attachmentId: attachmentId,
      fileName: fileName,
    ).path;
  }

  /// 判定密文缓存是否就绪，并解密出短命明文供展示。
  ///
  /// 密文长度含分块 GCM 框架开销、与明文长度不等，**不能再拿密文 stat 比对
  /// [clearByteSize]**；改为解密后验明文长度，长度不符视为损坏并清掉明文。
  static Future<ChatDownloadedAttachment?> readCachedAttachment({
    required String conversationId,
    required String attachmentId,
    required String fileName,
    required String contentType,
    required int clearByteSize,
    required Directory cacheDirectory,
    required List<int> attachmentKey,
    required Directory plainDirectory,
  }) async {
    final cachePath = attachmentCachePath(
      cacheDirectory: cacheDirectory,
      conversationId: conversationId,
      attachmentId: attachmentId,
      fileName: fileName,
    );
    if (!await AttachmentVault.hasCipher(cachePath)) {
      return null;
    }
    // 先复用已解密好的明文：会话打开时每条媒体消息都会走一次路径解析，
    // 若每次都整文件解密，一个有若干视频的会话首屏就要解出上 GB。
    final reusable = await AttachmentVault.existingPlain(
      cachePath: cachePath,
      plainDirectory: plainDirectory,
    );
    final plain = reusable != null && await reusable.length() == clearByteSize
        ? reusable
        : await AttachmentVault.openPlain(
            cachePath: cachePath,
            key: attachmentKey,
            plainDirectory: plainDirectory,
          );
    final length = await plain.length();
    if (length != clearByteSize) {
      await AttachmentVault.releasePlain(plain);
      return null;
    }
    return ChatDownloadedAttachment(
      attachmentId: attachmentId,
      fileName: fileName,
      contentType: contentType,
      clearByteSize: length,
      filePath: plain.path,
    );
  }
}

/// 只允许稳定服务端错误码进入诊断日志；其他异常仅记录类型，避免泄漏响应正文。
String _safeTraceError(Object error) {
  final value = error.toString();
  return RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(value)
      ? value
      : error.runtimeType.toString();
}

String _newMessageId(String conversationId, int millis, int index) {
  final normalized = conversationId.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
  return '$normalized-$millis-$index';
}

String _safePath(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
}

String _safeFileName(String value) {
  final cleaned = value
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'[^a-zA-Z0-9_.() -]'), '_')
      .trim();
  return cleaned.isEmpty ? 'attachment.bin' : cleaned;
}

File _attachmentCacheFile({
  required Directory cacheDirectory,
  required String conversationId,
  required String attachmentId,
  required String fileName,
}) {
  final targetDirectory = Directory(
    '${cacheDirectory.path}/${_safePath(conversationId)}/${_safePath(attachmentId)}',
  );
  return File('${targetDirectory.path}/${_safeFileName(fileName)}');
}
