import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import 'mls_boundary.dart';
import 'mls_group_boundary.dart';
import 'mls_state_store.dart';

/// OpenMLS native smoke 结果。
class MlsNativeSmokeResult {
  const MlsNativeSmokeResult({
    required this.plaintext,
    required this.decryptedPlaintext,
    required this.cipherSuite,
    required this.aliceWireMessageHex,
    required this.bobKeyPackageHex,
    required this.welcomeHex,
  });

  final String plaintext;
  final String decryptedPlaintext;
  final String cipherSuite;
  final String aliceWireMessageHex;
  final String bobKeyPackageHex;
  final String welcomeHex;

  bool get roundTripOk => plaintext == decryptedPlaintext;

  factory MlsNativeSmokeResult.fromJson(Map<String, dynamic> json) {
    return MlsNativeSmokeResult(
      plaintext: (json['plaintext'] ?? '').toString(),
      decryptedPlaintext: (json['decrypted_plaintext'] ?? '').toString(),
      cipherSuite: (json['cipher_suite'] ?? '').toString(),
      aliceWireMessageHex: (json['alice_wire_message_hex'] ?? '').toString(),
      bobKeyPackageHex: (json['bob_key_package_hex'] ?? '').toString(),
      welcomeHex: (json['welcome_hex'] ?? '').toString(),
    );
  }
}

/// 通过现有 native 库调用 Rust OpenMLS。
///
/// 该类只负责跨 FFI 边界，密码学实现全部在 Rust OpenMLS 中完成。
class NativeMlsCrypto implements MlsGroupCrypto {
  NativeMlsCrypto({
    MlsNativeBindings? bindings,
    ChatDevice? identity,
    MlsStateStore? stateStore,
  }) : _bindings = bindings ?? MlsNativeBindings.load(),
       _identity = identity,
       _stateStore = stateStore;

  final MlsNativeBindings _bindings;
  final ChatDevice? _identity;
  final MlsStateStore? _stateStore;

  /// 当前账户运行上下文退出后立即清零 Dart 侧 MLS 状态消息钥。
  void dispose() {
    _stateStore?.dispose();
  }

  @override
  Future<MlsKeyPackage> createKeyPackage(
    ChatDevice identity, {
    bool lastResort = false,
  }) async {
    final error = identity.validate();
    if (error != null) {
      throw ArgumentError(error);
    }

    final response = _bindings.callJson(_bindings.createKeyPackage, {
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      if (_stateStore != null) 'state_store_dir': _stateStore.path,
      if (_stateStore != null) 'state_key_hex': _stateStore.stateKeyHex,
      'last_resort': lastResort,
    });
    return MlsKeyPackage(
      userId: identity.userId,
      deviceId: identity.deviceId,
      keyPackageRef: _requireField(response, 'key_package_ref'),
      keyPackageBytes: _hexToBytes(_requireField(response, 'key_package_hex')),
      cipherSuite: (response['cipher_suite'] ?? '').toString(),
      notBeforeMillis: (response['not_before_millis'] as num?)?.toInt() ?? 0,
      notAfterMillis: (response['not_after_millis'] as num?)?.toInt() ?? 0,
      lastResort: response['last_resort'] == true,
    );
  }

  /// 运行 Rust OpenMLS 两方 round-trip smoke。
  Future<MlsNativeSmokeResult> runTwoPartySmoke({
    required String plaintext,
  }) async {
    final response = _bindings.callJson(_bindings.twoPartySmoke, {
      'plaintext': plaintext,
    });
    return MlsNativeSmokeResult.fromJson(response);
  }

  // 私聊和群聊统一调用同一套 OpenMLS 群接口。

  @override
  Future<GroupCreated> createGroup(String groupId) async {
    final identity = _requireIdentity();
    final stateStore = _requireStateStore();
    await stateStore.ensureReady();
    final response = _bindings.callJson(_bindings.groupCreate, {
      'state_store_dir': stateStore.path,
      'state_key_hex': stateStore.stateKeyHex,
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      'group_id': groupId,
    });
    return GroupCreated(
      groupId: (response['group_id'] ?? groupId).toString(),
      epoch: (response['epoch'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<GroupCommitBundle> addMembers(
    String groupId,
    List<MlsKeyPackage> keyPackages,
  ) async {
    final identity = _requireIdentity();
    final stateStore = _requireStateStore();
    await stateStore.ensureReady();
    final response = _bindings.callJson(_bindings.groupAddMembers, {
      'state_store_dir': stateStore.path,
      'state_key_hex': stateStore.stateKeyHex,
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      'group_id': groupId,
      'key_packages_hex': keyPackages
          .map((keyPackage) => keyPackage.keyPackageHex)
          .toList(),
    });
    final welcomeHex = (response['welcome_wire_hex'] ?? '').toString();
    return GroupCommitBundle(
      groupId: (response['group_id'] ?? groupId).toString(),
      epoch: (response['epoch'] as num?)?.toInt() ?? 0,
      commit: _groupWire(
        groupId,
        (response['commit_wire_hex'] ?? '').toString(),
        MlsMessageKind.commit,
      ),
      welcome: welcomeHex.isEmpty
          ? null
          : _groupWire(groupId, welcomeHex, MlsMessageKind.welcome),
    );
  }

  @override
  Future<GroupCommitBundle> removeMembers(
    String groupId,
    List<String> memberUserIds,
  ) async {
    final identity = _requireIdentity();
    final stateStore = _requireStateStore();
    await stateStore.ensureReady();
    final response = _bindings.callJson(_bindings.groupRemoveMembers, {
      'state_store_dir': stateStore.path,
      'state_key_hex': stateStore.stateKeyHex,
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      'group_id': groupId,
      'member_user_ids': memberUserIds,
    });
    final removed =
        (response['removed_user_ids'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];
    return GroupCommitBundle(
      groupId: (response['group_id'] ?? groupId).toString(),
      epoch: (response['epoch'] as num?)?.toInt() ?? 0,
      commit: _groupWire(
        groupId,
        (response['commit_wire_hex'] ?? '').toString(),
        MlsMessageKind.commit,
      ),
      removedUserIds: removed,
    );
  }

  @override
  Future<MlsWireMessage> groupCreateMessage(
    String groupId,
    List<int> plaintext,
  ) async {
    final identity = _requireIdentity();
    final stateStore = _requireStateStore();
    await stateStore.ensureReady();
    final response = _bindings.callJson(_bindings.groupCreateMessage, {
      'state_store_dir': stateStore.path,
      'state_key_hex': stateStore.stateKeyHex,
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      'group_id': groupId,
      'plaintext_hex': _bytesToHex(plaintext),
    });
    return _groupWire(
      groupId,
      (response['application_wire_hex'] ?? '').toString(),
      MlsMessageKind.application,
    );
  }

  @override
  Future<GroupInbound> groupProcess(MlsWireMessage wire) async {
    final identity = _requireIdentity();
    final stateStore = _requireStateStore();
    await stateStore.ensureReady();
    final response = _bindings.callJson(_bindings.groupProcess, {
      'state_store_dir': stateStore.path,
      'state_key_hex': stateStore.stateKeyHex,
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      'group_id': wire.conversationId,
      'wire_message_hex': wire.wireHex,
    });
    final plaintextHex = response['plaintext_hex']?.toString();
    final members = (response['member_identities'] as List?)
        ?.map((item) => item.toString())
        .toList();
    return GroupInbound(
      groupId: (response['group_id'] ?? wire.conversationId).toString(),
      kind: GroupInboundKind.fromWireName(
        (response['message_kind'] ?? '').toString(),
      ),
      status: GroupProcessStatus.fromWireName(
        (response['status'] ?? '').toString(),
      ),
      messageEpoch: (response['message_epoch'] as num?)?.toInt() ?? 0,
      groupEpoch: (response['group_epoch'] as num?)?.toInt() ?? 0,
      selfRemoved: response['self_removed'] == true,
      plaintext: plaintextHex == null || plaintextHex.isEmpty
          ? null
          : _hexToBytes(plaintextHex),
      memberIdentities: members,
    );
  }

  @override
  Future<GroupState> groupState(String groupId) async {
    final identity = _requireIdentity();
    final stateStore = _requireStateStore();
    await stateStore.ensureReady();
    final response = _bindings.callJson(_bindings.groupState, {
      'state_store_dir': stateStore.path,
      'state_key_hex': stateStore.stateKeyHex,
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      'group_id': groupId,
    });
    final members =
        (response['member_identities'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];
    return GroupState(
      groupId: (response['group_id'] ?? groupId).toString(),
      epoch: (response['epoch'] as num?)?.toInt() ?? 0,
      memberIdentities: members,
    );
  }

  MlsWireMessage _groupWire(
    String groupId,
    String wireHex,
    MlsMessageKind kind,
  ) {
    return MlsWireMessage(
      wireBytes: _hexToBytes(wireHex),
      conversationId: groupId,
      messageKind: kind,
    );
  }

  ChatDevice _requireIdentity() {
    final identity = _identity;
    if (identity == null) {
      throw StateError('NativeMlsCrypto 需要 Chat 设备身份才能执行会话加解密');
    }
    final error = identity.validate();
    if (error != null) {
      throw ArgumentError(error);
    }
    return identity;
  }

  MlsStateStore _requireStateStore() {
    final store = _stateStore;
    if (store == null) {
      throw StateError('NativeMlsCrypto 需要 MLS stateStore 才能持久化会话');
    }
    return store;
  }
}

typedef MlsJsonNative =
    Pointer<Utf8> Function(
      Pointer<Utf8> requestJson,
      Pointer<Pointer<Utf8>> errorOut,
    );
typedef MlsJsonDart =
    Pointer<Utf8> Function(
      Pointer<Utf8> requestJson,
      Pointer<Pointer<Utf8>> errorOut,
    );
typedef MlsFreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef MlsFreeStringDart = void Function(Pointer<Utf8> ptr);

/// Chat MLS native bindings。
class MlsNativeBindings {
  MlsNativeBindings._({
    required this.createKeyPackage,
    required this.twoPartySmoke,
    required this.rekeyState,
    required this.groupCreate,
    required this.groupAddMembers,
    required this.groupRemoveMembers,
    required this.groupCreateMessage,
    required this.groupProcess,
    required this.groupState,
    required MlsFreeStringDart freeString,
  }) : _freeString = freeString;

  final MlsJsonDart createKeyPackage;
  final MlsJsonDart twoPartySmoke;
  final MlsJsonDart rekeyState;
  final MlsJsonDart groupCreate;
  final MlsJsonDart groupAddMembers;
  final MlsJsonDart groupRemoveMembers;
  final MlsJsonDart groupCreateMessage;
  final MlsJsonDart groupProcess;
  final MlsJsonDart groupState;
  final MlsFreeStringDart _freeString;

  static MlsNativeBindings load() {
    final library = _loadChatSdkLibrary();
    return MlsNativeBindings._(
      createKeyPackage: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'tatachat_sdk_mls_create_key_package_json',
      ),
      twoPartySmoke: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'tatachat_sdk_mls_two_party_smoke_json',
      ),
      rekeyState: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'tatachat_sdk_mls_rekey_state_json',
      ),
      groupCreate: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'tatachat_sdk_mls_group_create_json',
      ),
      groupAddMembers: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'tatachat_sdk_mls_group_add_members_json',
      ),
      groupRemoveMembers: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'tatachat_sdk_mls_group_remove_members_json',
      ),
      groupCreateMessage: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'tatachat_sdk_mls_group_create_message_json',
      ),
      groupProcess: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'tatachat_sdk_mls_group_process_json',
      ),
      groupState: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'tatachat_sdk_mls_group_state_json',
      ),
      freeString: library
          .lookupFunction<MlsFreeStringNative, MlsFreeStringDart>(
            'tatachat_sdk_free_string',
          ),
    );
  }

  Map<String, dynamic> callJson(
    MlsJsonDart function,
    Map<String, Object?> request,
  ) {
    final requestPtr = jsonEncode(request).toNativeUtf8();
    final errorOut = calloc<Pointer<Utf8>>();
    Pointer<Utf8> resultPtr = nullptr;
    try {
      resultPtr = function(requestPtr, errorOut);
      if (resultPtr == nullptr) {
        final errorPtr = errorOut.value;
        final message = errorPtr == nullptr
            ? 'OpenMLS native 调用失败'
            : errorPtr.toDartString();
        if (errorPtr != nullptr) {
          _freeString(errorPtr);
        }
        throw MlsNativeException.fromTechnicalMessage(message);
      }
      final json = jsonDecode(resultPtr.toDartString());
      return (json as Map).cast<String, dynamic>();
    } finally {
      calloc.free(requestPtr);
      calloc.free(errorOut);
      if (resultPtr != nullptr) {
        _freeString(resultPtr);
      }
    }
  }

  /// 运行 Rust MLS 状态换绑边界；明文只在 Rust 内存中短暂存在。
  void runStateRekey({
    required String stateStoreDir,
    required String action,
    String? currentStateKeyHex,
    String? newStateKeyHex,
  }) {
    callJson(rekeyState, <String, Object?>{
      'state_store_dir': stateStoreDir,
      'action': action,
      if (currentStateKeyHex != null)
        'current_state_key_hex': currentStateKeyHex,
      if (newStateKeyHex != null) 'new_state_key_hex': newStateKeyHex,
    });
  }
}

DynamicLibrary _loadChatSdkLibrary() {
  // iOS 由 TataChatSDK 自己的 CocoaPods 目标链接、嵌入并签名动态 XCFramework；dyld
  // 在 Dart 启动前已经装载该 Framework，因此从当前进程解析其唯一 C FFI 符号。
  // Smoldot 不再参与 TataChatSDK 的编译、链接、导出或加载。
  if (Platform.isIOS) {
    return DynamicLibrary.process();
  }
  final candidates = <String>[];
  final cwd = Directory.current.path;
  if (Platform.isMacOS) {
    candidates.addAll([
      path.join(cwd, 'native', 'target', 'debug', 'libtatachat_sdk.dylib'),
      path.join(cwd, 'native', 'target', 'release', 'libtatachat_sdk.dylib'),
      path.join(
        cwd,
        '..',
        'tatachatsdk',
        'native',
        'target',
        'debug',
        'libtatachat_sdk.dylib',
      ),
      path.join(
        cwd,
        '..',
        'tatachatsdk',
        'native',
        'target',
        'release',
        'libtatachat_sdk.dylib',
      ),
      'libtatachat_sdk.dylib',
    ]);
  } else if (Platform.isWindows) {
    candidates.addAll([
      path.join(cwd, 'native', 'target', 'debug', 'tatachat_sdk.dll'),
      path.join(cwd, 'native', 'target', 'release', 'tatachat_sdk.dll'),
      path.join(
        cwd,
        '..',
        'tatachatsdk',
        'native',
        'target',
        'debug',
        'tatachat_sdk.dll',
      ),
      path.join(
        cwd,
        '..',
        'tatachatsdk',
        'native',
        'target',
        'release',
        'tatachat_sdk.dll',
      ),
      'tatachat_sdk.dll',
    ]);
  } else {
    candidates.addAll([
      path.join(cwd, 'native', 'target', 'debug', 'libtatachat_sdk.so'),
      path.join(cwd, 'native', 'target', 'release', 'libtatachat_sdk.so'),
      path.join(
        cwd,
        '..',
        'tatachatsdk',
        'native',
        'target',
        'debug',
        'libtatachat_sdk.so',
      ),
      path.join(
        cwd,
        '..',
        'tatachatsdk',
        'native',
        'target',
        'release',
        'libtatachat_sdk.so',
      ),
      'libtatachat_sdk.so',
    ]);
  }

  Object? lastError;
  for (final candidate in candidates) {
    if (candidate.startsWith('lib') || File(candidate).existsSync()) {
      try {
        return DynamicLibrary.open(candidate);
      } catch (e) {
        lastError = e;
      }
    }
  }
  throw MlsNativeException(
    MlsNativeErrorCode.libraryUnavailable,
    '无法加载 libtatachat_sdk native 库: $lastError',
  );
}

/// OpenMLS FFI 的结构化错误类别。
///
/// 技术信息仅供日志和测试定位；页面必须通过 [userMessage] 展示固定中文文案，禁止把
/// native 路径、Dart `Bad state` 前缀或不可控底层文本直接交给用户。
enum MlsNativeErrorCode {
  stateOwnerMismatch,
  storageReadFailed,
  storageAuthFailed,
  deviceReadFailed,
  deviceAuthFailed,
  stateInvalid,
  signerMissing,
  libraryUnavailable,
  invalidRequest,
  invalidResponse,
  operationFailed,
}

class MlsNativeException implements Exception {
  const MlsNativeException(this.code, this.technicalMessage);

  factory MlsNativeException.fromTechnicalMessage(String message) {
    if (message.contains('CHAT_MLS_STATE_OWNER_MISMATCH')) {
      return MlsNativeException(MlsNativeErrorCode.stateOwnerMismatch, message);
    }
    if (message.contains('CHAT_MLS_STORAGE_READ_FAILED')) {
      return MlsNativeException(MlsNativeErrorCode.storageReadFailed, message);
    }
    if (message.contains('CHAT_MLS_STORAGE_AUTH_FAILED')) {
      return MlsNativeException(MlsNativeErrorCode.storageAuthFailed, message);
    }
    if (message.contains('CHAT_MLS_DEVICE_READ_FAILED')) {
      return MlsNativeException(MlsNativeErrorCode.deviceReadFailed, message);
    }
    if (message.contains('CHAT_MLS_DEVICE_AUTH_FAILED')) {
      return MlsNativeException(MlsNativeErrorCode.deviceAuthFailed, message);
    }
    if (message.contains('CHAT_MLS_STATE_INVALID')) {
      return MlsNativeException(MlsNativeErrorCode.stateInvalid, message);
    }
    if (message.contains('CHAT_MLS_SIGNER_MISSING')) {
      return MlsNativeException(MlsNativeErrorCode.signerMissing, message);
    }
    return MlsNativeException(MlsNativeErrorCode.operationFailed, message);
  }

  final MlsNativeErrorCode code;
  final String technicalMessage;

  /// 只有本机 TataChatSDK 状态自身无法认证或解析时才允许清空 Chat 域重建。
  bool get requiresStateReset => switch (code) {
    MlsNativeErrorCode.stateOwnerMismatch ||
    MlsNativeErrorCode.storageReadFailed ||
    MlsNativeErrorCode.storageAuthFailed ||
    MlsNativeErrorCode.deviceReadFailed ||
    MlsNativeErrorCode.deviceAuthFailed ||
    MlsNativeErrorCode.stateInvalid ||
    MlsNativeErrorCode.signerMissing => true,
    _ => false,
  };

  /// 脱敏诊断只记录该稳定码，不记录用户、账户、路径、密钥或底层文本。
  String get diagnosticCode => switch (code) {
    MlsNativeErrorCode.stateOwnerMismatch => 'state_owner_mismatch',
    MlsNativeErrorCode.storageReadFailed => 'storage_read_failed',
    MlsNativeErrorCode.storageAuthFailed => 'storage_auth_failed',
    MlsNativeErrorCode.deviceReadFailed => 'device_read_failed',
    MlsNativeErrorCode.deviceAuthFailed => 'device_auth_failed',
    MlsNativeErrorCode.stateInvalid => 'state_invalid',
    MlsNativeErrorCode.signerMissing => 'signer_missing',
    MlsNativeErrorCode.libraryUnavailable => 'library_unavailable',
    MlsNativeErrorCode.invalidRequest => 'invalid_request',
    MlsNativeErrorCode.invalidResponse => 'invalid_response',
    MlsNativeErrorCode.operationFailed => 'operation_failed',
  };

  String get userMessage => switch (code) {
    MlsNativeErrorCode.stateOwnerMismatch => '当前用户身份的聊天设备状态属于其他用户，请重新切换账户后再试',
    MlsNativeErrorCode.storageReadFailed ||
    MlsNativeErrorCode.storageAuthFailed ||
    MlsNativeErrorCode.deviceReadFailed ||
    MlsNativeErrorCode.deviceAuthFailed ||
    MlsNativeErrorCode.stateInvalid ||
    MlsNativeErrorCode.signerMissing => '当前用户身份的聊天加密状态无法恢复，请重新进入宿主',
    MlsNativeErrorCode.libraryUnavailable => '聊天安全组件加载失败，请重新安装当前版本',
    MlsNativeErrorCode.invalidRequest ||
    MlsNativeErrorCode.invalidResponse ||
    MlsNativeErrorCode.operationFailed => '聊天安全组件暂时无法使用，请稍后重试',
  };

  @override
  String toString() => technicalMessage;
}

/// 返回可持久记录的脱敏错误码；非 native 错误统一收敛，不读取异常原文。
String chatSdkDiagnosticCode(Object error) =>
    error is MlsNativeException ? error.diagnosticCode : 'operation_failed';

/// 将 Chat/OpenMLS 异常收敛为可公开展示的固定中文文案。
///
/// 未列入白名单的底层异常统一返回 [fallback]；禁止把 `Bad state`、动态库路径、native
/// 调试文本或损坏字节直接渲染到 Android/iOS 页面。
String chatSdkUserErrorMessage(
  Object error, {
  String fallback = '聊天暂时无法使用，请稍后重试',
}) {
  if (error is MlsNativeException) return error.userMessage;
  final technical = error.toString();
  if (technical.contains('当前默认账户尚未注册用户身份')) {
    return '当前默认账户尚未注册用户身份，无法使用聊天';
  }
  if (technical.contains('身份账户已切换') ||
      technical.contains('用户身份当前绑定已切换') ||
      technical.contains('当前用户投影不一致')) {
    return '当前登录用户已切换，请重新进入聊天';
  }
  if (technical.contains('key_package_not_available') ||
      technical.contains('对方没有可用 Chat KeyPackage') ||
      technical.contains('没有可用 Chat KeyPackage')) {
    return '对方暂时无法接收加密消息，请稍后重试';
  }
  if (technical.contains('invalid_key_package_lifetime') ||
      technical.contains('key_package_write_rejected')) {
    return '聊天安全材料更新失败，请稍后重试';
  }
  if (technical.contains('对方尚未绑定身份（用户身份）')) {
    return '对方尚未绑定身份（用户身份）';
  }
  if (technical.contains('对方 用户身份 当前没有有效钱包绑定')) {
    return '对方 用户身份 当前没有有效钱包绑定';
  }
  if (technical.contains('允许麦克风权限')) {
    return '请在系统设置中允许麦克风权限';
  }
  if (technical.contains('已退出该群')) {
    return '已退出该群，无法继续操作';
  }
  if (technical.contains('群不存在')) {
    return '该群聊已不存在';
  }
  return fallback;
}

/// 读 Rust 侧**必填**响应字段;缺字段或空值一律抛错,绝不静默退化成空串。
///
/// FFI 两侧字段名没有编译期约束，任何拼写漂移都会让错误远离根因；因此必须在
/// OpenMLS 边界立即失败，禁止把空串继续传入群状态或 KeyPackage 流程。
///
/// 只用于**恒非空**的字段;可为空的响应字段(如无新会话时的
/// `welcome_wire_message_hex`、Welcome 消息的 `plaintext_hex`)照旧走 `?? ''`。
String _requireField(Map<String, dynamic> response, String key) {
  final value = (response[key] ?? '').toString();
  if (value.isEmpty) {
    throw MlsNativeException(
      MlsNativeErrorCode.invalidResponse,
      'OpenMLS native 响应缺少必填字段 $key;请核对 Rust 侧 FFI 键名',
    );
  }
  return value;
}

List<int> _hexToBytes(String value) {
  final normalized = value.startsWith('0x') ? value.substring(2) : value;
  if (normalized.length.isOdd) {
    throw const FormatException('OpenMLS hex 长度必须为偶数');
  }
  if (normalized.isNotEmpty &&
      !RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized)) {
    throw const FormatException('OpenMLS hex 必须合法');
  }
  final bytes = <int>[];
  for (var i = 0; i < normalized.length; i += 2) {
    bytes.add(int.parse(normalized.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

String _bytesToHex(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
