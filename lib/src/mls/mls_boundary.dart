// TataChatSDK 的 RFC 9420 MLS 边界模型。
//
// Dart 只传递身份、KeyPackage 和 MLS wire bytes。所有密码学操作唯一由
// Rust OpenMLS 完成，禁止另建原始 HPKE 直聊协议或应用层密钥编号。

export 'mls_session.dart';

/// 本机 Chat 设备身份。
class ChatDevice {
  const ChatDevice({required this.userId, required this.deviceId});

  /// Chat 永久用户身份主键，由宿主产品注入。
  final String userId;

  /// 同一用户下唯一设备标识。
  final String deviceId;

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
