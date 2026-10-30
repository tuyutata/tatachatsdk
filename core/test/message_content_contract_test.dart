import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_core/basic_content.dart';
import 'package:tatachat_core/serial_executor.dart';

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
}

