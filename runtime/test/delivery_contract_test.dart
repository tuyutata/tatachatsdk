import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_core/chat_content.dart';
import 'package:tatachat_core/chat_message.dart';
import 'package:tatachat_mls/mls_boundary.dart';
import 'package:tatachat_mls/mls_group_boundary.dart';
import 'package:tatachat_protocol/message.dart';
import 'package:tatachat_runtime/direct_flow.dart';
import 'package:tatachat_storage/flow_store.dart';

// 直接执行收件流程并记录持久化边界，源码文字位置不能证明异步顺序。
void main() {
  for (final fails in [false, true]) {
    test('业务落盘${fails ? '失败不确认' : '成功后才确认原生结果，重投不重复落盘'}', () async {
      final events = <String>[];
      final crypto = _Crypto(events);
      final store = _Store(events, fails);
      final flow = ChatFlow<Object>(
        crypto: crypto,
        store: store,
        bindingToken: Object(),
        ownerUserId: 'local',
        currentAccountId: 'account',
        deliverer: (_, _, _, _) async => throw StateError('收件不得触发发送'),
      );
      final message =
          MlsWireMessage(
            conversationId: 'dm:local:peer',
            wireBytes: utf8.encode(
              ChatPayloadCodec.encode(ChatContent.text('hello')),
            ),
          ).toEncryptedMessage(
            messageId: 'message',
            senderUserId: 'peer',
            senderDeviceId: 'device',
            recipientUserId: 'local',
            recipientDeviceId: 'local-device',
            createdAtMillis: 1,
          );
      final processing = flow.processIncomingMessageBytes(
        message.writeToBuffer(),
      );
      if (fails) {
        await expectLater(processing, throwsStateError);
        expect(events, ['process', 'store']);
        expect(crypto.confirmed, false);
      } else {
        final result = await processing;
        expect(result.accepted, true);
        expect(events, ['process', 'store', 'ack']);
        events.clear();
        expect(
          (await flow.processIncomingMessageBytes(message.writeToBuffer()))
              .accepted,
          true,
        );
        expect(events, ['process']);
      }
    });
  }
}

class _Crypto implements MlsGroupCrypto, MlsPersistentCrypto {
  _Crypto(this.events);
  final List<String> events;
  bool confirmed = false;
  @override
  Future<T> withMessage<T>(String id, Future<T> Function() operation) =>
      operation();
  @override
  Future<void> acknowledgeMessage(String id) async {
    events.add('ack');
    confirmed = true;
  }

  @override
  Future<GroupInbound> groupProcess(MlsWireMessage wire) async {
    events.add('process');
    return GroupInbound(
      groupId: wire.conversationId,
      kind: GroupInboundKind.application,
      status: confirmed ? GroupProcessStatus.stale : GroupProcessStatus.applied,
      messageEpoch: 0,
      groupEpoch: 0,
      selfRemoved: false,
      plaintext: wire.wireBytes,
      senderMemberIdentity: 'peer:device',
      committed: confirmed,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected crypto');
}

class _Store implements ChatFlowStore<Object> {
  _Store(this.events, this.fails);
  final List<String> events;
  final bool fails;
  @override
  Future<void> saveIncomingMessage({
    required Object bindingToken,
    required String ownerUserId,
    required String currentAccountId,
    required EncryptedMessage message,
    required List<int> messageBytes,
    required ChatMessageKind messageKind,
    required String plaintext,
  }) async {
    events.add('store');
    if (fails) throw StateError('synthetic persistence failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected store');
}
