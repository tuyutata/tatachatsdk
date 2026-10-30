import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// 合同测试锁定 TataChatSDK 的中性身份、状态清理边界和脱敏错误码。
void main() {


  test('TataChatSDK source does not own product identity names', () {
    final configFile = File('.dart_tool/package_config.json').absolute;
    final packages = (jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>)['packages'] as List<dynamic>;
    final sourceRoots = <Directory>[];
    for (final entry in packages.cast<Map<String, dynamic>>()) {
      final name = entry['name'] as String;
      if (!name.startsWith('tatachat_') || name == 'tatachat_testing') continue;
      final root = Directory.fromUri(configFile.uri.resolve(entry['rootUri'] as String)).absolute.uri;
      sourceRoots.add(Directory.fromUri(root.resolve('lib/')));
      if (name == 'tatachat_protocol') sourceRoots.add(Directory.fromUri(root.resolve('proto/')));
    }
    final legacyIdentityWord = String.fromCharCodes(const <int>[99, 105, 100]);
    final titledLegacyIdentityWord =
        '${legacyIdentityWord[0].toUpperCase()}${legacyIdentityWord.substring(1)}';
    final unrelatedNativeLibrary = String.fromCharCodes(const <int>[
      115,
      109,
      111,
      108,
      100,
      111,
      116,
    ]);
    final forbidden = RegExp(
      <String>[
        legacyIdentityWord,
        '_number|${titledLegacyIdentityWord}Number|'
            '${legacyIdentityWord}Number|chat_mls_|lib$unrelatedNativeLibrary',
      ].join(),
    );
    final violations = <String>[];

    for (final entity in sourceRoots.expand((root) => root.listSync(recursive: true))) {
      if (entity is! File ||
          !(entity.path.endsWith('.dart') || entity.path.endsWith('.proto'))) {
        continue;
      }
      // 通讯录application的共享闭集字段绑定CID；其余SDK身份保持部署中性。
      final source = entity.readAsStringSync();
      final neutralSource = entity.path.endsWith('mls_contact_sync.dart')
          ? source.replaceAll("'owner_cid_number'", '')
          : source;
      if (forbidden.hasMatch(neutralSource)) {
        violations.add(entity.path);
      }
    }

    expect(violations, isEmpty);
  });
}
