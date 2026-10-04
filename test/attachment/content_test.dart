import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  MediaContent content({
    MediaContentKind kind = MediaContentKind.file,
    int byteSize = 1024,
    int cipherByteSize = 1060,
  }) => MediaContent(
    kind: kind,
    attachmentId: 'attachment-1',
    fileName: kind == MediaContentKind.video ? 'clip.mp4' : 'document.bin',
    mime: kind == MediaContentKind.video
        ? 'video/mp4'
        : 'application/octet-stream',
    byteSize: byteSize,
    durationMs: kind == MediaContentKind.video ? 3000 : null,
    cipherKey: List<int>.filled(32, 7),
    cipherByteSize: cipherByteSize,
    cipherSha256: List<int>.filled(32, 9),
  );

  test('media protobuf round-trips sizes above four GiB', () {
    const clearSize = 5 * 1024 * 1024 * 1024;
    final decoded = MediaContentCodec.decode(
      MediaContentCodec.encode(
        content(byteSize: clearSize, cipherByteSize: clearSize + 81920),
      ),
    );
    expect(decoded.byteSize, clearSize);
    expect(decoded.cipherByteSize, clearSize + 81920);
    expect(decoded.cipherKey, List<int>.filled(32, 7));
  });

  test('media protobuf rejects unknown fields and invalid descriptors', () {
    final valid = MediaContentCodec.encode(content());
    expect(
      () => MediaContentCodec.decode(<int>[...valid, 0xa0, 0x01, 0x01]),
      throwsFormatException,
    );
    expect(
      () => MediaContentCodec.encode(
        MediaContent(
          kind: MediaContentKind.audio,
          attachmentId: 'attachment-1',
          fileName: 'voice.m4a',
          mime: 'video/mp4',
          byteSize: 100,
          durationMs: 1000,
          cipherKey: List<int>.filled(32, 1),
          cipherByteSize: 136,
          cipherSha256: List<int>.filled(32, 2),
        ),
      ),
      throwsFormatException,
    );
  });

  test('attachment transfer URLs require HTTPS', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    expect(
      (TataChatServerAccess(
        tataChatServerUrl: Uri.parse('https://objects.example.com'),
        tataChatServerToken: 'token',
        expiresAtMillis: now + 120000,
      )..validate(now)).tataChatServerUrl.scheme,
      'https',
    );
    expect(
      () => TataChatServerAccess(
        tataChatServerUrl: Uri.parse(
          'http'
          '://objects.example.com',
        ),
        tataChatServerToken: 'token',
        expiresAtMillis: now + 120000,
      ).validate(now),
      throwsStateError,
    );
    expect(
      () => TataChatServerAccess(
        tataChatServerUrl: Uri.parse('https://user@example.com'),
        tataChatServerToken: 'token',
        expiresAtMillis: now + 120000,
      ).validate(now),
      throwsStateError,
    );
  });
}
