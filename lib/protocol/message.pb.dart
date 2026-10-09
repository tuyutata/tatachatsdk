// This is a generated file - do not edit.
//
// Generated from message.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// 一个接收设备的中性路由身份。
class Recipient extends $pb.GeneratedMessage {
  factory Recipient({
    $core.String? userId,
    $core.String? deviceId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (deviceId != null) result.deviceId = deviceId;
    return result;
  }

  Recipient._();

  factory Recipient.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Recipient.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Recipient',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'deviceId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Recipient clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Recipient copyWith(void Function(Recipient) updates) =>
      super.copyWith((message) => updates(message as Recipient)) as Recipient;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Recipient create() => Recipient._();
  @$core.override
  Recipient createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Recipient getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Recipient>(create);
  static Recipient? _defaultInstance;

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
}

/// OpenMLS 为一个接收设备产生的独立密文。
class EncryptedDelivery extends $pb.GeneratedMessage {
  factory EncryptedDelivery({
    Recipient? recipient,
    $core.List<$core.int>? openmlsCiphertext,
  }) {
    final result = create();
    if (recipient != null) result.recipient = recipient;
    if (openmlsCiphertext != null) result.openmlsCiphertext = openmlsCiphertext;
    return result;
  }

  EncryptedDelivery._();

  factory EncryptedDelivery.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EncryptedDelivery.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EncryptedDelivery',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOM<Recipient>(1, _omitFieldNames ? '' : 'recipient',
        subBuilder: Recipient.create)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'openmlsCiphertext', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EncryptedDelivery clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EncryptedDelivery copyWith(void Function(EncryptedDelivery) updates) =>
      super.copyWith((message) => updates(message as EncryptedDelivery))
          as EncryptedDelivery;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EncryptedDelivery create() => EncryptedDelivery._();
  @$core.override
  EncryptedDelivery createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EncryptedDelivery getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EncryptedDelivery>(create);
  static EncryptedDelivery? _defaultInstance;

  @$pb.TagNumber(1)
  Recipient get recipient => $_getN(0);
  @$pb.TagNumber(1)
  set recipient(Recipient value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRecipient() => $_has(0);
  @$pb.TagNumber(1)
  void clearRecipient() => $_clearField(1);
  @$pb.TagNumber(1)
  Recipient ensureRecipient() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.List<$core.int> get openmlsCiphertext => $_getN(1);
  @$pb.TagNumber(2)
  set openmlsCiphertext($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOpenmlsCiphertext() => $_has(1);
  @$pb.TagNumber(2)
  void clearOpenmlsCiphertext() => $_clearField(2);
}

/// 一条逻辑消息。message_id 是消息全链路唯一编号。
class EncryptedMessage extends $pb.GeneratedMessage {
  factory EncryptedMessage({
    $core.String? messageId,
    $core.String? conversationId,
    $core.String? senderUserId,
    $core.String? senderDeviceId,
    $core.Iterable<EncryptedDelivery>? deliveries,
    $fixnum.Int64? createdAtMillis,
  }) {
    final result = create();
    if (messageId != null) result.messageId = messageId;
    if (conversationId != null) result.conversationId = conversationId;
    if (senderUserId != null) result.senderUserId = senderUserId;
    if (senderDeviceId != null) result.senderDeviceId = senderDeviceId;
    if (deliveries != null) result.deliveries.addAll(deliveries);
    if (createdAtMillis != null) result.createdAtMillis = createdAtMillis;
    return result;
  }

  EncryptedMessage._();

  factory EncryptedMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EncryptedMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EncryptedMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'conversationId')
    ..aOS(3, _omitFieldNames ? '' : 'senderUserId')
    ..aOS(4, _omitFieldNames ? '' : 'senderDeviceId')
    ..pPM<EncryptedDelivery>(5, _omitFieldNames ? '' : 'deliveries',
        subBuilder: EncryptedDelivery.create)
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'createdAtMillis', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EncryptedMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EncryptedMessage copyWith(void Function(EncryptedMessage) updates) =>
      super.copyWith((message) => updates(message as EncryptedMessage))
          as EncryptedMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EncryptedMessage create() => EncryptedMessage._();
  @$core.override
  EncryptedMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EncryptedMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EncryptedMessage>(create);
  static EncryptedMessage? _defaultInstance;

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
  $core.String get senderUserId => $_getSZ(2);
  @$pb.TagNumber(3)
  set senderUserId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSenderUserId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSenderUserId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get senderDeviceId => $_getSZ(3);
  @$pb.TagNumber(4)
  set senderDeviceId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSenderDeviceId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSenderDeviceId() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<EncryptedDelivery> get deliveries => $_getList(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get createdAtMillis => $_getI64(5);
  @$pb.TagNumber(6)
  set createdAtMillis($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedAtMillis() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAtMillis() => $_clearField(6);
}

/// SDK 内部使用的设备路由快照。
class ChatRoute extends $pb.GeneratedMessage {
  factory ChatRoute({
    $core.String? peerUserId,
    $core.String? deviceId,
    $fixnum.Int64? createdAtMillis,
    $fixnum.Int64? expiresAtMillis,
  }) {
    final result = create();
    if (peerUserId != null) result.peerUserId = peerUserId;
    if (deviceId != null) result.deviceId = deviceId;
    if (createdAtMillis != null) result.createdAtMillis = createdAtMillis;
    if (expiresAtMillis != null) result.expiresAtMillis = expiresAtMillis;
    return result;
  }

  ChatRoute._();

  factory ChatRoute.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChatRoute.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatRoute',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerUserId')
    ..aOS(2, _omitFieldNames ? '' : 'deviceId')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'createdAtMillis', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'expiresAtMillis', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatRoute clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatRoute copyWith(void Function(ChatRoute) updates) =>
      super.copyWith((message) => updates(message as ChatRoute)) as ChatRoute;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatRoute create() => ChatRoute._();
  @$core.override
  ChatRoute createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChatRoute getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatRoute>(create);
  static ChatRoute? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerUserId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerUserId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get createdAtMillis => $_getI64(2);
  @$pb.TagNumber(3)
  set createdAtMillis($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCreatedAtMillis() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreatedAtMillis() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get expiresAtMillis => $_getI64(3);
  @$pb.TagNumber(4)
  set expiresAtMillis($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExpiresAtMillis() => $_has(3);
  @$pb.TagNumber(4)
  void clearExpiresAtMillis() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
