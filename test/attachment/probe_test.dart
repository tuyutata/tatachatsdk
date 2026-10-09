import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tatachat_sdk/attachment/attachment_platform.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

Uint8List _tinyPng() {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(120, 80, 200));
  return img.encodePng(image);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encodeBlurhash 由小图字节产出非空 hash', () {
    final hash = MediaProbe.encodeBlurhash(_tinyPng());
    expect(hash, isNotNull);
    expect(hash!.isNotEmpty, isTrue);
  });

  test('encodeBlurhash 坏字节返回 null 且不抛', () {
    expect(MediaProbe.encodeBlurhash(const [1, 2, 3]), isNull);
  });

  test('probe(image) 装配宽高与 blurhash(缩略字节走注入)', () async {
    final png = _tinyPng();
    final probe = MediaProbe(
      imageSize: (_) => (width: 800, height: 600),
      imageThumbBytes: (_) async => png,
    );
    final result = await probe.probe(
      path: '/p.jpg',
      kind: ChatMessageKind.image,
    );
    expect(result.width, 800);
    expect(result.height, 600);
    expect(result.durationMs, isNull);
    expect(result.blurhash, isNotNull);
  });

  test('probe(video) 装配宽高/时长/blurhash', () async {
    final png = _tinyPng();
    final probe = MediaProbe(
      videoProbe: (_) async =>
          (width: 1920, height: 1080, durationMs: 4200, thumbnailBytes: png),
    );
    final result = await probe.probe(
      path: '/v.mp4',
      kind: ChatMessageKind.video,
    );
    expect(result.width, 1920);
    expect(result.height, 1080);
    expect(result.durationMs, 4200);
    expect(result.blurhash, isNotNull);
  });

  test('probe(file) 不探测,字段留空', () async {
    final result = await MediaProbe().probe(
      path: '/x.pdf',
      kind: ChatMessageKind.file,
    );
    expect(result.width, isNull);
    expect(result.height, isNull);
    expect(result.blurhash, isNull);
  });

  test('probe:缩略图为空时 blurhash 降级为 null,宽高仍在', () async {
    final probe = MediaProbe(
      imageSize: (_) => (width: 800, height: 600),
      imageThumbBytes: (_) async => null,
    );
    final result = await probe.probe(
      path: '/p.jpg',
      kind: ChatMessageKind.image,
    );
    expect(result.width, 800);
    expect(result.height, 600);
    expect(result.blurhash, isNull);
  });

  test('probe(video) 原生未返回小封面时仍保留宽高和时长', () async {
    final probe = MediaProbe(
      videoProbe: (_) async =>
          (width: 3840, height: 2160, durationMs: 180000, thumbnailBytes: null),
    );
    final result = await probe.probe(
      path: '/v.mp4',
      kind: ChatMessageKind.video,
    );
    expect(result.width, 3840);
    expect(result.height, 2160);
    expect(result.durationMs, 180000);
    expect(result.blurhash, isNull);
  });

  test('encodeBlurhash 对纵向缩略图也降到 ≤64 并产出 hash', () {
    final tall = img.Image(width: 40, height: 320);
    img.fill(tall, color: img.ColorRgb8(10, 200, 90));
    final hash = MediaProbe.encodeBlurhash(img.encodePng(tall));
    expect(hash, isNotNull);
    expect(hash!.isNotEmpty, isTrue);
  });

  test('探测抛错时不阻断,返回空结果', () async {
    final probe = MediaProbe(
      imageSize: (_) => throw StateError('boom'),
      imageThumbBytes: (_) async => throw StateError('boom'),
    );
    final result = await probe.probe(
      path: '/p.jpg',
      kind: ChatMessageKind.image,
    );
    expect(result.width, isNull);
    expect(result.blurhash, isNull);
  });

  test('视频平台探测失败时不阻断,返回空结果', () async {
    final probe = MediaProbe(
      videoProbe: (_) async => throw StateError('native probe failed'),
    );
    final result = await probe.probe(
      path: '/v.mp4',
      kind: ChatMessageKind.video,
    );
    expect(result.width, isNull);
    expect(result.height, isNull);
    expect(result.durationMs, isNull);
    expect(result.blurhash, isNull);
  });

  test('默认视频通道只接受受限小封面和正整数元数据', () async {
    const channel = MethodChannel('chat.tata.sdk/attachment');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'probeVideo');
      expect(call.arguments, {'path': '/v.mp4'});
      return <String, Object?>{
        'width': 1080,
        'height': 1920,
        'duration_ms': 4200,
        'thumbnail_bytes': _tinyPng(),
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final result = await MediaProbe().probe(
      path: '/v.mp4',
      kind: ChatMessageKind.video,
    );
    expect(result.width, 1080);
    expect(result.height, 1920);
    expect(result.durationMs, 4200);
    expect(result.blurhash, isNotNull);
  });

  test('默认视频通道拒绝错误字段且降级为空结果', () async {
    const channel = MethodChannel('chat.tata.sdk/attachment');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async {
      return <String, Object?>{'width': '1080', 'duration_ms': -1};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final result = await MediaProbe().probe(
      path: '/v.mp4',
      kind: ChatMessageKind.video,
    );
    expect(result.width, isNull);
    expect(result.height, isNull);
    expect(result.durationMs, isNull);
    expect(result.blurhash, isNull);
  });

  test('附件平台只接受绝对临时路径、文件名和标准 MIME', () async {
    const channel = MethodChannel('chat.tata.sdk/attachment');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'pickFile');
      expect(call.arguments, isNull);
      return <String, Object?>{
        'path': '/tmp/document.pdf',
        'file_name': '文档.pdf',
        'mime': 'application/pdf',
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final picked = await const ChatAttachmentPlatform().pickFile();
    expect(picked?.path, '/tmp/document.pdf');
    expect(picked?.fileName, '文档.pdf');
    expect(picked?.mime, 'application/pdf');
  });

  test('附件平台把系统取消原样返回为空', () async {
    const channel = MethodChannel('chat.tata.sdk/attachment');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    expect(await const ChatAttachmentPlatform().pickFile(), isNull);
  });

  test('附件平台拒绝越界路径、文件名和 MIME', () async {
    const channel = MethodChannel('chat.tata.sdk/attachment');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    for (final invalid in <Map<String, Object?>>[
      {
        'path': 'relative.pdf',
        'file_name': 'document.pdf',
        'mime': 'application/pdf',
      },
      {
        'path': '/tmp/document.pdf',
        'file_name': '../document.pdf',
        'mime': 'application/pdf',
      },
      {
        'path': '/tmp/document.pdf',
        'file_name': 'document.pdf',
        'mime': 'invalid',
      },
    ]) {
      messenger.setMockMethodCallHandler(channel, (_) async => invalid);
      await expectLater(
        const ChatAttachmentPlatform().pickFile(),
        throwsFormatException,
      );
    }
  });
}
