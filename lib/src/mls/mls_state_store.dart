import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'mls_session.dart';

/// TataChatSDK 的 MLS 本地状态目录。
///
/// OpenMLS provider storage 由 Rust native 写入该目录；Dart 只管理目录位置、
/// 下传状态消息密钥，以及 application 早于 Welcome 到达时的 pending 队列。
///
/// 该目录下**一律不得出现明文**：`openmls_storage.bin` / `device.bin` 由 Rust
/// 用 [stateKey] 做 AES-256-GCM 消息；`pending_inbound.bin` 由本类同钥加密。
class MlsStateStore {
  const MlsStateStore(
    this.directory, {
    required this.ownerUserId,
    required this.stateKey,
  });

  final Directory directory;
  final String ownerUserId;

  /// MLS 本地状态密钥（32 字节，来自 `LocalKeyPurpose.mls` 子钥）。
  final Uint8List stateKey;

  String get path => directory.path;

  /// 下传给 Rust native 的小写 hex 形式。
  String get stateKeyHex =>
      stateKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// 运行上下文失效时立即清零 MLS 状态消息钥，不等待垃圾回收。
  void dispose() {
    stateKey.fillRange(0, stateKey.length, 0);
  }

  String get _pendingAad => 'tatachatsdk/mls|$ownerUserId|pending_inbound';

  Future<void> ensureReady() async {
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
  }

  /// 删除当前设备的全部 TataChatSDK 密码状态并立即建立空目录。
  ///
  /// 调用方仍持有同一 [stateKey]，但 OpenMLS 签名者、KeyPackage、群状态和
  /// pending 队列都会从唯一空状态重新建立，禁止保留第二套设备公开钥状态。
  Future<void> reset() async {
    final target = directory.absolute;
    if (target.path == target.parent.path) {
      throw StateError('TataChatSDK 状态目录不能是文件系统根目录');
    }
    final type = await FileSystemEntity.type(target.path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      await Link(target.path).delete();
    } else if (type == FileSystemEntityType.directory) {
      await target.delete(recursive: true);
    } else if (type != FileSystemEntityType.notFound) {
      throw StateError('TataChatSDK 状态路径必须是目录');
    }
    await target.create(recursive: true);
  }

  File get _pendingFile => _pendingFileFor(directory);

  File get _pendingRekeyFile => _pendingRekeyFileFor(directory);

  Future<void> queuePendingInbound(MlsWireMessage message) async {
    await ensureReady();
    final existing = await readPendingInbound();
    existing.add(message);
    final encoded = existing.map(_wireMessageToJson).toList();
    await _writePending(encoded);
  }

  Future<List<MlsWireMessage>> readPendingInbound() async {
    if (!_pendingFile.existsSync()) {
      return [];
    }
    final blob = await _pendingFile.readAsString();
    if (blob.trim().isEmpty) {
      return [];
    }
    // 解密失败必须抛出：静默返回空会让早到的 application message 被悄悄丢弃。
    final raw = await _decryptStateString(
      key: stateKey,
      blob: blob,
      aad: _pendingAad,
    );
    if (raw.trim().isEmpty) {
      return [];
    }
    final items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return items.map(_wireMessageFromJson).toList();
  }

  Future<void> clearPendingInbound() async {
    if (_pendingFile.existsSync()) {
      await _writePending(const <Map<String, Object?>>[]);
    }
  }

  Future<void> _writePending(List<Map<String, Object?>> items) async {
    final blob = await _encryptStateString(
      key: stateKey,
      plaintext: jsonEncode(items),
      aad: _pendingAad,
    );
    await _pendingFile.writeAsString(blob, flush: true);
  }

  /// 只在内存解开 pending 队列并写入新账户密文旁路文件，正式文件保持不动。
  Future<void> stageAccountHandover(Uint8List newStateKey) async {
    if (!_pendingFile.existsSync()) return;
    final oldBlob = await _pendingFile.readAsString();
    final plaintext = await _decryptStateString(
      key: stateKey,
      blob: oldBlob,
      aad: _pendingAad,
    );
    final newBlob = await _encryptStateString(
      key: newStateKey,
      plaintext: plaintext,
      aad: _pendingAad,
    );
    // 写前再验一次目标密文，确保新账户密钥确实能够接管。
    await _decryptStateString(
      key: newStateKey,
      blob: newBlob,
      aad: _pendingAad,
    );
    await _pendingRekeyFile.writeAsString(newBlob, flush: true);
  }

  /// finalized 后只提交已验证的目标密文文件，不构造或接收任何占位密钥。
  static Future<void> commitAccountHandoverFiles(Directory directory) async {
    final pendingFile = _pendingFileFor(directory);
    final pendingRekeyFile = _pendingRekeyFileFor(directory);
    if (!await pendingRekeyFile.exists()) return;
    final backup = File('${pendingFile.path}.account_previous');
    if (await backup.exists()) await backup.delete();
    if (await pendingFile.exists()) await pendingFile.rename(backup.path);
    try {
      await pendingRekeyFile.rename(pendingFile.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (await pendingFile.exists()) await pendingFile.delete();
      if (await backup.exists()) await backup.rename(pendingFile.path);
      rethrow;
    }
  }

  static Future<void> discardAccountHandoverFiles(Directory directory) async {
    final pendingRekeyFile = _pendingRekeyFileFor(directory);
    if (await pendingRekeyFile.exists()) await pendingRekeyFile.delete();
  }

  static File _pendingFileFor(Directory directory) =>
      File('${directory.path}/pending_inbound.bin');

  static File _pendingRekeyFileFor(Directory directory) =>
      File('${directory.path}/pending_inbound.account_rekey');
}

final AesGcm _pendingCipher = AesGcm.with256bits();

Future<String> _encryptStateString({
  required Uint8List key,
  required String plaintext,
  required String aad,
}) async {
  final secretBox = await _pendingCipher.encrypt(
    utf8.encode(plaintext),
    secretKey: SecretKey(key),
    nonce: _pendingCipher.newNonce(),
    aad: utf8.encode(aad),
  );
  return base64Encode(secretBox.concatenation());
}

Future<String> _decryptStateString({
  required Uint8List key,
  required String blob,
  required String aad,
}) async {
  final secretBox = SecretBox.fromConcatenation(
    base64Decode(blob),
    nonceLength: 12,
    macLength: 16,
  );
  final plaintext = await _pendingCipher.decrypt(
    secretBox,
    secretKey: SecretKey(key),
    aad: utf8.encode(aad),
  );
  return utf8.decode(plaintext);
}

Map<String, Object?> _wireMessageToJson(MlsWireMessage message) {
  return {
    'conversation_id': message.conversationId,
    'wire_hex': _bytesToHex(message.wireBytes),
  };
}

MlsWireMessage _wireMessageFromJson(Map<String, dynamic> json) {
  return MlsWireMessage(
    conversationId: (json['conversation_id'] ?? '').toString(),
    wireBytes: _hexToBytes((json['wire_hex'] ?? '').toString()),
  );
}

String _bytesToHex(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

List<int> _hexToBytes(String value) {
  final normalized = value.startsWith('0x') ? value.substring(2) : value;
  if (normalized.length.isOdd) {
    throw const FormatException('Chat MLS pending hex 长度必须为偶数');
  }
  final bytes = <int>[];
  for (var i = 0; i < normalized.length; i += 2) {
    bytes.add(int.parse(normalized.substring(i, i + 2), radix: 16));
  }
  return bytes;
}
