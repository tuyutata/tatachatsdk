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
    final outbound = await _crypto.withMessage(
      pendingLocalMessageId ?? '$conversationId:$now',
      () => _createDirectOutbound(
        conversationId: conversationId,
        recipientUserId: recipientUserId,
        senderDeviceId: senderDeviceId,
        recipientKeyPackages: recipientKeyPackages,
        plaintext: utf8.encode(payload),
        messageId: pendingLocalMessageId ?? '$conversationId:$now',
      ),
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
    final outbound = await _crypto.withMessage(
      pendingLocalMessageId ?? '$conversationId:$now',
      () => _createDirectOutbound(
        conversationId: conversationId,
        recipientUserId: recipientUserId,
        senderDeviceId: senderDeviceId,
        recipientKeyPackages: recipientKeyPackages,
        plaintext: utf8.encode(payload),
        messageId: pendingLocalMessageId ?? '$conversationId:$now',
      ),
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

  /// 附件创建前固定私聊实际设备叶子；首次会话只保存真实Welcome，不造占位消息。
  Future<GroupState> prepareAttachmentAudience({
    required String conversationId, required String recipientUserId,
    required String senderDeviceId, required List<MlsKeyPackage> keyPackages,
    required String messageId,
  }) async {
    GroupState state;
    final transaction = '$messageId:audience';
    try {
      state = await _crypto.groupState(conversationId);
    } catch (error) {
      if (!_needsDirectWelcome(error)) rethrow;
      await _crypto.withMessage(transaction, () => _crypto.createGroup(conversationId));
      state = await _crypto.groupState(conversationId);
    }
    if (state.memberIdentities.length == 1 && state.memberIdentities.single == '$_ownerUserId:$senderDeviceId') {
      if (keyPackages.isEmpty || keyPackages.any((p) => p.userId != recipientUserId || !p.lastResort)) {
        throw StateError('附件首次私聊KeyPackage无效');
      }
      await _crypto.withMessage(transaction, () => _crypto.addMembers(conversationId,keyPackages));
      state = await _crypto.groupState(conversationId);
    }
    final queued = <EncryptedMessage>[];
    for (final record in await _crypto.pendingMessageResults(transaction)) {
      final saved = (record['result'] as Map).cast<String,dynamic>();
      if (saved['welcome_wire_hex'] is! String) continue;
      final now = saved['created_at_millis'] as int;
      final hex = saved['welcome_wire_hex'] as String;
      final welcome = MlsWireMessage(
        conversationId:conversationId, messageKind:MlsMessageKind.welcome,
        wireBytes:[for(var i=0;i<hex.length;i+=2)int.parse(hex.substring(i,i+2),radix:16)],
      );
      for (final value in (saved['welcome_member_identities'] as List).cast<String>()) {
        final member = MlsMemberIdentity.parse(value);
        final message = welcome.toEncryptedMessage(
          messageId:_newMessageId('$transaction:${member.wireValue}',now,0),senderUserId:_ownerUserId,
          senderDeviceId:senderDeviceId,recipientUserId:member.userId,
          recipientDeviceId:member.deviceId,createdAtMillis:now,
        );
        await _store.queueOutgoingMessage(
          bindingToken:_bindingToken,ownerUserId:_ownerUserId,message:message,
          messageBytes:message.writeToBuffer(),recipientUserId:member.userId,
          deliveryState:ChatMessageDeliveryState.queued,
        );
        queued.add(message);
      }
    }
    await _crypto.acknowledgeMessage(transaction);
    if (queued.isNotEmpty) {
      final scheduler = deliveryScheduler;
      Future<void> deliver() async {
        for(final message in queued) {
          final result = await _deliverer(message,message.writeToBuffer(),message.recipientUserId,message.recipientDeviceId);
          await _store.markOutgoingDelivery(bindingToken:_bindingToken,ownerUserId:_ownerUserId,messageId:message.messageId,state:result.state,errorMessage:result.errorMessage);
        }
      }
      if(scheduler!=null) { scheduler(conversationId,deliver); } else { await deliver(); }
    }
    return state;
  }

  /// R2完成后发送唯一MLS附件描述；不携带应用密钥。
  Future<List<ChatDeliveryResult>> sendMediaControl({
    required String conversationId,
    required String senderUserId,
    required String recipientUserId,
    required String senderDeviceId,
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
    final outbound = await _crypto.withMessage(
      pendingLocalMessageId ?? '$conversationId:$now',
      () => _createMediaOutbound(
        conversationId: conversationId,
        media: media,
        senderDeviceId: senderDeviceId,
        plaintext: utf8.encode(payload),
        messageId: pendingLocalMessageId ?? '$conversationId:$now',
      ),
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
      // 附件控制按精确设备区分可靠队列键，防止同CID其他设备的条目被覆盖。
      final isMedia = const {
        ChatMessageKind.image, ChatMessageKind.video, ChatMessageKind.file, ChatMessageKind.audio,
      }.contains(messageKind);
      final seed = isMedia
          ? '${pendingLocalMessageId ?? conversationId}:${target.recipient.wireValue}'
          : pendingLocalMessageId ?? conversationId;
      final message = wireMessage.toEncryptedMessage(
        // 本地待发送行用稳定 ID 与语义序号做 seed；初始化或网络失败后重试
        // 仍得到同一 Message ID，Store/收端幂等去重。
        messageId: _newMessageId(
          seed,
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

    await _crypto.acknowledgeMessage(
      pendingLocalMessageId ?? '$conversationId:$nowMillis',
    );

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
      final inbound = await _crypto.withMessage(
        message.messageId,
        () => _crypto.groupProcess(wireMessage),
      );
      if (inbound.status == GroupProcessStatus.stale && inbound.committed) {
        return ChatIncomingProcessResult(
          messageId: message.messageId,
          accepted: true,
          queuedPending: false,
          acceptedMessages: <EncryptedMessage>[message],
        );
      }
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
        await _crypto.acknowledgeMessage(message.messageId);
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
        await _crypto.acknowledgeMessage(message.messageId);
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
      if (content.isMedia && (
          inbound.senderMemberIdentity != '${message.senderUserId}:${message.senderDeviceId}' ||
          content.attachmentSenderMemberIdentity != inbound.senderMemberIdentity)) {
        throw StateError('附件控制实际MLS发送者不一致');
      }
      await _store.saveIncomingMessage(
        bindingToken: _bindingToken,
        ownerUserId: _ownerUserId,
        currentAccountId: _currentAccountId,
        message: message,
        messageBytes: messageBytes,
        messageKind: content.kind,
        plaintext: plaintext,
      );
      await _crypto.acknowledgeMessage(message.messageId);
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
  /// 文件控制只使用已固定的聊天组，不能为附件补新人或重新创建会话。
  Future<List<_DirectWireTarget>> _createMediaOutbound({
    required String conversationId,required ChatContent media,
    required String senderDeviceId,required List<int> plaintext,required String messageId,
  }) async {
    final saved=await _crypto.pendingMessageResults(messageId);
    if(!saved.any((r)=>(r['result'] as Map)['application_wire_hex'] is String)) {
      final state=await _crypto.groupState(conversationId);
      if(state.epoch!=media.attachmentChatEpoch ||
          jsonEncode([...state.memberIdentities]..sort())!=jsonEncode(media.attachmentMemberIdentities)) {
        throw StateError('附件控制的聊天设备名册已失效');
      }
    }
    final wire=await _crypto.groupCreateMessage(conversationId,plaintext);
    return membersFromMemberIdentities(await _crypto.messageMemberIdentities(conversationId,messageId))
        .where((m)=>m.wireValue!='$_ownerUserId:$senderDeviceId')
        .map((m)=>_DirectWireTarget(wire:wire,recipient:m)).toList();
  }

  Future<List<_DirectWireTarget>> _createDirectOutbound({
    required String conversationId,
    required String recipientUserId,
    required String senderDeviceId,
    required List<MlsKeyPackage> recipientKeyPackages,
    required List<int> plaintext,
    required String messageId,
  }) async {
    final result = <_DirectWireTarget>[];
    // 崩溃后名册已前进时，仍恢复此前已提交的Welcome/Commit，不能只补Application。
    final persisted = await _crypto.pendingMessageResults(messageId);
    for (final entry in persisted) {
      final saved = (entry['result'] as Map).cast<String, dynamic>();
      if (saved['welcome_wire_hex'] is! String) continue;
      MlsWireMessage restoreWire(String field, MlsMessageKind kind) {
        final hex = saved[field] as String;
        return MlsWireMessage(
          conversationId: conversationId,
          messageKind: kind,
          wireBytes: [
            for (var i = 0; i < hex.length; i += 2)
              int.parse(hex.substring(i, i + 2), radix: 16),
          ],
        );
      }

      for (final identity
          in (saved['welcome_member_identities'] as List).cast<String>()) {
        result.add(
          _DirectWireTarget(
            wire: restoreWire('welcome_wire_hex', MlsMessageKind.welcome),
            recipient: MlsMemberIdentity.parse(identity),
          ),
        );
      }
      for (final identity
          in (saved['prior_member_identities'] as List).cast<String>()) {
        final member = MlsMemberIdentity.parse(identity);
        if (member.userId == _ownerUserId &&
            member.deviceId == senderDeviceId) {
          continue;
        }
        result.add(
          _DirectWireTarget(
            wire: restoreWire('commit_wire_hex', MlsMessageKind.commit),
            recipient: member,
          ),
        );
      }
    }
    // 发送已经提交后，只复核同一明文请求并使用原成员；不再取当前名册补新人。
    if (persisted.any(
      (entry) => (entry['result'] as Map)['application_wire_hex'] is String,
    )) {
      final application = await _crypto.groupCreateMessage(
        conversationId,
        plaintext,
      );
      for (final member in membersFromMemberIdentities(
        await _crypto.messageMemberIdentities(conversationId, messageId),
      )) {
        if (member.userId == _ownerUserId &&
            member.deviceId == senderDeviceId) {
          continue;
        }
        result.add(_DirectWireTarget(wire: application, recipient: member));
      }
      return result;
    }
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

    final application = await _crypto.groupCreateMessage(
      conversationId,
      plaintext,
    );
    final current = membersFromMemberIdentities(
      await _crypto.messageMemberIdentities(conversationId, messageId),
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
      plainDirectory: plainDirectory,
    );
    if (cached != null) return cached;
    throw StateError('附件尚未完成设备间传输');
  }

  /// 把一份本机文件导入 App 私有缓存(流式,零整块内存)。
  ///
  /// 接收文件经MLS及完整性核验后流式收入系统保护缓存；moveSource只删除准确临时源。
  /// 发送方保留用户源文件，两端共用唯一缓存路径。
  static Future<ChatDownloadedAttachment> importAttachmentFileToCache({
    required String conversationId,
    required String attachmentId,
    required String fileName,
    required String contentType,
    required String sourcePath,
    required int byteSize,
    required bool moveSource,
    required Directory cacheDirectory,
    required Directory plainDirectory,
  }) async {
    final cachePath = attachmentCachePath(
      cacheDirectory: cacheDirectory,
      conversationId: conversationId,
      attachmentId: attachmentId,
      fileName: fileName,
    );
    // 已核验的明文流式写入系统保护缓存，不存在应用钥或再次加解密。
    final source = File(sourcePath);
    if (await source.length() != byteSize) throw StateError('附件缓存大小不一致');
    final cached = await AttachmentVault.cache(source:source,cachePath:cachePath);
    if (moveSource && source.path != cached.path) await source.delete();
    return ChatDownloadedAttachment(
      attachmentId:attachmentId,fileName:fileName,contentType:contentType,
      clearByteSize:byteSize,filePath:cached.path,
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

  /// 系统保护缓存只读；明文长度不符明确失败，不重新推进MLS接收链。
  static Future<ChatDownloadedAttachment?> readCachedAttachment({
    required String conversationId,
    required String attachmentId,
    required String fileName,
    required String contentType,
    required int clearByteSize,
    required Directory cacheDirectory,
    required Directory plainDirectory,
  }) async {
    final cachePath = attachmentCachePath(
      cacheDirectory: cacheDirectory,
      conversationId: conversationId,
      attachmentId: attachmentId,
      fileName: fileName,
    );
    if (!plainDirectory.isAbsolute) throw StateError('附件目录必须是绝对路径');
    if (!await AttachmentVault.hasCache(cachePath)) return null;
    final plain = File(cachePath);
    final length = await plain.length();
    if (length != clearByteSize) throw StateError('附件缓存大小不一致');
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
