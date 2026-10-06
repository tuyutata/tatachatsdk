import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  test('完整会话页只依赖 SDK 与显式宿主边界', () {
    final page = ChatConversationPage(
      sdk: ChatSdk(host: _Host()),
      conversationId: 'conversation',
      currentUserId: 'owner',
      accountId: '0x${'1' * 64}',
      peerUserId: 'peer',
      title: 'Peer',
      host: ChatConversationHost(
        style: const ChatViewStyle(),
        mediaLimits: const ChatUnlimitedMediaLimitPolicy(),
        canSend: (_) => true,
        unavailableMessage: (_) => 'unavailable',
        errorMessage: (error) => error.toString(),
        headerBuilder: (_, header) => throw UnimplementedError(),
        resolveUser: (userId, _, _) async => User(id: userId),
      ),
    );

    expect(page.conversationId, 'conversation');
    expect(page.currentUserId, 'owner');
    expect(page.host.canSend('owner'), isTrue);
  });
}

class _Host implements ChatRuntimeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
