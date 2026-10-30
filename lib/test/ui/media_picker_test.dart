import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  Future<List<PickedMediaFile>> pick(
    WidgetTester tester,
    List<XFile> files,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    return MediaPicker(pickGallery: (_) async => files).gallery(context);
  }

  testWidgets('相册一次可返回一至九张照片并保持顺序', (tester) async {
    final files = [
      for (var index = 0; index < 9; index++) XFile('/tmp/photo-$index.jpg'),
    ];
    final result = await pick(tester, files);
    expect(result, hasLength(9));
    expect(result.every((item) => item.kind == ChatMessageKind.image), isTrue);
    expect(result.first.fileName, 'photo-0.jpg');
    expect(result.last.fileName, 'photo-8.jpg');
  });

  testWidgets('相册一次可返回一个视频', (tester) async {
    final result = await pick(tester, [XFile('/tmp/clip.mp4')]);
    expect(result.single.kind, ChatMessageKind.video);
    expect(result.single.mime, 'video/mp4');
  });

  testWidgets('取消相册返回空列表', (tester) async {
    expect(await pick(tester, const []), isEmpty);
  });

  testWidgets('图片与视频混选失败关闭', (tester) async {
    expect(
      () => pick(tester, [XFile('/tmp/photo.jpg'), XFile('/tmp/clip.mp4')]),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('十张照片超过上限失败关闭', (tester) async {
    expect(
      () => pick(tester, [
        for (var index = 0; index < 10; index++) XFile('/tmp/photo-$index.jpg'),
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('非图片视频文件失败关闭', (tester) async {
    expect(
      () => pick(tester, [XFile('/tmp/document.pdf')]),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('XFile 自带 MIME 优先采用', (tester) async {
    final result = await pick(tester, [
      XFile('/tmp/noext', mimeType: 'image/png'),
    ]);
    expect(result.single.mime, 'image/png');
    expect(result.single.kind, ChatMessageKind.image);
  });
}
