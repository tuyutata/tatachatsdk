// This is a generated file - do not edit.
//
// Generated from media_content.proto.

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

@$core.Deprecated('Use mediaDescriptorDescriptor instead')
const MediaDescriptor$json = {
  '1': 'MediaDescriptor',
  '2': [
    {'1': 'attachment_id', '3': 1, '4': 1, '5': 9, '10': 'attachmentId'},
    {'1': 'file_name', '3': 2, '4': 1, '5': 9, '10': 'fileName'},
    {'1': 'mime', '3': 3, '4': 1, '5': 9, '10': 'mime'},
    {'1': 'byte_size', '3': 4, '4': 1, '5': 4, '10': 'byteSize'},
    {'1': 'width', '3': 5, '4': 1, '5': 13, '10': 'width'},
    {'1': 'height', '3': 6, '4': 1, '5': 13, '10': 'height'},
    {'1': 'duration_ms', '3': 7, '4': 1, '5': 13, '10': 'durationMs'},
    {'1': 'blurhash', '3': 8, '4': 1, '5': 9, '10': 'blurhash'},
    {'1': 'cipher_byte_size', '3': 10, '4': 1, '5': 4, '10': 'cipherByteSize'},
    {'1': 'cipher_sha256', '3': 11, '4': 1, '5': 12, '10': 'cipherSha256'},
    {
      '1': 'attachment_group_id',
      '3': 12,
      '4': 1,
      '5': 9,
      '10': 'attachmentGroupId'
    },
    {
      '1': 'attachment_welcome',
      '3': 13,
      '4': 1,
      '5': 12,
      '10': 'attachmentWelcome'
    },
    {
      '1': 'attachment_member_identities',
      '3': 14,
      '4': 3,
      '5': 9,
      '10': 'attachmentMemberIdentities'
    },
    {
      '1': 'attachment_sender_member_identity',
      '3': 15,
      '4': 1,
      '5': 9,
      '10': 'attachmentSenderMemberIdentity'
    },
    {
      '1': 'attachment_chunk_count',
      '3': 16,
      '4': 1,
      '5': 13,
      '10': 'attachmentChunkCount'
    },
    {'1': 'plain_sha256', '3': 17, '4': 1, '5': 12, '10': 'plainSha256'},
    {
      '1': 'attachment_chat_epoch',
      '3': 18,
      '4': 1,
      '5': 4,
      '10': 'attachmentChatEpoch'
    },
  ],
  '9': [
    {'1': 9, '2': 10},
  ],
};

/// Descriptor for `MediaDescriptor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaDescriptorDescriptor = $convert.base64Decode(
    'Cg9NZWRpYURlc2NyaXB0b3ISIwoNYXR0YWNobWVudF9pZBgBIAEoCVIMYXR0YWNobWVudElkEh'
    'sKCWZpbGVfbmFtZRgCIAEoCVIIZmlsZU5hbWUSEgoEbWltZRgDIAEoCVIEbWltZRIbCglieXRl'
    'X3NpemUYBCABKARSCGJ5dGVTaXplEhQKBXdpZHRoGAUgASgNUgV3aWR0aBIWCgZoZWlnaHQYBi'
    'ABKA1SBmhlaWdodBIfCgtkdXJhdGlvbl9tcxgHIAEoDVIKZHVyYXRpb25NcxIaCghibHVyaGFz'
    'aBgIIAEoCVIIYmx1cmhhc2gSKAoQY2lwaGVyX2J5dGVfc2l6ZRgKIAEoBFIOY2lwaGVyQnl0ZV'
    'NpemUSIwoNY2lwaGVyX3NoYTI1NhgLIAEoDFIMY2lwaGVyU2hhMjU2Ei4KE2F0dGFjaG1lbnRf'
    'Z3JvdXBfaWQYDCABKAlSEWF0dGFjaG1lbnRHcm91cElkEi0KEmF0dGFjaG1lbnRfd2VsY29tZR'
    'gNIAEoDFIRYXR0YWNobWVudFdlbGNvbWUSQAocYXR0YWNobWVudF9tZW1iZXJfaWRlbnRpdGll'
    'cxgOIAMoCVIaYXR0YWNobWVudE1lbWJlcklkZW50aXRpZXMSSQohYXR0YWNobWVudF9zZW5kZX'
    'JfbWVtYmVyX2lkZW50aXR5GA8gASgJUh5hdHRhY2htZW50U2VuZGVyTWVtYmVySWRlbnRpdHkS'
    'NAoWYXR0YWNobWVudF9jaHVua19jb3VudBgQIAEoDVIUYXR0YWNobWVudENodW5rQ291bnQSIQ'
    'oMcGxhaW5fc2hhMjU2GBEgASgMUgtwbGFpblNoYTI1NhIyChVhdHRhY2htZW50X2NoYXRfZXBv'
    'Y2gYEiABKARSE2F0dGFjaG1lbnRDaGF0RXBvY2hKBAgJEAo=');

@$core.Deprecated('Use mediaPayloadDescriptor instead')
const MediaPayload$json = {
  '1': 'MediaPayload',
  '2': [
    {
      '1': 'image',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.MediaDescriptor',
      '9': 0,
      '10': 'image'
    },
    {
      '1': 'video',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.MediaDescriptor',
      '9': 0,
      '10': 'video'
    },
    {
      '1': 'file',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.MediaDescriptor',
      '9': 0,
      '10': 'file'
    },
    {
      '1': 'audio',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.MediaDescriptor',
      '9': 0,
      '10': 'audio'
    },
  ],
  '8': [
    {'1': 'content'},
  ],
};

/// Descriptor for `MediaPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaPayloadDescriptor = $convert.base64Decode(
    'CgxNZWRpYVBheWxvYWQSNgoFaW1hZ2UYECABKAsyHi5jaGF0LnByb3RvY29sLk1lZGlhRGVzY3'
    'JpcHRvckgAUgVpbWFnZRI2CgV2aWRlbxgRIAEoCzIeLmNoYXQucHJvdG9jb2wuTWVkaWFEZXNj'
    'cmlwdG9ySABSBXZpZGVvEjQKBGZpbGUYEiABKAsyHi5jaGF0LnByb3RvY29sLk1lZGlhRGVzY3'
    'JpcHRvckgAUgRmaWxlEjYKBWF1ZGlvGBMgASgLMh4uY2hhdC5wcm90b2NvbC5NZWRpYURlc2Ny'
    'aXB0b3JIAFIFYXVkaW9CCQoHY29udGVudA==');
