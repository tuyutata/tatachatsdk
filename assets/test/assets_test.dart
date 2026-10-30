import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_assets/sticker_pack.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('实际资源包可加载全部PNG，文件签名有效', () async {
    for (final item in StickerPack.items) {
      final bytes = await rootBundle.load(StickerPack.assetPath(item.id));
      expect(bytes.buffer.asUint8List(bytes.offsetInBytes, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(bytes.lengthInBytes, greaterThan(24));
    }
  });
}
