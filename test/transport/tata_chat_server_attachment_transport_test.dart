import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/src/transport/tata_chat_server_attachment_transport.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

final class _FakeHttpAdapter implements TataChatServerHttpAdapter {
  Uri? putUri;
  String? putToken;
  Uint8List? putBody;
  String? putHash;
  TataChatServerHttpResponse? getResponse;
  bool disposed = false;

  @override
  Future<TataChatServerHttpResponse> putChunk({
    required Uri uri,
    required String bearerToken,
    required Uint8List body,
    required String cipherSha256,
  }) async {
    putUri = uri;
    putToken = bearerToken;
    putBody = body;
    putHash = cipherSha256;
    return TataChatServerHttpResponse(
      statusCode: 204,
      headers: <String, String>{},
      body: Uint8List(0),
    );
  }

  @override
  Future<TataChatServerHttpResponse> getChunk({
    required Uri uri,
    required String bearerToken,
    required int maximumBytes,
  }) async => getResponse!;

  @override
  Future<void> dispose() async => disposed = true;
}

TataChatServerAccess _access() => TataChatServerAccess(
  tataChatServerUrl: Uri.parse('https://chat.example.test'),
  tataChatServerToken: 'signed-token',
  expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
);

void main() {
  test('upload verifies ciphertext before exact HTTPS chunk request', () async {
    final adapter = _FakeHttpAdapter();
    final transport = TataChatServerAttachmentTransport(
      access: _access(),
      adapter: adapter,
    );
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);
    final digest = crypto.sha256.convert(bytes).toString();

    await transport.putChunk(
      attachmentId: 'attachment-a',
      chunkIndex: 2,
      bytes: bytes,
      cipherSha256: digest,
    );
    expect(
      adapter.putUri.toString(),
      'https://chat.example.test/attachments/attachment-a/chunks/2',
    );
    expect(adapter.putToken, 'signed-token');
    expect(adapter.putBody, bytes);
    expect(adapter.putHash, digest);
    await transport.dispose();
    expect(adapter.disposed, isTrue);
  });

  test('download verifies length, response digest and actual bytes', () async {
    final bytes = Uint8List.fromList(<int>[4, 5, 6]);
    final digest = crypto.sha256.convert(bytes).toString();
    final adapter = _FakeHttpAdapter()
      ..getResponse = TataChatServerHttpResponse(
        statusCode: 200,
        headers: <String, String>{
          'content-length': '${bytes.length}',
          'x-chat-cipher-sha256': digest,
        },
        body: bytes,
      );
    final transport = TataChatServerAttachmentTransport(
      access: _access(),
      adapter: adapter,
    );
    expect(
      await transport.getChunk(
        attachmentId: 'attachment-a',
        chunkIndex: 0,
        expectedBytes: bytes.length,
      ),
      bytes,
    );
    await transport.dispose();
  });

  test('invalid upload digest fails before any network I/O', () async {
    final adapter = _FakeHttpAdapter();
    final transport = TataChatServerAttachmentTransport(
      access: _access(),
      adapter: adapter,
    );
    await expectLater(
      transport.putChunk(
        attachmentId: 'attachment-a',
        chunkIndex: 0,
        bytes: Uint8List.fromList(<int>[1]),
        cipherSha256: 'invalid',
      ),
      throwsA(isA<ChatServerConnectionException>()),
    );
    expect(adapter.putUri, isNull);
    await transport.dispose();
  });
}
