import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/attachment.dart';

void main() {
  late Directory root;
  setUp(() async {
    final temporary = await Directory.systemTemp.createTemp('chat_cache_');
    root = Directory(await temporary.resolveSymbolicLinks());
  });
  tearDown(() => root.delete(recursive: true));
  test('附件缓存完整复制，源文件保留且不存在第二版本', () async {
    final source = File(root.path + '/source');
    await source.writeAsBytes(List.generate(128 * 1024, (index) => index % 256));
    final path = root.path + '/cache/attachment.bin';
    final cached = await AttachmentVault.cache(source: source, cachePath: path);
    expect(await cached.readAsBytes(), await source.readAsBytes());
    expect(await AttachmentVault.hasCache(path), true);
    expect(await File(path + '.part').exists(), false);
  });
  test('路径段或父项链接失败前不创建目录，不读取外部缓存', () async {
    final source = File(root.path + '/source');
    await source.writeAsString('source');
    final target = await Directory(root.path + '/target').create();
    final link = Link(root.path + '/link');
    await link.create(target.path);
    await expectLater(AttachmentVault.cache(source: source, cachePath: link.path + '/new/file'), throwsStateError);
    expect(await Directory(target.path + '/new').exists(), false);
    await expectLater(AttachmentVault.cache(source: source, cachePath: root.path + '/new/../escape/file'), throwsStateError);
    expect(await Directory(root.path + '/new').exists(), false);
    final cached = File(target.path + '/existing');
    await cached.writeAsString('protected');
    await expectLater(AttachmentVault.hasCache(link.path + '/existing'), throwsStateError);
  });

  test('源文件读取失败不覆盖已提交缓存，并清除本次未提交残片', () async {
    final target = File(root.path + '/cache');
    await target.writeAsString('已提交缓存', flush:true);
    await expectLater(
      AttachmentVault.cache(source:File(root.path + '/missing'),cachePath:target.path),
      throwsA(isA<FileSystemException>()),
    );
    expect(await target.readAsString(),'已提交缓存');
    expect(await File(target.path + '.part').exists(),false);
  });

  test('拒绝缓存目标链接和临时文件链接', () async {
    final source = File(root.path + '/source');
    await source.writeAsString('source');
    final target = root.path + '/cache';
    await Link(target).create(source.path);
    await expectLater(AttachmentVault.cache(source: source, cachePath: target), throwsStateError);
    await Link(target).delete();
    await Link(target + '.part').create(source.path);
    await expectLater(AttachmentVault.cache(source: source, cachePath: target), throwsStateError);
    expect(await source.readAsString(), 'source');
  });
}
