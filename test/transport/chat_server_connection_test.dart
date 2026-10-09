import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/transport/chat_server_connection.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

final class _FakeSocket implements ChatSocket {
  @override
  String? get protocol => 'tatachat';
  final StreamController<Object?> _events = StreamController<Object?>();
  final List<ChatFrame> sent = <ChatFrame>[];
  bool closed = false;

  @override
  Stream<Object?> get events => _events.stream;

  @override
  void add(List<int> bytes) => sent.add(ChatFrame.fromBuffer(bytes));

  void receive(ChatFrame frame) => _events.add(frame.writeToBuffer());

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await _events.close();
  }
}

ChatAccess _access() => ChatAccess(
  realtimeUrl: Uri.parse('wss://chat.example.test/api/tatachat/realtime'),
  accessToken: 'signed-token',
  expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
);

void main() {
  test('邮箱保留完整Protobuf外层，ACK按100条分批且精确匹配回执', () async {
    final socket = _FakeSocket();
    final transport = ChatServerConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => _access(),
      socketConnector: (_, _) async {
        scheduleMicrotask(() => socket.receive(ChatFrame()..ready = Ready()));
        return socket;
      },
    );
    await transport.connect();
    final pending = transport.fetchMailbox();
    await Future<void>.delayed(Duration.zero);
    expect(socket.sent.last.syncMessages.limit, 100);
    final message = EncryptedMessage(
      messageId: 'message-a',
      conversationId: 'conversation-a',
      senderUserId: 'user-b',
      senderDeviceId: 'device-b',
      createdAtMillis: Int64.ONE,
      deliveries: [
        EncryptedDelivery(
          recipient: Recipient(userId: 'user-a', deviceId: 'device-a'),
          openmlsCiphertext: [1, 2, 3],
        ),
      ],
    );
    socket.receive(
      ChatFrame()..messageBatch = MessageBatch(messages: [message]),
    );
    final mailbox = await pending;
    expect(
      EncryptedMessage.fromBuffer(mailbox.single.messageBytes).writeToBuffer(),
      message.writeToBuffer(),
    );
    final ack = transport.acknowledgeMailbox(
      List.generate(205, (i) => 'message-$i'),
    );
    for (final count in [100, 100, 5]) {
      await Future<void>.delayed(Duration.zero);
      final ids = socket.sent.last.acknowledgeMessages.messageIds;
      expect(ids, hasLength(count));
      socket.receive(
        ChatFrame()..success = Success(kind: 'messages.acknowledged', ids: ids),
      );
    }
    await ack;
    await transport.dispose();
  });
  test('WSS negotiates tatachat and sends binary protobuf only', () async {
    final socket = _FakeSocket();
    late Uri connectedUri;
    late String connectedToken;
    final transport = ChatServerConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => _access(),
      socketConnector: (uri, token) async {
        connectedUri = uri;
        connectedToken = token;
        scheduleMicrotask(
          () => socket.receive(
            ChatFrame()..ready = Ready(serverTimeMillis: Int64.ONE),
          ),
        );
        return socket;
      },
    );

    await transport.connect();
    expect(
      connectedUri.toString(),
      'wss://chat.example.test/api/tatachat/realtime',
    );
    expect(connectedToken, 'signed-token');
    expect(socket.sent, isEmpty);
    await transport.dispose();
  });

  test(
    'protocol without request id keeps exactly one command in flight',
    () async {
      final socket = _FakeSocket();
      final transport = ChatServerConnection(
        identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
        accessProvider: () async => _access(),
        socketConnector: (uri, token) async {
          scheduleMicrotask(
            () => socket.receive(
              ChatFrame()..ready = Ready(serverTimeMillis: Int64.ONE),
            ),
          );
          return socket;
        },
      );
      await transport.connect();

      final first = transport.resolveKeyPackages('user-b');
      final second = transport.resolveKeyPackages('user-c');
      await Future<void>.delayed(Duration.zero);
      expect(socket.sent, hasLength(1));
      expect(socket.sent.single.resolveKeyPackages.userId, 'user-b');

      socket.receive(ChatFrame()..keyPackageBatch = KeyPackageBatch());
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(socket.sent, hasLength(2));
      expect(socket.sent.last.resolveKeyPackages.userId, 'user-c');

      socket.receive(ChatFrame()..keyPackageBatch = KeyPackageBatch());
      await second;
      await transport.dispose();
    },
  );

  test(
    'message available bypasses command queue and only emits wake event',
    () async {
      final socket = _FakeSocket();
      final events = <ChatServiceEvent>[];
      final transport = ChatServerConnection(
        identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
        accessProvider: () async => _access(),
        socketConnector: (uri, token) async {
          scheduleMicrotask(
            () => socket.receive(
              ChatFrame()..ready = Ready(serverTimeMillis: Int64.ONE),
            ),
          );
          return socket;
        },
      );
      final stop = await transport.connectRealtime(
        onEvent: (event) async => events.add(event),
      );
      socket.receive(
        ChatFrame()
          ..messageAvailable = (MessageAvailable()
            ..messageId = 'message-a'
            ..conversationId = 'conversation-a'
            ..serverTimeMillis = Int64(2)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.single, isA<ChatMessageAvailableEvent>());
      await stop();
      await transport.dispose();
    },
  );
}
