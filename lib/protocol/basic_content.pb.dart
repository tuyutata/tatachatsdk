// This is a generated file - do not edit.
//
// Generated from basic_content.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

enum BasicPayload_Content { text, emoji, sticker, notSet }

/// 第一类聊天内容的唯一 wire 真源。协议依靠 protobuf 字段号演进，不增加
/// 自定义版本字段；未知字段和未知内容类型由 TataChatSDK 失败关闭。
class BasicPayload extends $pb.GeneratedMessage {
  factory BasicPayload({
    TextContent? text,
    EmojiContent? emoji,
    StickerContent? sticker,
  }) {
    final result = create();
    if (text != null) result.text = text;
    if (emoji != null) result.emoji = emoji;
    if (sticker != null) result.sticker = sticker;
    return result;
  }

  BasicPayload._();

  factory BasicPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BasicPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, BasicPayload_Content>
      _BasicPayload_ContentByTag = {
    1: BasicPayload_Content.text,
    2: BasicPayload_Content.emoji,
    3: BasicPayload_Content.sticker,
    0: BasicPayload_Content.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BasicPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3])
    ..aOM<TextContent>(1, _omitFieldNames ? '' : 'text',
        subBuilder: TextContent.create)
    ..aOM<EmojiContent>(2, _omitFieldNames ? '' : 'emoji',
        subBuilder: EmojiContent.create)
    ..aOM<StickerContent>(3, _omitFieldNames ? '' : 'sticker',
        subBuilder: StickerContent.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BasicPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BasicPayload copyWith(void Function(BasicPayload) updates) =>
      super.copyWith((message) => updates(message as BasicPayload))
          as BasicPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BasicPayload create() => BasicPayload._();
  @$core.override
  BasicPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BasicPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BasicPayload>(create);
  static BasicPayload? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  BasicPayload_Content whichContent() =>
      _BasicPayload_ContentByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearContent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  TextContent get text => $_getN(0);
  @$pb.TagNumber(1)
  set text(TextContent value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);
  @$pb.TagNumber(1)
  TextContent ensureText() => $_ensure(0);

  @$pb.TagNumber(2)
  EmojiContent get emoji => $_getN(1);
  @$pb.TagNumber(2)
  set emoji(EmojiContent value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasEmoji() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmoji() => $_clearField(2);
  @$pb.TagNumber(2)
  EmojiContent ensureEmoji() => $_ensure(1);

  @$pb.TagNumber(3)
  StickerContent get sticker => $_getN(2);
  @$pb.TagNumber(3)
  set sticker(StickerContent value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSticker() => $_has(2);
  @$pb.TagNumber(3)
  void clearSticker() => $_clearField(3);
  @$pb.TagNumber(3)
  StickerContent ensureSticker() => $_ensure(2);
}

class TextContent extends $pb.GeneratedMessage {
  factory TextContent({
    $core.String? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  TextContent._();

  factory TextContent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TextContent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TextContent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextContent copyWith(void Function(TextContent) updates) =>
      super.copyWith((message) => updates(message as TextContent))
          as TextContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TextContent create() => TextContent._();
  @$core.override
  TextContent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TextContent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TextContent>(create);
  static TextContent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class EmojiContent extends $pb.GeneratedMessage {
  factory EmojiContent({
    $core.String? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  EmojiContent._();

  factory EmojiContent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EmojiContent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EmojiContent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EmojiContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EmojiContent copyWith(void Function(EmojiContent) updates) =>
      super.copyWith((message) => updates(message as EmojiContent))
          as EmojiContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EmojiContent create() => EmojiContent._();
  @$core.override
  EmojiContent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EmojiContent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EmojiContent>(create);
  static EmojiContent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class StickerContent extends $pb.GeneratedMessage {
  factory StickerContent({
    $core.String? packId,
    $core.String? stickerId,
  }) {
    final result = create();
    if (packId != null) result.packId = packId;
    if (stickerId != null) result.stickerId = stickerId;
    return result;
  }

  StickerContent._();

  factory StickerContent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StickerContent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StickerContent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'chat.protocol'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'packId')
    ..aOS(2, _omitFieldNames ? '' : 'stickerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StickerContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StickerContent copyWith(void Function(StickerContent) updates) =>
      super.copyWith((message) => updates(message as StickerContent))
          as StickerContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StickerContent create() => StickerContent._();
  @$core.override
  StickerContent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StickerContent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StickerContent>(create);
  static StickerContent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get packId => $_getSZ(0);
  @$pb.TagNumber(1)
  set packId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPackId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPackId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get stickerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set stickerId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStickerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearStickerId() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
