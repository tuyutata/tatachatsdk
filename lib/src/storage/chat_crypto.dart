import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// 宿主身份与本机聊天密文之间的公开绑定事实。
///
/// TataChatSDK 只使用这些字段隔离不同用户和绑定代次，不解释宿主账户的来源。
class ChatDataBinding {
  const ChatDataBinding({
    required this.keyDomain,
    required this.userId,
    required this.bindingRevision,
    required this.accountId,
  });

  final String keyDomain;
  final String userId;
  final int bindingRevision;
  final String accountId;

  String get id => '$keyDomain|$userId|$bindingRevision|$accountId';

  Map<String, Object> toJson() => <String, Object>{
    'key_domain': keyDomain,
    'user_id': userId,
    'binding_revision': bindingRevision,
    'account_id': accountId,
  };

  factory ChatDataBinding.fromJson(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference(const <String>{
          'key_domain',
          'user_id',
          'binding_revision',
          'account_id',
        }).isNotEmpty ||
        value.length != 4 ||
        value['key_domain'] is! String ||
        value['user_id'] is! String ||
        value['binding_revision'] is! int ||
        value['account_id'] is! String) {
      throw const FormatException('聊天数据绑定格式无效');
    }
    final binding = ChatDataBinding(
      keyDomain: value['key_domain'] as String,
      userId: value['user_id'] as String,
      bindingRevision: value['binding_revision'] as int,
      accountId: value['account_id'] as String,
    );
    binding.validate();
    return binding;
  }

  void validate() {
    if (keyDomain.trim().isEmpty ||
        userId.trim().isEmpty ||
        bindingRevision <= 0 ||
        accountId.trim().isEmpty) {
      throw StateError('聊天数据绑定不完整');
    }
  }
}

/// TataChatSDK 请求宿主派生的三个相互隔离的本机用途钥。
enum ChatStorageKeyPurpose { chat, chatIndex, attachment }

/// 宿主提供用途钥；TataChatSDK 永远不接触钱包、链或产品密钥实现。
abstract interface class ChatStorageKeyProvider {
  Future<ChatDataBinding> resolveBinding({
    required String ownerUserId,
    required String currentAccountId,
    String? expectedKeyDomain,
  });

  Future<List<Uint8List>> readDataKeysForBinding(
    ChatDataBinding binding,
    List<({ChatStorageKeyPurpose purpose, String? context})> requests,
  );

  Future<List<Uint8List>> deriveDataKeysForBindingHandover(
    ChatDataBinding binding,
    List<({ChatStorageKeyPurpose purpose, String? context})> requests,
  );
}

/// 本机静止态 AES-256-GCM 失败。
class ChatLocalCipherException implements Exception {
  const ChatLocalCipherException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 聊天本地静止态的唯一加解密边界。
class ChatCrypto {
  ChatCrypto([ChatStorageKeyProvider? keyProvider]) : _configured = keyProvider;

  /// 宿主启动时登记唯一用途钥提供者；测试也可以直接向构造器注入。
  static ChatStorageKeyProvider? defaultKeyProvider;

  final ChatStorageKeyProvider? _configured;

  ChatStorageKeyProvider get _keyProvider {
    final provider = _configured ?? defaultKeyProvider;
    if (provider == null) {
      throw StateError('TataChatSDK 尚未配置本机用途钥提供者');
    }
    return provider;
  }

  static final Hmac _hmac = Hmac.sha256();
  static final AesGcm _cipher = AesGcm.with256bits();
  static final Random _random = Random.secure();

  static const int _tokenBytes = 8;
  static const int _gram = 2;
  static const int _nonceBytes = 12;
  static const int _macBytes = 16;
  static const String _debugKeyDomain =
      '0000000000000000000000000000000000000000000000000000000000000000';

  /// 测试只能注入固定用途钥，生产始终使用宿主提供者。
  @visibleForTesting
  static Map<ChatStorageKeyPurpose, Uint8List>? debugFixedKeys;

  Future<ChatCipherBinding> resolveCipherBinding({
    required String ownerUserId,
    required String currentAccountId,
    String? expectedKeyDomain,
  }) async {
    if (debugFixedKeys != null) {
      return ChatCipherBinding(
        keyDomain: expectedKeyDomain ?? _debugKeyDomain,
        bindingRevision: 1,
        accountId: currentAccountId,
      );
    }
    final binding = await _keyProvider.resolveBinding(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      expectedKeyDomain: expectedKeyDomain,
    );
    binding.validate();
    if (binding.userId != ownerUserId ||
        binding.accountId != currentAccountId) {
      throw StateError('聊天数据属主与当前宿主账户不一致');
    }
    return ChatCipherBinding(
      keyDomain: binding.keyDomain,
      bindingRevision: binding.bindingRevision,
      accountId: binding.accountId,
    );
  }

  Future<_ChatKeys> _keysFor({
    required String ownerUserId,
    required String currentAccountId,
    ChatCipherBinding? binding,
  }) async {
    final fixed = debugFixedKeys;
    if (fixed != null) {
      final content = fixed[ChatStorageKeyPurpose.chat];
      final index = fixed[ChatStorageKeyPurpose.chatIndex];
      if (content == null || index == null) {
        throw StateError('聊天测试用途钥不完整');
      }
      return _ChatKeys(
        content: Uint8List.fromList(content),
        index: Uint8List.fromList(index),
      );
    }
    final resolved = binding == null
        ? await _keyProvider.resolveBinding(
            ownerUserId: ownerUserId,
            currentAccountId: currentAccountId,
          )
        : ChatDataBinding(
            keyDomain: binding.keyDomain,
            userId: ownerUserId,
            bindingRevision: binding.bindingRevision,
            accountId: binding.accountId,
          );
    resolved.validate();
    if (resolved.userId != ownerUserId ||
        resolved.accountId != currentAccountId) {
      throw StateError('聊天数据属主与当前宿主账户不一致');
    }
    final keys = await _keyProvider.readDataKeysForBinding(
      resolved,
      const <({ChatStorageKeyPurpose purpose, String? context})>[
        (purpose: ChatStorageKeyPurpose.chat, context: null),
        (purpose: ChatStorageKeyPurpose.chatIndex, context: null),
      ],
    );
    try {
      if (keys.length != 2 || keys.any((key) => key.length != 32)) {
        throw StateError('聊天用途钥不完整');
      }
      return _ChatKeys(content: keys[0], index: keys[1]);
    } catch (_) {
      _clearKeys(keys);
      rethrow;
    }
  }

  Future<ChatCipherSession> openCipherSession({
    required String ownerUserId,
    required String currentAccountId,
    ChatCipherBinding? binding,
  }) async {
    final keys = await _keysFor(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      binding: binding,
    );
    return ChatCipherSession._(ownerUserId: ownerUserId, keys: keys);
  }

  Future<ChatHandoverKeys> handoverKeys(ChatDataBinding binding) async {
    binding.validate();
    final keys = await _keyProvider.deriveDataKeysForBindingHandover(
      binding,
      const <({ChatStorageKeyPurpose purpose, String? context})>[
        (purpose: ChatStorageKeyPurpose.chat, context: null),
        (purpose: ChatStorageKeyPurpose.chatIndex, context: null),
      ],
    );
    try {
      if (keys.length != 2 || keys.any((key) => key.length != 32)) {
        throw StateError('聊天交接用途钥不完整');
      }
      return ChatHandoverKeys(content: keys[0], index: keys[1]);
    } catch (_) {
      _clearKeys(keys);
      rethrow;
    }
  }

  Future<String> decryptForHandover({
    required ChatDataBinding binding,
    required ChatHandoverKeys keys,
    required String recordId,
    required String blob,
  }) {
    if (blob.isEmpty) return Future<String>.value('');
    return _decryptString(
      key: keys.content,
      blob: blob,
      aad: _aad(binding.userId, recordId),
    );
  }

  Future<String> encryptForHandover({
    required ChatDataBinding binding,
    required ChatHandoverKeys keys,
    required String recordId,
    required String plaintext,
  }) => _encryptString(
    key: keys.content,
    plaintext: plaintext,
    aad: _aad(binding.userId, recordId),
  );

  Future<List<String>> searchTokensForHandover({
    required ChatHandoverKeys keys,
    required String text,
  }) async {
    final output = <String>[];
    for (final gram in tokenize(text)) {
      output.add(await _tokenHash(keys.index, gram));
    }
    return output;
  }

  Future<String> encryptText({
    required String ownerUserId,
    required String currentAccountId,
    required String recordId,
    required String plaintext,
    ChatCipherBinding? binding,
  }) async {
    final keys = await _keysFor(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      binding: binding,
    );
    try {
      return await _encryptString(
        key: keys.content,
        plaintext: plaintext,
        aad: _aad(ownerUserId, recordId),
      );
    } finally {
      keys.dispose();
    }
  }

  Future<String> decryptText({
    required String ownerUserId,
    required String currentAccountId,
    required String recordId,
    required String blob,
    ChatCipherBinding? binding,
  }) async {
    if (blob.isEmpty) return '';
    final keys = await _keysFor(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      binding: binding,
    );
    try {
      return await _decryptString(
        key: keys.content,
        blob: blob,
        aad: _aad(ownerUserId, recordId),
      );
    } finally {
      keys.dispose();
    }
  }

  Future<List<String>> buildSearchTokens({
    required String ownerUserId,
    required String currentAccountId,
    required String text,
    ChatCipherBinding? binding,
  }) async {
    final grams = tokenize(text);
    if (grams.isEmpty) return const <String>[];
    final keys = await _keysFor(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      binding: binding,
    );
    try {
      final output = <String>[];
      for (final gram in grams) {
        output.add(await _tokenHash(keys.index, gram));
      }
      return output;
    } finally {
      keys.dispose();
    }
  }

  Future<List<String>> buildQueryTokens({
    required String ownerUserId,
    required String currentAccountId,
    required String query,
    ChatCipherBinding? binding,
  }) => buildSearchTokens(
    ownerUserId: ownerUserId,
    currentAccountId: currentAccountId,
    text: query,
    binding: binding,
  );

  static List<String> tokenize(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return const <String>[];
    final runes = normalized.runes.toList(growable: false);
    if (runes.length < _gram) return const <String>[];
    final seen = <String>{};
    final output = <String>[];
    for (var index = 0; index + _gram <= runes.length; index += 1) {
      final gram = String.fromCharCodes(runes.sublist(index, index + _gram));
      if (seen.add(gram)) output.add(gram);
    }
    return output;
  }

  static Future<String> _tokenHash(List<int> indexKey, String gram) async {
    final mac = await _hmac.calculateMac(
      utf8.encode(gram),
      secretKey: SecretKey(indexKey),
    );
    return mac.bytes
        .sublist(0, _tokenBytes)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static Future<String> _encryptString({
    required List<int> key,
    required String plaintext,
    required String aad,
  }) async {
    _requireKey(key);
    final nonce = Uint8List.fromList(
      List<int>.generate(_nonceBytes, (_) => _random.nextInt(256)),
    );
    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: utf8.encode(aad),
    );
    final output = Uint8List(_nonceBytes + box.cipherText.length + _macBytes)
      ..setAll(0, nonce)
      ..setAll(_nonceBytes, box.cipherText)
      ..setAll(_nonceBytes + box.cipherText.length, box.mac.bytes);
    return base64Encode(output);
  }

  static Future<String> _decryptString({
    required List<int> key,
    required String blob,
    required String aad,
  }) async {
    _requireKey(key);
    late final Uint8List raw;
    try {
      raw = base64Decode(blob);
    } on FormatException {
      throw const ChatLocalCipherException('聊天本地密文编码无效');
    }
    if (raw.length < _nonceBytes + _macBytes) {
      throw const ChatLocalCipherException('聊天本地密文长度无效');
    }
    final nonce = raw.sublist(0, _nonceBytes);
    final cipherEnd = raw.length - _macBytes;
    try {
      final clear = await _cipher.decrypt(
        SecretBox(
          raw.sublist(_nonceBytes, cipherEnd),
          nonce: nonce,
          mac: Mac(raw.sublist(cipherEnd)),
        ),
        secretKey: SecretKey(key),
        aad: utf8.encode(aad),
      );
      return utf8.decode(clear);
    } on Object {
      throw const ChatLocalCipherException('聊天本地密文认证失败');
    }
  }

  static void _requireKey(List<int> key) {
    if (key.length != 32) {
      throw ArgumentError.value(key.length, 'key', '聊天用途钥必须为 32 字节');
    }
  }

  static String _aad(String ownerUserId, String recordId) =>
      'tatachat_sdk.local/chat|$ownerUserId|$recordId';

  static void _clearKeys(List<Uint8List> keys) {
    for (final key in keys) {
      key.fillRange(0, key.length, 0);
    }
  }
}

/// 聊天密文的公开绑定上下文。
class ChatCipherBinding {
  const ChatCipherBinding({
    required this.keyDomain,
    required this.bindingRevision,
    required this.accountId,
  });

  final String keyDomain;
  final int bindingRevision;
  final String accountId;
}

/// 单次存储操作复用的短命用途钥会话。
class ChatCipherSession {
  ChatCipherSession._({required this.ownerUserId, required _ChatKeys keys})
    : _keys = keys;

  final String ownerUserId;
  final _ChatKeys _keys;
  bool _disposed = false;

  void _ensureActive() {
    if (_disposed) throw StateError('聊天密文会话已清零');
  }

  Future<String> encryptText({
    required String recordId,
    required String plaintext,
  }) {
    _ensureActive();
    return ChatCrypto._encryptString(
      key: _keys.content,
      plaintext: plaintext,
      aad: ChatCrypto._aad(ownerUserId, recordId),
    );
  }

  Future<String> decryptText({required String recordId, required String blob}) {
    _ensureActive();
    if (blob.isEmpty) return Future<String>.value('');
    return ChatCrypto._decryptString(
      key: _keys.content,
      blob: blob,
      aad: ChatCrypto._aad(ownerUserId, recordId),
    );
  }

  Future<List<String>> buildSearchTokens(String text) async {
    _ensureActive();
    final output = <String>[];
    for (final gram in ChatCrypto.tokenize(text)) {
      output.add(await ChatCrypto._tokenHash(_keys.index, gram));
    }
    return output;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _keys.dispose();
  }
}

class _ChatKeys {
  const _ChatKeys({required this.content, required this.index});

  final Uint8List content;
  final Uint8List index;

  void dispose() {
    content.fillRange(0, content.length, 0);
    index.fillRange(0, index.length, 0);
  }
}

/// 绑定交接期间短时持有的聊天用途钥。
class ChatHandoverKeys {
  const ChatHandoverKeys({required this.content, required this.index});

  final Uint8List content;
  final Uint8List index;

  void dispose() {
    content.fillRange(0, content.length, 0);
    index.fillRange(0, index.length, 0);
  }
}
