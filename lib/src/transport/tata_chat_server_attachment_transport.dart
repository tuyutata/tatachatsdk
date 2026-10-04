import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'chat_service_transport.dart';

const int chatAttachmentChunkBytes = 4 * 1024 * 1024;

/// 一次 HTTPS 附件响应。生产实现会在返回前限制并收齐一个固定大小的密文块。
final class TataChatServerHttpResponse {
  const TataChatServerHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Uint8List body;
}

/// 可注入测试替身的 HTTPS 边界；实现层禁止重定向和明文 HTTP。
abstract interface class TataChatServerHttpAdapter {
  Future<TataChatServerHttpResponse> putChunk({
    required Uri uri,
    required String bearerToken,
    required Uint8List body,
    required String cipherSha256,
  });

  Future<TataChatServerHttpResponse> getChunk({
    required Uri uri,
    required String bearerToken,
    required int maximumBytes,
  });

  Future<void> dispose();
}

typedef TataChatServerHttpAdapterFactory = TataChatServerHttpAdapter Function();

/// 使用系统 TLS 的正式附件客户端。
final class IoTataChatServerHttpAdapter implements TataChatServerHttpAdapter {
  IoTataChatServerHttpAdapter({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;
  bool _disposed = false;

  @override
  Future<TataChatServerHttpResponse> putChunk({
    required Uri uri,
    required String bearerToken,
    required Uint8List body,
    required String cipherSha256,
  }) async {
    _validateRequest(uri, bearerToken);
    final request = await _client.putUrl(uri);
    request.followRedirects = false;
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken')
      ..set(HttpHeaders.contentTypeHeader, 'application/octet-stream')
      ..set(HttpHeaders.contentLengthHeader, body.length)
      ..set('x-chat-cipher-sha256', cipherSha256);
    request.add(body);
    final response = await request.close();
    return _readResponse(response, maximumBytes: 0);
  }

  @override
  Future<TataChatServerHttpResponse> getChunk({
    required Uri uri,
    required String bearerToken,
    required int maximumBytes,
  }) async {
    _validateRequest(uri, bearerToken);
    if (maximumBytes <= 0 || maximumBytes > chatAttachmentChunkBytes) {
      throw const ChatServerConnectionException('attachment_size_invalid');
    }
    final request = await _client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
    final response = await request.close();
    return _readResponse(response, maximumBytes: maximumBytes);
  }

  Future<TataChatServerHttpResponse> _readResponse(
    HttpClientResponse response, {
    required int maximumBytes,
  }) async {
    final body = BytesBuilder(copy: false);
    await for (final bytes in response) {
      if (maximumBytes == 0 && bytes.isNotEmpty) {
        throw const ChatServerConnectionException(
          'attachment_response_invalid',
        );
      }
      if (body.length + bytes.length > maximumBytes) {
        throw const ChatServerConnectionException('attachment_size_invalid');
      }
      body.add(bytes);
    }
    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      if (values.isNotEmpty) headers[name.toLowerCase()] = values.first;
    });
    return TataChatServerHttpResponse(
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
        bearerToken.isEmpty ||
        bearerToken.codeUnits.any((unit) => unit <= 32)) {
      throw const ChatServerConnectionException(
        'attachment_request_invalid',
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _client.close(force: true);
  }
}

/// TataChatServer 附件数据面：只传端到端加密后的密文字节。
final class TataChatServerAttachmentTransport {
  TataChatServerAttachmentTransport({
    required TataChatServerAccess access,
    TataChatServerHttpAdapter? adapter,
  }) : _access = access,
       _adapter = adapter ?? IoTataChatServerHttpAdapter() {
    _access.validate(DateTime.now().millisecondsSinceEpoch);
  }

  final TataChatServerAccess _access;
  final TataChatServerHttpAdapter _adapter;

  Uri _chunkUri(String attachmentId, int chunkIndex) {
    if (!_validIdentifier(attachmentId) || chunkIndex < 0) {
      throw const ChatServerConnectionException('attachment_path_invalid');
    }
    return _access.tataChatServerUrl.replace(
      path: '/attachments/$attachmentId/chunks/$chunkIndex',
    );
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
    final response = await _adapter.putChunk(
      uri: _chunkUri(attachmentId, chunkIndex),
      bearerToken: _access.tataChatServerToken,
      body: bytes,
      cipherSha256: actual,
    );
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
    final response = await _adapter.getChunk(
      uri: _chunkUri(attachmentId, chunkIndex),
      bearerToken: _access.tataChatServerToken,
      maximumBytes: expectedBytes,
    );
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

  Future<void> dispose() => _adapter.dispose();
}

bool _validIdentifier(String value) =>
    value.isNotEmpty &&
    value.length <= 128 &&
    value.codeUnits.every(
      (unit) =>
          (unit >= 48 && unit <= 57) ||
          (unit >= 65 && unit <= 90) ||
          (unit >= 97 && unit <= 122) ||
          unit == 45 ||
          unit == 46 ||
          unit == 95,
    );

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
