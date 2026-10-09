// This is a generated file - do not edit.
//
// Generated from basic_content.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use basicPayloadDescriptor instead')
const BasicPayload$json = {
  '1': 'BasicPayload',
  '2': [
    {
      '1': 'text',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.TextContent',
      '9': 0,
      '10': 'text'
    },
    {
      '1': 'emoji',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.EmojiContent',
      '9': 0,
      '10': 'emoji'
    },
    {
      '1': 'sticker',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.StickerContent',
      '9': 0,
      '10': 'sticker'
    },
  ],
  '8': [
    {'1': 'content'},
  ],
};

/// Descriptor for `BasicPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List basicPayloadDescriptor = $convert.base64Decode(
    'CgxCYXNpY1BheWxvYWQSMAoEdGV4dBgBIAEoCzIaLmNoYXQucHJvdG9jb2wuVGV4dENvbnRlbn'
    'RIAFIEdGV4dBIzCgVlbW9qaRgCIAEoCzIbLmNoYXQucHJvdG9jb2wuRW1vamlDb250ZW50SABS'
    'BWVtb2ppEjkKB3N0aWNrZXIYAyABKAsyHS5jaGF0LnByb3RvY29sLlN0aWNrZXJDb250ZW50SA'
    'BSB3N0aWNrZXJCCQoHY29udGVudA==');

@$core.Deprecated('Use textContentDescriptor instead')
const TextContent$json = {
  '1': 'TextContent',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `TextContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textContentDescriptor =
    $convert.base64Decode('CgtUZXh0Q29udGVudBIUCgV2YWx1ZRgBIAEoCVIFdmFsdWU=');

@$core.Deprecated('Use emojiContentDescriptor instead')
const EmojiContent$json = {
  '1': 'EmojiContent',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `EmojiContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emojiContentDescriptor =
    $convert.base64Decode('CgxFbW9qaUNvbnRlbnQSFAoFdmFsdWUYASABKAlSBXZhbHVl');

@$core.Deprecated('Use stickerContentDescriptor instead')
const StickerContent$json = {
  '1': 'StickerContent',
  '2': [
    {'1': 'pack_id', '3': 1, '4': 1, '5': 9, '10': 'packId'},
    {'1': 'sticker_id', '3': 2, '4': 1, '5': 9, '10': 'stickerId'},
  ],
};

/// Descriptor for `StickerContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stickerContentDescriptor = $convert.base64Decode(
    'Cg5TdGlja2VyQ29udGVudBIXCgdwYWNrX2lkGAEgASgJUgZwYWNrSWQSHQoKc3RpY2tlcl9pZB'
    'gCIAEoCVIJc3RpY2tlcklk');
