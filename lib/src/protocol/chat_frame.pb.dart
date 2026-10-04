// This is a generated file - do not edit.
//
// Generated from chat_frame.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'attachment.pb.dart' as $1;
import 'message.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

enum ChatFrame_Body {
  ready,
  failure,
  success,
  ping,
  pong,
  publishKeyPackage,
  resolveKeyPackages,
  keyPackageBatch,
  sendMessage,
  syncMessages,
  messageBatch,
  acknowledgeMessages,
  messageAvailable,
  beginAttachment,
  completeAttachment,
  attachmentReady,
  acknowledgeAttachment,
  abortAttachment,
  registerPush,
  removePush,
  notSet
}

/// WSS 唯一顶层二进制帧。业务相关性只使用消息、附件或密钥包自身编号。
class ChatFrame extends $pb.GeneratedMessage {
  factory ChatFrame({
    Ready? ready,
    Failure? failure,
    Success? success,
    Ping? ping,
    Pong? pong,
    PublishKeyPackage? publishKeyPackage,
    ResolveKeyPackages? resolveKeyPackages,
    KeyPackageBatch? keyPackageBatch,
    SendMessage? sendMessage,
    SyncMessages? syncMessages,
    MessageBatch? messageBatch,
    AcknowledgeMessages? acknowledgeMessages,
    MessageAvailable? messageAvailable,
    BeginAttachment? beginAttachment,
    CompleteAttachment? completeAttachment,
    AttachmentReady? attachmentReady,
    AcknowledgeAttachment? acknowledgeAttachment,
    AbortAttachment? abortAttachment,
    RegisterPush? registerPush,
    RemovePush? removePush,
  }) {
    final result = create();
    if (ready != null) result.ready = ready;
    if (failure != null) result.failure = failure;
    if (success != null) result.success = success;
    if (ping != null) result.ping = ping;
    if (pong != null) result.pong = pong;
    if (publishKeyPackage != null) result.publishKeyPackage = publishKeyPackage;
    if (resolveKeyPackages != null)
      result.resolveKeyPackages = resolveKeyPackages;
    if (keyPackageBatch != null) result.keyPackageBatch = keyPackageBatch;
    if (sendMessage != null) result.sendMessage = sendMessage;
    if (syncMessages != null) result.syncMessages = syncMessages;
    if (messageBatch != null) result.messageBatch = messageBatch;
    if (acknowledgeMessages != null)
      result.acknowledgeMessages = acknowledgeMessages;
    if (messageAvailable != null) result.messageAvailable = messageAvailable;
    if (beginAttachment != null) result.beginAttachment = beginAttachment;
    if (completeAttachment != null)
      result.completeAttachment = completeAttachment;
    if (attachmentReady != null) result.attachmentReady = attachmentReady;
    if (acknowledgeAttachment != null)
      result.acknowledgeAttachment = acknowledgeAttachment;
    if (abortAttachment != null) result.abortAttachment = abortAttachment;
    if (registerPush != null) result.registerPush = registerPush;
    if (removePush != null) result.removePush = removePush;
    return result;
  }

  ChatFrame._();

  factory ChatFrame.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChatFrame.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ChatFrame_Body> _ChatFrame_BodyByTag = {
    1: ChatFrame_Body.ready,
    2: ChatFrame_Body.failure,
    3: ChatFrame_Body.success,
    4: ChatFrame_Body.ping,
    5: ChatFrame_Body.pong,
    10: ChatFrame_Body.publishKeyPackage,
    11: ChatFrame_Body.resolveKeyPackages,
    12: ChatFrame_Body.keyPackageBatch,
    20: ChatFrame_Body.sendMessage,
    21: ChatFrame_Body.syncMessages,
    22: ChatFrame_Body.messageBatch,
    23: ChatFrame_Body.acknowledgeMessages,
    24: ChatFrame_Body.messageAvailable,
    30: ChatFrame_Body.beginAttachment,
    31: ChatFrame_Body.completeAttachment,
    32: ChatFrame_Body.attachmentReady,
    33: ChatFrame_Body.acknowledgeAttachment,
    34: ChatFrame_Body.abortAttachment,
    40: ChatFrame_Body.registerPush,
    41: ChatFrame_Body.removePush,
    0: ChatFrame_Body.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatFrame',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..oo(0, [
      1,
      2,
      3,
      4,
      5,
      10,
      11,
      12,
      20,
      21,
      22,
      23,
      24,
      30,
      31,
      32,
      33,
      34,
      40,
      41
    ])
    ..aOM<Ready>(1, _omitFieldNames ? '' : 'ready', subBuilder: Ready.create)
    ..aOM<Failure>(2, _omitFieldNames ? '' : 'failure',
        subBuilder: Failure.create)
    ..aOM<Success>(3, _omitFieldNames ? '' : 'success',
        subBuilder: Success.create)
    ..aOM<Ping>(4, _omitFieldNames ? '' : 'ping', subBuilder: Ping.create)
    ..aOM<Pong>(5, _omitFieldNames ? '' : 'pong', subBuilder: Pong.create)
    ..aOM<PublishKeyPackage>(10, _omitFieldNames ? '' : 'publishKeyPackage',
        subBuilder: PublishKeyPackage.create)
    ..aOM<ResolveKeyPackages>(11, _omitFieldNames ? '' : 'resolveKeyPackages',
        subBuilder: ResolveKeyPackages.create)
    ..aOM<KeyPackageBatch>(12, _omitFieldNames ? '' : 'keyPackageBatch',
        subBuilder: KeyPackageBatch.create)
    ..aOM<SendMessage>(20, _omitFieldNames ? '' : 'sendMessage',
        subBuilder: SendMessage.create)
    ..aOM<SyncMessages>(21, _omitFieldNames ? '' : 'syncMessages',
        subBuilder: SyncMessages.create)
    ..aOM<MessageBatch>(22, _omitFieldNames ? '' : 'messageBatch',
        subBuilder: MessageBatch.create)
    ..aOM<AcknowledgeMessages>(23, _omitFieldNames ? '' : 'acknowledgeMessages',
        subBuilder: AcknowledgeMessages.create)
    ..aOM<MessageAvailable>(24, _omitFieldNames ? '' : 'messageAvailable',
        subBuilder: MessageAvailable.create)
    ..aOM<BeginAttachment>(30, _omitFieldNames ? '' : 'beginAttachment',
        subBuilder: BeginAttachment.create)
    ..aOM<CompleteAttachment>(31, _omitFieldNames ? '' : 'completeAttachment',
        subBuilder: CompleteAttachment.create)
    ..aOM<AttachmentReady>(32, _omitFieldNames ? '' : 'attachmentReady',
        subBuilder: AttachmentReady.create)
    ..aOM<AcknowledgeAttachment>(
        33, _omitFieldNames ? '' : 'acknowledgeAttachment',
        subBuilder: AcknowledgeAttachment.create)
    ..aOM<AbortAttachment>(34, _omitFieldNames ? '' : 'abortAttachment',
        subBuilder: AbortAttachment.create)
    ..aOM<RegisterPush>(40, _omitFieldNames ? '' : 'registerPush',
        subBuilder: RegisterPush.create)
    ..aOM<RemovePush>(41, _omitFieldNames ? '' : 'removePush',
        subBuilder: RemovePush.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatFrame clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatFrame copyWith(void Function(ChatFrame) updates) =>
      super.copyWith((message) => updates(message as ChatFrame)) as ChatFrame;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatFrame create() => ChatFrame._();
  @$core.override
  ChatFrame createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChatFrame getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatFrame>(create);
  static ChatFrame? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(40)
  @$pb.TagNumber(41)
  ChatFrame_Body whichBody() => _ChatFrame_BodyByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(40)
  @$pb.TagNumber(41)
  void clearBody() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  Ready get ready => $_getN(0);
  @$pb.TagNumber(1)
  set ready(Ready value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasReady() => $_has(0);
  @$pb.TagNumber(1)
  void clearReady() => $_clearField(1);
  @$pb.TagNumber(1)
  Ready ensureReady() => $_ensure(0);

  @$pb.TagNumber(2)
  Failure get failure => $_getN(1);
  @$pb.TagNumber(2)
  set failure(Failure value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFailure() => $_has(1);
  @$pb.TagNumber(2)
  void clearFailure() => $_clearField(2);
  @$pb.TagNumber(2)
  Failure ensureFailure() => $_ensure(1);

  @$pb.TagNumber(3)
  Success get success => $_getN(2);
  @$pb.TagNumber(3)
  set success(Success value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSuccess() => $_has(2);
  @$pb.TagNumber(3)
  void clearSuccess() => $_clearField(3);
  @$pb.TagNumber(3)
  Success ensureSuccess() => $_ensure(2);

  @$pb.TagNumber(4)
  Ping get ping => $_getN(3);
  @$pb.TagNumber(4)
  set ping(Ping value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPing() => $_has(3);
  @$pb.TagNumber(4)
  void clearPing() => $_clearField(4);
  @$pb.TagNumber(4)
  Ping ensurePing() => $_ensure(3);

  @$pb.TagNumber(5)
  Pong get pong => $_getN(4);
  @$pb.TagNumber(5)
  set pong(Pong value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPong() => $_has(4);
  @$pb.TagNumber(5)
  void clearPong() => $_clearField(5);
  @$pb.TagNumber(5)
  Pong ensurePong() => $_ensure(4);

  @$pb.TagNumber(10)
  PublishKeyPackage get publishKeyPackage => $_getN(5);
  @$pb.TagNumber(10)
  set publishKeyPackage(PublishKeyPackage value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasPublishKeyPackage() => $_has(5);
  @$pb.TagNumber(10)
  void clearPublishKeyPackage() => $_clearField(10);
  @$pb.TagNumber(10)
  PublishKeyPackage ensurePublishKeyPackage() => $_ensure(5);

  @$pb.TagNumber(11)
  ResolveKeyPackages get resolveKeyPackages => $_getN(6);
  @$pb.TagNumber(11)
  set resolveKeyPackages(ResolveKeyPackages value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasResolveKeyPackages() => $_has(6);
  @$pb.TagNumber(11)
  void clearResolveKeyPackages() => $_clearField(11);
  @$pb.TagNumber(11)
  ResolveKeyPackages ensureResolveKeyPackages() => $_ensure(6);

  @$pb.TagNumber(12)
  KeyPackageBatch get keyPackageBatch => $_getN(7);
  @$pb.TagNumber(12)
  set keyPackageBatch(KeyPackageBatch value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasKeyPackageBatch() => $_has(7);
  @$pb.TagNumber(12)
  void clearKeyPackageBatch() => $_clearField(12);
  @$pb.TagNumber(12)
  KeyPackageBatch ensureKeyPackageBatch() => $_ensure(7);

  @$pb.TagNumber(20)
  SendMessage get sendMessage => $_getN(8);
  @$pb.TagNumber(20)
  set sendMessage(SendMessage value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasSendMessage() => $_has(8);
  @$pb.TagNumber(20)
  void clearSendMessage() => $_clearField(20);
  @$pb.TagNumber(20)
  SendMessage ensureSendMessage() => $_ensure(8);

  @$pb.TagNumber(21)
  SyncMessages get syncMessages => $_getN(9);
  @$pb.TagNumber(21)
  set syncMessages(SyncMessages value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasSyncMessages() => $_has(9);
  @$pb.TagNumber(21)
  void clearSyncMessages() => $_clearField(21);
  @$pb.TagNumber(21)
  SyncMessages ensureSyncMessages() => $_ensure(9);

  @$pb.TagNumber(22)
  MessageBatch get messageBatch => $_getN(10);
  @$pb.TagNumber(22)
  set messageBatch(MessageBatch value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasMessageBatch() => $_has(10);
  @$pb.TagNumber(22)
  void clearMessageBatch() => $_clearField(22);
  @$pb.TagNumber(22)
  MessageBatch ensureMessageBatch() => $_ensure(10);

  @$pb.TagNumber(23)
  AcknowledgeMessages get acknowledgeMessages => $_getN(11);
  @$pb.TagNumber(23)
  set acknowledgeMessages(AcknowledgeMessages value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasAcknowledgeMessages() => $_has(11);
  @$pb.TagNumber(23)
  void clearAcknowledgeMessages() => $_clearField(23);
  @$pb.TagNumber(23)
  AcknowledgeMessages ensureAcknowledgeMessages() => $_ensure(11);

  @$pb.TagNumber(24)
  MessageAvailable get messageAvailable => $_getN(12);
  @$pb.TagNumber(24)
  set messageAvailable(MessageAvailable value) => $_setField(24, value);
  @$pb.TagNumber(24)
  $core.bool hasMessageAvailable() => $_has(12);
  @$pb.TagNumber(24)
  void clearMessageAvailable() => $_clearField(24);
  @$pb.TagNumber(24)
  MessageAvailable ensureMessageAvailable() => $_ensure(12);

  @$pb.TagNumber(30)
  BeginAttachment get beginAttachment => $_getN(13);
  @$pb.TagNumber(30)
  set beginAttachment(BeginAttachment value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasBeginAttachment() => $_has(13);
  @$pb.TagNumber(30)
  void clearBeginAttachment() => $_clearField(30);
  @$pb.TagNumber(30)
  BeginAttachment ensureBeginAttachment() => $_ensure(13);

  @$pb.TagNumber(31)
  CompleteAttachment get completeAttachment => $_getN(14);
  @$pb.TagNumber(31)
  set completeAttachment(CompleteAttachment value) => $_setField(31, value);
  @$pb.TagNumber(31)
  $core.bool hasCompleteAttachment() => $_has(14);
  @$pb.TagNumber(31)
  void clearCompleteAttachment() => $_clearField(31);
  @$pb.TagNumber(31)
  CompleteAttachment ensureCompleteAttachment() => $_ensure(14);

  @$pb.TagNumber(32)
  AttachmentReady get attachmentReady => $_getN(15);
  @$pb.TagNumber(32)
  set attachmentReady(AttachmentReady value) => $_setField(32, value);
  @$pb.TagNumber(32)
  $core.bool hasAttachmentReady() => $_has(15);
  @$pb.TagNumber(32)
  void clearAttachmentReady() => $_clearField(32);
  @$pb.TagNumber(32)
  AttachmentReady ensureAttachmentReady() => $_ensure(15);

  @$pb.TagNumber(33)
  AcknowledgeAttachment get acknowledgeAttachment => $_getN(16);
  @$pb.TagNumber(33)
  set acknowledgeAttachment(AcknowledgeAttachment value) =>
      $_setField(33, value);
  @$pb.TagNumber(33)
  $core.bool hasAcknowledgeAttachment() => $_has(16);
  @$pb.TagNumber(33)
  void clearAcknowledgeAttachment() => $_clearField(33);
  @$pb.TagNumber(33)
  AcknowledgeAttachment ensureAcknowledgeAttachment() => $_ensure(16);

  @$pb.TagNumber(34)
  AbortAttachment get abortAttachment => $_getN(17);
  @$pb.TagNumber(34)
  set abortAttachment(AbortAttachment value) => $_setField(34, value);
  @$pb.TagNumber(34)
  $core.bool hasAbortAttachment() => $_has(17);
  @$pb.TagNumber(34)
  void clearAbortAttachment() => $_clearField(34);
  @$pb.TagNumber(34)
  AbortAttachment ensureAbortAttachment() => $_ensure(17);

  @$pb.TagNumber(40)
  RegisterPush get registerPush => $_getN(18);
  @$pb.TagNumber(40)
  set registerPush(RegisterPush value) => $_setField(40, value);
  @$pb.TagNumber(40)
  $core.bool hasRegisterPush() => $_has(18);
  @$pb.TagNumber(40)
  void clearRegisterPush() => $_clearField(40);
  @$pb.TagNumber(40)
  RegisterPush ensureRegisterPush() => $_ensure(18);

  @$pb.TagNumber(41)
  RemovePush get removePush => $_getN(19);
  @$pb.TagNumber(41)
  set removePush(RemovePush value) => $_setField(41, value);
  @$pb.TagNumber(41)
  $core.bool hasRemovePush() => $_has(19);
  @$pb.TagNumber(41)
  void clearRemovePush() => $_clearField(41);
  @$pb.TagNumber(41)
  RemovePush ensureRemovePush() => $_ensure(19);
}

class Ready extends $pb.GeneratedMessage {
  factory Ready({
    $fixnum.Int64? serverTimeMillis,
  }) {
    final result = create();
    if (serverTimeMillis != null) result.serverTimeMillis = serverTimeMillis;
    return result;
  }

  Ready._();

  factory Ready.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Ready.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ready',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'serverTimeMillis', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ready clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ready copyWith(void Function(Ready) updates) =>
      super.copyWith((message) => updates(message as Ready)) as Ready;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Ready create() => Ready._();
  @$core.override
  Ready createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Ready getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Ready>(create);
  static Ready? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get serverTimeMillis => $_getI64(0);
  @$pb.TagNumber(1)
  set serverTimeMillis($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServerTimeMillis() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerTimeMillis() => $_clearField(1);
}

class Failure extends $pb.GeneratedMessage {
  factory Failure({
    $core.String? code,
    $core.String? message,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (message != null) result.message = message;
    return result;
  }

  Failure._();

  factory Failure.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Failure.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Failure',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Failure clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Failure copyWith(void Function(Failure) updates) =>
      super.copyWith((message) => updates(message as Failure)) as Failure;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Failure create() => Failure._();
  @$core.override
  Failure createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Failure getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Failure>(create);
  static Failure? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class Success extends $pb.GeneratedMessage {
  factory Success({
    $core.String? kind,
    $core.Iterable<$core.String>? ids,
  }) {
    final result = create();
    if (kind != null) result.kind = kind;
    if (ids != null) result.ids.addAll(ids);
    return result;
  }

  Success._();

  factory Success.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Success.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Success',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'kind')
    ..pPS(2, _omitFieldNames ? '' : 'ids')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Success clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Success copyWith(void Function(Success) updates) =>
      super.copyWith((message) => updates(message as Success)) as Success;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Success create() => Success._();
  @$core.override
  Success createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Success getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Success>(create);
  static Success? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get kind => $_getSZ(0);
  @$pb.TagNumber(1)
  set kind($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get ids => $_getList(1);
}

class Ping extends $pb.GeneratedMessage {
  factory Ping({
    $fixnum.Int64? sentAtMillis,
  }) {
    final result = create();
    if (sentAtMillis != null) result.sentAtMillis = sentAtMillis;
    return result;
  }

  Ping._();

  factory Ping.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Ping.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ping',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'sentAtMillis', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ping clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ping copyWith(void Function(Ping) updates) =>
      super.copyWith((message) => updates(message as Ping)) as Ping;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Ping create() => Ping._();
  @$core.override
  Ping createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Ping getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Ping>(create);
  static Ping? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get sentAtMillis => $_getI64(0);
  @$pb.TagNumber(1)
  set sentAtMillis($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSentAtMillis() => $_has(0);
  @$pb.TagNumber(1)
  void clearSentAtMillis() => $_clearField(1);
}

class Pong extends $pb.GeneratedMessage {
  factory Pong({
    $fixnum.Int64? sentAtMillis,
    $fixnum.Int64? serverTimeMillis,
  }) {
    final result = create();
    if (sentAtMillis != null) result.sentAtMillis = sentAtMillis;
    if (serverTimeMillis != null) result.serverTimeMillis = serverTimeMillis;
    return result;
  }

  Pong._();

  factory Pong.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Pong.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Pong',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'sentAtMillis', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'serverTimeMillis', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Pong clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Pong copyWith(void Function(Pong) updates) =>
      super.copyWith((message) => updates(message as Pong)) as Pong;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Pong create() => Pong._();
  @$core.override
  Pong createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Pong getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Pong>(create);
  static Pong? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get sentAtMillis => $_getI64(0);
  @$pb.TagNumber(1)
  set sentAtMillis($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSentAtMillis() => $_has(0);
  @$pb.TagNumber(1)
  void clearSentAtMillis() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get serverTimeMillis => $_getI64(1);
  @$pb.TagNumber(2)
  set serverTimeMillis($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasServerTimeMillis() => $_has(1);
  @$pb.TagNumber(2)
  void clearServerTimeMillis() => $_clearField(2);
}

class KeyPackage extends $pb.GeneratedMessage {
  factory KeyPackage({
    $core.String? userId,
    $core.String? deviceId,
    $core.String? keyPackageRef,
    $core.List<$core.int>? keyPackage,
    $core.String? cipherSuite,
    $fixnum.Int64? notBefore,
    $fixnum.Int64? notAfter,
    $core.bool? lastResort,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (deviceId != null) result.deviceId = deviceId;
    if (keyPackageRef != null) result.keyPackageRef = keyPackageRef;
    if (keyPackage != null) result.keyPackage = keyPackage;
    if (cipherSuite != null) result.cipherSuite = cipherSuite;
    if (notBefore != null) result.notBefore = notBefore;
    if (notAfter != null) result.notAfter = notAfter;
    if (lastResort != null) result.lastResort = lastResort;
    return result;
  }

  KeyPackage._();

  factory KeyPackage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeyPackage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyPackage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'deviceId')
    ..aOS(3, _omitFieldNames ? '' : 'keyPackageRef')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'keyPackage', $pb.PbFieldType.OY)
    ..aOS(5, _omitFieldNames ? '' : 'cipherSuite')
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'notBefore', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        7, _omitFieldNames ? '' : 'notAfter', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(8, _omitFieldNames ? '' : 'lastResort')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyPackage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyPackage copyWith(void Function(KeyPackage) updates) =>
      super.copyWith((message) => updates(message as KeyPackage)) as KeyPackage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeyPackage create() => KeyPackage._();
  @$core.override
  KeyPackage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KeyPackage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KeyPackage>(create);
  static KeyPackage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get keyPackageRef => $_getSZ(2);
  @$pb.TagNumber(3)
  set keyPackageRef($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKeyPackageRef() => $_has(2);
  @$pb.TagNumber(3)
  void clearKeyPackageRef() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get keyPackage => $_getN(3);
  @$pb.TagNumber(4)
  set keyPackage($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasKeyPackage() => $_has(3);
  @$pb.TagNumber(4)
  void clearKeyPackage() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get cipherSuite => $_getSZ(4);
  @$pb.TagNumber(5)
  set cipherSuite($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCipherSuite() => $_has(4);
  @$pb.TagNumber(5)
  void clearCipherSuite() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get notBefore => $_getI64(5);
  @$pb.TagNumber(6)
  set notBefore($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNotBefore() => $_has(5);
  @$pb.TagNumber(6)
  void clearNotBefore() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get notAfter => $_getI64(6);
  @$pb.TagNumber(7)
  set notAfter($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNotAfter() => $_has(6);
  @$pb.TagNumber(7)
  void clearNotAfter() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get lastResort => $_getBF(7);
  @$pb.TagNumber(8)
  set lastResort($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLastResort() => $_has(7);
  @$pb.TagNumber(8)
  void clearLastResort() => $_clearField(8);
}

class PublishKeyPackage extends $pb.GeneratedMessage {
  factory PublishKeyPackage({
    KeyPackage? keyPackage,
  }) {
    final result = create();
    if (keyPackage != null) result.keyPackage = keyPackage;
    return result;
  }

  PublishKeyPackage._();

  factory PublishKeyPackage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PublishKeyPackage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PublishKeyPackage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOM<KeyPackage>(1, _omitFieldNames ? '' : 'keyPackage',
        subBuilder: KeyPackage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PublishKeyPackage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PublishKeyPackage copyWith(void Function(PublishKeyPackage) updates) =>
      super.copyWith((message) => updates(message as PublishKeyPackage))
          as PublishKeyPackage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PublishKeyPackage create() => PublishKeyPackage._();
  @$core.override
  PublishKeyPackage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PublishKeyPackage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PublishKeyPackage>(create);
  static PublishKeyPackage? _defaultInstance;

  @$pb.TagNumber(1)
  KeyPackage get keyPackage => $_getN(0);
  @$pb.TagNumber(1)
  set keyPackage(KeyPackage value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKeyPackage() => $_has(0);
  @$pb.TagNumber(1)
  void clearKeyPackage() => $_clearField(1);
  @$pb.TagNumber(1)
  KeyPackage ensureKeyPackage() => $_ensure(0);
}

class ResolveKeyPackages extends $pb.GeneratedMessage {
  factory ResolveKeyPackages({
    $core.String? userId,
    $core.String? deviceId,
    $core.int? limit,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (deviceId != null) result.deviceId = deviceId;
    if (limit != null) result.limit = limit;
    return result;
  }

  ResolveKeyPackages._();

  factory ResolveKeyPackages.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResolveKeyPackages.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveKeyPackages',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'deviceId')
    ..aI(3, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveKeyPackages clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveKeyPackages copyWith(void Function(ResolveKeyPackages) updates) =>
      super.copyWith((message) => updates(message as ResolveKeyPackages))
          as ResolveKeyPackages;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResolveKeyPackages create() => ResolveKeyPackages._();
  @$core.override
  ResolveKeyPackages createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResolveKeyPackages getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResolveKeyPackages>(create);
  static ResolveKeyPackages? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get limit => $_getIZ(2);
  @$pb.TagNumber(3)
  set limit($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);
}

class KeyPackageBatch extends $pb.GeneratedMessage {
  factory KeyPackageBatch({
    $core.Iterable<KeyPackage>? keyPackages,
  }) {
    final result = create();
    if (keyPackages != null) result.keyPackages.addAll(keyPackages);
    return result;
  }

  KeyPackageBatch._();

  factory KeyPackageBatch.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeyPackageBatch.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyPackageBatch',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..pPM<KeyPackage>(1, _omitFieldNames ? '' : 'keyPackages',
        subBuilder: KeyPackage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyPackageBatch clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyPackageBatch copyWith(void Function(KeyPackageBatch) updates) =>
      super.copyWith((message) => updates(message as KeyPackageBatch))
          as KeyPackageBatch;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeyPackageBatch create() => KeyPackageBatch._();
  @$core.override
  KeyPackageBatch createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KeyPackageBatch getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KeyPackageBatch>(create);
  static KeyPackageBatch? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<KeyPackage> get keyPackages => $_getList(0);
}

class SendMessage extends $pb.GeneratedMessage {
  factory SendMessage({
    $0.EncryptedMessage? message,
  }) {
    final result = create();
    if (message != null) result.message = message;
    return result;
  }

  SendMessage._();

  factory SendMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOM<$0.EncryptedMessage>(1, _omitFieldNames ? '' : 'message',
        subBuilder: $0.EncryptedMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMessage copyWith(void Function(SendMessage) updates) =>
      super.copyWith((message) => updates(message as SendMessage))
          as SendMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendMessage create() => SendMessage._();
  @$core.override
  SendMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendMessage>(create);
  static SendMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $0.EncryptedMessage get message => $_getN(0);
  @$pb.TagNumber(1)
  set message($0.EncryptedMessage value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.EncryptedMessage ensureMessage() => $_ensure(0);
}

class SyncMessages extends $pb.GeneratedMessage {
  factory SyncMessages({
    $core.int? limit,
  }) {
    final result = create();
    if (limit != null) result.limit = limit;
    return result;
  }

  SyncMessages._();

  factory SyncMessages.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncMessages.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncMessages',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncMessages clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncMessages copyWith(void Function(SyncMessages) updates) =>
      super.copyWith((message) => updates(message as SyncMessages))
          as SyncMessages;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncMessages create() => SyncMessages._();
  @$core.override
  SyncMessages createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncMessages getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncMessages>(create);
  static SyncMessages? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get limit => $_getIZ(0);
  @$pb.TagNumber(1)
  set limit($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLimit() => $_has(0);
  @$pb.TagNumber(1)
  void clearLimit() => $_clearField(1);
}

class MessageBatch extends $pb.GeneratedMessage {
  factory MessageBatch({
    $core.Iterable<$0.EncryptedMessage>? messages,
  }) {
    final result = create();
    if (messages != null) result.messages.addAll(messages);
    return result;
  }

  MessageBatch._();

  factory MessageBatch.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MessageBatch.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageBatch',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..pPM<$0.EncryptedMessage>(1, _omitFieldNames ? '' : 'messages',
        subBuilder: $0.EncryptedMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageBatch clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageBatch copyWith(void Function(MessageBatch) updates) =>
      super.copyWith((message) => updates(message as MessageBatch))
          as MessageBatch;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageBatch create() => MessageBatch._();
  @$core.override
  MessageBatch createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MessageBatch getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessageBatch>(create);
  static MessageBatch? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$0.EncryptedMessage> get messages => $_getList(0);
}

class AcknowledgeMessages extends $pb.GeneratedMessage {
  factory AcknowledgeMessages({
    $core.Iterable<$core.String>? messageIds,
  }) {
    final result = create();
    if (messageIds != null) result.messageIds.addAll(messageIds);
    return result;
  }

  AcknowledgeMessages._();

  factory AcknowledgeMessages.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AcknowledgeMessages.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AcknowledgeMessages',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'messageIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcknowledgeMessages clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcknowledgeMessages copyWith(void Function(AcknowledgeMessages) updates) =>
      super.copyWith((message) => updates(message as AcknowledgeMessages))
          as AcknowledgeMessages;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AcknowledgeMessages create() => AcknowledgeMessages._();
  @$core.override
  AcknowledgeMessages createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AcknowledgeMessages getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AcknowledgeMessages>(create);
  static AcknowledgeMessages? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get messageIds => $_getList(0);
}

class MessageAvailable extends $pb.GeneratedMessage {
  factory MessageAvailable({
    $core.String? messageId,
    $core.String? conversationId,
    $fixnum.Int64? serverTimeMillis,
  }) {
    final result = create();
    if (messageId != null) result.messageId = messageId;
    if (conversationId != null) result.conversationId = conversationId;
    if (serverTimeMillis != null) result.serverTimeMillis = serverTimeMillis;
    return result;
  }

  MessageAvailable._();

  factory MessageAvailable.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MessageAvailable.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageAvailable',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'conversationId')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'serverTimeMillis', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageAvailable clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageAvailable copyWith(void Function(MessageAvailable) updates) =>
      super.copyWith((message) => updates(message as MessageAvailable))
          as MessageAvailable;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageAvailable create() => MessageAvailable._();
  @$core.override
  MessageAvailable createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MessageAvailable getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessageAvailable>(create);
  static MessageAvailable? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get conversationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set conversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConversationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConversationId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get serverTimeMillis => $_getI64(2);
  @$pb.TagNumber(3)
  set serverTimeMillis($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasServerTimeMillis() => $_has(2);
  @$pb.TagNumber(3)
  void clearServerTimeMillis() => $_clearField(3);
}

class BeginAttachment extends $pb.GeneratedMessage {
  factory BeginAttachment({
    $1.AttachmentMetadata? attachment,
  }) {
    final result = create();
    if (attachment != null) result.attachment = attachment;
    return result;
  }

  BeginAttachment._();

  factory BeginAttachment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeginAttachment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeginAttachment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOM<$1.AttachmentMetadata>(1, _omitFieldNames ? '' : 'attachment',
        subBuilder: $1.AttachmentMetadata.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginAttachment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginAttachment copyWith(void Function(BeginAttachment) updates) =>
      super.copyWith((message) => updates(message as BeginAttachment))
          as BeginAttachment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeginAttachment create() => BeginAttachment._();
  @$core.override
  BeginAttachment createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeginAttachment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeginAttachment>(create);
  static BeginAttachment? _defaultInstance;

  @$pb.TagNumber(1)
  $1.AttachmentMetadata get attachment => $_getN(0);
  @$pb.TagNumber(1)
  set attachment($1.AttachmentMetadata value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAttachment() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttachment() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.AttachmentMetadata ensureAttachment() => $_ensure(0);
}

class CompleteAttachment extends $pb.GeneratedMessage {
  factory CompleteAttachment({
    $core.String? attachmentId,
  }) {
    final result = create();
    if (attachmentId != null) result.attachmentId = attachmentId;
    return result;
  }

  CompleteAttachment._();

  factory CompleteAttachment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompleteAttachment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompleteAttachment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'attachmentId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteAttachment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteAttachment copyWith(void Function(CompleteAttachment) updates) =>
      super.copyWith((message) => updates(message as CompleteAttachment))
          as CompleteAttachment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompleteAttachment create() => CompleteAttachment._();
  @$core.override
  CompleteAttachment createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompleteAttachment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompleteAttachment>(create);
  static CompleteAttachment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get attachmentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set attachmentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAttachmentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttachmentId() => $_clearField(1);
}

class AttachmentReady extends $pb.GeneratedMessage {
  factory AttachmentReady({
    $core.String? attachmentId,
  }) {
    final result = create();
    if (attachmentId != null) result.attachmentId = attachmentId;
    return result;
  }

  AttachmentReady._();

  factory AttachmentReady.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AttachmentReady.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AttachmentReady',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'attachmentId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachmentReady clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachmentReady copyWith(void Function(AttachmentReady) updates) =>
      super.copyWith((message) => updates(message as AttachmentReady))
          as AttachmentReady;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AttachmentReady create() => AttachmentReady._();
  @$core.override
  AttachmentReady createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AttachmentReady getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AttachmentReady>(create);
  static AttachmentReady? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get attachmentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set attachmentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAttachmentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttachmentId() => $_clearField(1);
}

class AcknowledgeAttachment extends $pb.GeneratedMessage {
  factory AcknowledgeAttachment({
    $core.String? attachmentId,
  }) {
    final result = create();
    if (attachmentId != null) result.attachmentId = attachmentId;
    return result;
  }

  AcknowledgeAttachment._();

  factory AcknowledgeAttachment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AcknowledgeAttachment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AcknowledgeAttachment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'attachmentId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcknowledgeAttachment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcknowledgeAttachment copyWith(
          void Function(AcknowledgeAttachment) updates) =>
      super.copyWith((message) => updates(message as AcknowledgeAttachment))
          as AcknowledgeAttachment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AcknowledgeAttachment create() => AcknowledgeAttachment._();
  @$core.override
  AcknowledgeAttachment createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AcknowledgeAttachment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AcknowledgeAttachment>(create);
  static AcknowledgeAttachment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get attachmentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set attachmentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAttachmentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttachmentId() => $_clearField(1);
}

class AbortAttachment extends $pb.GeneratedMessage {
  factory AbortAttachment({
    $core.String? attachmentId,
  }) {
    final result = create();
    if (attachmentId != null) result.attachmentId = attachmentId;
    return result;
  }

  AbortAttachment._();

  factory AbortAttachment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AbortAttachment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AbortAttachment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'attachmentId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AbortAttachment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AbortAttachment copyWith(void Function(AbortAttachment) updates) =>
      super.copyWith((message) => updates(message as AbortAttachment))
          as AbortAttachment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AbortAttachment create() => AbortAttachment._();
  @$core.override
  AbortAttachment createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AbortAttachment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AbortAttachment>(create);
  static AbortAttachment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get attachmentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set attachmentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAttachmentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttachmentId() => $_clearField(1);
}

class RegisterPush extends $pb.GeneratedMessage {
  factory RegisterPush({
    $core.String? platform,
    $core.String? token,
  }) {
    final result = create();
    if (platform != null) result.platform = platform;
    if (token != null) result.token = token;
    return result;
  }

  RegisterPush._();

  factory RegisterPush.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterPush.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterPush',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'platform')
    ..aOS(2, _omitFieldNames ? '' : 'token')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterPush clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterPush copyWith(void Function(RegisterPush) updates) =>
      super.copyWith((message) => updates(message as RegisterPush))
          as RegisterPush;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterPush create() => RegisterPush._();
  @$core.override
  RegisterPush createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterPush getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterPush>(create);
  static RegisterPush? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get platform => $_getSZ(0);
  @$pb.TagNumber(1)
  set platform($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlatform() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlatform() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get token => $_getSZ(1);
  @$pb.TagNumber(2)
  set token($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearToken() => $_clearField(2);
}

class RemovePush extends $pb.GeneratedMessage {
  factory RemovePush({
    $core.String? platform,
  }) {
    final result = create();
    if (platform != null) result.platform = platform;
    return result;
  }

  RemovePush._();

  factory RemovePush.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemovePush.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemovePush',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'platform')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemovePush clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemovePush copyWith(void Function(RemovePush) updates) =>
      super.copyWith((message) => updates(message as RemovePush)) as RemovePush;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemovePush create() => RemovePush._();
  @$core.override
  RemovePush createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemovePush getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemovePush>(create);
  static RemovePush? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get platform => $_getSZ(0);
  @$pb.TagNumber(1)
  set platform($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlatform() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlatform() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
