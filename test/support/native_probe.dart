// OpenMLS tests probe the independent TataChatSDK native library once per process.
// A missing host library skips only native integration cases; protocol and Dart
// tests continue to run, while the official native job must build the library.

import 'package:tatachat_sdk/tatachat_sdk.dart';

bool _probed = false;
String? _reason;

/// libtatachat_sdk native 库的 skip 原因:可加载→`null`(测试照跑);不可加载→文案(skip)。
///
/// 直接传给 `test(..., skip: chatSdkNativeSkipReason())` / `testWidgets(..., skip: ...)`。
String? chatSdkNativeSkipReason() {
  if (_probed) return _reason;
  _probed = true;
  try {
    // NativeMlsCrypto() 构造即 dlopen libtatachat_sdk(与链 RPC 同一库);成功=库可用。
    NativeMlsCrypto();
    _reason = null;
  } on Object catch (_) {
    _reason =
        'libtatachat_sdk native library is unavailable; build it with '
        './scripts/build-native.sh before native integration tests';
  }
  return _reason;
}
