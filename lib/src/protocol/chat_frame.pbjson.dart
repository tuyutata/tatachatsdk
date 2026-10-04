// This is a generated file - do not edit.
//
// Generated from chat_frame.proto.

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

@$core.Deprecated('Use chatFrameDescriptor instead')
const ChatFrame$json = {
  '1': 'ChatFrame',
  '2': [
    {
      '1': 'ready',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.Ready',
      '9': 0,
      '10': 'ready'
    },
    {
      '1': 'failure',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.Failure',
      '9': 0,
      '10': 'failure'
    },
    {
      '1': 'success',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.Success',
      '9': 0,
      '10': 'success'
    },
    {
      '1': 'ping',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.Ping',
      '9': 0,
      '10': 'ping'
    },
    {
      '1': 'pong',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.Pong',
      '9': 0,
      '10': 'pong'
    },
    {
      '1': 'publish_key_package',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.PublishKeyPackage',
      '9': 0,
      '10': 'publishKeyPackage'
    },
    {
      '1': 'resolve_key_packages',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.ResolveKeyPackages',
      '9': 0,
      '10': 'resolveKeyPackages'
    },
    {
      '1': 'key_package_batch',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.KeyPackageBatch',
      '9': 0,
      '10': 'keyPackageBatch'
    },
    {
      '1': 'send_message',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.SendMessage',
      '9': 0,
      '10': 'sendMessage'
    },
    {
      '1': 'sync_messages',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.SyncMessages',
      '9': 0,
      '10': 'syncMessages'
    },
    {
      '1': 'message_batch',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.MessageBatch',
      '9': 0,
      '10': 'messageBatch'
    },
    {
      '1': 'acknowledge_messages',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.AcknowledgeMessages',
      '9': 0,
      '10': 'acknowledgeMessages'
    },
    {
      '1': 'message_available',
      '3': 24,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.MessageAvailable',
      '9': 0,
      '10': 'messageAvailable'
    },
    {
      '1': 'begin_attachment',
      '3': 30,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.BeginAttachment',
      '9': 0,
      '10': 'beginAttachment'
    },
    {
      '1': 'complete_attachment',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.CompleteAttachment',
      '9': 0,
      '10': 'completeAttachment'
    },
    {
      '1': 'attachment_ready',
      '3': 32,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.AttachmentReady',
      '9': 0,
      '10': 'attachmentReady'
    },
    {
      '1': 'acknowledge_attachment',
      '3': 33,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.AcknowledgeAttachment',
      '9': 0,
      '10': 'acknowledgeAttachment'
    },
    {
      '1': 'abort_attachment',
      '3': 34,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.AbortAttachment',
      '9': 0,
      '10': 'abortAttachment'
    },
    {
      '1': 'register_push',
      '3': 40,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.RegisterPush',
      '9': 0,
      '10': 'registerPush'
    },
    {
      '1': 'remove_push',
      '3': 41,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.RemovePush',
      '9': 0,
      '10': 'removePush'
    },
  ],
  '8': [
    {'1': 'body'},
  ],
};

/// Descriptor for `ChatFrame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatFrameDescriptor = $convert.base64Decode(
    'CglDaGF0RnJhbWUSLAoFcmVhZHkYASABKAsyFC5jaGF0LnByb3RvY29sLlJlYWR5SABSBXJlYW'
    'R5EjIKB2ZhaWx1cmUYAiABKAsyFi5jaGF0LnByb3RvY29sLkZhaWx1cmVIAFIHZmFpbHVyZRIy'
    'CgdzdWNjZXNzGAMgASgLMhYuY2hhdC5wcm90b2NvbC5TdWNjZXNzSABSB3N1Y2Nlc3MSKQoEcG'
    'luZxgEIAEoCzITLmNoYXQucHJvdG9jb2wuUGluZ0gAUgRwaW5nEikKBHBvbmcYBSABKAsyEy5j'
    'aGF0LnByb3RvY29sLlBvbmdIAFIEcG9uZxJSChNwdWJsaXNoX2tleV9wYWNrYWdlGAogASgLMi'
    'AuY2hhdC5wcm90b2NvbC5QdWJsaXNoS2V5UGFja2FnZUgAUhFwdWJsaXNoS2V5UGFja2FnZRJV'
    'ChRyZXNvbHZlX2tleV9wYWNrYWdlcxgLIAEoCzIhLmNoYXQucHJvdG9jb2wuUmVzb2x2ZUtleV'
    'BhY2thZ2VzSABSEnJlc29sdmVLZXlQYWNrYWdlcxJMChFrZXlfcGFja2FnZV9iYXRjaBgMIAEo'
    'CzIeLmNoYXQucHJvdG9jb2wuS2V5UGFja2FnZUJhdGNoSABSD2tleVBhY2thZ2VCYXRjaBI/Cg'
    'xzZW5kX21lc3NhZ2UYFCABKAsyGi5jaGF0LnByb3RvY29sLlNlbmRNZXNzYWdlSABSC3NlbmRN'
    'ZXNzYWdlEkIKDXN5bmNfbWVzc2FnZXMYFSABKAsyGy5jaGF0LnByb3RvY29sLlN5bmNNZXNzYW'
    'dlc0gAUgxzeW5jTWVzc2FnZXMSQgoNbWVzc2FnZV9iYXRjaBgWIAEoCzIbLmNoYXQucHJvdG9j'
    'b2wuTWVzc2FnZUJhdGNoSABSDG1lc3NhZ2VCYXRjaBJXChRhY2tub3dsZWRnZV9tZXNzYWdlcx'
    'gXIAEoCzIiLmNoYXQucHJvdG9jb2wuQWNrbm93bGVkZ2VNZXNzYWdlc0gAUhNhY2tub3dsZWRn'
    'ZU1lc3NhZ2VzEk4KEW1lc3NhZ2VfYXZhaWxhYmxlGBggASgLMh8uY2hhdC5wcm90b2NvbC5NZX'
    'NzYWdlQXZhaWxhYmxlSABSEG1lc3NhZ2VBdmFpbGFibGUSSwoQYmVnaW5fYXR0YWNobWVudBge'
    'IAEoCzIeLmNoYXQucHJvdG9jb2wuQmVnaW5BdHRhY2htZW50SABSD2JlZ2luQXR0YWNobWVudB'
    'JUChNjb21wbGV0ZV9hdHRhY2htZW50GB8gASgLMiEuY2hhdC5wcm90b2NvbC5Db21wbGV0ZUF0'
    'dGFjaG1lbnRIAFISY29tcGxldGVBdHRhY2htZW50EksKEGF0dGFjaG1lbnRfcmVhZHkYICABKA'
    'syHi5jaGF0LnByb3RvY29sLkF0dGFjaG1lbnRSZWFkeUgAUg9hdHRhY2htZW50UmVhZHkSXQoW'
    'YWNrbm93bGVkZ2VfYXR0YWNobWVudBghIAEoCzIkLmNoYXQucHJvdG9jb2wuQWNrbm93bGVkZ2'
    'VBdHRhY2htZW50SABSFWFja25vd2xlZGdlQXR0YWNobWVudBJLChBhYm9ydF9hdHRhY2htZW50'
    'GCIgASgLMh4uY2hhdC5wcm90b2NvbC5BYm9ydEF0dGFjaG1lbnRIAFIPYWJvcnRBdHRhY2htZW'
    '50EkIKDXJlZ2lzdGVyX3B1c2gYKCABKAsyGy5jaGF0LnByb3RvY29sLlJlZ2lzdGVyUHVzaEgA'
    'UgxyZWdpc3RlclB1c2gSPAoLcmVtb3ZlX3B1c2gYKSABKAsyGS5jaGF0LnByb3RvY29sLlJlbW'
    '92ZVB1c2hIAFIKcmVtb3ZlUHVzaEIGCgRib2R5');

@$core.Deprecated('Use readyDescriptor instead')
const Ready$json = {
  '1': 'Ready',
  '2': [
    {
      '1': 'server_time_millis',
      '3': 1,
      '4': 1,
      '5': 4,
      '10': 'serverTimeMillis'
    },
  ],
};

/// Descriptor for `Ready`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List readyDescriptor = $convert.base64Decode(
    'CgVSZWFkeRIsChJzZXJ2ZXJfdGltZV9taWxsaXMYASABKARSEHNlcnZlclRpbWVNaWxsaXM=');

@$core.Deprecated('Use failureDescriptor instead')
const Failure$json = {
  '1': 'Failure',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `Failure`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List failureDescriptor = $convert.base64Decode(
    'CgdGYWlsdXJlEhIKBGNvZGUYASABKAlSBGNvZGUSGAoHbWVzc2FnZRgCIAEoCVIHbWVzc2FnZQ'
    '==');

@$core.Deprecated('Use successDescriptor instead')
const Success$json = {
  '1': 'Success',
  '2': [
    {'1': 'kind', '3': 1, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'ids', '3': 2, '4': 3, '5': 9, '10': 'ids'},
  ],
};

/// Descriptor for `Success`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List successDescriptor = $convert.base64Decode(
    'CgdTdWNjZXNzEhIKBGtpbmQYASABKAlSBGtpbmQSEAoDaWRzGAIgAygJUgNpZHM=');

@$core.Deprecated('Use pingDescriptor instead')
const Ping$json = {
  '1': 'Ping',
  '2': [
    {'1': 'sent_at_millis', '3': 1, '4': 1, '5': 4, '10': 'sentAtMillis'},
  ],
};

/// Descriptor for `Ping`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingDescriptor = $convert.base64Decode(
    'CgRQaW5nEiQKDnNlbnRfYXRfbWlsbGlzGAEgASgEUgxzZW50QXRNaWxsaXM=');

@$core.Deprecated('Use pongDescriptor instead')
const Pong$json = {
  '1': 'Pong',
  '2': [
    {'1': 'sent_at_millis', '3': 1, '4': 1, '5': 4, '10': 'sentAtMillis'},
    {
      '1': 'server_time_millis',
      '3': 2,
      '4': 1,
      '5': 4,
      '10': 'serverTimeMillis'
    },
  ],
};

/// Descriptor for `Pong`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pongDescriptor = $convert.base64Decode(
    'CgRQb25nEiQKDnNlbnRfYXRfbWlsbGlzGAEgASgEUgxzZW50QXRNaWxsaXMSLAoSc2VydmVyX3'
    'RpbWVfbWlsbGlzGAIgASgEUhBzZXJ2ZXJUaW1lTWlsbGlz');

@$core.Deprecated('Use keyPackageDescriptor instead')
const KeyPackage$json = {
  '1': 'KeyPackage',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'device_id', '3': 2, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'key_package_ref', '3': 3, '4': 1, '5': 9, '10': 'keyPackageRef'},
    {'1': 'key_package', '3': 4, '4': 1, '5': 12, '10': 'keyPackage'},
    {'1': 'cipher_suite', '3': 5, '4': 1, '5': 9, '10': 'cipherSuite'},
    {'1': 'not_before', '3': 6, '4': 1, '5': 4, '10': 'notBefore'},
    {'1': 'not_after', '3': 7, '4': 1, '5': 4, '10': 'notAfter'},
    {'1': 'last_resort', '3': 8, '4': 1, '5': 8, '10': 'lastResort'},
  ],
};

/// Descriptor for `KeyPackage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyPackageDescriptor = $convert.base64Decode(
    'CgpLZXlQYWNrYWdlEhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIbCglkZXZpY2VfaWQYAiABKA'
    'lSCGRldmljZUlkEiYKD2tleV9wYWNrYWdlX3JlZhgDIAEoCVINa2V5UGFja2FnZVJlZhIfCgtr'
    'ZXlfcGFja2FnZRgEIAEoDFIKa2V5UGFja2FnZRIhCgxjaXBoZXJfc3VpdGUYBSABKAlSC2NpcG'
    'hlclN1aXRlEh0KCm5vdF9iZWZvcmUYBiABKARSCW5vdEJlZm9yZRIbCglub3RfYWZ0ZXIYByAB'
    'KARSCG5vdEFmdGVyEh8KC2xhc3RfcmVzb3J0GAggASgIUgpsYXN0UmVzb3J0');

@$core.Deprecated('Use publishKeyPackageDescriptor instead')
const PublishKeyPackage$json = {
  '1': 'PublishKeyPackage',
  '2': [
    {
      '1': 'key_package',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.KeyPackage',
      '10': 'keyPackage'
    },
  ],
};

/// Descriptor for `PublishKeyPackage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List publishKeyPackageDescriptor = $convert.base64Decode(
    'ChFQdWJsaXNoS2V5UGFja2FnZRI6CgtrZXlfcGFja2FnZRgBIAEoCzIZLmNoYXQucHJvdG9jb2'
    'wuS2V5UGFja2FnZVIKa2V5UGFja2FnZQ==');

@$core.Deprecated('Use resolveKeyPackagesDescriptor instead')
const ResolveKeyPackages$json = {
  '1': 'ResolveKeyPackages',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'device_id', '3': 2, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'limit', '3': 3, '4': 1, '5': 13, '10': 'limit'},
  ],
};

/// Descriptor for `ResolveKeyPackages`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resolveKeyPackagesDescriptor = $convert.base64Decode(
    'ChJSZXNvbHZlS2V5UGFja2FnZXMSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhsKCWRldmljZV'
    '9pZBgCIAEoCVIIZGV2aWNlSWQSFAoFbGltaXQYAyABKA1SBWxpbWl0');

@$core.Deprecated('Use keyPackageBatchDescriptor instead')
const KeyPackageBatch$json = {
  '1': 'KeyPackageBatch',
  '2': [
    {
      '1': 'key_packages',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.chat.protocol.KeyPackage',
      '10': 'keyPackages'
    },
  ],
};

/// Descriptor for `KeyPackageBatch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyPackageBatchDescriptor = $convert.base64Decode(
    'Cg9LZXlQYWNrYWdlQmF0Y2gSPAoMa2V5X3BhY2thZ2VzGAEgAygLMhkuY2hhdC5wcm90b2NvbC'
    '5LZXlQYWNrYWdlUgtrZXlQYWNrYWdlcw==');

@$core.Deprecated('Use sendMessageDescriptor instead')
const SendMessage$json = {
  '1': 'SendMessage',
  '2': [
    {
      '1': 'message',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.EncryptedMessage',
      '10': 'message'
    },
  ],
};

/// Descriptor for `SendMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendMessageDescriptor = $convert.base64Decode(
    'CgtTZW5kTWVzc2FnZRI5CgdtZXNzYWdlGAEgASgLMh8uY2hhdC5wcm90b2NvbC5FbmNyeXB0ZW'
    'RNZXNzYWdlUgdtZXNzYWdl');

@$core.Deprecated('Use syncMessagesDescriptor instead')
const SyncMessages$json = {
  '1': 'SyncMessages',
  '2': [
    {'1': 'limit', '3': 1, '4': 1, '5': 13, '10': 'limit'},
  ],
};

/// Descriptor for `SyncMessages`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncMessagesDescriptor =
    $convert.base64Decode('CgxTeW5jTWVzc2FnZXMSFAoFbGltaXQYASABKA1SBWxpbWl0');

@$core.Deprecated('Use messageBatchDescriptor instead')
const MessageBatch$json = {
  '1': 'MessageBatch',
  '2': [
    {
      '1': 'messages',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.chat.protocol.EncryptedMessage',
      '10': 'messages'
    },
  ],
};

/// Descriptor for `MessageBatch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageBatchDescriptor = $convert.base64Decode(
    'CgxNZXNzYWdlQmF0Y2gSOwoIbWVzc2FnZXMYASADKAsyHy5jaGF0LnByb3RvY29sLkVuY3J5cH'
    'RlZE1lc3NhZ2VSCG1lc3NhZ2Vz');

@$core.Deprecated('Use acknowledgeMessagesDescriptor instead')
const AcknowledgeMessages$json = {
  '1': 'AcknowledgeMessages',
  '2': [
    {'1': 'message_ids', '3': 1, '4': 3, '5': 9, '10': 'messageIds'},
  ],
};

/// Descriptor for `AcknowledgeMessages`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List acknowledgeMessagesDescriptor = $convert.base64Decode(
    'ChNBY2tub3dsZWRnZU1lc3NhZ2VzEh8KC21lc3NhZ2VfaWRzGAEgAygJUgptZXNzYWdlSWRz');

@$core.Deprecated('Use messageAvailableDescriptor instead')
const MessageAvailable$json = {
  '1': 'MessageAvailable',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'conversation_id', '3': 2, '4': 1, '5': 9, '10': 'conversationId'},
    {
      '1': 'server_time_millis',
      '3': 3,
      '4': 1,
      '5': 4,
      '10': 'serverTimeMillis'
    },
  ],
};

/// Descriptor for `MessageAvailable`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageAvailableDescriptor = $convert.base64Decode(
    'ChBNZXNzYWdlQXZhaWxhYmxlEh0KCm1lc3NhZ2VfaWQYASABKAlSCW1lc3NhZ2VJZBInCg9jb2'
    '52ZXJzYXRpb25faWQYAiABKAlSDmNvbnZlcnNhdGlvbklkEiwKEnNlcnZlcl90aW1lX21pbGxp'
    'cxgDIAEoBFIQc2VydmVyVGltZU1pbGxpcw==');

@$core.Deprecated('Use beginAttachmentDescriptor instead')
const BeginAttachment$json = {
  '1': 'BeginAttachment',
  '2': [
    {
      '1': 'attachment',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.AttachmentMetadata',
      '10': 'attachment'
    },
  ],
};

/// Descriptor for `BeginAttachment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beginAttachmentDescriptor = $convert.base64Decode(
    'Cg9CZWdpbkF0dGFjaG1lbnQSQQoKYXR0YWNobWVudBgBIAEoCzIhLmNoYXQucHJvdG9jb2wuQX'
    'R0YWNobWVudE1ldGFkYXRhUgphdHRhY2htZW50');

@$core.Deprecated('Use completeAttachmentDescriptor instead')
const CompleteAttachment$json = {
  '1': 'CompleteAttachment',
  '2': [
    {'1': 'attachment_id', '3': 1, '4': 1, '5': 9, '10': 'attachmentId'},
  ],
};

/// Descriptor for `CompleteAttachment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeAttachmentDescriptor = $convert.base64Decode(
    'ChJDb21wbGV0ZUF0dGFjaG1lbnQSIwoNYXR0YWNobWVudF9pZBgBIAEoCVIMYXR0YWNobWVudE'
    'lk');

@$core.Deprecated('Use attachmentReadyDescriptor instead')
const AttachmentReady$json = {
  '1': 'AttachmentReady',
  '2': [
    {'1': 'attachment_id', '3': 1, '4': 1, '5': 9, '10': 'attachmentId'},
  ],
};

/// Descriptor for `AttachmentReady`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attachmentReadyDescriptor = $convert.base64Decode(
    'Cg9BdHRhY2htZW50UmVhZHkSIwoNYXR0YWNobWVudF9pZBgBIAEoCVIMYXR0YWNobWVudElk');

@$core.Deprecated('Use acknowledgeAttachmentDescriptor instead')
const AcknowledgeAttachment$json = {
  '1': 'AcknowledgeAttachment',
  '2': [
    {'1': 'attachment_id', '3': 1, '4': 1, '5': 9, '10': 'attachmentId'},
  ],
};

/// Descriptor for `AcknowledgeAttachment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List acknowledgeAttachmentDescriptor = $convert.base64Decode(
    'ChVBY2tub3dsZWRnZUF0dGFjaG1lbnQSIwoNYXR0YWNobWVudF9pZBgBIAEoCVIMYXR0YWNobW'
    'VudElk');

@$core.Deprecated('Use abortAttachmentDescriptor instead')
const AbortAttachment$json = {
  '1': 'AbortAttachment',
  '2': [
    {'1': 'attachment_id', '3': 1, '4': 1, '5': 9, '10': 'attachmentId'},
  ],
};

/// Descriptor for `AbortAttachment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List abortAttachmentDescriptor = $convert.base64Decode(
    'Cg9BYm9ydEF0dGFjaG1lbnQSIwoNYXR0YWNobWVudF9pZBgBIAEoCVIMYXR0YWNobWVudElk');

@$core.Deprecated('Use registerPushDescriptor instead')
const RegisterPush$json = {
  '1': 'RegisterPush',
  '2': [
    {'1': 'platform', '3': 1, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'token', '3': 2, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `RegisterPush`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerPushDescriptor = $convert.base64Decode(
    'CgxSZWdpc3RlclB1c2gSGgoIcGxhdGZvcm0YASABKAlSCHBsYXRmb3JtEhQKBXRva2VuGAIgAS'
    'gJUgV0b2tlbg==');

@$core.Deprecated('Use removePushDescriptor instead')
const RemovePush$json = {
  '1': 'RemovePush',
  '2': [
    {'1': 'platform', '3': 1, '4': 1, '5': 9, '10': 'platform'},
  ],
};

/// Descriptor for `RemovePush`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removePushDescriptor = $convert
    .base64Decode('CgpSZW1vdmVQdXNoEhoKCHBsYXRmb3JtGAEgASgJUghwbGF0Zm9ybQ==');
