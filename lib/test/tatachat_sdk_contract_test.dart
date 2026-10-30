import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  test('SDK根层只保留唯一公开入口，类型继续由该入口提供', () {
    final files = Directory('lib')
        .listSync(followLinks: false)
        .whereType<File>();
    expect(files.map((file) => file.uri.pathSegments.last).toList(), <String>[
      'tatachat_sdk.dart',
    ]);
    final incoming = DirectMessageInbound(
      conversationId: 'conversation-a',
      content: BasicContent.text('hello'),
    );
    expect(incoming.conversationId, 'conversation-a');
    expect(
      BasicContentCodec.decode(BasicContentCodec.encode(incoming.content))
          .value,
      'hello',
    );
    expect(const DirectCallState(DirectCallPhase.ended).isTerminal, isTrue);
  });

  test('公开入口接收完整 WSS 地址并派生同源 HTTPS 分块', () {
    final access = ChatAccess(
      realtimeUrl: Uri.parse('wss://chat.example.com/api/tatachat/realtime'),
      accessToken: 'test-token',
      expiresAtMillis: 200000,
    );
    access.validate(1000);
    expect(
      access.realtimeUrl.toString(),
      'wss://chat.example.com/api/tatachat/realtime',
    );
  });
}
