import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_mls/mls_boundary.dart';
import 'package:tatachat_protocol/chat_frame.pb.dart';
import 'package:tatachat_protocol/message.dart';
import 'package:tatachat_protocol/message.pb.dart';
import 'package:tatachat_transport/chat_attachment_transport.dart';
import 'package:tatachat_transport/chat_server_connection.dart';
import 'package:tatachat_transport/chat_service_transport.dart';

final class _FakeSocket implements ChatSocket {
  @override
  String? get protocol => 'tatachat';
  final StreamController<Object?> _events = StreamController<Object?>();
  final List<ChatFrame> sent = <ChatFrame>[];
  bool closed = false;
  bool refuseSend = false;

  @override
  Stream<Object?> get events => _events.stream;

  @override
  void add(List<int> bytes) {
    if (refuseSend) throw StateError('synthetic-private-socket-detail');
    sent.add(ChatFrame.fromBuffer(bytes));
  }

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
  test('不匹配的响应不能结清当前命令预留，关闭连接保留不确定消耗', () async {
    final socket = _FakeSocket(), gate = _ResourceGate();
    final transport = ChatServerConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => ChatAccess(
        realtimeUrl: _access().realtimeUrl,
        accessToken: 'signed-token',
        expiresAtMillis: _access().expiresAtMillis,
        resources: gate,
      ),
      socketConnector: (_, _) async {
        scheduleMicrotask(() => socket.receive(ChatFrame()..ready = Ready()));
        return socket;
      },
    );
    await transport.connect();
    final mailbox = transport.fetchMailbox();
    final assertion = expectLater(
      mailbox,
      throwsA(
        isA<ChatServerConnectionException>().having(
          (e) => e.code,
          '相关性',
          'realtime_response_mismatch',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    socket.receive(ChatFrame()..success = (Success()..kind = 'unmatched'));
    await assertion;
    await transport.dispose();
    expect(gate.finished, 1); // 只结清Ready，不能以旧/错误响应退款当前命令。
    expect(gate.cancelled, greaterThan(0));
  });

  test('真实发送失败仍关闭连接并返回固定错误码，不泄漏原异常', () async {
    final socket = _FakeSocket()..refuseSend = true;
    final transport = ChatServerConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => _access(),
      socketConnector: (_, _) async {
        scheduleMicrotask(() => socket.receive(ChatFrame()..ready = Ready()));
        return socket;
      },
    );
    await expectLater(
      transport.fetchMailbox(),
      throwsA(
        isA<ChatServerConnectionException>().having(
          (e) => e.code,
          '固定发送失败',
          'realtime_send_failed',
        ),
      ),
    );
    await transport.dispose();
    expect(socket.closed, isTrue);
    expect(socket.sent, isEmpty);
  });

  test('连接预检等待期间关闭，迟到预留释放且不打开socket', () async {
    final gate = _ResourceGate()..connectWait = Completer<void>();
    var openings = 0;
    final transport = ChatServerConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => ChatAccess(
        realtimeUrl: _access().realtimeUrl,
        accessToken: 'signed-token',
        expiresAtMillis: _access().expiresAtMillis,
        resources: gate,
      ),
      socketConnector: (_, _) async {
        openings++;
        return _FakeSocket();
      },
    );
    final opening = transport.connect();
    final assertion = expectLater(
      opening,
      throwsA(isA<ChatServerConnectionException>()),
    );
    await Future<void>.delayed(Duration.zero);
    await transport.dispose();
    gate.connectWait!.complete();
    await assertion;
    await Future<void>.delayed(Duration.zero);
    expect(openings, 0);
    expect(gate.cancelled, 1);
  });

  test('宿主拒绝连接时零socket；异步命令预检取消后零发送', () async {
    final gate = _ResourceGate();
    var connections = 0;
    final socket = _FakeSocket();
    final transport = ChatServerConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => ChatAccess(
        realtimeUrl: _access().realtimeUrl,
        accessToken: 'signed-token',
        expiresAtMillis: _access().expiresAtMillis,
        resources: gate,
      ),
      socketConnector: (_, _) async {
        connections++;
        scheduleMicrotask(() => socket.receive(ChatFrame()..ready = Ready()));
        return socket;
      },
    );
    gate.reject = true;
    await expectLater(transport.connect(), throwsA(isA<StateError>()));
    expect(connections, 0);
    gate.reject = false;
    await transport.connect();
    expect(gate.actions, ['chat_connect', 'chat_connect']);
    gate.wait = Completer<void>();
    final command = transport.fetchMailbox();
    final assertion = expectLater(
      command,
      throwsA(isA<ChatServerConnectionException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(socket.sent, isEmpty);
    await transport.dispose();
    gate.wait!.complete();
    await assertion;
    await Future<void>.delayed(Duration.zero);
    expect(socket.sent, isEmpty);
    expect(gate.cancelled, greaterThan(0));
  });

  test('空闲26秒不发送业务Ping，连接仍可执行原邮箱命令', () async {
    final clock = FakeAsync();
    late _FakeSocket socket;
    var closed = false;
    clock.run((clock) {
      socket = _FakeSocket();
      final transport = ChatServerConnection(
        identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
        accessProvider: () async => _access(),
        socketConnector: (_, _) async {
          scheduleMicrotask(() => socket.receive(ChatFrame()..ready = Ready()));
          return socket;
        },
      );
      var connected = false;
      transport.connect().then((_) {
        connected = true;
      });
      clock.flushMicrotasks();
      expect(connected, isTrue);
      // FakeSocket没有网络时钟；仍验证原26秒边界，不挤占30秒总期限。
      clock.elapse(const Duration(seconds: 26));
      expect(socket.sent, isEmpty);
      expect(socket.closed, isFalse);
      List<ChatMailboxMessage>? mailbox;
      transport.fetchMailbox().then((value) {
        mailbox = value;
      });
      clock.flushMicrotasks();
      expect(socket.sent.single.whichBody(), ChatFrame_Body.syncMessages);
      socket.receive(ChatFrame()..messageBatch = MessageBatch());
      clock.flushMicrotasks();
      expect(mailbox, isEmpty);
      transport.dispose().then((_) {
        closed = true;
      });
      clock.flushMicrotasks();
    });
    // StreamController取消的系统Future在真实zone完成；只排空收尾，不推进协议时间。
    for (var turn = 0; turn < 5 && !closed; turn++) {
      await Future<void>.delayed(Duration.zero);
      clock.flushMicrotasks();
    }
    expect(closed, isTrue);
    expect(socket.closed, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('未请求的应用层Pong继续关闭连接', () async {
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
    socket.receive(ChatFrame()..pong = Pong(sentAtMillis: Int64.ONE));
    await Future<void>.delayed(Duration.zero);
    expect(socket.closed, isTrue);
    expect(transport.lastRealtimeDiagnosticCode, 'realtime_pong_unmatched');
    await transport.dispose();
  });

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

  for (final wrongDevice in [false, true]) {
    test('邮箱实际拒绝错误${wrongDevice ? '设备' : '用户'}且不交付密文', () async {
      final socket = _FakeSocket();
      final transport = ChatServerConnection(
        identity: const ChatDevice(userId: 'local', deviceId: 'device'),
        accessProvider: () async => _access(),
        socketConnector: (_, _) async {
          scheduleMicrotask(() => socket.receive(ChatFrame()..ready = Ready()));
          return socket;
        },
      );
      final pending = transport.fetchMailbox();
      final assertion = expectLater(
        pending,
        throwsA(
          isA<ChatServerConnectionException>().having(
            (error) => error.code,
            'code',
            'mailbox_identity_invalid',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      socket.receive(
        ChatFrame()
          ..messageBatch = MessageBatch(
            messages: [
              EncryptedMessage(
                messageId: 'message',
                conversationId: 'conversation',
                senderUserId: 'peer',
                senderDeviceId: 'peer-device',
                createdAtMillis: Int64.ONE,
                deliveries: [
                  EncryptedDelivery(
                    recipient: Recipient(
                      userId: wrongDevice ? 'local' : 'other',
                      deviceId: wrongDevice ? 'other' : 'device',
                    ),
                    openmlsCiphertext: [1, 2, 3],
                  ),
                ],
              ),
            ],
          ),
      );
      await assertion;
      await transport.dispose();
    });
  }
}

final class _ResourceGate implements ChatResourceGate {
  bool reject = false;
  Completer<void>? wait;
  Completer<void>? connectWait;
  final actions = <String>[];
  int cancelled = 0;
  int finished = 0;
  @override
  Future<ChatResourceLease> reserve(
    String action, {
    List<int> frame = const [],
    int bytes = 0,
  }) async {
    actions.add(action);
    if (action == 'chat_connect') await connectWait?.future;
    if (reject) {
      throw StateError('synthetic-local-limit');
    }
    if (action == 'chat_command') {
      expect(frame, isNotEmpty);
      await wait?.future;
    }
    return _ResourceLease(() => cancelled++, () => finished++);
  }
}

final class _ResourceLease implements ChatResourceLease {
  _ResourceLease(this.onCancel, this.onFinish);
  final void Function() onCancel;
  final void Function() onFinish;
  @override
  void sent() {}
  @override
  void finish({
    ResourceUsage? receipt,
    Map<String, String>? headers,
    bool accepted = true,
    String? errorCode,
  }) {
    onFinish();
  }

  @override
  void cancel() => onCancel();
}
