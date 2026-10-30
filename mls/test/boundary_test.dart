import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_mls/mls_boundary.dart';
import 'package:tatachat_mls/mls_native.dart';
import 'package:tatachat_testing/native.dart';

// 合同测试锁定 TataChatSDK 的中性身份、状态清理边界和脱敏错误码。
void main() {

  TestWidgetsFlutterBinding.ensureInitialized();

  test('原生存储错误只有固定分类，不授权自动清理', () {
    final storage = MlsNativeException.fromTechnicalMessage(
      'CHAT_MLS_STORAGE_READ_FAILED:detail',
    );
    final invalid = MlsNativeException.fromTechnicalMessage(
      'CHAT_MLS_STATE_INVALID:detail',
    );
    expect(storage.code, MlsNativeErrorCode.storageReadFailed);
    expect(storage.diagnosticCode, 'storage_read_failed');
    expect(invalid.code, MlsNativeErrorCode.stateInvalid);
    expect(chatSdkDiagnosticCode(StateError('hidden')), 'operation_failed');
  });

  test('结构化认证请求固定字段且复制正文，禁止签名域和身份注入', () {
    final bytes = [1, 2, 3];
    final request = createAuthenticationRequest(body: bytes);
    bytes[0] = 9;
    expect(request.bodyBytes, [1, 2, 3]);
    expect(() => request.bodyBytes[0] = 9, throwsUnsupportedError);
    expect(
      request.toJson().keys,
      unorderedEquals([
        'service_origin',
        'nonce_id',
        'expires_at',
        'http_method',
        'request_target',
        'body_hex',
      ]),
    );
    expect(request.toJson()['body_hex'], '010203');
    request.validate();
  });

  test('认证拒绝非HTTPS源、地址别名、过期挑战和非法请求', () {
    for (final request in [
      createAuthenticationRequest(
        origin: Uri(scheme: 'http', host: 'api.example.test').toString(),
      ),
      createAuthenticationRequest(
        origin: Uri(scheme: 'ws', host: 'api.example.test').toString(),
      ),
      createAuthenticationRequest(origin: 'wss://api.example.test'),
      createAuthenticationRequest(origin: 'https://user@api.example.test'),
      createAuthenticationRequest(origin: 'https://api.example.test/path'),
      createAuthenticationRequest(origin: 'https://api.example.test?query'),
      createAuthenticationRequest(origin: 'https://api.example.test#fragment'),
      createAuthenticationRequest(target: '//other.example.test/path'),
      createAuthenticationRequest(target: '/path#fragment'),
      createAuthenticationRequest(target: '/path%xx'),
      createAuthenticationRequest(target: '/path\nheader'),
      createAuthenticationRequest(method: 'post'),
      createAuthenticationRequest(challenge: '22'),
      createAuthenticationRequest(expiry: 0),
      createAuthenticationRequest(expiry: DateTime.now().millisecondsSinceEpoch + 600000),
      createAuthenticationRequest(body: [-1]),
      createAuthenticationRequest(body: [256]),
      createAuthenticationRequest(body: List.filled(MlsAuthenticationRequest.maxBodyBytes + 1, 0)),
    ]) {
      expect(request.validate, throwsArgumentError);
    }
  });
}
