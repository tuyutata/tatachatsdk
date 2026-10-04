import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  group('第一类消息协议', () {
    test('文字、emoji、贴纸均通过唯一 protobuf 往返', () {
      final contents = <BasicContent>[
        BasicContent.text('hello'),
        BasicContent.textInput('😀'),
        BasicContent.sticker(packId: 'fluent3d', stickerId: 'hello_1'),
      ];
      final decoded = contents
          .map(
            (content) =>
                BasicContentCodec.decode(BasicContentCodec.encode(content)),
          )
          .toList(growable: false);
      expect(decoded.map((item) => item.kind), <BasicContentKind>[
        BasicContentKind.text,
        BasicContentKind.emoji,
        BasicContentKind.sticker,
      ]);
    });

    test('未知字段、空内容和超限内容全部失败关闭', () {
      final valid = BasicContentCodec.encode(BasicContent.text('x'));
      expect(
        () => BasicContentCodec.decode(<int>[...valid, 0x20, 0x01]),
        throwsFormatException,
      );
      expect(
        () => BasicContentCodec.encode(BasicContent.text('')),
        throwsFormatException,
      );
      expect(
        () => BasicContentCodec.encode(
          BasicContent.text('x' * (BasicContentCodec.maxTextBytes + 1)),
        ),
        throwsFormatException,
      );
    });
  });

  test('群消息单密文扇出且同一重试产生同一消息 ID', () {
    const wire = MlsWireMessage(
      wireBytes: <int>[1, 2, 3],
      conversationId: 'group-a',
      messageKind: MlsMessageKind.application,
    );
    List<EncryptedMessage> run() => GroupMessageFanout.fanOut(
      wire: wire,
      recipients: const <MlsMemberIdentity>[
        MlsMemberIdentity(userId: 'user-b', deviceId: 'device-b'),
        MlsMemberIdentity(userId: 'user-c', deviceId: 'device-c'),
        MlsMemberIdentity(userId: 'user-b', deviceId: 'device-b'),
      ],
      senderUserId: 'user-a',
      senderDeviceId: 'device-a',
      createdAtMillis: 100,
    );
    final first = run();
    final retried = run();
    expect(first.length, 2);
    expect(
      first.map((item) => item.openmlsCiphertext),
      everyElement(<int>[1, 2, 3]),
    );
    expect(
      retried.map((item) => item.messageId),
      first.map((item) => item.messageId),
    );
    expect(first[0].messageId, isNot(first[1].messageId));
  });

  test('同一会话严格串行，不同任务不会越过前序密码学操作', () async {
    final serial = SerialExecutor();
    final gate = Completer<void>();
    final order = <int>[];
    final first = serial.run('conversation', () async {
      order.add(1);
      await gate.future;
      order.add(2);
    });
    final second = serial.run('conversation', () async => order.add(3));
    await Future<void>.delayed(Duration.zero);
    expect(order, <int>[1]);
    gate.complete();
    await Future.wait<void>(<Future<void>>[first, second]);
    expect(order, <int>[1, 2, 3]);
  });

  test('网络端点拒绝非加密协议', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    expect(
      () => TataChatServerAccess(
        tataChatServerUrl: Uri.parse(
          'http'
          '://example.com',
        ),
        tataChatServerToken: 'token',
        expiresAtMillis: now + 120000,
      ).validate(now),
      throwsStateError,
    );
    expect(
      (TataChatServerAccess(
        tataChatServerUrl: Uri.parse('https://example.com'),
        tataChatServerToken: 'token',
        expiresAtMillis: now + 120000,
      )..validate(now)).realtimeUrl.scheme,
      'wss',
    );
    expect(
      (TataChatServerAccess(
        tataChatServerUrl: Uri.parse('https://example.com'),
        tataChatServerToken: 'token',
        expiresAtMillis: now + 120000,
      )..validate(now)).tataChatServerUrl.scheme,
      'https',
    );
  });
}
