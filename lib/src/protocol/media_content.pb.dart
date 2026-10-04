// This is a generated file - do not edit.
//
// Generated from media_content.proto.

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

/// Encrypted attachment metadata carried inside the MLS mailbox.
class MediaDescriptor extends $pb.GeneratedMessage {
  factory MediaDescriptor({
    $core.String? attachmentId,
    $core.String? fileName,
    $core.String? mime,
    $fixnum.Int64? byteSize,
    $core.int? width,
    $core.int? height,
    $core.int? durationMs,
    $core.String? blurhash,
    $core.List<$core.int>? cipherKey,
    $fixnum.Int64? cipherByteSize,
    $core.List<$core.int>? cipherSha256,
  }) {
    final result = create();
    if (attachmentId != null) result.attachmentId = attachmentId;
    if (fileName != null) result.fileName = fileName;
    if (mime != null) result.mime = mime;
    if (byteSize != null) result.byteSize = byteSize;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (durationMs != null) result.durationMs = durationMs;
    if (blurhash != null) result.blurhash = blurhash;
    if (cipherKey != null) result.cipherKey = cipherKey;
    if (cipherByteSize != null) result.cipherByteSize = cipherByteSize;
    if (cipherSha256 != null) result.cipherSha256 = cipherSha256;
    return result;
  }

  MediaDescriptor._();

  factory MediaDescriptor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MediaDescriptor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaDescriptor',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'attachmentId')
    ..aOS(2, _omitFieldNames ? '' : 'fileName')
    ..aOS(3, _omitFieldNames ? '' : 'mime')
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'byteSize', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(5, _omitFieldNames ? '' : 'width', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'height', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'durationMs', fieldType: $pb.PbFieldType.OU3)
    ..aOS(8, _omitFieldNames ? '' : 'blurhash')
    ..a<$core.List<$core.int>>(
        9, _omitFieldNames ? '' : 'cipherKey', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(
        10, _omitFieldNames ? '' : 'cipherByteSize', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(
        11, _omitFieldNames ? '' : 'cipherSha256', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaDescriptor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaDescriptor copyWith(void Function(MediaDescriptor) updates) =>
      super.copyWith((message) => updates(message as MediaDescriptor))
          as MediaDescriptor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MediaDescriptor create() => MediaDescriptor._();
  @$core.override
  MediaDescriptor createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MediaDescriptor getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaDescriptor>(create);
  static MediaDescriptor? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get attachmentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set attachmentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAttachmentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttachmentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get fileName => $_getSZ(1);
  @$pb.TagNumber(2)
  set fileName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFileName() => $_has(1);
  @$pb.TagNumber(2)
  void clearFileName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get mime => $_getSZ(2);
  @$pb.TagNumber(3)
  set mime($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMime() => $_has(2);
  @$pb.TagNumber(3)
  void clearMime() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get byteSize => $_getI64(3);
  @$pb.TagNumber(4)
  set byteSize($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasByteSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearByteSize() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get width => $_getIZ(4);
  @$pb.TagNumber(5)
  set width($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWidth() => $_has(4);
  @$pb.TagNumber(5)
  void clearWidth() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get height => $_getIZ(5);
  @$pb.TagNumber(6)
  set height($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeight() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get durationMs => $_getIZ(6);
  @$pb.TagNumber(7)
  set durationMs($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDurationMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearDurationMs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get blurhash => $_getSZ(7);
  @$pb.TagNumber(8)
  set blurhash($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBlurhash() => $_has(7);
  @$pb.TagNumber(8)
  void clearBlurhash() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.List<$core.int> get cipherKey => $_getN(8);
  @$pb.TagNumber(9)
  set cipherKey($core.List<$core.int> value) => $_setBytes(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCipherKey() => $_has(8);
  @$pb.TagNumber(9)
  void clearCipherKey() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get cipherByteSize => $_getI64(9);
  @$pb.TagNumber(10)
  set cipherByteSize($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCipherByteSize() => $_has(9);
  @$pb.TagNumber(10)
  void clearCipherByteSize() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.List<$core.int> get cipherSha256 => $_getN(10);
  @$pb.TagNumber(11)
  set cipherSha256($core.List<$core.int> value) => $_setBytes(10, value);
  @$pb.TagNumber(11)
  $core.bool hasCipherSha256() => $_has(10);
  @$pb.TagNumber(11)
  void clearCipherSha256() => $_clearField(11);
}

enum MediaPayload_Content { image, video, file, audio, notSet }

/// Fields 16-19 do not overlap BasicPayload fields 1-3. Receivers can reject
/// the wrong payload family without a parallel version or discriminator field.
class MediaPayload extends $pb.GeneratedMessage {
  factory MediaPayload({
    MediaDescriptor? image,
    MediaDescriptor? video,
    MediaDescriptor? file,
    MediaDescriptor? audio,
  }) {
    final result = create();
    if (image != null) result.image = image;
    if (video != null) result.video = video;
    if (file != null) result.file = file;
    if (audio != null) result.audio = audio;
    return result;
  }

  MediaPayload._();

  factory MediaPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MediaPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, MediaPayload_Content>
      _MediaPayload_ContentByTag = {
    16: MediaPayload_Content.image,
    17: MediaPayload_Content.video,
    18: MediaPayload_Content.file,
    19: MediaPayload_Content.audio,
    0: MediaPayload_Content.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..oo(0, [16, 17, 18, 19])
    ..aOM<MediaDescriptor>(16, _omitFieldNames ? '' : 'image',
        subBuilder: MediaDescriptor.create)
    ..aOM<MediaDescriptor>(17, _omitFieldNames ? '' : 'video',
        subBuilder: MediaDescriptor.create)
    ..aOM<MediaDescriptor>(18, _omitFieldNames ? '' : 'file',
        subBuilder: MediaDescriptor.create)
    ..aOM<MediaDescriptor>(19, _omitFieldNames ? '' : 'audio',
        subBuilder: MediaDescriptor.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaPayload copyWith(void Function(MediaPayload) updates) =>
      super.copyWith((message) => updates(message as MediaPayload))
          as MediaPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MediaPayload create() => MediaPayload._();
  @$core.override
  MediaPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MediaPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaPayload>(create);
  static MediaPayload? _defaultInstance;

  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  MediaPayload_Content whichContent() =>
      _MediaPayload_ContentByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  void clearContent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(16)
  MediaDescriptor get image => $_getN(0);
  @$pb.TagNumber(16)
  set image(MediaDescriptor value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasImage() => $_has(0);
  @$pb.TagNumber(16)
  void clearImage() => $_clearField(16);
  @$pb.TagNumber(16)
  MediaDescriptor ensureImage() => $_ensure(0);

  @$pb.TagNumber(17)
  MediaDescriptor get video => $_getN(1);
  @$pb.TagNumber(17)
  set video(MediaDescriptor value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasVideo() => $_has(1);
  @$pb.TagNumber(17)
  void clearVideo() => $_clearField(17);
  @$pb.TagNumber(17)
  MediaDescriptor ensureVideo() => $_ensure(1);

  @$pb.TagNumber(18)
  MediaDescriptor get file => $_getN(2);
  @$pb.TagNumber(18)
  set file(MediaDescriptor value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasFile() => $_has(2);
  @$pb.TagNumber(18)
  void clearFile() => $_clearField(18);
  @$pb.TagNumber(18)
  MediaDescriptor ensureFile() => $_ensure(2);

  @$pb.TagNumber(19)
  MediaDescriptor get audio => $_getN(3);
  @$pb.TagNumber(19)
  set audio(MediaDescriptor value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasAudio() => $_has(3);
  @$pb.TagNumber(19)
  void clearAudio() => $_clearField(19);
  @$pb.TagNumber(19)
  MediaDescriptor ensureAudio() => $_ensure(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
