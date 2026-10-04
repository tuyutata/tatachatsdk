import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto_hash;

import 'package:cryptography/cryptography.dart';

/// 聊天附件的本地静止态金库。
///
/// **长期缓存一律密文**（`<原路径>.enc`，使用 [_AttachmentCrypto] 的分块流式
/// AES-256-GCM,5GB 也不进内存);播放/预览时才解密到**短命明文临时文件**。
///
/// 明文窗口是本方案(用户 2026-07-29 选定的方案 A)自觉接受的代价:图片/视频
/// 播放器要的是文件路径而不是内存字节,走内存流对视频的工程代价过高。
/// 代价靠把生命周期管死来压缩:
/// - 明文只落 [plainDirName] 这一个专用目录,与密文缓存物理分开;
/// - 用完即删([releasePlain]),异常路径也删(调用方 try/finally);
/// - App 启动时整目录清空([purgePlainDirectory]),防崩溃残留跨会话存活。
class AttachmentVault {
  const AttachmentVault._();

  /// 密文缓存后缀。与明文路径永不重名,避免"以为加密了其实读的是旧明文"。
  static const String cipherSuffix = '.enc';

  /// 短命明文目录名(位于附件缓存根下)。
  static const String plainDirName = '.plain';
  static const String _handoverDirName = '.account-handover';

  static File cipherFileOf(String cachePath) => File('$cachePath$cipherSuffix');

  /// 把明文文件加密进长期缓存,成功后**删除明文源**。
  ///
  /// [deleteSource]=false 用于发送端保留用户原始文件的场景。
  static Future<void> seal({
    required File plainSource,
    required String cachePath,
    required List<int> key,
    bool deleteSource = true,
  }) async {
    final target = cipherFileOf(cachePath);
    await target.parent.create(recursive: true);
    await _AttachmentCrypto.encryptFile(
      sourcePath: plainSource.path,
      destPath: target.path,
      key: key,
    );
    if (deleteSource && await plainSource.exists()) {
      await plainSource.delete();
    }
  }

  /// 生成可直传 R2 的分块密文；调用方持有并最终擦除 [key]，服务端永远看不到它。
  static Future<AttachmentTransportCipher> sealForTransport({
    required File plainSource,
    required File cipherTarget,
    required List<int> key,
  }) async {
    await cipherTarget.parent.create(recursive: true);
    try {
      final byteSize = await _AttachmentCrypto.encryptFile(
        sourcePath: plainSource.path,
        destPath: cipherTarget.path,
        key: key,
      );
      final digest = await crypto_hash.sha256
          .bind(cipherTarget.openRead())
          .first;
      return AttachmentTransportCipher(
        file: cipherTarget,
        byteSize: byteSize,
        sha256: digest.toString(),
      );
    } catch (_) {
      if (await cipherTarget.exists()) await cipherTarget.delete();
      rethrow;
    }
  }

  /// 校验后的 R2 密文流式解密到短命明文；失败删除半成品，禁止进入长期缓存。
  static Future<File> openTransportCipher({
    required File cipherSource,
    required File plainTarget,
    required List<int> key,
  }) async {
    if (await plainTarget.exists()) await plainTarget.delete();
    try {
      await _AttachmentCrypto.decryptFile(
        sourcePath: cipherSource.path,
        destPath: plainTarget.path,
        key: key,
      );
      return plainTarget;
    } catch (_) {
      if (await plainTarget.exists()) await plainTarget.delete();
      rethrow;
    }
  }

  /// 密文缓存是否已就绪。
  static Future<bool> hasCipher(String cachePath) =>
      cipherFileOf(cachePath).exists();

  /// 已解密好的短命明文文件（不存在返回 null，不触发解密）。
  ///
  /// 供列表渲染这类**高频路径**先探一次，命中就直接复用，避免同一附件被反复
  /// 整文件解密——会话里每条媒体消息都会走一次路径解析，视频动辄上百 MB。
  static Future<File?> existingPlain({
    required String cachePath,
    required Directory plainDirectory,
  }) async {
    final plain = File('${plainDirectory.path}/${_plainName(cachePath)}');
    return await plain.exists() ? plain : null;
  }

  /// 解密到短命明文临时文件并返回它。
  ///
  /// 明文生命周期由「前台存活」策略统一兜底（启动 / 退后台 / 删会话三处 purge），
  /// 调用方不需要逐处交接所有权；[releasePlain] 只用于确定不再需要的即时清理。
  static Future<File> openPlain({
    required String cachePath,
    required List<int> key,
    required Directory plainDirectory,
  }) async {
    final cipher = cipherFileOf(cachePath);
    if (!await cipher.exists()) {
      throw StateError('附件密文缓存不存在: $cachePath');
    }
    await plainDirectory.create(recursive: true);
    final plain = File('${plainDirectory.path}/${_plainName(cachePath)}');
    if (await plain.exists()) {
      await plain.delete();
    }
    try {
      await _AttachmentCrypto.decryptFile(
        sourcePath: cipher.path,
        destPath: plain.path,
        key: key,
      );
    } catch (_) {
      // 解密失败也不能把半截明文留在盘上。
      if (await plain.exists()) {
        await plain.delete();
      }
      rethrow;
    }
    return plain;
  }

  /// 删除某个短命明文文件（用完即调，失败静默——文件可能已被清理）。
  static Future<void> releasePlain(File plain) async {
    try {
      if (await plain.exists()) {
        await plain.delete();
      }
    } on FileSystemException {
      // 已被 purge 或系统清理，无需处理。
    }
  }

  /// 整目录清空短命明文（App 启动 / 退出账户时调）。
  ///
  /// 崩溃或强杀会跳过 [releasePlain]，必须有这道兜底，否则明文会跨会话存活。
  static Future<void> purgePlainDirectory(Directory plainDirectory) async {
    if (!await plainDirectory.exists()) return;
    try {
      await plainDirectory.delete(recursive: true);
    } on FileSystemException {
      // 目录被占用时逐个删，尽力而为。
      await for (final entity in plainDirectory.list()) {
        try {
          await entity.delete(recursive: true);
        } on FileSystemException {
          continue;
        }
      }
    }
  }

  /// 账户交接的严格瞬时目录清理。
  ///
  /// 与前台尽力清理不同，换绑只有在 `.plain` 与 `.tmp` 均确定不存在后才能写入
  /// stage-complete receipt；任一删除或复核失败必须中止，禁止把明文或 `.part`
  /// 文件随整个 binding 目录移动到目标账户。
  static Future<void> purgeTransientDirectoriesForHandover(
    Directory attachmentDirectory,
  ) async {
    for (final name in const <String>[plainDirName, '.tmp']) {
      final directory = Directory(
        '${attachmentDirectory.path}${Platform.pathSeparator}$name',
      );
      final type = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.directory) {
        throw StateError('Chat 附件瞬时路径类型异常，禁止继续换绑');
      }
      await directory.delete(recursive: true);
      if (await FileSystemEntity.type(directory.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('Chat 附件瞬时目录未彻底清除，禁止继续换绑');
      }
    }
  }

  /// commit 前再次复核瞬时目录，防止 stage receipt 之后的残留被整树移动。
  static Future<void> requireNoTransientDirectoriesForHandover(
    Directory attachmentDirectory,
  ) async {
    for (final name in const <String>[plainDirName, '.tmp']) {
      final path = '${attachmentDirectory.path}${Platform.pathSeparator}$name';
      if (await FileSystemEntity.type(path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('Chat 附件存在未清除的瞬时文件，禁止提交换绑');
      }
    }
  }

  /// 把附件树全部预演成目标账户密文，正式 `.enc` 文件保持不动。
  static Future<void> stageAccountHandover({
    required Directory attachmentDirectory,
    required String handoverId,
    required List<int> currentKey,
    required List<int> newKey,
  }) async {
    if (!await attachmentDirectory.exists()) return;
    final stageRoot = _handoverDirectory(attachmentDirectory, handoverId);
    if (await stageRoot.exists()) await stageRoot.delete(recursive: true);
    await for (final entity in attachmentDirectory.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith(cipherSuffix)) continue;
      if (entity.path.startsWith(
            '${stageRoot.path}${Platform.pathSeparator}',
          ) ||
          entity.path.contains(
            '${Platform.pathSeparator}$_handoverDirName${Platform.pathSeparator}',
          ) ||
          entity.path.contains(
            '${Platform.pathSeparator}$plainDirName${Platform.pathSeparator}',
          )) {
        continue;
      }
      final relative = entity.path.substring(
        attachmentDirectory.path.length + 1,
      );
      await _AttachmentCrypto.reencryptFile(
        sourcePath: entity.path,
        destPath: '${stageRoot.path}${Platform.pathSeparator}$relative',
        currentKey: currentKey,
        newKey: newKey,
      );
    }
  }

  /// finalized 后逐文件替换正式附件密文；每个文件均保留可回滚备份直到替换成功。
  static Future<void> commitAccountHandover({
    required Directory attachmentDirectory,
    required String handoverId,
  }) async {
    final stageRoot = _handoverDirectory(attachmentDirectory, handoverId);
    if (!await stageRoot.exists()) return;
    final stagedFiles = <File>[];
    await for (final entity in stageRoot.list(recursive: true)) {
      if (entity is File) stagedFiles.add(entity);
    }
    for (final staged in stagedFiles) {
      final relative = staged.path.substring(stageRoot.path.length + 1);
      final target = File(
        '${attachmentDirectory.path}${Platform.pathSeparator}$relative',
      );
      final backup = File('${target.path}.account-previous');
      await target.parent.create(recursive: true);
      if (await backup.exists()) await backup.delete();
      if (await target.exists()) await target.rename(backup.path);
      try {
        await staged.rename(target.path);
        if (await backup.exists()) await backup.delete();
      } catch (_) {
        if (await target.exists()) await target.delete();
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
    }
    if (await stageRoot.exists()) await stageRoot.delete(recursive: true);
  }

  static Future<void> discardAccountHandover({
    required Directory attachmentDirectory,
    required String handoverId,
  }) async {
    final stageRoot = _handoverDirectory(attachmentDirectory, handoverId);
    if (await stageRoot.exists()) await stageRoot.delete(recursive: true);
  }

  static Directory _handoverDirectory(
    Directory attachmentDirectory,
    String handoverId,
  ) => Directory(
    '${attachmentDirectory.path}${Platform.pathSeparator}$_handoverDirName'
    '${Platform.pathSeparator}$handoverId',
  );

  /// 明文临时文件名：保留原扩展名，播放器按扩展名选解码器。
  static String _plainName(String cachePath) {
    final base = cachePath.split(Platform.pathSeparator).last;
    return base.isEmpty ? 'attachment.bin' : base;
  }
}

class AttachmentTransportCipher {
  const AttachmentTransportCipher({
    required this.file,
    required this.byteSize,
    required this.sha256,
  });

  final File file;
  final int byteSize;
  final String sha256;
}

/// 附件本地静止态的分块 AES-256-GCM 实现。
///
/// 该实现只服务设备本地附件保险库，不生成传输内容密钥，也不参与任何云端中继。
/// 每块 nonce 由块序号唯一派生；文件始终流式读写，最高档大文件不会整块进入内存。
class _AttachmentCrypto {
  _AttachmentCrypto._();

  static const int _chunkSize = 1024 * 1024;
  static const int _frameHeaderBytes = 4;
  static const int _macBytes = 16;
  static final AesGcm _algorithm = AesGcm.with256bits();

  static List<int> _nonceForChunk(int chunkIndex) {
    final nonce = Uint8List(12);
    ByteData.sublistView(nonce).setUint64(4, chunkIndex, Endian.big);
    return nonce;
  }

  static Future<List<int>> _encryptChunk(
    List<int> key,
    int chunkIndex,
    List<int> plaintext,
  ) async {
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: _nonceForChunk(chunkIndex),
    );
    return <int>[...box.cipherText, ...box.mac.bytes];
  }

  static Future<List<int>> _decryptChunk(
    List<int> key,
    int chunkIndex,
    List<int> frame,
  ) {
    if (frame.length < _macBytes) {
      throw const FormatException('附件密文块过短');
    }
    return _algorithm.decrypt(
      SecretBox(
        frame.sublist(0, frame.length - _macBytes),
        nonce: _nonceForChunk(chunkIndex),
        mac: Mac(frame.sublist(frame.length - _macBytes)),
      ),
      secretKey: SecretKey(key),
    );
  }

  static Future<int> encryptFile({
    required String sourcePath,
    required String destPath,
    required List<int> key,
  }) async {
    final source = await File(sourcePath).open();
    final sink = File(destPath).openWrite();
    var written = 0;
    try {
      final total = await source.length();
      var index = 0;
      for (var offset = 0; offset < total; offset += _chunkSize) {
        await source.setPosition(offset);
        final plain = await source.read(min(_chunkSize, total - offset));
        final frame = await _encryptChunk(key, index, plain);
        final header = ByteData(_frameHeaderBytes)
          ..setUint32(0, frame.length, Endian.big);
        sink.add(header.buffer.asUint8List());
        sink.add(frame);
        written += _frameHeaderBytes + frame.length;
        index += 1;
      }
    } finally {
      await source.close();
      await sink.close();
    }
    return written;
  }

  static Future<void> decryptFile({
    required String sourcePath,
    required String destPath,
    required List<int> key,
  }) async {
    final source = await File(sourcePath).open();
    final sink = File(destPath).openWrite();
    try {
      await _transformFrames(
        source: source,
        sink: sink,
        transform: (index, frame) => _decryptChunk(key, index, frame),
      );
    } finally {
      await source.close();
      await sink.close();
    }
  }

  static Future<void> reencryptFile({
    required String sourcePath,
    required String destPath,
    required List<int> currentKey,
    required List<int> newKey,
  }) async {
    if (sourcePath == destPath) {
      throw ArgumentError('附件重加密源路径与目标路径不得相同');
    }
    final source = await File(sourcePath).open();
    final target = File(destPath);
    await target.parent.create(recursive: true);
    final sink = target.openWrite();
    try {
      await _transformFrames(
        source: source,
        sink: sink,
        transform: (index, frame) async {
          final plaintext = await _decryptChunk(currentKey, index, frame);
          try {
            return await _encryptChunk(newKey, index, plaintext);
          } finally {
            plaintext.fillRange(0, plaintext.length, 0);
          }
        },
        writeFramedOutput: true,
      );
    } catch (_) {
      await sink.close();
      await source.close();
      if (await target.exists()) await target.delete();
      rethrow;
    }
    await source.close();
    await sink.close();
    await verifyEncryptedFile(path: destPath, key: newKey);
  }

  static Future<void> verifyEncryptedFile({
    required String path,
    required List<int> key,
  }) async {
    final source = await File(path).open();
    final sink = _DiscardingSink();
    try {
      await _transformFrames(
        source: source,
        sink: sink,
        transform: (index, frame) async {
          final plaintext = await _decryptChunk(key, index, frame);
          plaintext.fillRange(0, plaintext.length, 0);
          return const <int>[];
        },
      );
    } finally {
      await source.close();
      await sink.close();
    }
  }

  static Future<void> _transformFrames({
    required RandomAccessFile source,
    required IOSink sink,
    required Future<List<int>> Function(int index, List<int> frame) transform,
    bool writeFramedOutput = false,
  }) async {
    final total = await source.length();
    var position = 0;
    var index = 0;
    while (position < total) {
      await source.setPosition(position);
      final header = await source.read(_frameHeaderBytes);
      if (header.length != _frameHeaderBytes) {
        throw const FormatException('附件密文帧头截断');
      }
      final frameLength = ByteData.sublistView(
        Uint8List.fromList(header),
      ).getUint32(0);
      final frame = await source.read(frameLength);
      if (frame.length != frameLength) {
        throw const FormatException('附件密文帧截断');
      }
      final output = await transform(index, frame);
      if (writeFramedOutput) {
        final outputHeader = ByteData(_frameHeaderBytes)
          ..setUint32(0, output.length, Endian.big);
        sink.add(outputHeader.buffer.asUint8List());
      }
      sink.add(output);
      position += _frameHeaderBytes + frameLength;
      index += 1;
    }
  }
}

/// 认证附件密文时丢弃输出，避免生成任何临时明文文件。
class _DiscardingSink implements IOSink {
  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final _ in stream) {}
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> get done => Future<void>.value();

  @override
  Future<void> flush() async {}

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = '']) {}
}
