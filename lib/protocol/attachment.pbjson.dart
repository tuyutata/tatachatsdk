// This is a generated file - do not edit.
//
// Generated from attachment.proto.

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

@$core.Deprecated('Use attachmentChunkDescriptor instead')
const AttachmentChunk$json = {
  '1': 'AttachmentChunk',
  '2': [
    {'1': 'chunk_index', '3': 1, '4': 1, '5': 13, '10': 'chunkIndex'},
    {'1': 'cipher_byte_size', '3': 2, '4': 1, '5': 4, '10': 'cipherByteSize'},
    {'1': 'cipher_sha256', '3': 3, '4': 1, '5': 9, '10': 'cipherSha256'},
  ],
};

/// Descriptor for `AttachmentChunk`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attachmentChunkDescriptor = $convert.base64Decode(
    'Cg9BdHRhY2htZW50Q2h1bmsSHwoLY2h1bmtfaW5kZXgYASABKA1SCmNodW5rSW5kZXgSKAoQY2'
    'lwaGVyX2J5dGVfc2l6ZRgCIAEoBFIOY2lwaGVyQnl0ZVNpemUSIwoNY2lwaGVyX3NoYTI1NhgD'
    'IAEoCVIMY2lwaGVyU2hhMjU2');

@$core.Deprecated('Use attachmentMetadataDescriptor instead')
const AttachmentMetadata$json = {
  '1': 'AttachmentMetadata',
  '2': [
    {'1': 'attachment_id', '3': 1, '4': 1, '5': 9, '10': 'attachmentId'},
    {'1': 'sender_user_id', '3': 2, '4': 1, '5': 9, '10': 'senderUserId'},
    {
      '1': 'recipient_user_ids',
      '3': 3,
      '4': 3,
      '5': 9,
      '10': 'recipientUserIds'
    },
    {
      '1': 'chunks',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.chat.protocol.AttachmentChunk',
      '10': 'chunks'
    },
    {'1': 'cipher_byte_size', '3': 5, '4': 1, '5': 4, '10': 'cipherByteSize'},
    {'1': 'cipher_sha256', '3': 6, '4': 1, '5': 9, '10': 'cipherSha256'},
    {'1': 'created_at_millis', '3': 7, '4': 1, '5': 4, '10': 'createdAtMillis'},
  ],
};

/// Descriptor for `AttachmentMetadata`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attachmentMetadataDescriptor = $convert.base64Decode(
    'ChJBdHRhY2htZW50TWV0YWRhdGESIwoNYXR0YWNobWVudF9pZBgBIAEoCVIMYXR0YWNobWVudE'
    'lkEiQKDnNlbmRlcl91c2VyX2lkGAIgASgJUgxzZW5kZXJVc2VySWQSLAoScmVjaXBpZW50X3Vz'
    'ZXJfaWRzGAMgAygJUhByZWNpcGllbnRVc2VySWRzEjYKBmNodW5rcxgEIAMoCzIeLmNoYXQucH'
    'JvdG9jb2wuQXR0YWNobWVudENodW5rUgZjaHVua3MSKAoQY2lwaGVyX2J5dGVfc2l6ZRgFIAEo'
    'BFIOY2lwaGVyQnl0ZVNpemUSIwoNY2lwaGVyX3NoYTI1NhgGIAEoCVIMY2lwaGVyU2hhMjU2Ei'
    'oKEWNyZWF0ZWRfYXRfbWlsbGlzGAcgASgEUg9jcmVhdGVkQXRNaWxsaXM=');
