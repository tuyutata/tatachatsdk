import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  test('私聊路由使用 SDK 唯一会话标识规则', () {
    expect(
      ChatSdk.directConversationId('user-b', 'user-a'),
      ChatSdk.directConversationId('user-a', 'user-b'),
    );
  });
}
