import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

const int _limit = 10 * 1024 * 1024;

MediaCompressor _compressor({
  required FileSizeReader sizeOf,
  required ImageCompressStep compressImage,
}) => MediaCompressor(
  limitForKind: (_) => _limit,
  sizeOf: sizeOf,
  compressImage: compressImage,
);

void main() {
  test('files within the host limit pass through unchanged', () async {
    final compressor = _compressor(
      sizeOf: (_) async => 5,
      compressImage: (_, __) async => throw StateError('must not compress'),
    );
    expect(
      await compressor.ensureWithinLimit(
        path: '/photo.jpg',
        kind: ChatMessageKind.image,
      ),
      '/photo.jpg',
    );
  });

  test('an oversized image may be compressed once', () async {
    final sizes = {'/large.jpg': _limit + 1, '/small.jpg': 10};
    final compressor = _compressor(
      sizeOf: (path) async => sizes[path]!,
      compressImage: (_, __) async => '/small.jpg',
    );
    expect(
      await compressor.ensureWithinLimit(
        path: '/large.jpg',
        kind: ChatMessageKind.image,
      ),
      '/small.jpg',
    );
  });

  test('an image still over limit is rejected', () async {
    final compressor = _compressor(
      sizeOf: (_) async => _limit + 1,
      compressImage: (_, __) async => '/still-large.jpg',
    );
    await expectLater(
      compressor.ensureWithinLimit(
        path: '/large.jpg',
        kind: ChatMessageKind.image,
      ),
      throwsA(isA<ChatMediaTooLargeException>()),
    );
  });

  test('a failed image compression is rejected', () async {
    final compressor = _compressor(
      sizeOf: (_) async => _limit + 1,
      compressImage: (_, __) async => null,
    );
    await expectLater(
      compressor.ensureWithinLimit(
        path: '/large.jpg',
        kind: ChatMessageKind.image,
      ),
      throwsA(isA<ChatMediaTooLargeException>()),
    );
  });

  test('oversized video is rejected without transcoding', () async {
    var compressCalled = false;
    final compressor = _compressor(
      sizeOf: (_) async => _limit + 1,
      compressImage: (_, __) async {
        compressCalled = true;
        return null;
      },
    );
    await expectLater(
      compressor.ensureWithinLimit(
        path: '/large.mp4',
        kind: ChatMessageKind.video,
      ),
      throwsA(isA<ChatMediaTooLargeException>()),
    );
    expect(compressCalled, isFalse);
  });
}
