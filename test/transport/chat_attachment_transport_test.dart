import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';
import 'package:tatachat_sdk/transport/chat_attachment_transport.dart';

final class _FakeHttpAdapter implements ChatHttpAdapter {
  Uri? putUri;
  String? putToken;
  Uint8List? putBody;
  String? putHash;
  ChatHttpResponse? getResponse;
  bool disposed = false;

  @override
  Future<ChatHttpResponse> putChunk({
    required Uri uri,
    required String bearerToken,
    required Uint8List body,
    required String cipherSha256,
  }) async {
    putUri = uri;
    putToken = bearerToken;
    putBody = body;
    putHash = cipherSha256;
    return ChatHttpResponse(
      statusCode: 204,
      headers: <String, String>{},
      body: Uint8List(0),
    );
  }

  @override
  Future<ChatHttpResponse> getChunk({
    required Uri uri,
    required String bearerToken,
    required int maximumBytes,
  }) async => getResponse!;

  @override
  Future<void> dispose() async => disposed = true;
}

ChatAccess _access() => ChatAccess(
  realtimeUrl: Uri.parse('wss://chat.example.test/api/tatachat/realtime'),
  accessToken: 'signed-token',
  expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
);

void main() {
  test('附件编号拒绝点、路径穿越和越界块号，同端口派生HTTPS', () async {
    final access = ChatAccess(
      realtimeUrl: Uri.parse(
        'wss://chat.example.test:8443/api/tatachat/realtime',
      ),
      accessToken: 'signed-token',
      expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
    );
    expect(
      access.attachmentChunkUrl('attachment-a', 0).toString(),
      'https://chat.example.test:8443/api/tatachat/attachments/attachment-a/chunks/0',
    );
    for (final id in ['..', 'attachment.a', 'a/b', 'a?token']) {
      expect(() => access.attachmentChunkUrl(id, 0), throwsArgumentError);
    }
    expect(
      () => access.attachmentChunkUrl('attachment-a', -1),
      throwsArgumentError,
    );
    expect(
      () => access.attachmentChunkUrl('attachment-a', 0x100000000),
      throwsArgumentError,
    );
  });
  test('upload verifies ciphertext before exact HTTPS chunk request', () async {
    final adapter = _FakeHttpAdapter();
    final transport = ChatAttachmentTransport(
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
      'https://chat.example.test/api/tatachat/attachments/attachment-a/chunks/2',
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
      ..getResponse = ChatHttpResponse(
        statusCode: 200,
        headers: <String, String>{
          'content-length': '${bytes.length}',
          'x-chat-cipher-sha256': digest,
        },
        body: bytes,
      );
    final transport = ChatAttachmentTransport(
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
    final transport = ChatAttachmentTransport(
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
