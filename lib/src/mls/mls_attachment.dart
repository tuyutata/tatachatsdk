import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;

import '../core/chat_content.dart';
import 'mls_boundary.dart';
import 'mls_group_boundary.dart';
import 'mls_state_store.dart';

typedef MlsAttachmentMutation =
    Future<T> Function<T>(Future<T> Function() operation);

/// 文件组的公开描述；所有秘密只存在已有OpenMLS保护状态中。
class MlsAttachmentDescriptor {
  const MlsAttachmentDescriptor({
    required this.groupId,
    required this.welcome,
    required this.members,
    required this.sender,
    required this.chunkCount,
    required this.plainSha256,
    required this.cipherByteSize,
    required this.cipherSha256,
  });
  final String groupId;
  final List<int> welcome;
  final List<String> members;
  final String sender;
  final int chunkCount;
  final String plainSha256;
  final int cipherByteSize;
  final String cipherSha256;
}

/// 每文件独立MLS组，复用同一设备签名身份；块不推进普通聊天发送链。
/// 状态与原结果先提交，原文件字节flush后才归档当前块，最多一块常驻。
class MlsAttachment {
  const MlsAttachment({
    required this.crypto,
    required this.store,
    required this.identity,
    required this.protectedRoot,
    required this.mutate,
    required this.requireCurrent,
  });
  final MlsGroupCrypto crypto;
  final MlsStateStore store;
  final ChatDevice identity;
  final Directory protectedRoot;
  final MlsAttachmentMutation mutate;
  final Future<void> Function() requireCurrent;
  static const chunkBytes = 1024 * 1024;
  static const frameOverhead = 4096;
  static const _zeroDigest =
      '0000000000000000000000000000000000000000000000000000000000000000';

  String get _self => '${identity.userId}:${identity.deviceId}';
  static String groupId(String sender, String attachmentId) =>
      'attachment:$sender:$attachmentId';
  static String chunkMessageId(String group, int index) =>
      '$group:chunk:$index';

  Future<Map<String, dynamic>> _action(
    String action,
    Map<String, Object?> value,
  ) => mutate(() async {
    await requireCurrent();
    if (store.ownerUserId != identity.userId) throw StateError('附件MLS所有者错误');
    return store.attachmentAction(action, value);
  });

  /// 文件路径必须在当前CID的已准备保护目录内；创建任何父项前先拒绝链接。
  Future<void> _path(File file) async {
    final parts = file.path.split(Platform.pathSeparator);
    if (!file.isAbsolute ||
        parts.any((p) => p == '.' || p == '..') ||
        !file.path.startsWith(
          '${protectedRoot.path}${Platform.pathSeparator}',
        )) {
      throw StateError('附件路径越界');
    }
    if (await protectedRoot.resolveSymbolicLinks() != protectedRoot.path) {
      throw StateError('附件保护根异常');
    }
    var parent = file.parent;
    while (true) {
      final type = await FileSystemEntity.type(parent.path, followLinks: false);
      if (type == FileSystemEntityType.directory) break;
      if (type != FileSystemEntityType.notFound ||
          parent.path == protectedRoot.path) {
        throw StateError('附件父项异常');
      }
      parent = parent.parent;
    }
    if (await parent.resolveSymbolicLinks() != parent.path ||
        await FileSystemEntity.type(file.path, followLinks: false) ==
            FileSystemEntityType.link) {
      throw StateError('附件路径拒绝链接');
    }
    await file.parent.create(recursive: true);
  }

  static Future<String> digest(File file) async =>
      (await hash.sha256.bind(file.openRead()).first).toString();
  static String _chain(String previous, List<int> bytes) =>
      hash.sha256.convert([...utf8.encode(previous), ...bytes]).toString();

  /// 只读回验已归档前缀，复杂度随重启次数而非每块增长；缺失或损坏不能重置链。
  Future<void> _verifyPrefix(
    File file,
    Map<String, dynamic> progress, {
    required bool framed,
  }) async {
    final count = progress['next_chunk'] as int;
    final committedBytes = progress['durable_bytes'] as int;
    if (!await file.exists()) {
      if (count != 0) throw StateError('MLS已消费附件但原文件缺失');
      return;
    }
    await _path(file);
    final input = await file.open();
    var chain = '';
    var read = 0;
    try {
      if (await input.length() < committedBytes) {
        throw StateError('MLS附件持久前缀截断');
      }
      for (var index = 0; index < count; index++) {
        await requireCurrent();
        final bytes = framed
            ? await _readFrame(input, includeLength: true)
            : await _readExact(
                input,
                min(
                  chunkBytes,
                  (progress['byte_size'] as int) - index * chunkBytes,
                ),
              );
        chain = _chain(chain, bytes);
        read += bytes.length;
      }
      if (read != committedBytes || chain != progress['durable_sha256']) {
        throw StateError('MLS附件持久前缀损坏');
      }
    } finally {
      await input.close();
    }
  }

  static Future<Uint8List> _readExact(RandomAccessFile input, int count) async {
    final out = Uint8List(count);
    var offset = 0;
    while (offset < count) {
      final part = await input.read(count - offset);
      if (part.isEmpty) throw const FormatException('附件帧截断');
      out.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return out;
  }

  static Future<Uint8List> _readFrame(
    RandomAccessFile input, {
    bool includeLength = false,
  }) async {
    final header = await _readExact(input, 4);
    final count = ByteData.sublistView(header).getUint32(0, Endian.big);
    if (count == 0 || count > chunkBytes + frameOverhead - 4) {
      throw const FormatException('附件帧长度越界');
    }
    final bytes = await _readExact(input, count);
    return includeLength ? Uint8List.fromList([...header, ...bytes]) : bytes;
  }

  /// 未确认尾部允许用原生保存的同一结果补齐；已确认前缀绝不覆盖或重加密。
  Future<Map<String, dynamic>> _persistChunk(
    File file,
    Map<String, dynamic> progress,
    int index,
    List<int> bytes,
  ) => mutate(() async {
    await requireCurrent();
    await _path(file);
    final position = progress['durable_bytes'] as int;
    final out = await file.open(mode: FileMode.append);
    try {
      if (await out.length() < position) throw StateError('附件持久前缀缺失');
      await out.truncate(position);
      await out.setPosition(position);
      await out.writeFrom(bytes);
      await out.flush();
    } finally {
      await out.close();
    }
    await requireCurrent();
    return store.attachmentAction('confirm_attachment_chunk', {
      'group_id': progress['group_id'],
      'chunk_index': index,
      'durable_bytes': position + bytes.length,
      'durable_sha256': _chain(progress['durable_sha256'] as String, bytes),
    });
  });

  Future<void> finish(String group) async {
    await _action('finish_attachment', {'group_id': group});
  }

  Future<void> abort(String group) async {
    await _action('abort_attachment', {'group_id': group});
  }

  /// 附件名册由当前聊天精确叶子给出，不按用户去重，也不自动吸收新设备。
  Future<ChatContent> seal({
    required String attachmentId,
    required int byteSize,
    required File source,
    required File target,
    required List<String> members,
    required List<MlsKeyPackage> keyPackages,
    required ChatContent Function(MlsAttachmentDescriptor descriptor)
    contentBuilder,
  }) async {
    await requireCurrent();
    await _path(target);
    if (byteSize <= 0 || await source.length() != byteSize) {
      throw StateError('附件明文大小错误');
    }
    final plainSha = await digest(source);
    await requireCurrent();
    final roster = [...members]..sort();
    final other = roster.where((m) => m != _self).toList();
    final packages = [...keyPackages]
      ..sort(
        (a, b) =>
            '${a.userId}:${a.deviceId}'.compareTo('${b.userId}:${b.deviceId}'),
      );
    if (roster.toSet().length != roster.length ||
        !roster.contains(_self) ||
        jsonEncode(other) !=
            jsonEncode(
              packages.map((p) => '${p.userId}:${p.deviceId}').toList(),
            ) ||
        packages.any((p) => !p.lastResort)) {
      throw StateError('附件KeyPackage与聊天名册不一致');
    }
    final group = groupId(_self, attachmentId);
    final count = (byteSize + chunkBytes - 1) ~/ chunkBytes;
    var progress = await _action('begin_attachment', {
      'group_id': group,
      'direction': 'send',
      'chunk_count': count,
      'byte_size': byteSize,
      'plain_sha256': plainSha,
      'sender_member_identity': _self,
      'member_identities': roster,
    });
    if (progress['terminal'] == true) throw StateError('附件发送链已终结，必须使用原控制描述');
    List<int> welcome;
    final saved = await crypto.pendingMessageResults('$group:add');
    if (saved.isNotEmpty) {
      final hex = (saved.single['result'] as Map)['welcome_wire_hex'] as String;
      welcome = [
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ];
    } else {
      await crypto.withMessage(
        '$group:create',
        () => crypto.createGroup(group),
      );
      final bundle = await crypto.withMessage(
        '$group:add',
        () => crypto.addMembers(group, packages),
      );
      if (bundle.welcome == null) throw StateError('附件Welcome缺失');
      welcome = bundle.welcome!.wireBytes;
    }
    final state = await crypto.groupState(group);
    final actual = [...state.memberIdentities]..sort();
    if (state.epoch != 1 || jsonEncode(actual) != jsonEncode(roster)) {
      throw StateError('附件MLS实际名册不一致');
    }
    ChatContent content(int bytes, String sha) => contentBuilder(
      MlsAttachmentDescriptor(
        groupId: group,
        welcome: welcome,
        members: roster,
        sender: _self,
        chunkCount: count,
        plainSha256: plainSha,
        cipherByteSize: bytes,
        cipherSha256: sha,
      ),
    );
    // 在第一块发送链消费之前，验证最终控制描述最大64KiB。
    ChatPayloadCodec.encode(content(byteSize + count, _zeroDigest));
    await _verifyPrefix(target, progress, framed: true);
    final input = await source.open();
    try {
      for (var index = progress['next_chunk'] as int; index < count; index++) {
        await Future<void>.delayed(Duration.zero);
        await requireCurrent();
        await input.setPosition(index * chunkBytes);
        final plain = await _readExact(
          input,
          min(chunkBytes, byteSize - index * chunkBytes),
        );
        final payload = _encodeChunk(
          group,
          attachmentId,
          _self,
          index,
          count,
          byteSize,
          plain,
        );
        final wire = await crypto.withMessage(
          chunkMessageId(group, index),
          () => crypto.groupCreateMessage(group, payload),
        );
        if (wire.wireBytes.length + 4 > plain.length + frameOverhead) {
          throw StateError('MLS附件帧开销超限');
        }
        final length = ByteData(4)
          ..setUint32(0, wire.wireBytes.length, Endian.big);
        progress = await _persistChunk(target, progress, index, [
          ...length.buffer.asUint8List(),
          ...wire.wireBytes,
        ]);
        plain.fillRange(0, plain.length, 0);
        payload.fillRange(0, payload.length, 0);
      }
    } finally {
      await input.close();
    }
    if (await source.length() != byteSize || await digest(source) != plainSha) {
      throw StateError('附件源文件发送期间发生变化');
    }
    final result = content(await target.length(), await digest(target));
    ChatPayloadCodec.encode(result);
    await requireCurrent();
    await finish(group);
    return result;
  }

  /// 正常聊天MLS已经核验的控制描述才可调用；Welcome与每块真实发送者再次核验。
  Future<File> open({
    required ChatContent content,
    required File cipher,
    required File target,
  }) async {
    ChatPayloadCodec.encode(content);
    await requireCurrent();
    await _path(target);
    final group = content.attachmentGroupId!;
    final count = content.attachmentChunkCount!;
    final size = content.byteSize!;
    if (await cipher.length() != content.cipherByteSize ||
        await digest(cipher) != content.cipherSha256) {
      throw const FormatException('附件原密文摘要错误');
    }
    final encodedWelcome = content.attachmentWelcome!;
    final welcomeBytes = base64Url.decode(
      encodedWelcome.padRight((encodedWelcome.length + 3) ~/ 4 * 4, '='),
    );
    var progress = await _action('begin_attachment', {
      'cipher_byte_size': content.cipherByteSize!,
      'cipher_sha256': content.cipherSha256!,
      'welcome_sha256': hash.sha256.convert(welcomeBytes).toString(),
      'group_id': group,
      'direction': 'receive',
      'chunk_count': count,
      'byte_size': size,
      'plain_sha256': content.plainSha256!,
      'sender_member_identity': content.attachmentSenderMemberIdentity!,
      'member_identities': content.attachmentMemberIdentities!,
    });
    if (progress['terminal'] == true) throw StateError('附件接收链已终结，不能重新入组');
    final id = '$group:welcome';
    final saved = await crypto.pendingMessageResults(id);
    if (saved.isEmpty) {
      final bytes = welcomeBytes;
      final joined = await crypto.withMessage(
        id,
        () => crypto.groupProcess(
          MlsWireMessage(
            conversationId: group,
            wireBytes: bytes,
            messageKind: MlsMessageKind.welcome,
          ),
        ),
      );
      if (!joined.isApplied ||
          joined.kind != GroupInboundKind.welcome ||
          joined.senderMemberIdentity !=
              content.attachmentSenderMemberIdentity ||
          jsonEncode([...joined.memberIdentities!]..sort()) !=
              jsonEncode(content.attachmentMemberIdentities)) {
        throw StateError('附件Welcome合同不一致');
      }
    }
    await crypto.acknowledgeMessage(id);
    final state = await crypto.groupState(group);
    if (state.epoch != 1 ||
        jsonEncode([...state.memberIdentities]..sort()) !=
            jsonEncode(content.attachmentMemberIdentities)) {
      throw StateError('附件当前MLS名册不一致');
    }
    await _verifyPrefix(target, progress, framed: false);
    final input = await cipher.open();
    try {
      for (var index = 0; index < count; index++) {
        await Future<void>.delayed(Duration.zero);
        await requireCurrent();
        final wire = await _readFrame(input);
        if (index < (progress['next_chunk'] as int)) continue;
        final decoded = await crypto.withMessage(
          chunkMessageId(group, index),
          () => crypto.groupProcess(
            MlsWireMessage(
              conversationId: group,
              wireBytes: wire,
              messageKind: MlsMessageKind.application,
            ),
          ),
        );
        if (!decoded.isApplied ||
            decoded.kind != GroupInboundKind.application ||
            decoded.senderMemberIdentity !=
                content.attachmentSenderMemberIdentity ||
            decoded.groupEpoch != 1 ||
            decoded.plaintext == null) {
          throw StateError('附件实际MLS块无效');
        }
        final plain = _decodeChunk(
          decoded.plaintext!,
          group,
          content.attachmentId!,
          content.attachmentSenderMemberIdentity!,
          index,
          count,
          size,
        );
        if (wire.length + 4 > plain.length + frameOverhead) {
          throw const FormatException('附件块开销越界');
        }
        progress = await _persistChunk(target, progress, index, plain);
        plain.fillRange(0, plain.length, 0);
        decoded.plaintext!.fillRange(0, decoded.plaintext!.length, 0);
      }
      if (await input.position() != await input.length()) {
        throw const FormatException('附件存在多余帧');
      }
    } finally {
      await input.close();
    }
    if (await target.length() != size ||
        await digest(target) != content.plainSha256) {
      throw const FormatException('附件明文摘要错误');
    }
    await requireCurrent();
    // 调用方在最终缓存系统保护提交之后才调用finish，不在此处提前删除接收组。
    return target;
  }

  static Map<String, Object> _header(
    String group,
    String attachment,
    String sender,
    int index,
    int count,
    int bytes,
  ) => {
    'group_id': group,
    'attachment_id': attachment,
    'sender_member_identity': sender,
    'chunk_index': index,
    'chunk_count': count,
    'byte_size': bytes,
  };

  static Uint8List _encodeChunk(
    String group,
    String attachment,
    String sender,
    int index,
    int count,
    int bytes,
    List<int> plain,
  ) {
    final header = utf8.encode(
      jsonEncode(_header(group, attachment, sender, index, count, bytes)),
    );
    if (header.length > 2044) throw StateError('附件块头超限');
    final length = ByteData(4)..setUint32(0, header.length, Endian.big);
    return Uint8List.fromList([
      ...length.buffer.asUint8List(),
      ...header,
      ...plain,
    ]);
  }

  static Uint8List _decodeChunk(
    List<int> payload,
    String group,
    String attachment,
    String sender,
    int index,
    int count,
    int bytes,
  ) {
    if (payload.length < 4) throw const FormatException('附件应用块截断');
    final data = Uint8List.fromList(payload);
    final length = ByteData.sublistView(data).getUint32(0, Endian.big);
    if (length == 0 || length > 2044 || 4 + length >= data.length) {
      throw const FormatException('附件块头错误');
    }
    final expected = utf8.encode(
      jsonEncode(_header(group, attachment, sender, index, count, bytes)),
    );
    if (jsonEncode(data.sublist(4, 4 + length)) != jsonEncode(expected)) {
      throw const FormatException('附件块身份、顺序或字段不一致');
    }
    final plain = Uint8List.fromList(data.sublist(4 + length));
    if (plain.length != min(chunkBytes, bytes - index * chunkBytes)) {
      throw const FormatException('附件明文块大小错误');
    }
    return plain;
  }
}
