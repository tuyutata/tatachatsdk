import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_mls/mls_native.dart';
import 'package:tatachat_mls/mls_state_store.dart';
import 'package:tatachat_runtime/chat_runtime.dart';
import 'package:tatachat_storage/chat_store.dart';
import 'package:tatachat_testing/native.dart';

// 合同测试锁定 TataChatSDK 的中性身份、状态清理边界和脱敏错误码。
void main() {

  TestWidgetsFlutterBinding.ensureInitialized();

  test('Dart拒绝错身份、错请求、漏字段、额外字段或私钥夹带的原生证明', () async {
    final root = await Directory.systemTemp.createTemp(
      'tatachat_auth_boundary_',
    );
    addTearDown(() => root.delete(recursive: true));
    final directory = Directory(await root.resolveSymbolicLinks());
    final request = createAuthenticationRequest();
    for (final field in [
      'user_id',
      'device_id',
      'public_key',
      'account_id',
      'bind_rev',
      'service_origin',
      'nonce_id',
      'expires_at',
      'http_method',
      'request_target',
      'body_hash',
      'signature',
      'private_key',
      'body_hex',
    ]) {
      final store = MlsStateStore(
        directory,
        ownerUserId: 'user-a',
        debugCallJson: (input) {
          final result = _nativeResponse(input);
          if (input['action'] == 'sign_authentication') {
            result[field] = field == 'bind_rev' || field == 'expires_at'
                ? 2
                : 'synthetic invalid value';
          }
          return result;
        },
      );
      await expectLater(
        store.signAuthentication(
          accountId: _hex(0x11),
          bindingRevision: 1,
          request: request,
        ),
        throwsStateError,
      );
    }
    final missing = MlsStateStore(
      directory,
      ownerUserId: 'user-a',
      debugCallJson: (input) {
        final result = _nativeResponse(input);
        if (input['action'] == 'sign_authentication') {
          result.remove('signature');
        }
        return result;
      },
    );
    await expectLater(
      missing.signAuthentication(
        accountId: _hex(0x11),
        bindingRevision: 1,
        request: request,
      ),
      throwsStateError,
    );
  });

  for (final changed in [false, true]) {
    test('离线自动准备固定当前账户，准备前绑定变化=$changed不得交付身份', () async {
      final temporary = await Directory.systemTemp.createTemp('mls_prepare_');
      final root = Directory(await temporary.resolveSymbolicLinks());
      addTearDown(() => root.delete(recursive: true));
      final host = _AuthenticationHost(_account());
      final actions = <Object?>[];
      final runtime = ChatRuntimeCore(
        host: host,
        store: ChatStore(),
        documentsDirectoryProvider: () async => root,
        stateStoreFactory: (user) async {
          if (changed) host.account = _account(user: 'other-user');
          return MlsStateStore(
            root,
            ownerUserId: user,
            debugCallJson: (input) {
              actions.add(input['action']);
              return {
                'user_id': user,
                'device_id': '22' * 32,
                'public_key': '0x${'22' * 32}',
              };
            },
          );
        },
      );
      addTearDown(runtime.close);
      final result = runtime.readLocalMlsIdentity();
      if (changed) {
        await expectLater(result, throwsA(isA<MlsNativeException>()));
        expect(actions, isEmpty);
      } else {
        expect((await result).userId, 'user-a');
        expect(actions, ['prepare']);
        await runtime.readLocalMlsIdentity();
        expect(actions, ['prepare', 'prepare']);
      }
      expect(host.forbiddenCalls, 0);
    });
  }

  for (final change in ['user', 'account', 'binding', 'domain', 'host']) {
    test('自动准备原生返回后$change变化，不交付旧身份或启动网络', () async {
      final temporary = await Directory.systemTemp.createTemp(
        'mls_prepare_late_',
      );
      final root = Directory(await temporary.resolveSymbolicLinks());
      addTearDown(() => root.delete(recursive: true));
      final host = _AuthenticationHost(_account());
      var calls = 0;
      final runtime = ChatRuntimeCore(
        host: host,
        store: ChatStore(),
        documentsDirectoryProvider: () async => root,
        stateStoreFactory: (user) async => MlsStateStore(
          root,
          ownerUserId: user,
          debugCallJson: (input) {
            expect(input['action'], 'prepare');
            calls++;
            host.account = _account(
              user: change == 'user' ? 'user-b' : 'user-a',
              account: change == 'account' ? _hex(0x33) : _hex(0x11),
              revision: change == 'binding' ? 2 : 1,
              domain: change == 'domain' ? 'other' : 'synthetic',
              hostIndex: change == 'host' ? 2 : 1,
            );
            return {
              'user_id': user,
              'device_id': '22' * 32,
              'public_key': '0x${'22' * 32}',
            };
          },
        ),
      );
      addTearDown(runtime.close);
      await expectLater(
        runtime.readLocalMlsIdentity(),
        throwsA(isA<MlsNativeException>()),
      );
      expect(calls, 1);
      expect(host.forbiddenCalls, 0);
    });
  }

  test('运行时只读取宿主当前账户和已有MLS身份，不触发钱包、供钥或网络', () async {
    final root = await Directory.systemTemp.createTemp(
      'tatachat_auth_runtime_',
    );
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
          // 请求证明严格读取已准备身份，不在签名途中准备新密钥。
          debugCallJson: (input) {
            actions.add(input['action']);
            return _nativeResponse(input);
          },
        );
      },
    );
    addTearDown(runtime.close);
    final proof = await runtime.createMlsAuthenticationProof(createAuthenticationRequest());
    expect(proof.toJson()['user_id'], host.account.userId);
    expect(proof.toJson()['account_id'], host.account.accountId);
    expect(proof.toJson()['bind_rev'], host.account.bindingRevision);
    expect(actions, ['read', 'sign_authentication']);
    expect(host.forbiddenCalls, 0);
  });

  for (final phase in ['before signing', 'after signing']) {
    for (final change in ['user', 'account', 'binding', 'domain', 'host']) {
      test('认证$phase时$change变化必须失败，不交付旧账户证明', () async {
        final root = await Directory.systemTemp.createTemp(
          'tatachat_auth_race_',
        );
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
          runtime.createMlsAuthenticationProof(createAuthenticationRequest()),
          throwsStateError,
        );
        expect(signs, phase == 'before signing' ? 0 : 1);
        expect(host.forbiddenCalls, 0);
      });
    }
  }

  for (final prepare in [false, true]) {
    test('等待保护存储期间关闭运行时，准备=$prepare不得生成或交付旧结果', () async {
      final root = await Directory.systemTemp.createTemp(
        'tatachat_auth_close_',
      );
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
            directory,
            ownerUserId: user,
            debugCallJson: (input) {
              nativeCalls++;
              return _nativeResponse(input);
            },
          );
        },
      );
      addTearDown(runtime.close);
      final result = prepare
          ? runtime.readLocalMlsIdentity()
          : runtime.createMlsAuthenticationProof(createAuthenticationRequest());
      final rejected = expectLater(
        result,
        prepare ? throwsA(isA<MlsNativeException>()) : throwsStateError,
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
}


// 以下全部为合成夹具，不读取设备数据、真实账户或真实密钥。
String _hex(int byte, {int length = 32}) =>
    '0x${List.filled(length, byte.toRadixString(16).padLeft(2, '0')).join()}';

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
    'bind_rev': input['bind_rev'],
    'service_origin': request['service_origin'],
    'nonce_id': request['nonce_id'],
    'expires_at': request['expires_at'],
    'http_method': request['http_method'],
    'request_target': request['request_target'],
    'body_hash': '0x${crypto_hash.sha256.convert(body)}',
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
  Future<ChatRuntimeAccount?> currentAccount({
    String? expectedAccountId,
  }) async => account;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    forbiddenCalls++;
    throw StateError('认证不得访问其他宿主能力');
  }
}
