// This is a generated file - do not edit.
//
// Generated from message.proto.

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

@$core.Deprecated('Use recipientDescriptor instead')
const Recipient$json = {
  '1': 'Recipient',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'device_id', '3': 2, '4': 1, '5': 9, '10': 'deviceId'},
  ],
};

/// Descriptor for `Recipient`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recipientDescriptor = $convert.base64Decode(
    'CglSZWNpcGllbnQSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhsKCWRldmljZV9pZBgCIAEoCV'
    'IIZGV2aWNlSWQ=');

@$core.Deprecated('Use encryptedDeliveryDescriptor instead')
const EncryptedDelivery$json = {
  '1': 'EncryptedDelivery',
  '2': [
    {
      '1': 'recipient',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.chat.protocol.Recipient',
      '10': 'recipient'
    },
    {
      '1': 'openmls_ciphertext',
      '3': 2,
      '4': 1,
      '5': 12,
      '10': 'openmlsCiphertext'
    },
  ],
};

/// Descriptor for `EncryptedDelivery`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List encryptedDeliveryDescriptor = $convert.base64Decode(
    'ChFFbmNyeXB0ZWREZWxpdmVyeRI2CglyZWNpcGllbnQYASABKAsyGC5jaGF0LnByb3RvY29sLl'
    'JlY2lwaWVudFIJcmVjaXBpZW50Ei0KEm9wZW5tbHNfY2lwaGVydGV4dBgCIAEoDFIRb3Blbm1s'
    'c0NpcGhlcnRleHQ=');

@$core.Deprecated('Use encryptedMessageDescriptor instead')
const EncryptedMessage$json = {
  '1': 'EncryptedMessage',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'conversation_id', '3': 2, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'sender_user_id', '3': 3, '4': 1, '5': 9, '10': 'senderUserId'},
    {'1': 'sender_device_id', '3': 4, '4': 1, '5': 9, '10': 'senderDeviceId'},
    {
      '1': 'deliveries',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.chat.protocol.EncryptedDelivery',
      '10': 'deliveries'
    },
    {'1': 'created_at_millis', '3': 6, '4': 1, '5': 4, '10': 'createdAtMillis'},
  ],
};

/// Descriptor for `EncryptedMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List encryptedMessageDescriptor = $convert.base64Decode(
    'ChBFbmNyeXB0ZWRNZXNzYWdlEh0KCm1lc3NhZ2VfaWQYASABKAlSCW1lc3NhZ2VJZBInCg9jb2'
    '52ZXJzYXRpb25faWQYAiABKAlSDmNvbnZlcnNhdGlvbklkEiQKDnNlbmRlcl91c2VyX2lkGAMg'
    'ASgJUgxzZW5kZXJVc2VySWQSKAoQc2VuZGVyX2RldmljZV9pZBgEIAEoCVIOc2VuZGVyRGV2aW'
    'NlSWQSQAoKZGVsaXZlcmllcxgFIAMoCzIgLmNoYXQucHJvdG9jb2wuRW5jcnlwdGVkRGVsaXZl'
    'cnlSCmRlbGl2ZXJpZXMSKgoRY3JlYXRlZF9hdF9taWxsaXMYBiABKARSD2NyZWF0ZWRBdE1pbG'
    'xpcw==');

@$core.Deprecated('Use chatRouteDescriptor instead')
const ChatRoute$json = {
  '1': 'ChatRoute',
  '2': [
    {'1': 'peer_user_id', '3': 1, '4': 1, '5': 9, '10': 'peerUserId'},
    {'1': 'device_id', '3': 2, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'created_at_millis', '3': 3, '4': 1, '5': 4, '10': 'createdAtMillis'},
    {'1': 'expires_at_millis', '3': 4, '4': 1, '5': 4, '10': 'expiresAtMillis'},
  ],
};

/// Descriptor for `ChatRoute`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatRouteDescriptor = $convert.base64Decode(
    'CglDaGF0Um91dGUSIAoMcGVlcl91c2VyX2lkGAEgASgJUgpwZWVyVXNlcklkEhsKCWRldmljZV'
    '9pZBgCIAEoCVIIZGV2aWNlSWQSKgoRY3JlYXRlZF9hdF9taWxsaXMYAyABKARSD2NyZWF0ZWRB'
    'dE1pbGxpcxIqChFleHBpcmVzX2F0X21pbGxpcxgEIAEoBFIPZXhwaXJlc0F0TWlsbGlz');
