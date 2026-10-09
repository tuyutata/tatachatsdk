import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';
import 'package:tatachat_sdk/transport/chat_attachment_transport.dart';
import 'package:tatachat_sdk/transport/chat_server_connection.dart';

final class _Socket implements ChatSocket {
  final controller = StreamController<Object?>();
  final sent = <ChatFrame>[];
  void Function(ChatFrame)? respond;
  int closes = 0;
  bool failClose = false;
  @override
  String? get protocol => 'tatachat';
  @override
  Stream<Object?> get events => controller.stream;
  @override
  void add(List<int> bytes) {
    final frame = ChatFrame.fromBuffer(bytes);
    sent.add(frame);
    respond?.call(frame);
  }

  void receive(ChatFrame frame) => controller.add(frame.writeToBuffer());
  @override
  Future<void> close() async {
    closes++;
    if (failClose) throw StateError('synthetic close failure');
    if (!controller.isClosed) unawaited(controller.close());
  }
}

final class _Http implements ChatHttpAdapter {
  final response = Completer<ChatHttpResponse>();
  final enteredGet = Completer<void>();
  int closes = 0;
  int puts = 0;
  int successfulPuts = 0;
  int putFailures = 0;
  bool pendingPut = false;
  @override
  Future<ChatHttpResponse> putChunk({
    required Uri uri,
    required String bearerToken,
    required Uint8List body,
    required String cipherSha256,
  }) async {
    puts++;
    if (putFailures > 0) {
      putFailures--;
      throw const ChatServerConnectionException('attachment_network_failed');
    }
    if (pendingPut) return response.future;
    successfulPuts++;
    return ChatHttpResponse(statusCode: 204, headers: {}, body: Uint8List(0));
  }

  @override
  Future<ChatHttpResponse> getChunk({
    required Uri uri,
    required String bearerToken,
    required int maximumBytes,
  }) {
    if (!enteredGet.isCompleted) enteredGet.complete();
    return response.future;
  }

  @override
  Future<void> dispose() async {
    closes++;
  }
}

ChatAccess _access({int lifetime = 300000}) => ChatAccess(
  realtimeUrl: Uri.parse('wss://chat.example.test/api/tatachat/realtime'),
  accessToken: 'opaque-token',
  expiresAtMillis: DateTime.now().millisecondsSinceEpoch + lifetime,
);

ChatServerConnection _connection({
  ChatAccessProvider? access,
  required ChatSocketConnector connector,
  _Http? http,
}) => ChatServerConnection(
  identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
  accessProvider: access ?? () async => _access(),
  socketConnector: connector,
  httpAdapterFactory: http == null ? null : () => http,
);

Future<ChatSocket> _ready(_Socket socket) async {
  scheduleMicrotask(
    () =>
        socket.receive(ChatFrame()..ready = Ready(serverTimeMillis: Int64.ONE)),
  );
  return socket;
}

void main() {
  test('超出2MiB的入站帧在解析前关闭，方向错误的Ping也不能回Pong', () async {
    for (final oversized in [true, false]) {
      final socket = _Socket(), http = _Http();
      final transport = _connection(
        connector: (_, _) => _ready(socket),
        http: http,
      );
      await transport.connect();
      if (oversized) {
        socket.controller.add(Uint8List(2 * 1024 * 1024 + 1));
      } else {
        socket.receive(ChatFrame()..ping = Ping(sentAtMillis: Int64.ONE));
      }
      await Future<void>.delayed(Duration.zero);
      expect(socket.closes, 1);
      expect(http.closes, 1);
      expect(socket.sent, isEmpty);
      await transport.dispose();
    }
  });
  test('分块中断后以同 ID 同创建时间和原摘要重试 begin，不盲目 abort', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chat-chunk-retry-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/cipher');
    await file.writeAsBytes([1, 2, 3]);
    final http = _Http()..putFailures = 1, socket = _Socket();
    final metadata = <List<int>>[];
    socket.respond = (frame) {
      if (frame.whichBody() == ChatFrame_Body.beginAttachment) {
        metadata.add(frame.beginAttachment.attachment.writeToBuffer());
        socket.receive(
          ChatFrame()
            ..success = Success(
              kind: 'attachment.begun',
              ids: ['attachment-a'],
            ),
        );
      } else if (frame.whichBody() == ChatFrame_Body.completeAttachment) {
        socket.receive(
          http.successfulPuts == 0
              ? (ChatFrame()..failure = Failure(code: 'storage_unavailable'))
              : (ChatFrame()
                  ..attachmentReady = AttachmentReady(
                    attachmentId: 'attachment-a',
                  )),
        );
      } else {
        fail('unexpected command');
      }
    };
    final transport = _connection(
      connector: (_, _) => _ready(socket),
      http: http,
    );
    Future<void> upload() => transport.uploadEncryptedAttachment(
      attachmentId: 'attachment-a',
      recipientUserIds: ['user-b'],
      cipherFile: file,
      cipherByteSize: 3,
      cipherSha256: crypto.sha256.convert([1, 2, 3]).toString(),
      createdAtMillis: 567,
    );
    await expectLater(upload(), throwsA(isA<ChatServerConnectionException>()));
    await upload();
    expect(metadata, hasLength(2));
    expect(metadata.first, metadata.last);
    expect(http.puts, 2);
    expect(
      socket.sent.where(
        (frame) => frame.whichBody() == ChatFrame_Body.abortAttachment,
      ),
      isEmpty,
    );
    await transport.dispose();
  });

  test('停止期间迟到许可不能创建 socket，原 provider 故障保留', () async {
    final access = Completer<ChatAccess>();
    var opens = 0;
    final transport = _connection(
      access: () => access.future,
      connector: (_, _) async {
        opens++;
        return _Socket();
      },
    );
    final rejected = expectLater(
      transport.connect(),
      throwsA(isA<ChatServerConnectionException>()),
    );
    await Future<void>.delayed(Duration.zero);
    await transport.dispose();
    access.complete(_access());
    await rejected;
    await Future<void>.delayed(Duration.zero);
    expect(opens, 0);

    final error = StateError('synthetic host error');
    final failed = _connection(
      access: () async => throw error,
      connector: (_, _) async => _Socket(),
    );
    await expectLater(failed.connect(), throwsA(same(error)));
    await failed.dispose();
  });

  test('迟到 socket 必须关闭，不能恢复已停止的连接', () async {
    final entered = Completer<void>(), opening = Completer<ChatSocket>();
    final transport = _connection(
      connector: (_, _) {
        entered.complete();
        return opening.future;
      },
    );
    final rejected = expectLater(
      transport.connect(),
      throwsA(isA<ChatServerConnectionException>()),
    );
    await entered.future;
    await transport.dispose();
    final lateSocket = _Socket();
    opening.complete(lateSocket);
    await rejected;
    await Future<void>.delayed(Duration.zero);
    expect(lateSocket.closes, 1);
  });

  test('失败 Ready 不能当作就绪，下次连接重新取许可', () async {
    final sockets = [_Socket(), _Socket()];
    var reads = 0, opens = 0;
    final transport = _connection(
      access: () async {
        reads++;
        return _access();
      },
      connector: (_, _) async {
        final socket = sockets[opens++];
        scheduleMicrotask(
          () => socket.receive(
            opens == 1
                ? (ChatFrame()..success = Success(kind: 'unexpected'))
                : (ChatFrame()..ready = Ready()),
          ),
        );
        return socket;
      },
    );
    await expectLater(
      transport.connect(),
      throwsA(isA<ChatServerConnectionException>()),
    );
    await transport.connect();
    expect(reads, 2);
    expect(sockets.first.closes, 1);
    await transport.dispose();
  });

  test('命令超时关闭整条连接，后续排队命令不能匹配迟到回执', () async {
    final socket = _Socket(), http = _Http();
    final transport = _connection(
      connector: (_, _) => _ready(socket),
      http: http,
    );
    await transport.connect();
    final first = expectLater(
      transport.resolveKeyPackages('user-b'),
      throwsA(isA<ChatServerConnectionException>()),
    );
    final second = expectLater(
      transport.resolveKeyPackages('user-c'),
      throwsA(isA<ChatServerConnectionException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(socket.sent, hasLength(1));
    // 传输层使用真实异步资源；跨过现行12秒期限后核验关闭与排队拒绝。
    await Future<void>.delayed(const Duration(seconds: 13));
    await Future.wait([first, second]);
    expect(socket.sent, hasLength(1));
    expect(socket.closes, 1);
    expect(http.closes, 1);
    await transport.dispose();
  });

  test('许可截止同时关闭 WSS 和在途 HTTPS，晚响应不能变成成功', () async {
    final socket = _Socket(), http = _Http();
    final transport = _connection(
      access: () async => _access(lifetime: 61000),
      connector: (_, _) => _ready(socket),
      http: http,
    );
    await transport.connect();
    final directory = await Directory.systemTemp.createTemp('chat-expiry-');
    addTearDown(() => directory.delete(recursive: true));
    final pending = expectLater(
      transport.downloadEncryptedAttachment(
        attachmentId: 'attachment-a',
        target: File('${directory.path}/cipher'),
        expectedByteSize: 1,
        expectedSha256: crypto.sha256.convert([1]).toString(),
      ),
      throwsA(isA<ChatServerConnectionException>()),
    );
    await http.enteredGet.future;
    await pending;
    http.response.complete(
      ChatHttpResponse(
        statusCode: 200,
        headers: {
          'content-length': '1',
          'x-chat-cipher-sha256': crypto.sha256.convert([1]).toString(),
        },
        body: Uint8List.fromList([1]),
      ),
    );
    expect(socket.closes, 1);
    expect(http.closes, 1);
    await transport.dispose();
  });

  test('关闭失败保留资源并可重试，已关闭 HTTP 不重复回收', () async {
    final socket = _Socket()..failClose = true, http = _Http();
    final transport = _connection(
      connector: (_, _) => _ready(socket),
      http: http,
    );
    await transport.connect();
    await expectLater(
      transport.dispose(),
      throwsA(isA<ChatServerConnectionException>()),
    );
    expect(http.closes, 1);
    socket.failClose = false;
    await transport.dispose();
    expect(socket.closes, 2);
    expect(http.closes, 1);
  });

  test('同 ID 附件重试固定元数据，丢失完成响应不 abort，Ready 才成功', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chat-attachment-retry-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/cipher');
    await file.writeAsBytes([1, 2, 3]);
    final hash = crypto.sha256.convert([1, 2, 3]).toString();
    final http = _Http(), socket = _Socket();
    final metadata = <List<int>>[];
    var completed = false, loseReply = true;
    socket.respond = (frame) {
      switch (frame.whichBody()) {
        case ChatFrame_Body.beginAttachment:
          metadata.add(frame.beginAttachment.attachment.writeToBuffer());
          socket.receive(
            ChatFrame()
              ..success = Success(
                kind: 'attachment.begun',
                ids: ['attachment-a'],
              ),
          );
        case ChatFrame_Body.completeAttachment:
          if (!completed && http.puts == 0) {
            socket.receive(ChatFrame()..failure = Failure(code: 'not_found'));
          } else if (loseReply) {
            completed = true;
            socket.receive(
              ChatFrame()..failure = Failure(code: 'storage_unavailable'),
            );
          } else {
            socket.receive(
              ChatFrame()
                ..attachmentReady = AttachmentReady(
                  attachmentId: 'attachment-a',
                ),
            );
          }
        default:
          fail('unexpected command');
      }
    };
    final transport = _connection(
      connector: (_, _) => _ready(socket),
      http: http,
    );
    Future<void> upload() => transport.uploadEncryptedAttachment(
      attachmentId: 'attachment-a',
      recipientUserIds: ['user-b'],
      cipherFile: file,
      cipherByteSize: 3,
      cipherSha256: hash,
      createdAtMillis: 123,
    );
    await expectLater(upload(), throwsA(isA<ChatServerConnectionException>()));
    expect(
      socket.sent.where((f) => f.whichBody() == ChatFrame_Body.abortAttachment),
      isEmpty,
    );
    expect(metadata.single, isNotEmpty);
    expect(
      AttachmentMetadata.fromBuffer(metadata.single).createdAtMillis.toInt(),
      123,
    );
    loseReply = false;
    await upload();
    expect(metadata, hasLength(1));
    expect(http.puts, 1);
    await transport.dispose();
  });
}
