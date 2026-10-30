import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test('本轮独立动态库真实导出头文件中的全部SDK接口', () {
    final file = Platform.environment['TATACHATSDK_TEST_NATIVE_LIBRARY'];
    expect(file, isNotNull, reason: '必须由本产品测试入口交付本轮真实原生库');
    final library = DynamicLibrary.open(file!);
    final header = File('../native/tatachat_sdk.h').readAsStringSync();
    final names = RegExp(r'\b(tatachat_sdk_[a-z_]+)\s*\(')
        .allMatches(header).map((value) => value.group(1)!).toSet();
    expect(names.length, greaterThan(1));
    for (final name in names) {
      expect(library.lookup<NativeFunction<Void Function()>>(name).address,
          isNot(0), reason: name);
    }
    for (final name in ['tatachat_sdk_mls_rekey_state_json',
      'tatachat_sdk_mls_two_party_smoke_json', 'tatachat_sdk_device_identity_json',
      'tatachat_sdk_mls_encrypt_json', 'tatachat_sdk_mls_decrypt_json']) {
      expect(() => library.lookup<NativeFunction<Void Function()>>(name),
          throwsArgumentError, reason: '禁止重新导出退役接口$name');
    }
  });
}

