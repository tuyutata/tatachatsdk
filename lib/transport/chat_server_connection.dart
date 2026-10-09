import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:fixnum/fixnum.dart' as fixnum;

import '../core/chat_message.dart';
import '../mls/mls_boundary.dart';
import '../protocol/attachment.pb.dart' as attachment_protocol;
import '../protocol/chat_frame.pb.dart' as frame_protocol;
import '../protocol/message.dart' as message_protocol;
import 'chat_attachment_transport.dart';
import 'chat_service_transport.dart';
import 'chat_transport.dart';

abstract interface class ChatSocket {
  String? get protocol;
  Stream<Object?> get events;
  void add(List<int> bytes);
  Future<void> close();
}

typedef ChatSocketConnector = Future<ChatSocket> Function(
  Uri uri,
  String bearerToken,
);

final class _IoChatSocket implements ChatSocket {
  _IoChatSocket(this._socket, this._client);

  final WebSocket _socket;
  final HttpClient _client;

  @override
  String? get protocol => _socket.protocol;

  @override
  Stream<Object?> get events => _socket;

  @override
  void add(List<int> bytes) => _socket.add(bytes);

  @override
  Future<void> close() async {
    _client.close(force: true);
    await _socket.close(WebSocketStatus.normalClosure);
  }
}

// 系统 WebSocket 握手仍负责 TLS/升级校验；在它取得的实际 HTTP 请求上关闭重定向。
final class _HandshakeClient implements HttpClient {
  _HandshakeClient(this.client);
  final HttpClient client;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = await client.openUrl(method, url);
    request.followRedirects = false;
    return request;
  }

  @override
  void close({bool force = false}) => client.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ChatSocket> _connectIoSocket(
  Uri uri,
  String bearerToken,
  HttpClient client,
) async {
  if (uri.scheme != 'wss' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw const ChatServerConnectionException('realtime_url_invalid');
  }
  var abandoned = false;
  final opening =
      WebSocket.connect(
        uri.toString(),
        headers: <String, String>{
          HttpHeaders.authorizationHeader: 'Bearer $bearerToken',
        },
        protocols: const <String>['tatachat'],
        maxPayloadLength: _maximumFrameBytes,
        customClient: _HandshakeClient(client),
      ).then((socket) async {
        if (abandoned) {
          await socket.close(WebSocketStatus.normalClosure);
          throw const ChatServerConnectionException(
            'realtime_connect_cancelled',
          );
        }
        return _IoChatSocket(socket, client);
      });
  try {
    return await opening.timeout(_responseDeadline);
  } catch (_) {
    abandoned = true;
    client.close(force: true);
    throw const ChatServerConnectionException('realtime_socket_failed');
  }
}

const _responseDeadline = Duration(seconds: 12);
const _maximumFrameBytes = 2 * 1024 * 1024;
const _maximumQueuedCommands = 128;
const _serverFailureCodes = <String>{
  'invalid_request',
  'forbidden',
  'not_found',
  'conflict',
  'resource_limit',
  'storage_unavailable',
};

final class _CloseAction {
  _CloseAction(this.close);
  final Future<void> Function() close;
  Future<void>? flight;
  bool done = false;
  Future<void> run() {
    if (done) return Future<void>.value();
    final existing = flight;
    if (existing != null) return existing.timeout(_responseDeadline);
    late final Future<void> created;
    created = Future<void>.sync(close)
        .then((_) {
          done = true;
        })
        .whenComplete(() {
          if (identical(flight, created)) flight = null;
        });
    flight = created;
    return created.timeout(_responseDeadline);
  }
}

final class _MailboxMessage implements ChatMailboxMessage {
  _MailboxMessage(message_protocol.EncryptedMessage message)
    : messageId = message.messageId,
      senderUserId = message.senderUserId,
      recipientUserId = message.recipientUserId,
      recipientDeviceId = message.recipientDeviceId,
      conversationId = message.conversationId,
      // Runtime 要复核完整外层路由与原生收据；不能只交付里面的 MLS 密文。
      messageBytes = List<int>.unmodifiable(message.writeToBuffer()),
      createdAtMillis = message.createdAtMillis.toInt();

  @override
  final String messageId;
  @override
  final String senderUserId;
  @override
  final String recipientUserId;
  @override
  final String recipientDeviceId;
  @override
  final String conversationId;
  @override
  final List<int> messageBytes;
  @override
  final int createdAtMillis;
}

final class _PendingCommand<T> {
  _PendingCommand({
    required this.frame,
    required this.accept,
    required this.decode,
  });

  final frame_protocol.ChatFrame frame;
  final bool Function(frame_protocol.ChatFrame frame) accept;
  final T Function(frame_protocol.ChatFrame frame) decode;
  final Completer<T> completer = Completer<T>();
  Timer? deadline;
  bool sent = false;
}

/// TataChatSDK 唯一正式传输。一个连接同一时刻只允许一个命令等待响应。
final class ChatServerConnection implements ChatServiceTransport {
  ChatServerConnection({
    required this.identity,
    required ChatAccessProvider accessProvider,
    ChatSocketConnector? socketConnector,
    ChatHttpAdapterFactory? httpAdapterFactory,
  }) : _accessProvider = accessProvider,
       _socketConnector = socketConnector,
       _httpAdapterFactory = httpAdapterFactory ?? (() => IoChatHttpAdapter());

  final ChatDevice identity;
  final ChatAccessProvider _accessProvider;
  final ChatSocketConnector? _socketConnector;
  final ChatHttpAdapterFactory _httpAdapterFactory;
  final List<_PendingCommand<Object?>> _commands = <_PendingCommand<Object?>>[];

  ChatSocket? _socket;
  HttpClient? _handshakeClient;
  StreamSubscription<Object?>? _subscription;
  ChatAttachmentTransport? _attachments;
  ChatAccess? _access;
  Completer<void>? _connecting;
  Completer<void>? _ready;
  Timer? _pingTimer;
  Timer? _pongDeadline;
  Timer? _expiryTimer;
  int? _pendingPing;
  Future<void> Function(ChatServiceEvent event)? _onEvent;
  Future<void> Function()? _onDisconnected;
  bool _disposed = false;
  bool _readySuccess = false;
  int _generation = 0;
  int _realtimeOwner = 0;
  Future<void>? _disconnecting;
  final List<_CloseAction> _closeActions = [];

  @override
  ChatTransportType get type => ChatTransportType.server;

  @override
  String? lastRealtimeDiagnosticCode;

  @override
  Future<void> connect() async {
    final closing = _disconnecting;
    if (closing != null) await closing;
    if (_closeActions.isNotEmpty) await _closeResources();
    if (_disposed) {
      throw const ChatServerConnectionException('transport_disposed');
    }
    if (_socket != null &&
        _readySuccess &&
        _access?.isUsable(DateTime.now().millisecondsSinceEpoch) == true) {
      return;
    }
    if (_socket != null && _readySuccess) {
      await _disconnect('realtime_access_expired', notify: true);
      if (_disposed) {
        throw const ChatServerConnectionException('transport_disposed');
      }
    }
    final connecting = _connecting;
    if (connecting != null) return connecting.future;

    final completer = Completer<void>();
    _connecting = completer;
    final generation = ++_generation;
    unawaited(_connectOnce(generation, completer));
    return completer.future;
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  void _ensureCurrent(int generation) {
    if (!_current(generation)) {
      throw const ChatServerConnectionException('realtime_connect_cancelled');
    }
  }

  Future<void> _connectOnce(int generation, Completer<void> completer) async {
    try {
      final access = await _accessProvider().timeout(
        _responseDeadline,
        onTimeout: () => throw const ChatServerConnectionException(
          'realtime_access_timeout',
        ),
      );
      _ensureCurrent(generation);
      final now = DateTime.now().millisecondsSinceEpoch;
      access.validate(now);
      var abandoned = false;
      final connector = _socketConnector;
      Future<ChatSocket> socketFuture;
      if (connector == null) {
        final client = HttpClient();
        _handshakeClient = client;
        socketFuture = _connectIoSocket(
          access.realtimeUrl,
          access.accessToken,
          client,
        );
      } else {
        socketFuture = connector(access.realtimeUrl, access.accessToken);
      }
      final opening = socketFuture.then((socket) async {
        if (abandoned || !_current(generation)) {
          _closeActions.add(_CloseAction(socket.close));
          await _closeResources();
          throw const ChatServerConnectionException(
            'realtime_connect_cancelled',
          );
        }
        return socket;
      });
      late final ChatSocket socket;
      try {
        socket = await opening.timeout(_responseDeadline);
      } catch (_) {
        abandoned = true;
        throw const ChatServerConnectionException('realtime_socket_failed');
      }
      _ensureCurrent(generation);
      _handshakeClient = null; // 升级后由 _IoChatSocket 接管同一 client。
      if (socket.protocol != 'tatachat') {
        _closeActions.add(_CloseAction(socket.close));
        await _closeResources();
        throw const ChatServerConnectionException('realtime_protocol_invalid');
      }
      _socket = socket;
      _access = access;
      _readySuccess = false;
      _ready = Completer<void>();
      unawaited(_ready!.future.catchError((Object _) {}));
      final readyFuture = _ready!.future.timeout(
        _responseDeadline,
        onTimeout: () =>
            throw const ChatServerConnectionException('realtime_ready_timeout'),
      );
      // 先接管 HTTP 所有权，之后每个异步阶段失败均由同一回收路径收口。
      _attachments = ChatAttachmentTransport(
        access: access,
        adapter: _httpAdapterFactory(),
      );
      _subscription = socket.events.listen(
        (event) {
          if (_current(generation)) _handleSocketEvent(event);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (_current(generation)) _disconnectSafely('realtime_stream_error');
        },
        onDone: () {
          if (_current(generation)) _disconnectSafely('realtime_closed');
        },
        cancelOnError: false,
      );
      _scheduleExpiry(access.expiresAtMillis, now);
      await readyFuture;
      _ensureCurrent(generation);
      _readySuccess = true;
      _startPing();
      lastRealtimeDiagnosticCode = null;
      if (!completer.isCompleted) completer.complete();
    } catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
      if (_current(generation)) {
        try {
          await _disconnect('realtime_connect_failed', notify: false);
        } catch (_) {
          lastRealtimeDiagnosticCode = 'realtime_cleanup_failed';
        }
      }
    } finally {
      if (identical(_connecting, completer)) _connecting = null;
    }
  }

  void _handleSocketEvent(Object? event) {
    if (_access?.isUsable(DateTime.now().millisecondsSinceEpoch) != true) {
      _disconnectSafely('realtime_access_expired');
      return;
    }
    if (event is! List<int>) {
      _disconnectSafely('realtime_frame_not_binary');
      return;
    }
    if (event.isEmpty || event.length > _maximumFrameBytes) {
      _disconnectSafely('realtime_frame_size_invalid');
      return;
    }
    frame_protocol.ChatFrame frame;
    try {
      frame = frame_protocol.ChatFrame.fromBuffer(event);
      if (frame.unknownFields.isNotEmpty) {
        throw const FormatException('unknown chat frame field');
      }
    } catch (_) {
      _disconnectSafely('realtime_frame_invalid');
      return;
    }
    final ready = _ready;
    if (ready != null && !ready.isCompleted) {
      if (frame.whichBody() != frame_protocol.ChatFrame_Body.ready) {
        ready.completeError(
          const ChatServerConnectionException('realtime_ready_invalid'),
        );
        _disconnectSafely('realtime_ready_invalid');
        return;
      }
      ready.complete();
      _readySuccess = true;
      return;
    }

    switch (frame.whichBody()) {
      case frame_protocol.ChatFrame_Body.ping:
        _disconnectSafely('realtime_frame_direction_invalid');
        return;
      case frame_protocol.ChatFrame_Body.pong:
        if (_pendingPing == frame.pong.sentAtMillis.toInt()) {
          _pendingPing = null;
          _pongDeadline?.cancel();
          _pongDeadline = null;
        } else {
          _disconnectSafely('realtime_pong_unmatched');
        }
        return;
      case frame_protocol.ChatFrame_Body.messageAvailable:
        final callback = _onEvent;
        if (callback != null) {
          final value = frame.messageAvailable;
          unawaited(
            callback(
              ChatMessageAvailableEvent(
                messageId: value.messageId,
                conversationId: value.conversationId,
                serverTimeMillis: value.serverTimeMillis.toInt(),
              ),
            ).catchError((Object _) {}),
          );
        }
        return;
      default:
        break;
    }

    if (_commands.isEmpty) {
      _disconnectSafely('realtime_response_unmatched');
      return;
    }
    final current = _commands.first;
    if (frame.whichBody() == frame_protocol.ChatFrame_Body.failure) {
      _commands.removeAt(0);
      current.deadline?.cancel();
      current.completer.completeError(
        ChatServerConnectionException(
          _serverFailureCodes.contains(frame.failure.code)
              ? frame.failure.code
              : 'server_failure',
        ),
      );
      _dispatchNext();
      return;
    }
    if (!current.accept(frame)) {
      _disconnectSafely('realtime_response_mismatch');
      return;
    }
    _commands.removeAt(0);
    current.deadline?.cancel();
    try {
      current.completer.complete(current.decode(frame));
    } catch (error, stackTrace) {
      current.completer.completeError(error, stackTrace);
      _disconnectSafely('realtime_response_invalid');
      return;
    }
    _dispatchNext();
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_socket == null || _pendingPing != null) return;
      final sentAt = DateTime.now().millisecondsSinceEpoch;
      _pendingPing = sentAt;
      try {
        _send(
          frame_protocol.ChatFrame()
            ..ping = (frame_protocol.Ping()
              ..sentAtMillis = fixnum.Int64(sentAt)),
        );
      } catch (_) {
        _disconnectSafely('realtime_send_failed');
        return;
      }
      _pongDeadline?.cancel();
      _pongDeadline = Timer(const Duration(seconds: 12), () {
        if (_pendingPing == sentAt) {
          _disconnectSafely('realtime_pong_timeout');
        }
      });
    });
  }

  void _scheduleExpiry(int expiresAtMillis, int nowMillis) {
    _expiryTimer?.cancel();
    final delay = math.max(0, expiresAtMillis - nowMillis - 60 * 1000);
    _expiryTimer = Timer(Duration(milliseconds: delay), () {
      _disconnectSafely('realtime_access_expired');
    });
  }

  void _send(frame_protocol.ChatFrame frame) {
    final socket = _socket;
    if (socket == null ||
        _access?.isUsable(DateTime.now().millisecondsSinceEpoch) != true) {
      throw const ChatServerConnectionException('realtime_not_connected');
    }
    final bytes = frame.writeToBuffer();
    if (bytes.isEmpty || bytes.length > _maximumFrameBytes) {
      throw const ChatServerConnectionException('realtime_frame_size_invalid');
    }
    socket.add(bytes);
  }

  Future<T> _command<T>({
    required frame_protocol.ChatFrame frame,
    required bool Function(frame_protocol.ChatFrame frame) accept,
    required T Function(frame_protocol.ChatFrame frame) decode,
  }) async {
    await connect();
    if (_commands.length >= _maximumQueuedCommands) {
      throw const ChatServerConnectionException('realtime_queue_full');
    }
    if (frame.writeToBuffer().length > _maximumFrameBytes) {
      throw const ChatServerConnectionException('realtime_frame_size_invalid');
    }
    final pending = _PendingCommand<T>(
      frame: frame,
      accept: accept,
      decode: decode,
    );
    _commands.add(pending as _PendingCommand<Object?>);
    if (_commands.length == 1) _dispatchNext();
    return pending.completer.future;
  }

  void _dispatchNext() {
    if (_commands.isEmpty || _socket == null || !_readySuccess) {
      return;
    }
    final command = _commands.first;
    if (command.sent) return;
    command.sent = true;
    command.deadline = Timer(_responseDeadline, () {
      if (_commands.isNotEmpty && identical(_commands.first, command)) {
        _disconnectSafely('realtime_command_timeout');
      }
    });
    try {
      _send(command.frame);
    } catch (_) {
      _disconnectSafely('realtime_send_failed');
    }
  }

  bool _success(frame_protocol.ChatFrame frame, String kind, {String? id}) {
    if (frame.whichBody() != frame_protocol.ChatFrame_Body.success ||
        frame.success.kind != kind) {
      return false;
    }
    return id == null || frame.success.ids.contains(id);
  }

  @override
  Future<void> publishKeyPackage(MlsKeyPackage keyPackage) {
    if (keyPackage.userId != identity.userId ||
        keyPackage.deviceId != identity.deviceId) {
      throw const ChatServerConnectionException('key_package_identity_invalid');
    }
    final value = frame_protocol.KeyPackage()
      ..userId = keyPackage.userId
      ..deviceId = keyPackage.deviceId
      ..keyPackageRef = keyPackage.keyPackageRef
      ..keyPackage = keyPackage.keyPackageBytes
      ..cipherSuite = keyPackage.cipherSuite
      ..notBefore = fixnum.Int64(keyPackage.notBeforeMillis)
      ..notAfter = fixnum.Int64(keyPackage.notAfterMillis)
      ..lastResort = keyPackage.lastResort;
    return _command<void>(
      frame: frame_protocol.ChatFrame()
        ..publishKeyPackage = (frame_protocol.PublishKeyPackage()
          ..keyPackage = value),
      accept: (frame) => _success(
        frame,
        'key_package.published',
        id: keyPackage.keyPackageRef,
      ),
      decode: (_) {},
    );
  }

  @override
  Future<List<MlsKeyPackage>> resolveKeyPackages(String recipientUserId) {
    if (recipientUserId.isEmpty) {
      throw const ChatServerConnectionException('recipient_invalid');
    }
    return _command<List<MlsKeyPackage>>(
      frame: frame_protocol.ChatFrame()
        ..resolveKeyPackages = (frame_protocol.ResolveKeyPackages()
          ..userId = recipientUserId
          ..limit = 100),
      accept: (frame) =>
          frame.whichBody() == frame_protocol.ChatFrame_Body.keyPackageBatch,
      decode: (frame) {
        if (frame.keyPackageBatch.keyPackages.length > 100) {
          throw const ChatServerConnectionException(
            'key_package_batch_invalid',
          );
        }
        final devices = <String>{};
        return frame.keyPackageBatch.keyPackages
            .map((value) {
              if (value.userId != recipientUserId ||
                  value.deviceId.isEmpty ||
                  !devices.add(value.deviceId) ||
                  value.keyPackage.isEmpty) {
                throw const ChatServerConnectionException(
                  'key_package_identity_invalid',
                );
              }
              return MlsKeyPackage(
                userId: value.userId,
                deviceId: value.deviceId,
                keyPackageRef: value.keyPackageRef,
                keyPackageBytes: List<int>.unmodifiable(value.keyPackage),
                cipherSuite: value.cipherSuite,
                notBeforeMillis: value.notBefore.toInt(),
                notAfterMillis: value.notAfter.toInt(),
                lastResort: value.lastResort,
              );
            })
            .toList(growable: false);
      },
    );
  }

  @override
  Future<ChatDeliveryResult> sendEncryptedMessage({
    required String messageId,
    required List<int> messageBytes,
    required String recipientUserId,
    required String recipientDeviceId,
  }) async {
    message_protocol.EncryptedMessage message;
    try {
      message = message_protocol.EncryptedMessage.fromBuffer(messageBytes);
    } catch (_) {
      throw const ChatServerConnectionException('message_invalid');
    }
    if (message.messageId != messageId ||
        message.senderUserId != identity.userId ||
        message.senderDeviceId != identity.deviceId ||
        message.recipientUserId != recipientUserId ||
        message.recipientDeviceId != recipientDeviceId) {
      throw const ChatServerConnectionException('message_identity_invalid');
    }
    try {
      await _command<void>(
        frame: frame_protocol.ChatFrame()
          ..sendMessage = (frame_protocol.SendMessage()..message = message),
        accept: (frame) => _success(frame, 'message.accepted', id: messageId),
        decode: (_) {},
      );
      return ChatDeliveryResult(
        messageId: messageId,
        transportType: type,
        state: ChatMessageDeliveryState.sent,
      );
    } on ChatServerConnectionException catch (error) {
      return ChatDeliveryResult(
        messageId: messageId,
        transportType: type,
        state: ChatMessageDeliveryState.failed,
        errorMessage: error.code,
      );
    }
  }

  @override
  Future<List<ChatMailboxMessage>> fetchMailbox() {
    return _command<List<ChatMailboxMessage>>(
      frame: frame_protocol.ChatFrame()
        ..syncMessages = (frame_protocol.SyncMessages()..limit = 100),
      accept: (frame) =>
          frame.whichBody() == frame_protocol.ChatFrame_Body.messageBatch,
      decode: (frame) {
        if (frame.messageBatch.messages.length > 100) {
          throw const ChatServerConnectionException('mailbox_batch_invalid');
        }
        final ids = <String>{};
        return frame.messageBatch.messages
            .map((message) {
              final value = _MailboxMessage(message);
              if (value.recipientUserId != identity.userId ||
                  value.recipientDeviceId != identity.deviceId ||
                  value.messageId.isEmpty ||
                  !ids.add(value.messageId) ||
                  value.messageBytes.isEmpty) {
                throw const ChatServerConnectionException(
                  'mailbox_identity_invalid',
                );
              }
              return value;
            })
            .toList(growable: false);
      },
    );
  }

  @override
  Future<void> acknowledgeMailbox(List<String> messageIds) async {
    if (messageIds.any((id) => id.isEmpty)) {
      throw const ChatServerConnectionException('mailbox_ack_invalid');
    }
    final ids = messageIds.toSet().toList(growable: false);
    for (var offset = 0; offset < ids.length; offset += 100) {
      final batch = ids.sublist(offset, math.min(ids.length, offset + 100));
      final value = frame_protocol.AcknowledgeMessages()
        ..messageIds.addAll(batch);
      await _command<void>(
        frame: frame_protocol.ChatFrame()..acknowledgeMessages = value,
        accept: (frame) =>
            _success(frame, 'messages.acknowledged') &&
            frame.success.ids.length == batch.length &&
            frame.success.ids.toSet().containsAll(batch),
        decode: (_) {},
      );
    }
  }

  @override
  Future<void> registerPushEndpoint({
    required String pushProvider,
    required String pushToken,
    required String? apnsEnvironment,
    required int expiresAtMillis,
  }) {
    final platform = switch (pushProvider.toLowerCase()) {
      'ios' || 'apns' => 'ios',
      'android' || 'fcm' => 'android',
      _ => throw const ChatServerConnectionException('push_platform_invalid'),
    };
    return _command<void>(
      frame: frame_protocol.ChatFrame()
        ..registerPush = (frame_protocol.RegisterPush()
          ..platform = platform
          ..token = pushToken),
      accept: (frame) => _success(frame, 'push.registered'),
      decode: (_) {},
    );
  }

  @override
  Future<void> uploadEncryptedAttachment({
    required String attachmentId,
    required List<String> recipientUserIds,
    required File cipherFile,
    required int cipherByteSize,
    required String cipherSha256,
    required int createdAtMillis,
  }) async {
    if (cipherByteSize <= 0 ||
        cipherByteSize > chatAttachmentChunkBytes * 10000 ||
        createdAtMillis <= 0 ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(attachmentId) ||
        recipientUserIds.isEmpty ||
        recipientUserIds.length > 256 ||
        recipientUserIds.any((value) => value.isEmpty)) {
      throw const ChatServerConnectionException('attachment_metadata_invalid');
    }
    final stat = await cipherFile.stat();
    if (stat.type != FileSystemEntityType.file || stat.size != cipherByteSize) {
      throw const ChatServerConnectionException('attachment_size_invalid');
    }
    final actualWholeHash =
        (await crypto.sha256.bind(cipherFile.openRead()).first).toString();
    if (actualWholeHash != cipherSha256.toLowerCase()) {
      throw const ChatServerConnectionException('attachment_hash_mismatch');
    }

    final chunks = <attachment_protocol.AttachmentChunk>[];
    final file = await cipherFile.open();
    try {
      var offset = 0;
      var index = 0;
      while (offset < cipherByteSize) {
        final size = math.min(
          chatAttachmentChunkBytes,
          cipherByteSize - offset,
        );
        final bytes = await file.read(size);
        if (bytes.length != size) {
          throw const ChatServerConnectionException('attachment_size_invalid');
        }
        chunks.add(
          attachment_protocol.AttachmentChunk()
            ..chunkIndex = index
            ..cipherByteSize = fixnum.Int64(size)
            ..cipherSha256 = crypto.sha256.convert(bytes).toString(),
        );
        offset += size;
        index += 1;
      }
    } finally {
      await file.close();
    }

    final metadata = attachment_protocol.AttachmentMetadata()
      ..attachmentId = attachmentId
      ..senderUserId = identity.userId
      ..recipientUserIds.addAll(recipientUserIds.toSet())
      ..chunks.addAll(chunks)
      ..cipherByteSize = fixnum.Int64(cipherByteSize)
      ..cipherSha256 = actualWholeHash
      ..createdAtMillis = fixnum.Int64(createdAtMillis);
    // 只有 Ready 是完成证明。未得到证明时以原元数据继续幂等 begin；
    // storage_unavailable 也可能是缺块断言失败，不能据此 abort 或声称成功。
    if (await _attachmentIsComplete(attachmentId)) return;
    await _command<void>(
      frame: frame_protocol.ChatFrame()
        ..beginAttachment = (frame_protocol.BeginAttachment()
          ..attachment = metadata),
      accept: (frame) => _success(frame, 'attachment.begun', id: attachmentId),
      decode: (_) {},
    );
    if (await _attachmentIsComplete(attachmentId)) return;

    {
      final attachments = _attachments;
      if (attachments == null) {
        throw const ChatServerConnectionException('attachment_not_connected');
      }
      final input = await cipherFile.open();
      try {
        for (final chunk in chunks) {
          final bytes = await input.read(chunk.cipherByteSize.toInt());
          await attachments.putChunk(
            attachmentId: attachmentId,
            chunkIndex: chunk.chunkIndex,
            bytes: Uint8List.fromList(bytes),
            cipherSha256: chunk.cipherSha256,
          );
        }
      } finally {
        await input.close();
      }
      await _completeAttachment(attachmentId);
    }
  }

  Future<void> _completeAttachment(String attachmentId) => _command<void>(
    frame: frame_protocol.ChatFrame()
      ..completeAttachment = (frame_protocol.CompleteAttachment()
        ..attachmentId = attachmentId),
    accept: (frame) =>
        frame.whichBody() == frame_protocol.ChatFrame_Body.attachmentReady &&
        frame.attachmentReady.attachmentId == attachmentId,
    decode: (_) {},
  );

  Future<bool> _attachmentIsComplete(String attachmentId) async {
    try {
      await _completeAttachment(attachmentId);
      return true;
    } on ChatServerConnectionException catch (error) {
      if (const {
        'not_found',
        'conflict',
        'storage_unavailable',
      }.contains(error.code)) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<void> downloadEncryptedAttachment({
    required String attachmentId,
    required File target,
    required int expectedByteSize,
    required String expectedSha256,
  }) async {
    if (expectedByteSize <= 0) {
      throw const ChatServerConnectionException('attachment_size_invalid');
    }
    final normalizedHash = expectedSha256.toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalizedHash)) {
      throw const ChatServerConnectionException('attachment_hash_invalid');
    }
    await connect();
    final attachments = _attachments;
    if (attachments == null) {
      throw const ChatServerConnectionException('attachment_not_connected');
    }
    await target.parent.create(recursive: true);
    IOSink? output;
    try {
      output = target.openWrite(mode: FileMode.writeOnly);
      var offset = 0;
      var index = 0;
      while (offset < expectedByteSize) {
        final size = math.min(
          chatAttachmentChunkBytes,
          expectedByteSize - offset,
        );
        final bytes = await attachments.getChunk(
          attachmentId: attachmentId,
          chunkIndex: index,
          expectedBytes: size,
        );
        output.add(bytes);
        offset += bytes.length;
        index += 1;
      }
      await output.flush();
      await output.close();
      output = null;
      final stat = await target.stat();
      final actualHash = (await crypto.sha256.bind(target.openRead()).first)
          .toString();
      if (stat.size != expectedByteSize || actualHash != normalizedHash) {
        throw const ChatServerConnectionException('attachment_hash_mismatch');
      }
    } catch (_) {
      if (output != null) await output.close();
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  @override
  Future<void> acknowledgeAttachment(String attachmentId) => _command<void>(
    frame: frame_protocol.ChatFrame()
      ..acknowledgeAttachment = (frame_protocol.AcknowledgeAttachment()
        ..attachmentId = attachmentId),
    accept: (frame) =>
        _success(frame, 'attachment.acknowledged', id: attachmentId),
    decode: (_) {},
  );

  @override
  Future<void> abortAttachment(String attachmentId) => _command<void>(
    frame: frame_protocol.ChatFrame()
      ..abortAttachment = (frame_protocol.AbortAttachment()
        ..attachmentId = attachmentId),
    accept: (frame) => _success(frame, 'attachment.aborted', id: attachmentId),
    decode: (_) {},
  );

  @override
  Future<Future<void> Function()> connectRealtime({
    required Future<void> Function(ChatServiceEvent event) onEvent,
    Future<void> Function()? onDisconnected,
  }) async {
    _onEvent = onEvent;
    _onDisconnected = onDisconnected;
    final owner = ++_realtimeOwner;
    await connect();
    var active = true;
    return () async {
      if (!active) return;
      if (owner != _realtimeOwner) {
        active = false;
        return;
      }
      _onEvent = null;
      _onDisconnected = null;
      await _disconnect('realtime_stopped', notify: false);
      active = false;
    };
  }

  void _disconnectSafely(String code) {
    unawaited(
      _disconnect(code, notify: true).catchError((Object _) {
        lastRealtimeDiagnosticCode = 'realtime_cleanup_failed';
      }),
    );
  }

  Future<void> _closeResources() async {
    var failed = false;
    await Future.wait(
      List<_CloseAction>.of(_closeActions).map((action) async {
        try {
          await action.run();
        } catch (_) {
          failed = true;
        }
        if (action.done) _closeActions.remove(action);
      }),
    );
    if (failed) {
      throw const ChatServerConnectionException('realtime_cleanup_failed');
    }
  }

  Future<void> _disconnect(String code, {required bool notify}) {
    final existing = _disconnecting;
    if (existing != null) return existing;
    // 代际先失效，再等待资源关闭。迟到 provider/socket 和旧 stream 不能重新交付。
    ++_generation;
    _readySuccess = false;
    _access = null;
    lastRealtimeDiagnosticCode = code;
    _pingTimer?.cancel();
    _pongDeadline?.cancel();
    _expiryTimer?.cancel();
    _pingTimer = null;
    _pongDeadline = null;
    _expiryTimer = null;
    _pendingPing = null;
    final subscription = _subscription;
    final socket = _socket;
    final handshakeClient = _handshakeClient;
    _handshakeClient = null;
    final attachments = _attachments;
    _subscription = null;
    _socket = null;
    _attachments = null;
    final ready = _ready;
    _ready = null;
    final connecting = _connecting;
    _connecting = null;
    if (connecting != null && !connecting.isCompleted) {
      connecting.completeError(ChatServerConnectionException(code));
    }
    if (ready != null && !ready.isCompleted) {
      ready.completeError(ChatServerConnectionException(code));
    }
    final pending = List<_PendingCommand<Object?>>.from(_commands);
    _commands.clear();
    for (final command in pending) {
      command.deadline?.cancel();
      if (!command.completer.isCompleted) {
        command.completer.completeError(ChatServerConnectionException(code));
      }
    }
    if (handshakeClient != null) {
      _closeActions.add(
        _CloseAction(() async {
          handshakeClient.close(force: true);
        }),
      );
    }
    if (subscription != null) {
      _closeActions.add(_CloseAction(subscription.cancel));
    }
    if (socket != null) _closeActions.add(_CloseAction(socket.close));
    if (attachments != null) {
      _closeActions.add(_CloseAction(attachments.dispose));
    }
    final callback = notify && !_disposed ? _onDisconnected : null;
    late final Future<void> created;
    created =
        () async {
          try {
            await _closeResources();
          } finally {
            if (callback != null && !_disposed) {
              try {
                await callback().timeout(_responseDeadline);
              } catch (_) {
                /* 回调不改变资源关闭结果。 */
              }
            }
          }
        }().whenComplete(() {
          if (identical(_disconnecting, created)) _disconnecting = null;
        });
    _disconnecting = created;
    return created;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _onEvent = null;
    _onDisconnected = null;
    await _disconnect('transport_disposed', notify: false);
    await _closeResources();
  }
}
