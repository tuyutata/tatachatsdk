import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  test('rename 编解码保真', () {
    final encoded = GroupControlCodec.encode(GroupControl.rename('我的群'));
    expect(jsonDecode(encoded), <String, dynamic>{
      'op': 'rename',
      'name': '我的群',
    });
    final decoded = GroupControlCodec.tryDecode(encoded);
    expect(decoded, isNotNull);
    expect(decoded!.op, GroupControlOp.rename);
    expect(decoded.groupName, '我的群');
  });

  test('leave_request 编解码', () {
    final decoded = GroupControlCodec.tryDecode(
      GroupControlCodec.encode(const GroupControl.leaveRequest()),
    );
    expect(decoded, isNotNull);
    expect(decoded!.op, GroupControlOp.leaveRequest);
    expect(decoded.groupName, isNull);
  });

  test('非 JSON 用户载荷不被误判为群控制', () {
    expect(GroupControlCodec.tryDecode('{"kind":"text","text":"hi"}'), isNull);
    expect(GroupControlCodec.tryDecode('CgsKCeWkp-WutuWlvQ'), isNull);
    expect(GroupControlCodec.tryDecode('随便一句话'), isNull);
  });

  test('JSON 控制载荷坏数据和未知 op 失败关闭', () {
    for (final raw in const <String>[
      '{"op":"unknown"}',
      '{"op":"leave_request","extra":true}',
      '{"op":"rename","name":""}',
    ]) {
      expect(
        () => GroupControlCodec.tryDecode(raw),
        throwsA(isA<FormatException>()),
        reason: raw,
      );
    }
  });
}
