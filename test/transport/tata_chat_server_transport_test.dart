import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/src/transport/chat_server_connection.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

final class _FakeSocket implements TataChatServerSocket {
  @override
  String? get protocol => 'tatachatserver';
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

TataChatServerAccess _access() => TataChatServerAccess(
  tataChatServerUrl: Uri.parse('https://chat.example.test'),
  tataChatServerToken: 'signed-token',
  expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
);

void main() {
  test(
    'WSS negotiates tatachatserver and sends binary protobuf only',
    () async {
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
      expect(connectedUri.toString(), 'wss://chat.example.test/realtime');
      expect(connectedToken, 'signed-token');
      expect(socket.sent, isEmpty);
      await transport.dispose();
    },
  );

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
