import 'dart:io';
import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'mls_boundary.dart';
import 'mls_native.dart';

/// SDK拥有的系统保护MLS目录；不持有应用供给的包装钥。
class MlsStateStore {
  const MlsStateStore(
    this.directory, {
    required this.ownerUserId,
    this.debugCallJson,
  });
  final Directory directory;
  final String ownerUserId;
  @visibleForTesting
  final Map<String, dynamic> Function(Map<String, Object?>)? debugCallJson;
  @visibleForTesting
  static Future<MlsStateStore> Function(String)? debugPrepare;
  @visibleForTesting
  static Future<void> Function(String?)? debugErase;
  String get path => directory.path;
  static const _security = MethodChannel('tatachat_sdk/security');

  /// 平台插件在任何MLS秘密生成前创建并验证存储保护。
  static Future<MlsStateStore> prepare(String userId) async {
    if (userId.trim().isEmpty || userId.contains(':')) {
      throw ArgumentError('用户身份无效');
    }
    final fixture = debugPrepare;
    if (fixture != null) {
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        throw UnsupportedError('MLS夹具仅用于合成测试');
      }
      return fixture(userId);
    }
    final result = await _security.invokeMapMethod<String, dynamic>(
      'prepareMlsStorage',
      {'user_id': userId},
    );
    if (result == null || result.length != 1 || result['path'] is! String) {
      throw StateError('MLS保护存储不可用');
    }
    final raw = Directory(result['path'] as String);
    // 插件逐项核验SDK子目录；只规范系统容器别名，末级链接仍拒绝。
    if (!raw.isAbsolute) {
      throw const MlsNativeException(
        MlsNativeErrorCode.directoryInvalid,
        'MLS目录必须为绝对路径',
      );
    }
    final Directory canonical;
    try {
      final type = await FileSystemEntity.type(raw.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        throw const MlsNativeException(
          MlsNativeErrorCode.directoryUnavailable,
          'MLS目录尚未准备',
        );
      }
      if (type != FileSystemEntityType.directory) {
        throw const MlsNativeException(
          MlsNativeErrorCode.directoryInvalid,
          'MLS目录类型无效',
        );
      }
      canonical = Directory(await raw.resolveSymbolicLinks());
    } on FileSystemException {
      throw const MlsNativeException(
        MlsNativeErrorCode.directoryUnavailable,
        'MLS目录暂不可读',
      );
    }
    final store = MlsStateStore(canonical, ownerUserId: userId);
    await store.ensureReady();
    return store;
  }

  /// 既有SDK隐私擦除入口使用；不读取或删除宿主钱包存储。
  static Future<void> erase({String? userId}) async {
    final fixture = debugErase;
    if (fixture != null) {
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        throw UnsupportedError('MLS夹具仅用于合成测试');
      }
      await fixture(userId);
      return;
    }
    // 无平台存储夹具的纯Dart测试从未创建系统MLS目录。
    if (Platform.environment.containsKey('FLUTTER_TEST') &&
        debugPrepare == null) {
      return;
    }
    await _security.invokeMethod<void>('eraseMlsStorage', {'user_id': ?userId});
  }

  Future<void> ensureReady() async {
    if (!directory.isAbsolute) {
      throw const MlsNativeException(
        MlsNativeErrorCode.directoryInvalid,
        'MLS目录必须为绝对路径',
      );
    }
    try {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        throw const MlsNativeException(
          MlsNativeErrorCode.directoryUnavailable,
          'MLS目录尚未准备',
        );
      }
      if (type != FileSystemEntityType.directory ||
          await directory.resolveSymbolicLinks() != path) {
        throw const MlsNativeException(
          MlsNativeErrorCode.directoryInvalid,
          'MLS目录存在链接或类型无效',
        );
      }
    } on FileSystemException {
      throw const MlsNativeException(
        MlsNativeErrorCode.directoryUnavailable,
        'MLS目录暂不可读',
      );
    }
  }

  /// 唯一自动准备入口；合法空目录和中断提交由原生持久事实幂等处理。
  Future<ChatDevice> prepareIdentity() => _identity('prepare');

  /// 只读已有身份；缺失或损坏不得在认证请求中生成新密钥。
  Future<ChatDevice> readIdentity() => _identity('read');
  Future<ChatDevice> _identity(String action) async {
    await ensureReady();
    final response = _call(true, {
      'state_store_dir': path,
      'user_id': ownerUserId,
      'action': action,
    });
    if (response['user_id'] != ownerUserId) throw StateError('MLS身份所有者不一致');
    final identity = ChatDevice(
      userId: ownerUserId,
      deviceId: response['device_id'] as String,
      publicKey: response['public_key'] as String,
    );
    final error = identity.validate();
    if (error != null ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(identity.publicKey ?? '')) {
      throw StateError('MLS公开身份结果无效');
    }
    return identity;
  }

  /// 复用已有MLS身份签固定认证证明；缺状态永不初始化，不写聊天快照。
  Future<MlsAuthenticationProof> signAuthentication({
    required String accountId,
    required int bindingRevision,
    required MlsAuthenticationRequest request,
  }) async {
    request.validate();
    if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(accountId) ||
        bindingRevision < 0 ||
        bindingRevision > MlsAuthenticationRequest.maxJsonInteger) {
      throw ArgumentError('MLS认证账户事实无效');
    }
    final identity = await readIdentity();
    if (identity.deviceId != identity.publicKey!.substring(2)) {
      throw StateError('MLS认证公开身份不一致');
    }
    request.validate();
    final response = _call(true, {
      'state_store_dir': path,
      'user_id': ownerUserId,
      'action': 'sign_authentication',
      'account_id': accountId,
      'bind_rev': bindingRevision,
      'request': request.toJson(),
    });
    final bodyHash = '0x${crypto_hash.sha256.convert(request.bodyBytes)}';
    final expected = <String, Object>{
      'user_id': ownerUserId,
      'device_id': identity.deviceId,
      'public_key': identity.publicKey!,
      'account_id': accountId,
      'bind_rev': bindingRevision,
      'service_origin': request.serviceOrigin,
      'nonce_id': request.nonceId,
      'expires_at': request.expiresAt,
      'http_method': request.httpMethod,
      'request_target': request.requestTarget,
      'body_hash': bodyHash,
    };
    final signature = response['signature'];
    if (response.length != expected.length + 1 ||
        expected.entries.any((entry) => response[entry.key] != entry.value) ||
        signature is! String ||
        !RegExp(r'^0x[0-9a-f]{128}$').hasMatch(signature)) {
      throw StateError('MLS认证证明结果无效');
    }
    MlsAuthenticationRequest.validateExpiry(request.expiresAt);
    return MlsAuthenticationProof.fromJson(response.cast<String, Object>());
  }

  Map<String, dynamic> _call(bool identity, Map<String, Object?> request) {
    final fixture = debugCallJson;
    if (fixture != null) {
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        throw UnsupportedError('MLS夹具仅用于合成测试');
      }
      return fixture(request);
    }
    final bindings = MlsNativeBindings.load();
    return bindings.callJson(
      identity ? bindings.identity : bindings.store,
      request,
    );
  }

  Map<String, dynamic> _store(
    String action, {
    String? messageId,
    Map<String, Object?>? pending,
  }) {
    return _call(false, {
      'state_store_dir': path,
      'user_id': ownerUserId,
      'action': action,
      'message_id': ?messageId,
      'pending_inbound': ?pending,
    });
  }

  /// 附件协议动作使用现有store FFI，只有公开组合同与持久游标可越过边界。
  Future<Map<String, dynamic>> attachmentAction(
    String action,
    Map<String, Object?> attachment,
  ) async {
    await ensureReady();
    return _call(false, {
      'state_store_dir': path,
      'user_id': ownerUserId,
      'action': action,
      'attachment': attachment,
    });
  }

  Future<void> acknowledge(String messageId) async {
    await ensureReady();
    _store('acknowledge', messageId: messageId);
  }

  Future<List<Map<String, dynamic>>> pendingResults(String? messageId) async {
    await ensureReady();
    return (_store('pending_results', messageId: messageId)['results'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<void> queuePendingInbound(MlsWireMessage wire) async {
    await ensureReady();
    _store(
      'queue_pending',
      pending: {
        'conversation_id': wire.conversationId,
        'wire_hex': wire.wireHex,
      },
    );
  }

  Future<List<MlsWireMessage>> readPendingInbound() async {
    await ensureReady();
    return (_store('read_pending')['pending_inbound'] as List).map((item) {
      final hex = item['wire_hex'] as String;
      if (hex.length.isOdd) throw const FormatException('MLS密文编码无效');
      return MlsWireMessage(
        conversationId: item['conversation_id'] as String,
        wireBytes: [
          for (var i = 0; i < hex.length; i += 2)
            int.parse(hex.substring(i, i + 2), radix: 16),
        ],
      );
    }).toList();
  }

  Future<void> clearPendingInbound() async {
    await ensureReady();
    _store('clear_pending');
  }

  /// 本对象没有秘密缓冲；销毁不删除持久化身份。
  void dispose() {}
}
