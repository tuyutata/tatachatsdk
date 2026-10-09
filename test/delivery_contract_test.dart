import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/runtime/chat_runtime.dart').readAsStringSync();

  test('独立MLS附件落盘后才异步HTTPS上传，普通消息不等待附件', () {
    final prepare = source.indexOf(
      'Future<ChatContent> _prepareEncryptedMedia',
    );
    final schedule = source.indexOf('void _schedulePendingMediaUpload');
    final upload = source.indexOf(
      'Future<void> _uploadPendingDirectAttachment',
    );

    expect(prepare, greaterThanOrEqualTo(0));
    expect(schedule, greaterThan(prepare));
    expect(upload, greaterThan(schedule));
    expect(source, contains('uploadEncryptedAttachment('));
    expect(source, contains('scheduleDelivery: false'));
    expect(source, contains('await engine.seal('));
    expect(source, contains('await _requireAttachmentAudience('));
    expect(source, contains('context.crypto.groupState(conversationId)'));
    expect(
      source,
      contains('recipientUserIds: _attachmentRecipientUserIds(content)'),
    );
    expect(
      source,
      contains('final recipients = _attachmentRecipientUserIds(content)'),
    );
    expect(
      source,
      contains('member != content.attachmentSenderMemberIdentity'),
    );
    final application = File('lib/mls/mls_attachment.dart').readAsStringSync();
    expect(
      application,
      matches(RegExp(r'crypto\.groupCreateMessage\(\s*group,\s*payload\s*\)')),
    );
    expect(application, contains("confirm_attachment_chunk"));
    expect(application, contains('Future<void>.delayed(Duration.zero)'));
  });

  test('mailbox acknowledgement follows successful local persistence', () {
    final batch = source.indexOf('Future<int> _consumeMailboxBatch');
    final consumeCall = source.indexOf('await _consumeMailboxMessage(', batch);
    final acknowledge = source.indexOf('acknowledgeMailbox(', batch);
    final consume = source.indexOf('Future<bool> _consumeMailboxMessage');
    final process = source.indexOf('_processMailboxMessage(', consume);
    final receipt = source.indexOf(
      '_mailboxMessageReceipts.add(receiptKey)',
      process,
    );
    final accepted = source.indexOf('return true;', receipt);

    expect(batch, greaterThanOrEqualTo(0));
    expect(consumeCall, greaterThan(batch));
    expect(acknowledge, greaterThan(consumeCall));
    expect(consume, greaterThanOrEqualTo(0));
    expect(process, greaterThan(consume));
    expect(receipt, greaterThan(process));
    expect(accepted, greaterThan(receipt));
  });

  test('host policy is checked only when creating a pending send', () {
    final create = source.indexOf('Future<String> _savePendingDirectPayload');
    final schedule = source.indexOf('void _schedulePendingOutgoing');
    final flush = source.indexOf('Future<bool> _flushPendingOutgoing');
    final expire = source.indexOf('Future<void> _expirePendingOutgoing');

    expect(create, greaterThanOrEqualTo(0));
    expect(source.substring(create, schedule), contains('_host.canSend'));
    expect(source.substring(flush, expire), isNot(contains('_host.canSend')));
  });

  test('message and attachment paths do not depend on peer connections', () {
    expect(source, isNot(contains('peer_ready')));
    expect(source, isNot(contains('RTCPeerConnection')));
    expect(source, contains('connectRealtime('));
    expect(source, contains('fetchMailbox()'));
  });

  test('聊天服务模块 邮箱密文必须匹配当前用户和当前设备', () {
    final transportSource = File('lib/transport/chat_server_connection.dart')
        .readAsStringSync();

    expect(
      transportSource,
      contains('value.recipientUserId != identity.userId'),
    );
    expect(
      transportSource,
      contains('value.recipientDeviceId != identity.deviceId'),
    );
    expect(transportSource, contains("'mailbox_identity_invalid'"));
  });
}
