import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

// 合同测试锁定 TataChatSDK 的中性身份、状态清理边界和脱敏错误码。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('protocol uses deployment-neutral user identifiers', () {
    final route = ChatRoute(
      peerUserId: 'user-42',
      deviceId: 'device-a',
      createdAtMillis: Int64.ONE,
      expiresAtMillis: Int64.TWO,
    );
    final message = EncryptedMessage(
      messageId: 'message-a',
      conversationId: 'conversation-a',
      senderUserId: 'user-1',
      senderDeviceId: 'device-a',
      deliveries: <EncryptedDelivery>[
        EncryptedDelivery(
          recipient: Recipient(userId: 'user-2', deviceId: 'device-b'),
          openmlsCiphertext: <int>[1, 2, 3],
        ),
      ],
      createdAtMillis: Int64.ONE,
    );

    expect(route.peerUserId, 'user-42');
    expect(message.senderUserId, 'user-1');
    expect(message.recipientUserId, 'user-2');
    expect(message.openmlsCiphertext, <int>[1, 2, 3]);
  });

  test('TataChatSDK source does not own product identity names', () {
    final sourceRoot = Directory('lib');
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

    for (final entity in sourceRoot.listSync(recursive: true)) {
      if (entity is! File ||
          !(entity.path.endsWith('.dart') || entity.path.endsWith('.proto'))) {
        continue;
      }
      if (forbidden.hasMatch(entity.readAsStringSync())) {
        violations.add(entity.path);
      }
    }

    expect(violations, isEmpty);
  });

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
    final request = _request(body: bytes);
    bytes[0] = 9;
    expect(request.bodyBytes, [1, 2, 3]);
    expect(() => request.bodyBytes[0] = 9, throwsUnsupportedError);
    expect(request.toJson().keys, unorderedEquals([
      'service_origin', 'challenge', 'expires_at_millis', 'method',
      'request_target', 'body_hex',
    ]));
    expect(request.toJson()['body_hex'], '010203');
    request.validate();
  });

  test('认证拒绝非HTTPS源、地址别名、过期挑战和非法请求', () {
    for (final request in [
      _request(origin: Uri(scheme: 'http', host: 'api.example.test').toString()),
      _request(origin: Uri(scheme: 'ws', host: 'api.example.test').toString()),
      _request(origin: 'wss://api.example.test'),
      _request(origin: 'https://user@api.example.test'),
      _request(origin: 'https://api.example.test/path'),
      _request(origin: 'https://api.example.test?query'),
      _request(origin: 'https://api.example.test#fragment'),
      _request(target: '//other.example.test/path'),
      _request(target: '/path#fragment'),
      _request(target: '/path%xx'),
      _request(target: '/path\nheader'),
      _request(method: 'post'),
      _request(challenge: '22'),
      _request(expiry: 0),
      _request(expiry: DateTime.now().millisecondsSinceEpoch + 600000),
      _request(body: [-1]),
      _request(body: [256]),
      _request(body: List.filled(MlsAuthenticationRequest.maxBodyBytes + 1, 0)),
    ]) {
      expect(request.validate, throwsArgumentError);
    }
  });

  test('Dart拒绝错身份、错请求、漏字段、额外字段或私钥夹带的原生证明', () async {
    final root = await Directory.systemTemp.createTemp('tatachat_auth_boundary_');
    addTearDown(() => root.delete(recursive: true));
    final directory = Directory(await root.resolveSymbolicLinks());
    final request = _request();
    for (final field in [
      'user_id', 'device_id', 'public_key', 'account_id', 'binding_revision',
      'service_origin', 'challenge', 'expires_at_millis', 'method',
      'request_target', 'body_sha256', 'signature', 'private_key', 'body_hex',
    ]) {
      final store = MlsStateStore(
        directory,
        ownerUserId: 'user-a',
        debugCallJson: (input) {
          final result = _nativeResponse(input);
          if (input['action'] == 'sign_authentication') {
            result[field] = field == 'binding_revision' ||
                    field == 'expires_at_millis'
                ? 2
                : 'synthetic invalid value';
          }
          return result;
        },
      );
      await expectLater(
        store.signAuthentication(
          accountId: _hex(0x11), bindingRevision: 1, request: request,
        ),
        throwsStateError,
      );
    }
    final missing = MlsStateStore(
      directory,
      ownerUserId: 'user-a',
      debugCallJson: (input) {
        final result = _nativeResponse(input);
        if (input['action'] == 'sign_authentication') result.remove('signature');
        return result;
      },
    );
    await expectLater(
      missing.signAuthentication(
        accountId: _hex(0x11), bindingRevision: 1, request: request,
      ),
      throwsStateError,
    );
  });

  test('运行时只读取宿主当前账户和已有MLS身份，不触发钱包、供钥或网络', () async {
    final root = await Directory.systemTemp.createTemp('tatachat_auth_runtime_');
    addTearDown(() => root.delete(recursive: true));
    final directory = Directory(await root.resolveSymbolicLinks());
    final host = _AuthenticationHost(_account());
    final actions = <Object?>[];
    final runtime = ChatRuntimeCore(
      host: host,
      store: ChatStore(),
      documentsDirectoryProvider: () async => directory,
      stateStoreFactory: (user) async {
        expect(user, 'user-a');
        return MlsStateStore(
          directory,
          ownerUserId: user,
          // 即使目录新建，认证也只能read，不能initialize。
          newlyCreated: true,
          debugCallJson: (input) {
            actions.add(input['action']);
            return _nativeResponse(input);
          },
        );
      },
    );
    addTearDown(runtime.close);
    final proof = await runtime.createMlsAuthenticationProof(_request());
    expect(proof.userId, host.account.userId);
    expect(proof.accountId, host.account.accountId);
    expect(proof.bindingRevision, host.account.bindingRevision);
    expect(actions, ['read', 'sign_authentication']);
    expect(host.forbiddenCalls, 0);
  });

  for (final phase in ['before signing', 'after signing']) {
    for (final change in ['user', 'account', 'binding', 'domain', 'host']) {
      test('认证$phase时$change变化必须失败，不交付旧账户证明', () async {
        final root = await Directory.systemTemp.createTemp('tatachat_auth_race_');
        addTearDown(() => root.delete(recursive: true));
        final directory = Directory(await root.resolveSymbolicLinks());
        final host = _AuthenticationHost(_account());
        var signs = 0;
        void changeAccount() {
          host.account = _account(
            user: change == 'user' ? 'user-b' : 'user-a',
            account: change == 'account' ? _hex(0x33) : _hex(0x11),
            revision: change == 'binding' ? 2 : 1,
            domain: change == 'domain' ? 'other' : 'synthetic',
            hostIndex: change == 'host' ? 2 : 1,
          );
        }
        final runtime = ChatRuntimeCore(
          host: host,
          store: ChatStore(),
          documentsDirectoryProvider: () async => directory,
          stateStoreFactory: (user) async {
            if (phase == 'before signing') changeAccount();
            return MlsStateStore(
              directory,
              ownerUserId: user,
              debugCallJson: (input) {
                final result = _nativeResponse(input);
                if (input['action'] == 'sign_authentication') {
                  signs++;
                  if (phase == 'after signing') changeAccount();
                }
                return result;
              },
            );
          },
        );
        addTearDown(runtime.close);
        await expectLater(
          runtime.createMlsAuthenticationProof(_request()),
          throwsStateError,
        );
        expect(signs, phase == 'before signing' ? 0 : 1);
        expect(host.forbiddenCalls, 0);
      });
    }
  }

  test('等待保护存储期间关闭运行时，必须失败且不能晚签', () async {
    final root = await Directory.systemTemp.createTemp('tatachat_auth_close_');
    addTearDown(() => root.delete(recursive: true));
    final directory = Directory(await root.resolveSymbolicLinks());
    final entered = Completer<void>(), release = Completer<void>();
    final host = _AuthenticationHost(_account());
    var nativeCalls = 0;
    final runtime = ChatRuntimeCore(
      host: host,
      store: ChatStore(),
      documentsDirectoryProvider: () async => directory,
      stateStoreFactory: (user) async {
        entered.complete();
        await release.future;
        return MlsStateStore(
          directory, ownerUserId: user,
          debugCallJson: (input) {
            nativeCalls++;
            return _nativeResponse(input);
          },
        );
      },
    );
    addTearDown(runtime.close);
    final rejected = expectLater(
      runtime.createMlsAuthenticationProof(_request()), throwsStateError,
    );
    await entered.future;
    final closed = runtime.close();
    release.complete();
    await rejected;
    await closed;
    expect(nativeCalls, 0);
    expect(host.forbiddenCalls, 0);
  });
}

// 以下全部为合成夹具，不读取设备数据、真实账户或真实密钥。
String _hex(int byte, {int length = 32}) =>
    '0x${List.filled(length, byte.toRadixString(16).padLeft(2, '0')).join()}';

MlsAuthenticationRequest _request({
  String origin = 'https://api.example.test',
  String target = '/auth/session',
  String method = 'POST',
  String? challenge,
  int? expiry,
  List<int> body = const [1, 2, 3],
}) => MlsAuthenticationRequest(
  serviceOrigin: origin,
  challenge: challenge ?? _hex(0x22),
  expiresAtMillis: expiry ?? DateTime.now().millisecondsSinceEpoch + 120000,
  method: method,
  requestTarget: target,
  bodyBytes: body,
);

Map<String, dynamic> _nativeResponse(Map<String, Object?> input) {
  final identity = <String, dynamic>{
    'user_id': input['user_id'],
    'device_id': _hex(0x44).substring(2),
    'public_key': _hex(0x44),
  };
  if (input['action'] == 'read') return identity;
  if (input['action'] != 'sign_authentication') {
    throw StateError('认证夹具禁止初始化或其他动作');
  }
  final request = input['request'] as Map<String, Object>;
  final bodyHex = request['body_hex'] as String;
  final body = [
    for (var i = 0; i < bodyHex.length; i += 2)
      int.parse(bodyHex.substring(i, i + 2), radix: 16),
  ];
  return {
    ...identity,
    'account_id': input['account_id'],
    'binding_revision': input['binding_revision'],
    'service_origin': request['service_origin'],
    'challenge': request['challenge'],
    'expires_at_millis': request['expires_at_millis'],
    'method': request['method'],
    'request_target': request['request_target'],
    'body_sha256': '0x${crypto_hash.sha256.convert(body)}',
    'signature': _hex(0x55, length: 64),
  };
}

ChatRuntimeAccount _account({
  String user = 'user-a',
  String? account,
  int revision = 1,
  String domain = 'synthetic',
  int hostIndex = 1,
}) => ChatRuntimeAccount(
  hostIndex: hostIndex,
  bindingScope: domain,
  userId: user,
  bindingRevision: revision,
  accountId: account ?? _hex(0x11),
  displayName: '合成测试账户',
);

class _AuthenticationHost implements ChatRuntimeHost {
  _AuthenticationHost(this.account);
  ChatRuntimeAccount account;
  int forbiddenCalls = 0;

  @override
  Future<ChatRuntimeAccount?> currentAccount({String? expectedAccountId}) async =>
      account;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    forbiddenCalls++;
    throw StateError('认证不得访问其他宿主能力');
  }
}
