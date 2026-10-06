import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mls_boundary.dart';
import 'mls_native.dart';

/// SDK拥有的系统保护MLS目录；不持有应用供给的包装钥。
class MlsStateStore {
  const MlsStateStore(
    this.directory, {
    required this.ownerUserId,
    this.newlyCreated = false,
    this.debugCallJson,
  });
  final Directory directory;
  final String ownerUserId;
  final bool newlyCreated;
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
    if (result == null ||
        result['path'] is! String ||
        result['created'] is! bool) {
      throw StateError('MLS保护存储不可用');
    }
    final store = MlsStateStore(
      Directory(result['path'] as String),
      ownerUserId: userId,
      newlyCreated: result['created'] as bool,
    );
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
    if (!directory.isAbsolute ||
        await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.directory ||
        await directory.resolveSymbolicLinks() != path) {
      throw StateError('MLS存储目录未准备或存在符号链接');
    }
  }

  /// 身份读取与初始化分离；已有目录缺状态时明确失败，不自动换钥。
  Future<ChatDevice> initializeIdentity() => _identity('initialize');
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
    String? handoverId,
    String? payloadJson,
  }) {
    return _call(false, {
      'state_store_dir': path,
      'user_id': ownerUserId,
      'action': action,
      'message_id': ?messageId,
      'pending_inbound': ?pending,
      'handover_id': ?handoverId,
      'payload_json': ?payloadJson,
    });
  }

  /// 交接收据使用同一系统保护存储，不另设MAC钥或签名钥。
  Future<void> writeReceipt(String id, String payload) async {
    await ensureReady();
    _store('write_receipt', handoverId: id, payloadJson: payload);
  }

  Future<List<String>> readReceipt(String id) async {
    await ensureReady();
    return (_store('read_receipt', handoverId: id)['payload_json'] as List?)
            ?.cast<String>() ??
        [];
  }

  Future<void> deleteReceipt(String id) async {
    await ensureReady();
    _store('delete_receipt', handoverId: id);
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
