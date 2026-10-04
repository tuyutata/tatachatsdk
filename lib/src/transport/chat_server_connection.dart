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
import 'chat_service_transport.dart';
import 'chat_transport.dart';
import 'tata_chat_server_attachment_transport.dart';

abstract interface class TataChatServerSocket {
  String? get protocol;
  Stream<Object?> get events;
  void add(List<int> bytes);
  Future<void> close();
}

typedef TataChatServerSocketConnector =
    Future<TataChatServerSocket> Function(Uri uri, String bearerToken);

final class _IoTataChatServerSocket implements TataChatServerSocket {
  _IoTataChatServerSocket(this._socket);

  final WebSocket _socket;

  @override
  String? get protocol => _socket.protocol;

  @override
  Stream<Object?> get events => _socket;

  @override
  void add(List<int> bytes) => _socket.add(bytes);

  @override
  Future<void> close() => _socket.close(WebSocketStatus.normalClosure);
}

Future<TataChatServerSocket> _connectIoSocket(
  Uri uri,
  String bearerToken,
) async {
  if (uri.scheme != 'wss' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw const ChatServerConnectionException('realtime_url_invalid');
  }
  final socket = await WebSocket.connect(
    uri.toString(),
    headers: <String, String>{
      HttpHeaders.authorizationHeader: 'Bearer $bearerToken',
    },
    protocols: const <String>['tatachatserver'],
  );
  return _IoTataChatServerSocket(socket);
}

final class _MailboxMessage implements ChatMailboxMessage {
  _MailboxMessage(message_protocol.EncryptedMessage message)
    : messageId = message.messageId,
      senderUserId = message.senderUserId,
      recipientUserId = message.recipientUserId,
      recipientDeviceId = message.recipientDeviceId,
      conversationId = message.conversationId,
      messageBytes = List<int>.unmodifiable(message.openmlsCiphertext),
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
}

/// TataChatSDK 唯一正式传输。一个连接同一时刻只允许一个命令等待响应。
final class ChatServerConnection implements ChatServiceTransport {
  ChatServerConnection({
    required this.identity,
    required TataChatServerAccessProvider accessProvider,
    TataChatServerSocketConnector? socketConnector,
    TataChatServerHttpAdapterFactory? httpAdapterFactory,
  }) : _accessProvider = accessProvider,
       _socketConnector = socketConnector ?? _connectIoSocket,
       _httpAdapterFactory =
           httpAdapterFactory ?? (() => IoTataChatServerHttpAdapter());

  final ChatDevice identity;
  final TataChatServerAccessProvider _accessProvider;
  final TataChatServerSocketConnector _socketConnector;
  final TataChatServerHttpAdapterFactory _httpAdapterFactory;
  final List<_PendingCommand<Object?>> _commands = <_PendingCommand<Object?>>[];

  TataChatServerSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  TataChatServerAttachmentTransport? _attachments;
  Completer<void>? _connecting;
  Completer<void>? _ready;
  Timer? _pingTimer;
  Timer? _pongDeadline;
  Timer? _expiryTimer;
  int? _pendingPing;
  Future<void> Function(ChatServiceEvent event)? _onEvent;
  Future<void> Function()? _onDisconnected;
  bool _disposed = false;
  bool _closing = false;

  @override
  ChatTransportType get type => ChatTransportType.server;

  @override
  String? lastRealtimeDiagnosticCode;

  @override
  Future<void> connect() {
    if (_disposed) {
      return Future<void>.error(
        const ChatServerConnectionException('transport_disposed'),
      );
    }
    if (_socket != null && _ready?.isCompleted == true) {
      return Future<void>.value();
    }
    final connecting = _connecting;
    if (connecting != null) return connecting.future;

    final completer = Completer<void>();
    _connecting = completer;
    unawaited(_connectOnce(completer));
    return completer.future;
  }

  Future<void> _connectOnce(Completer<void> completer) async {
    try {
      final access = await _accessProvider();
      final now = DateTime.now().millisecondsSinceEpoch;
      access.validate(now);
      final socket = await _socketConnector(
        access.realtimeUrl,
        access.tataChatServerToken,
      );
      if (socket.protocol != 'tatachatserver') {
        await socket.close();
        throw const ChatServerConnectionException('realtime_protocol_invalid');
      }
      _socket = socket;
      _ready = Completer<void>();
      _subscription = socket.events.listen(
        _handleSocketEvent,
        onError: (Object error, StackTrace stackTrace) {
          unawaited(_disconnect('realtime_stream_error', notify: true));
        },
        onDone: () {
          unawaited(_disconnect('realtime_closed', notify: true));
        },
        cancelOnError: false,
      );
      final oldAttachments = _attachments;
      _attachments = TataChatServerAttachmentTransport(
        access: access,
        adapter: _httpAdapterFactory(),
      );
      if (oldAttachments != null) await oldAttachments.dispose();
      _scheduleExpiry(access.expiresAtMillis, now);
      await _ready!.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () =>
            throw const ChatServerConnectionException('realtime_ready_timeout'),
      );
      _startPing();
      lastRealtimeDiagnosticCode = null;
      completer.complete();
    } catch (error, stackTrace) {
      await _disconnect('realtime_connect_failed', notify: false);
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    } finally {
      if (identical(_connecting, completer)) _connecting = null;
    }
  }

  void _handleSocketEvent(Object? event) {
    if (event is! List<int>) {
      unawaited(_disconnect('realtime_frame_not_binary', notify: true));
      return;
    }
    frame_protocol.ChatFrame frame;
    try {
      frame = frame_protocol.ChatFrame.fromBuffer(event);
    } catch (_) {
      unawaited(_disconnect('realtime_frame_invalid', notify: true));
      return;
    }
    final ready = _ready;
    if (ready != null && !ready.isCompleted) {
      if (frame.whichBody() != frame_protocol.ChatFrame_Body.ready) {
        ready.completeError(
          const ChatServerConnectionException('realtime_ready_invalid'),
        );
        unawaited(_disconnect('realtime_ready_invalid', notify: true));
        return;
      }
      ready.complete();
      _dispatchNext();
      return;
    }

    switch (frame.whichBody()) {
      case frame_protocol.ChatFrame_Body.ping:
        final pong = frame_protocol.Pong()
          ..sentAtMillis = frame.ping.sentAtMillis
          ..serverTimeMillis = fixnum.Int64(
            DateTime.now().millisecondsSinceEpoch,
          );
        _send(frame_protocol.ChatFrame()..pong = pong);
        return;
      case frame_protocol.ChatFrame_Body.pong:
        if (_pendingPing == frame.pong.sentAtMillis.toInt()) {
          _pendingPing = null;
          _pongDeadline?.cancel();
          _pongDeadline = null;
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
      unawaited(_disconnect('realtime_response_unmatched', notify: true));
      return;
    }
    final current = _commands.first;
    if (frame.whichBody() == frame_protocol.ChatFrame_Body.failure) {
      _commands.removeAt(0);
      current.completer.completeError(
        ChatServerConnectionException(
          frame.failure.code.isEmpty ? 'server_failure' : frame.failure.code,
        ),
      );
      _dispatchNext();
      return;
    }
    if (!current.accept(frame)) {
      unawaited(_disconnect('realtime_response_mismatch', notify: true));
      return;
    }
    _commands.removeAt(0);
    try {
      current.completer.complete(current.decode(frame));
    } catch (error, stackTrace) {
      current.completer.completeError(error, stackTrace);
    }
    _dispatchNext();
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_socket == null || _pendingPing != null) return;
      final sentAt = DateTime.now().millisecondsSinceEpoch;
      _pendingPing = sentAt;
      _send(
        frame_protocol.ChatFrame()
          ..ping = (frame_protocol.Ping()..sentAtMillis = fixnum.Int64(sentAt)),
      );
      _pongDeadline?.cancel();
      _pongDeadline = Timer(const Duration(seconds: 12), () {
        if (_pendingPing == sentAt) {
          unawaited(_disconnect('realtime_pong_timeout', notify: true));
        }
      });
    });
  }

  void _scheduleExpiry(int expiresAtMillis, int nowMillis) {
    _expiryTimer?.cancel();
    final delay = math.max(0, expiresAtMillis - nowMillis - 60 * 1000);
    _expiryTimer = Timer(Duration(milliseconds: delay), () {
      unawaited(_disconnect('realtime_access_expired', notify: true));
    });
  }

  void _send(frame_protocol.ChatFrame frame) {
    final socket = _socket;
    if (socket == null) {
      throw const ChatServerConnectionException('realtime_not_connected');
    }
    socket.add(frame.writeToBuffer());
  }

  Future<T> _command<T>({
    required frame_protocol.ChatFrame frame,
    required bool Function(frame_protocol.ChatFrame frame) accept,
    required T Function(frame_protocol.ChatFrame frame) decode,
  }) async {
    await connect();
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
    if (_commands.isEmpty || _socket == null || _ready?.isCompleted != true) {
      return;
    }
    if (_commands.length > 1 && _commands[1].completer.isCompleted) return;
    _send(_commands.first.frame);
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
      decode: (frame) => frame.keyPackageBatch.keyPackages
          .map(
            (value) => MlsKeyPackage(
              userId: value.userId,
              deviceId: value.deviceId,
              keyPackageRef: value.keyPackageRef,
              keyPackageBytes: List<int>.unmodifiable(value.keyPackage),
              cipherSuite: value.cipherSuite,
              notBeforeMillis: value.notBefore.toInt(),
              notAfterMillis: value.notAfter.toInt(),
              lastResort: value.lastResort,
            ),
          )
          .toList(growable: false),
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
        ..syncMessages = (frame_protocol.SyncMessages()..limit = 1000),
      accept: (frame) =>
          frame.whichBody() == frame_protocol.ChatFrame_Body.messageBatch,
      decode: (frame) => frame.messageBatch.messages
          .map((message) {
            final value = _MailboxMessage(message);
            if (value.recipientUserId != identity.userId ||
                value.recipientDeviceId != identity.deviceId) {
              throw const ChatServerConnectionException(
                'mailbox_identity_invalid',
              );
            }
            return value;
          })
          .toList(growable: false),
    );
  }

  @override
  Future<void> acknowledgeMailbox(List<String> messageIds) {
    if (messageIds.isEmpty) return Future<void>.value();
    final value = frame_protocol.AcknowledgeMessages()
      ..messageIds.addAll(messageIds);
    return _command<void>(
      frame: frame_protocol.ChatFrame()..acknowledgeMessages = value,
      accept: (frame) => _success(frame, 'messages.acknowledged'),
      decode: (_) {},
    );
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
  }) async {
    if (cipherByteSize <= 0 ||
        recipientUserIds.isEmpty ||
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
      ..createdAtMillis = fixnum.Int64(DateTime.now().millisecondsSinceEpoch);
    await _command<void>(
      frame: frame_protocol.ChatFrame()
        ..beginAttachment = (frame_protocol.BeginAttachment()
          ..attachment = metadata),
      accept: (frame) => _success(frame, 'attachment.begun', id: attachmentId),
      decode: (_) {},
    );

    try {
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
      await _command<void>(
        frame: frame_protocol.ChatFrame()
          ..completeAttachment = (frame_protocol.CompleteAttachment()
            ..attachmentId = attachmentId),
        accept: (frame) =>
            frame.whichBody() ==
                frame_protocol.ChatFrame_Body.attachmentReady &&
            frame.attachmentReady.attachmentId == attachmentId,
        decode: (_) {},
      );
    } catch (_) {
      try {
        await abortAttachment(attachmentId);
      } catch (_) {}
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
    await connect();
    var active = true;
    return () async {
      if (!active) return;
      active = false;
      _onEvent = null;
      _onDisconnected = null;
      await _disconnect('realtime_stopped', notify: false);
    };
  }

  Future<void> _disconnect(String code, {required bool notify}) async {
    if (_closing) return;
    _closing = true;
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
    _subscription = null;
    _socket = null;
    final ready = _ready;
    _ready = null;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(ChatServerConnectionException(code));
    }
    final pending = List<_PendingCommand<Object?>>.from(_commands);
    _commands.clear();
    for (final command in pending) {
      if (!command.completer.isCompleted) {
        command.completer.completeError(ChatServerConnectionException(code));
      }
    }
    try {
      if (subscription != null) await subscription.cancel();
    } catch (_) {}
    try {
      if (socket != null) await socket.close();
    } catch (_) {}
    _closing = false;
    if (notify && !_disposed) {
      final callback = _onDisconnected;
      if (callback != null) {
        try {
          await callback();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _onEvent = null;
    _onDisconnected = null;
    await _disconnect('transport_disposed', notify: false);
    final attachments = _attachments;
    _attachments = null;
    if (attachments != null) await attachments.dispose();
  }
}
