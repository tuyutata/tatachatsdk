import 'package:tatachat_sdk/tatachat_sdk.dart';

bool _probed = false;

/// 真实MLS回归必须加载本轮独立宿主库；缺件使套件失败，不允许跳过。
void requireChatSdkNative() {
  if (_probed) return;
  NativeMlsCrypto();
  _probed = true;
}
