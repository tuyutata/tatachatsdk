// TataChatSDK 的 RFC 9420 MLS 边界模型。
//
// Dart 只传递身份、KeyPackage、MLS wire bytes和受限认证请求。签名唯一由
// Rust OpenMLS 完成，禁止另建原始 HPKE 直聊协议或应用层密钥编号。

export 'mls_session.dart';

/// 本机 Chat 设备身份。
class ChatDevice {
  const ChatDevice({
    required this.userId,
    required this.deviceId,
    this.publicKey,
  });

  /// Chat 永久用户身份主键，由宿主产品注入。
  final String userId;

  /// 同一用户下唯一设备标识。
  final String deviceId;

  /// 已初始化原生MLS签名公钥；只读公开值，不是独立设备认证钥。
  final String? publicKey;

  String? validate() {
    if (userId.trim().isEmpty || userId.contains(':')) {
      return 'Chat 用户身份不能为空且不能包含冒号';
    }
    if (deviceId.trim().isEmpty || deviceId.contains(':')) {
      return 'Chat 设备 ID 不能为空且不能包含冒号';
    }
    return null;
  }
}

/// OpenMLS 生成的 RFC 9420 KeyPackage。
class MlsKeyPackage {
  const MlsKeyPackage({
    required this.userId,
    required this.deviceId,
    required this.keyPackageRef,
    required this.keyPackageBytes,
    required this.cipherSuite,
    required this.notBeforeMillis,
    required this.notAfterMillis,
    required this.lastResort,
  });

  final String userId;
  final String deviceId;

  /// OpenMLS 根据标准 KeyPackage 计算的 KeyPackageRef 十六进制值。
  final String keyPackageRef;

  final List<int> keyPackageBytes;
  final String cipherSuite;
  final int notBeforeMillis;
  final int notAfterMillis;
  final bool lastResort;

  String get keyPackageHex => _bytesToHex(keyPackageBytes);
}

String _bytesToHex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

/// 同一MLS身份的应用认证请求；不接受用户、设备、密钥或自选签名域。
///
/// 目标路径和正文必须与实际HTTPS请求逐字相同。调用方只能构造这一固定结构，
/// 不能用它获得普通MLS协议标签或其他任意字节的签名。
class MlsAuthenticationRequest {
  MlsAuthenticationRequest({
    required this.serviceOrigin,
    required this.challenge,
    required this.expiresAtMillis,
    required this.method,
    required this.requestTarget,
    required List<int> bodyBytes,
  }) : bodyBytes = List<int>.unmodifiable(bodyBytes);

  final String serviceOrigin;
  final String challenge;
  final int expiresAtMillis;
  final String method;
  final String requestTarget;
  final List<int> bodyBytes;

  static const maxBodyBytes = 1024 * 1024;
  static const maxJsonInteger = 9007199254740991;
  static final _hex32 = RegExp(r'^0x[0-9a-f]{64}$');
  static const _methods = {
    'GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS',
  };

  /// Dart提前拒绝无效结构；原生重复校验，FFI直接调用也不能绕过。
  void validate() {
    final origin = Uri.tryParse(serviceOrigin);
    if (origin == null ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        origin.path.isNotEmpty ||
        origin.port <= 0 ||
        origin.port > 65535 ||
        origin.origin != serviceOrigin ||
        serviceOrigin.length > 268 ||
        !serviceOrigin.codeUnits.every((byte) => byte >= 33 && byte <= 126) ||
        serviceOrigin.contains(r'\') ||
        !_hex32.hasMatch(challenge) ||
        !_methods.contains(method) ||
        requestTarget.length > 8192 ||
        !requestTarget.startsWith('/') ||
        requestTarget.startsWith('//') ||
        requestTarget.contains('#') ||
        requestTarget.contains(r'\') ||
        !requestTarget.codeUnits.every((byte) => byte >= 33 && byte <= 126) ||
        RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(requestTarget) ||
        bodyBytes.length > maxBodyBytes ||
        !bodyBytes.every((byte) => byte >= 0 && byte <= 255)) {
      throw ArgumentError('MLS认证请求结构无效');
    }
    validateExpiry(expiresAtMillis);
  }

  static void validateExpiry(int expiry) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (expiry > maxJsonInteger || expiry <= now || expiry - now > 300000) {
      throw ArgumentError('MLS认证挑战已过期或有效期非法');
    }
  }

  /// 仅供固定身份JSON入口消费；不接收签名标签或原始待签内容。
  Map<String, Object> toJson() => {
    'service_origin': serviceOrigin,
    'challenge': challenge,
    'expires_at_millis': expiresAtMillis,
    'method': method,
    'request_target': requestTarget,
    'body_hex': _bytesToHex(bodyBytes),
  };
}

/// 公开认证证明；私钥、请求正文和MLS内部状态从不返回。
///
/// 这是应用认证扩展。服务端必须验证可信登记身份、实际请求和一次性挑战，
/// 不能把公开公钥或这份自报身份当作已授权的会话。
class MlsAuthenticationProof {
  const MlsAuthenticationProof({
    required this.userId,
    required this.deviceId,
    required this.publicKey,
    required this.accountId,
    required this.bindingRevision,
    required this.serviceOrigin,
    required this.challenge,
    required this.expiresAtMillis,
    required this.method,
    required this.requestTarget,
    required this.bodySha256,
    required this.signature,
  });

  final String userId;
  final String deviceId;
  final String publicKey;
  final String accountId;
  final int bindingRevision;
  final String serviceOrigin;
  final String challenge;
  final int expiresAtMillis;
  final String method;
  final String requestTarget;
  final String bodySha256;
  final String signature;

  Map<String, Object> toJson() => {
    'user_id': userId,
    'device_id': deviceId,
    'public_key': publicKey,
    'account_id': accountId,
    'binding_revision': bindingRevision,
    'service_origin': serviceOrigin,
    'challenge': challenge,
    'expires_at_millis': expiresAtMillis,
    'method': method,
    'request_target': requestTarget,
    'body_sha256': bodySha256,
    'signature': signature,
  };
}
