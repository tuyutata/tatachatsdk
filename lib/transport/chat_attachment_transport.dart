import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'chat_service_transport.dart';

const int chatAttachmentChunkBytes = 4 * 1024 * 1024;

/// 一次 HTTPS 附件响应。生产实现会在返回前限制并收齐一个固定大小的密文块。
final class ChatHttpResponse {
  const ChatHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Uint8List body;
}

/// 可注入测试替身的 HTTPS 边界；实现层禁止重定向和明文 HTTP。
abstract interface class ChatHttpAdapter {
  Future<ChatHttpResponse> putChunk({
    required Uri uri,
    required String bearerToken,
    required Uint8List body,
    required String cipherSha256,
  });

  Future<ChatHttpResponse> getChunk({
    required Uri uri,
    required String bearerToken,
    required int maximumBytes,
  });

  Future<void> dispose();
}

typedef ChatHttpAdapterFactory = ChatHttpAdapter Function();

/// 使用系统 TLS 的正式附件客户端。
final class IoChatHttpAdapter implements ChatHttpAdapter {
  IoChatHttpAdapter({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;
  bool _disposed = false;
  bool _closed = false;
  final Set<HttpClientRequest> _requests = {};

  // 超时要终止实际请求。Future.timeout 本身不会停止 socket 或迟到的 openUrl。
  Future<ChatHttpResponse> _request(
    String method,
    Uri uri,
    String bearerToken, {
    Uint8List? bytes,
    String? cipherSha256,
    required int maximumBytes,
  }) async {
    _validateRequest(uri, bearerToken);
    HttpClientRequest? active;
    var finished = false;
    final operation = () async {
      final request = await _client.openUrl(method, uri);
      if (finished || _disposed) {
        request.abort();
        throw const ChatServerConnectionException('attachment_cancelled');
      }
      active = request;
      _requests.add(request);
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $bearerToken',
      );
      if (bytes != null) {
        request.headers
          ..set(HttpHeaders.contentTypeHeader, 'application/octet-stream')
          ..set('x-chat-cipher-sha256', cipherSha256!);
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close();
      return _readResponse(response, maximumBytes: maximumBytes);
    }();
    try {
      return await operation.timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const ChatServerConnectionException('attachment_timeout');
    } on ChatServerConnectionException {
      rethrow;
    } catch (_) {
      throw const ChatServerConnectionException('attachment_network_failed');
    } finally {
      finished = true;
      active?.abort();
      _requests.remove(active);
    }
  }

  @override
  Future<ChatHttpResponse> putChunk({
    required Uri uri,
    required String bearerToken,
    required Uint8List body,
    required String cipherSha256,
  }) async {
    return _request(
      'PUT',
      uri,
      bearerToken,
      bytes: body,
      cipherSha256: cipherSha256,
      maximumBytes: 0,
    );
  }

  @override
  Future<ChatHttpResponse> getChunk({
    required Uri uri,
    required String bearerToken,
    required int maximumBytes,
  }) async {
    _validateRequest(uri, bearerToken);
    if (maximumBytes <= 0 || maximumBytes > chatAttachmentChunkBytes) {
      throw const ChatServerConnectionException('attachment_size_invalid');
    }
    return _request('GET', uri, bearerToken, maximumBytes: maximumBytes);
  }

  Future<ChatHttpResponse> _readResponse(
    HttpClientResponse response, {
    required int maximumBytes,
  }) async {
    final body = BytesBuilder(copy: false);
    // 错误正文仅限量读取，不进入异常或 UI；成功 PUT 必须为空。
    final limit = response.statusCode >= 300 ? 16 * 1024 : maximumBytes;
    await for (final bytes in response) {
      if (limit == 0 && bytes.isNotEmpty) {
        throw const ChatServerConnectionException(
          'attachment_response_invalid',
        );
      }
      if (body.length + bytes.length > limit) {
        throw const ChatServerConnectionException('attachment_size_invalid');
      }
      body.add(bytes);
    }
    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      if (values.isNotEmpty) headers[name.toLowerCase()] = values.first;
    });
    return ChatHttpResponse(
      statusCode: response.statusCode,
      headers: Map.unmodifiable(headers),
      body: body.takeBytes(),
    );
  }

  void _validateRequest(Uri uri, String bearerToken) {
    if (_disposed ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        bearerToken.isEmpty ||
        bearerToken.length > 16 * 1024 ||
        bearerToken.codeUnits.any((unit) => unit <= 32 || unit >= 127)) {
      throw const ChatServerConnectionException('attachment_request_invalid');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    if (_closed) return;
    var failed = false;
    for (final request in List<HttpClientRequest>.of(_requests)) {
      try {
        request.abort();
        _requests.remove(request);
      } catch (_) {
        failed = true;
      }
    }
    try {
      _client.close(force: true);
    } catch (_) {
      failed = true;
    }
    if (failed) {
      throw const ChatServerConnectionException('attachment_cleanup_failed');
    }
    _closed = true;
  }
}

/// 聊天服务模块附件数据面：只传端到端加密后的密文字节。
final class ChatAttachmentTransport {
  ChatAttachmentTransport({
    required ChatAccess access,
    ChatHttpAdapter? adapter,
  }) : _access = access,
       _adapter = adapter ?? IoChatHttpAdapter() {
    _access.validate(DateTime.now().millisecondsSinceEpoch);
    _expiry = Timer(
      Duration(
        milliseconds:
            _access.expiresAtMillis -
            DateTime.now().millisecondsSinceEpoch -
            60000,
      ),
      () {
        unawaited(dispose().catchError((Object _) {}));
      },
    );
  }

  final ChatAccess _access;
  final ChatHttpAdapter _adapter;
  Timer? _expiry;
  bool _disposed = false;
  Future<void>? _disposing;
  bool _closed = false;
  final Set<Completer<ChatHttpResponse>> _pending = {};

  Future<ChatHttpResponse> _bounded(Future<ChatHttpResponse> operation) async {
    final cancellation = Completer<ChatHttpResponse>();
    _pending.add(cancellation);
    try {
      return await Future.any([operation, cancellation.future])
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      // 关闭本许可所属适配器，不能留下带授权的请求在后台继续传输。
      await dispose();
      throw const ChatServerConnectionException('attachment_timeout');
    } finally {
      _pending.remove(cancellation);
    }
  }

  void _ensureCurrent() {
    if (_disposed) {
      throw const ChatServerConnectionException('attachment_cancelled');
    }
    _access.validate(DateTime.now().millisecondsSinceEpoch);
  }

  Uri _chunkUri(String attachmentId, int chunkIndex) {
    _ensureCurrent();
    return _access.attachmentChunkUrl(attachmentId, chunkIndex);
  }

  Future<void> putChunk({
    required String attachmentId,
    required int chunkIndex,
    required Uint8List bytes,
    required String cipherSha256,
  }) async {
    _validateDigest(cipherSha256);
    if (bytes.isEmpty || bytes.length > chatAttachmentChunkBytes) {
      throw const ChatServerConnectionException('attachment_size_invalid');
    }
    final actual = crypto.sha256.convert(bytes).toString();
    if (actual != cipherSha256.toLowerCase()) {
      throw const ChatServerConnectionException('attachment_hash_mismatch');
    }
    final response = await _bounded(
      _adapter.putChunk(
        uri: _chunkUri(attachmentId, chunkIndex),
        bearerToken: _access.accessToken,
        body: bytes,
        cipherSha256: actual,
      ),
    );
    _ensureCurrent();
    if (response.statusCode != HttpStatus.noContent ||
        response.body.isNotEmpty) {
      throw ChatServerConnectionException(
        'attachment_upload_${response.statusCode}',
      );
    }
  }

  Future<Uint8List> getChunk({
    required String attachmentId,
    required int chunkIndex,
    required int expectedBytes,
    String? expectedSha256,
  }) async {
    if (expectedSha256 != null) _validateDigest(expectedSha256);
    if (expectedBytes <= 0 || expectedBytes > chatAttachmentChunkBytes) {
      throw const ChatServerConnectionException('attachment_size_invalid');
    }
    final response = await _bounded(
      _adapter.getChunk(
        uri: _chunkUri(attachmentId, chunkIndex),
        bearerToken: _access.accessToken,
        maximumBytes: expectedBytes,
      ),
    );
    _ensureCurrent();
    if (response.statusCode != HttpStatus.ok) {
      throw ChatServerConnectionException(
        'attachment_download_${response.statusCode}',
      );
    }
    final declaredLength = int.tryParse(
      response.headers['content-length'] ?? '',
    );
    final declaredHash = response.headers['x-chat-cipher-sha256']
        ?.toLowerCase();
    if (declaredHash == null) {
      throw const ChatServerConnectionException('attachment_hash_invalid');
    }
    _validateDigest(declaredHash);
    final expectedHash = expectedSha256?.toLowerCase();
    if (declaredLength != expectedBytes ||
        response.body.length != expectedBytes ||
        (expectedHash != null && declaredHash != expectedHash) ||
        crypto.sha256.convert(response.body).toString() != declaredHash) {
      throw const ChatServerConnectionException('attachment_hash_mismatch');
    }
    return response.body;
  }

  Future<void> dispose() {
    _disposed = true;
    for (final pending in _pending) {
      if (!pending.isCompleted) {
        pending.completeError(
          const ChatServerConnectionException('attachment_cancelled'),
        );
      }
    }
    _expiry?.cancel();
    _expiry = null;
    if (_closed) return Future<void>.value();
    final existing = _disposing;
    if (existing != null) return existing;
    late final Future<void> created;
    created = _adapter
        .dispose()
        .then((_) {
          _closed = true;
        })
        .whenComplete(() {
          if (identical(_disposing, created)) _disposing = null;
        });
    _disposing = created;
    return created;
  }
}

void _validateDigest(String value) {
  if (value.length != 64 ||
      !value.codeUnits.every(
        (unit) =>
            (unit >= 48 && unit <= 57) ||
            (unit >= 65 && unit <= 70) ||
            (unit >= 97 && unit <= 102),
      )) {
    throw const ChatServerConnectionException('attachment_hash_invalid');
  }
}

/// 对外只暴露稳定错误码，禁止把服务端或网络原文带入聊天 UI。
final class ChatServerConnectionException implements Exception {
  const ChatServerConnectionException(this.code);

  final String code;

  @override
  String toString() => 'ChatServerConnectionException($code)';
}
