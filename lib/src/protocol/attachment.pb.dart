// This is a generated file - do not edit.
//
// Generated from attachment.proto.

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

/// 一块端到端加密附件的密文字节摘要。
class AttachmentChunk extends $pb.GeneratedMessage {
  factory AttachmentChunk({
    $core.int? chunkIndex,
    $fixnum.Int64? cipherByteSize,
    $core.String? cipherSha256,
  }) {
    final result = create();
    if (chunkIndex != null) result.chunkIndex = chunkIndex;
    if (cipherByteSize != null) result.cipherByteSize = cipherByteSize;
    if (cipherSha256 != null) result.cipherSha256 = cipherSha256;
    return result;
  }

  AttachmentChunk._();

  factory AttachmentChunk.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AttachmentChunk.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AttachmentChunk',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'chunkIndex', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'cipherByteSize', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(3, _omitFieldNames ? '' : 'cipherSha256')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachmentChunk clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachmentChunk copyWith(void Function(AttachmentChunk) updates) =>
      super.copyWith((message) => updates(message as AttachmentChunk))
          as AttachmentChunk;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AttachmentChunk create() => AttachmentChunk._();
  @$core.override
  AttachmentChunk createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AttachmentChunk getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AttachmentChunk>(create);
  static AttachmentChunk? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get chunkIndex => $_getIZ(0);
  @$pb.TagNumber(1)
  set chunkIndex($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChunkIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearChunkIndex() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get cipherByteSize => $_getI64(1);
  @$pb.TagNumber(2)
  set cipherByteSize($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCipherByteSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearCipherByteSize() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get cipherSha256 => $_getSZ(2);
  @$pb.TagNumber(3)
  set cipherSha256($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCipherSha256() => $_has(2);
  @$pb.TagNumber(3)
  void clearCipherSha256() => $_clearField(3);
}

/// 附件控制面元数据。服务端永远拿不到内容密钥和明文字节。
class AttachmentMetadata extends $pb.GeneratedMessage {
  factory AttachmentMetadata({
    $core.String? attachmentId,
    $core.String? senderUserId,
    $core.Iterable<$core.String>? recipientUserIds,
    $core.Iterable<AttachmentChunk>? chunks,
    $fixnum.Int64? cipherByteSize,
    $core.String? cipherSha256,
    $fixnum.Int64? createdAtMillis,
  }) {
    final result = create();
    if (attachmentId != null) result.attachmentId = attachmentId;
    if (senderUserId != null) result.senderUserId = senderUserId;
    if (recipientUserIds != null)
      result.recipientUserIds.addAll(recipientUserIds);
    if (chunks != null) result.chunks.addAll(chunks);
    if (cipherByteSize != null) result.cipherByteSize = cipherByteSize;
    if (cipherSha256 != null) result.cipherSha256 = cipherSha256;
    if (createdAtMillis != null) result.createdAtMillis = createdAtMillis;
    return result;
  }

  AttachmentMetadata._();

  factory AttachmentMetadata.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AttachmentMetadata.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AttachmentMetadata',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'attachmentId')
    ..aOS(2, _omitFieldNames ? '' : 'senderUserId')
    ..pPS(3, _omitFieldNames ? '' : 'recipientUserIds')
    ..pPM<AttachmentChunk>(4, _omitFieldNames ? '' : 'chunks',
        subBuilder: AttachmentChunk.create)
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'cipherByteSize', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(6, _omitFieldNames ? '' : 'cipherSha256')
    ..a<$fixnum.Int64>(
        7, _omitFieldNames ? '' : 'createdAtMillis', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachmentMetadata clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachmentMetadata copyWith(void Function(AttachmentMetadata) updates) =>
      super.copyWith((message) => updates(message as AttachmentMetadata))
          as AttachmentMetadata;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AttachmentMetadata create() => AttachmentMetadata._();
  @$core.override
  AttachmentMetadata createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AttachmentMetadata getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AttachmentMetadata>(create);
  static AttachmentMetadata? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get attachmentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set attachmentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAttachmentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttachmentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get senderUserId => $_getSZ(1);
  @$pb.TagNumber(2)
  set senderUserId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSenderUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSenderUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get recipientUserIds => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<AttachmentChunk> get chunks => $_getList(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get cipherByteSize => $_getI64(4);
  @$pb.TagNumber(5)
  set cipherByteSize($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCipherByteSize() => $_has(4);
  @$pb.TagNumber(5)
  void clearCipherByteSize() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get cipherSha256 => $_getSZ(5);
  @$pb.TagNumber(6)
  set cipherSha256($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCipherSha256() => $_has(5);
  @$pb.TagNumber(6)
  void clearCipherSha256() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get createdAtMillis => $_getI64(6);
  @$pb.TagNumber(7)
  set createdAtMillis($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCreatedAtMillis() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreatedAtMillis() => $_clearField(7);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
