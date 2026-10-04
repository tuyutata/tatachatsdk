import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

TataChatServerAccess access(
  Uri url, {
  String token = 'test-token',
  int expires = 200000,
}) => TataChatServerAccess(
  tataChatServerUrl: url,
  tataChatServerToken: token,
  expiresAtMillis: expires,
);

void main() {
  test('唯一服务入口拒绝明文、WSS 根和相对地址', () {
    for (final url in [
      Uri.parse(
        'http'
        '://chat.example.com',
      ),
      Uri.parse(
        'ws'
        '://chat.example.com',
      ),
      Uri.parse('wss://chat.example.com'),
      Uri.parse('/chat'),
      Uri.parse('https:///chat'),
    ]) {
      expect(() => access(url).validate(1000), throwsStateError);
    }
  });

  test('服务根拒绝账户信息、业务路径、查询和片段', () {
    for (final url in [
      Uri.parse('https://user:password@chat.example.com'),
      Uri.parse('https://chat.example.com/chat'),
      Uri.parse('https://chat.example.com?token=value'),
      Uri.parse('https://chat.example.com/#fragment'),
    ]) {
      expect(() => access(url).validate(1000), throwsStateError);
    }
  });

  test('空令牌、带空白令牌和即将过期凭据均拒绝', () {
    final url = Uri.parse('https://chat.example.com');
    for (final token in ['', 'invalid token', 'invalid\ntoken']) {
      expect(() => access(url, token: token).validate(1000), throwsStateError);
    }
    expect(() => access(url, expires: 61000).validate(1000), throwsStateError);
    expect(() => access(url, expires: 61001).validate(1000), returnsNormally);
  });
}
