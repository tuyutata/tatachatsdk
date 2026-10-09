import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/mls/mls_attachment.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import '../support/isar_test_env.dart';
import '../support/native_probe.dart';

class _Device {
  _Device(this.store, this.identity, this.root);
  final MlsStateStore store;
  final ChatDevice identity;
  final Directory root;
  NativeMlsCrypto get crypto =>
      NativeMlsCrypto(identity: identity, stateStore: store);
  MlsAttachment attachment({
    MlsStateStore? state,
    Future<void> Function()? current,
  }) => MlsAttachment(
    crypto: NativeMlsCrypto(identity: identity, stateStore: state ?? store),
    store: state ?? store,
    identity: identity,
    protectedRoot: root,
    mutate: <T>(operation) => operation(),
    requireCurrent: current ?? () async {},
  );
}

Future<_Device> _device(
  Directory parent,
  String name, {
  String cid = 'CID-A',
}) async {
  final root = await Directory('${parent.path}/$name').create();
  final store = MlsStateStore(root, ownerUserId: cid);
  return _Device(store, await store.initializeIdentity(), root);
}

ChatContent _content(
  MlsAttachmentDescriptor d,
  int bytes, {
  String id = 'file-1',
}) => ChatContent.media(
  kind: ChatMessageKind.file,
  attachmentId: id,
  fileName: 'source.bin',
  mime: 'application/octet-stream',
  byteSize: bytes,
  attachmentChatEpoch: 1,
  attachmentGroupId: d.groupId,
  attachmentWelcome: base64UrlEncode(d.welcome).replaceAll('=', ''),
  attachmentMemberIdentities: d.members,
  attachmentSenderMemberIdentity: d.sender,
  attachmentChunkCount: d.chunkCount,
  plainSha256: d.plainSha256,
  cipherByteSize: d.cipherByteSize,
  cipherSha256: d.cipherSha256,
);

ChatContent _copy(
  ChatContent c, {
  String? cipherSha256,
  int? cipherByteSize,
  List<String>? members,
}) => ChatContent.media(
  kind: c.kind,
  attachmentId: c.attachmentId!,
  fileName: c.fileName!,
  mime: c.mime!,
  byteSize: c.byteSize!,
  attachmentChatEpoch: c.attachmentChatEpoch!,
  attachmentGroupId: c.attachmentGroupId!,
  attachmentWelcome: c.attachmentWelcome!,
  attachmentMemberIdentities: members ?? c.attachmentMemberIdentities!,
  attachmentSenderMemberIdentity: c.attachmentSenderMemberIdentity!,
  attachmentChunkCount: c.attachmentChunkCount!,
  plainSha256: c.plainSha256!,
  cipherByteSize: cipherByteSize ?? c.cipherByteSize!,
  cipherSha256: cipherSha256 ?? c.cipherSha256!,
);

void main() {
  useIsolatedChatIsar();
  final skip = chatSdkNativeSkipReason();
  Future<Directory> root() async {
    final temp = await Directory.systemTemp.createTemp('mls_attachment_');
    final dir = Directory(await temp.resolveSymbolicLinks());
    addTearDown(() => dir.delete(recursive: true));
    return dir;
  }

  test('真实MLS附件控制为同CID两台收件设备分别持久化Welcome和投递条目', () async {
    final dir = await root(), a = await _device(dir, 'a');
    final receivers = [
      await _device(dir, 'b', cid: 'CID-B'),
      await _device(dir, 'c', cid: 'CID-B'),
    ];
    final packages = <MlsKeyPackage>[];
    for (final receiver in receivers) {
      packages.add(
        await receiver.crypto.createKeyPackage(
          receiver.identity,
          lastResort: true,
        ),
      );
    }
    final database = ChatStore();
    final account = '0x${'33' * 32}';
    final token = await database.activateBindingFence(
      ChatBinding(
        userId: a.identity.userId,
        accountId: account,
        bindingRevision: 1,
        bindingScope: '0x${'44' * 32}',
      ),
    );
    final tasks = <Future<void> Function()>[];
    final controls = <ChatContent>[];
    final flow = ChatFlow<ChatBindingFenceToken>(
      crypto: a.crypto,
      store: database,
      bindingToken: token,
      ownerUserId: a.identity.userId,
      currentAccountId: account,
      deliveryScheduler: (_, delivery) => tasks.add(delivery),
      deliverer: (message, bytes, user, device) async {
        final receiver = receivers.singleWhere(
          (r) => r.identity.deviceId == device,
        );
        final result = await receiver.crypto.withMessage(
          message.messageId,
          () => receiver.crypto.groupProcess(
            MlsWireMessage(
              conversationId: message.conversationId,
              wireBytes: message.openmlsCiphertext,
            ),
          ),
        );
        if (result.kind == GroupInboundKind.application) {
          controls.add(ChatPayloadCodec.decode(utf8.decode(result.plaintext!)));
        }
        return ChatDeliveryResult(
          messageId: message.messageId,
          transportType: ChatTransportType.server,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );
    const conversation = 'direct-two-devices';
    final audience = await flow.prepareAttachmentAudience(
      conversationId: conversation,
      recipientUserId: 'CID-B',
      senderDeviceId: a.identity.deviceId,
      keyPackages: packages,
      messageId: 'file-1',
    );
    Future<List<ChatQueuedMessage>> queued() => database.readQueuedMessages(
      bindingToken: token,
      ownerUserId: a.identity.userId,
      conversationId: conversation,
    );
    final welcomes = await queued();
    expect(welcomes.length, 2);
    expect(welcomes.map((m) => m.messageId).toSet().length, 2);
    final welcomeTask = tasks.removeAt(0);
    await welcomeTask();
    final source = File('${a.root.path}/source'),
        cipher = File('${a.root.path}/cipher');
    await source.writeAsBytes([1, 2, 3], flush: true);
    final roster = [...audience.memberIdentities]..sort();
    final content = await a.attachment().seal(
      attachmentId: 'file-1',
      byteSize: 3,
      source: source,
      target: cipher,
      members: roster,
      keyPackages: packages,
      contentBuilder: (d) => _content(d, 3),
    );
    await flow.sendMediaControl(
      conversationId: conversation,
      senderUserId: a.identity.userId,
      recipientUserId: 'CID-B',
      senderDeviceId: a.identity.deviceId,
      media: content,
      createdAtMillis: 1234,
    );
    final media = await queued();
    expect(media.length, 2);
    expect(media.map((m) => m.messageId).toSet().length, 2);
    final envelopes = media
        .map((m) => EncryptedMessage.fromBuffer(m.messageBytes))
        .toList();
    expect(
      envelopes.map((m) => m.recipientDeviceId).toSet(),
      receivers.map((r) => r.identity.deviceId).toSet(),
    );
    expect(envelopes.first.openmlsCiphertext, envelopes.last.openmlsCiphertext);
    await tasks.removeAt(0)();
    expect(controls.length, 2);
    expect(
      controls.every((c) => c.attachmentGroupId == content.attachmentGroupId),
      true,
    );
    expect(
      (await a.crypto.groupState(conversation)).memberIdentities.toSet(),
      roster.toSet(),
    );
  }, skip: skip);

  test('真实MLS三设备附件组，分块精确复原且不推进普通聊天链', () async {
    final dir = await root();
    final a = await _device(dir, 'a'),
        b = await _device(dir, 'b'),
        c = await _device(dir, 'c', cid: 'CID-B');
    final packages = [
      await b.crypto.createKeyPackage(b.identity, lastResort: true),
      await c.crypto.createKeyPackage(c.identity, lastResort: true),
    ];
    await a.crypto.withMessage(
      'chat-create',
      () => a.crypto.createGroup('ordinary-chat'),
    );
    final added = await a.crypto.withMessage(
      'chat-add',
      () => a.crypto.addMembers('ordinary-chat', packages),
    );
    await b.crypto.withMessage(
      'chat-join',
      () => b.crypto.groupProcess(added.welcome!),
    );
    final chatBefore = await a.crypto.groupState('ordinary-chat');
    final source = File('${a.root.path}/source');
    const size = 2 * MlsAttachment.chunkBytes + 37;
    final bytes = Uint8List.fromList(List.generate(size, (i) => i % 251));
    await source.writeAsBytes(bytes, flush: true);
    final cipher = File('${a.root.path}/cipher');
    final roster = [
      a.identity,
      b.identity,
      c.identity,
    ].map((i) => '${i.userId}:${i.deviceId}').toList()..sort();
    final control = await a.attachment().seal(
      attachmentId: 'file-1',
      byteSize: size,
      source: source,
      target: cipher,
      members: roster,
      keyPackages: packages,
      contentBuilder: (d) => _content(d, size),
    );
    expect(control.attachmentChunkCount, 3);
    expect(
      control.cipherByteSize,
      lessThanOrEqualTo(size + 3 * MlsAttachment.frameOverhead),
    );
    expect(
      (await a.crypto.groupState('ordinary-chat')).epoch,
      chatBefore.epoch,
    );
    for (final receiver in [b, c]) {
      final output = File('${receiver.root.path}/plain');
      final decoded = await receiver.attachment().open(
        content: control,
        cipher: cipher,
        target: output,
      );
      expect(await decoded.readAsBytes(), bytes);
      await receiver.attachment().finish(control.attachmentGroupId!);
      await expectLater(
        receiver.crypto.groupState(control.attachmentGroupId!),
        throwsA(isA<MlsNativeException>()),
      );
      expect(
        (await receiver.store.readIdentity()).publicKey,
        receiver.identity.publicKey,
      );
      await expectLater(
        receiver.attachment().open(
          content: control,
          cipher: cipher,
          target: output,
        ),
        throwsStateError,
      );
    }
    await expectLater(
      a.crypto.groupState(control.attachmentGroupId!),
      throwsA(isA<MlsNativeException>()),
    );
    final ordinary = await a.crypto.withMessage(
      'ordinary-after-file',
      () => a.crypto.groupCreateMessage('ordinary-chat', utf8.encode('普通聊天继续')),
    );
    final received = await b.crypto.withMessage(
      'ordinary-receive',
      () => b.crypto.groupProcess(ordinary),
    );
    expect(utf8.decode(received.plaintext!), '普通聊天继续');
    expect(
      received.senderMemberIdentity,
      '${a.identity.userId}:${a.identity.deviceId}',
    );
  }, skip: skip);

  for (final committed in [false, true]) {
    test('真实块flush后确认${committed ? '已提交' : '未提交'}中断，恢复原帧与紧凑游标', () async {
      final dir = await root(),
          a = await _device(dir, 'a'),
          b = await _device(dir, 'b');
      final package = await b.crypto.createKeyPackage(
        b.identity,
        lastResort: true,
      );
      final roster = [
        '${a.identity.userId}:${a.identity.deviceId}',
        '${b.identity.userId}:${b.identity.deviceId}',
      ]..sort();
      final source = File('${a.root.path}/source'),
          cipher = File('${a.root.path}/cipher');
      const size = 3 * MlsAttachment.chunkBytes + 15;
      await source.writeAsBytes(
        List.generate(size, (i) => i % 239),
        flush: true,
      );
      final bindings = MlsNativeBindings.load();
      var interrupted = false;
      final hooked = MlsStateStore(
        a.store.directory,
        ownerUserId: a.identity.userId,
        debugCallJson: (request) {
          if (request['action'] == 'confirm_attachment_chunk' && !interrupted) {
            interrupted = true;
            if (committed) bindings.callJson(bindings.store, request);
            throw StateError('合成确认中断');
          }
          return bindings.callJson(bindings.store, request);
        },
      );
      Future<ChatContent> seal(MlsAttachment engine) => engine.seal(
        attachmentId: 'file-1',
        byteSize: size,
        source: source,
        target: cipher,
        members: roster,
        keyPackages: [package],
        contentBuilder: (d) => _content(d, size),
      );
      await expectLater(seal(a.attachment(state: hooked)), throwsStateError);
      final prefix = await cipher.readAsBytes();
      final nativeBefore = await a.store.attachmentAction(
        'attachment_progress',
        {
          'group_id': MlsAttachment.groupId(
            roster.firstWhere((m) => m.endsWith(a.identity.deviceId)),
            'file-1',
          ),
        },
      );
      expect(nativeBefore['next_chunk'], committed ? 1 : 0);
      final control = await seal(a.attachment());
      final complete = await cipher.readAsBytes();
      expect(complete.sublist(0, prefix.length), prefix);
      final state = jsonDecode(
        await File('${a.store.path}/state.bin').readAsString(),
      ) as Map;
      expect(
        (state['results'] as Map).values.where(
          (v) => (v as Map)['request']['group_id'] == control.attachmentGroupId,
        ),
        isEmpty,
      );
      final output = await b.attachment().open(
        content: control,
        cipher: cipher,
        target: File('${b.root.path}/plain'),
      );
      expect(await MlsAttachment.digest(output), control.plainSha256);
      await b.attachment().finish(control.attachmentGroupId!);
    }, skip: skip);
  }

  for (final committed in [false, true]) {
    test('真实接收块flush后确认${committed ? '已提交' : '未提交'}中断只恢复原结果', () async {
      final dir = await root(),
          a = await _device(dir, 'a'),
          b = await _device(dir, 'b');
      final package = await b.crypto.createKeyPackage(
        b.identity,
        lastResort: true,
      );
      final roster = [
        '${a.identity.userId}:${a.identity.deviceId}',
        '${b.identity.userId}:${b.identity.deviceId}',
      ]..sort();
      const size = 2 * MlsAttachment.chunkBytes + 17;
      final source = File('${a.root.path}/source'),
          cipher = File('${a.root.path}/cipher');
      await source.writeAsBytes(
        List.generate(size, (i) => i % 251),
        flush: true,
      );
      final control = await a.attachment().seal(
        attachmentId: 'file-1',
        byteSize: size,
        source: source,
        target: cipher,
        members: roster,
        keyPackages: [package],
        contentBuilder: (d) => _content(d, size),
      );
      final bindings = MlsNativeBindings.load();
      var interrupted = false;
      final hooked = MlsStateStore(
        b.store.directory,
        ownerUserId: b.identity.userId,
        debugCallJson: (request) {
          if (request['action'] == 'confirm_attachment_chunk' && !interrupted) {
            interrupted = true;
            if (committed) bindings.callJson(bindings.store, request);
            throw StateError('合成接收确认中断');
          }
          return bindings.callJson(bindings.store, request);
        },
      );
      final target = File('${b.root.path}/plain');
      await expectLater(
        b
            .attachment(state: hooked)
            .open(content: control, cipher: cipher, target: target),
        throwsStateError,
      );
      final prefix = await target.readAsBytes();
      final progress = await b.store.attachmentAction('attachment_progress', {
        'group_id': control.attachmentGroupId!,
      });
      expect(progress['next_chunk'], committed ? 1 : 0);
      final originalIdentity = (await b.store.readIdentity()).publicKey;
      final restored = await b.attachment().open(
        content: control,
        cipher: cipher,
        target: target,
      );
      expect((await restored.readAsBytes()).sublist(0, prefix.length), prefix);
      expect(await MlsAttachment.digest(restored), control.plainSha256);
      expect((await b.store.readIdentity()).publicKey, originalIdentity);
      final pending = await b.crypto.pendingMessageResults(
        MlsAttachment.chunkMessageId(control.attachmentGroupId!, 0),
      );
      expect(pending, isEmpty);
      await b.attachment().finish(control.attachmentGroupId!);
    }, skip: skip);
  }

  test('真实未确认结果不能改变输入，已消费前缀丢失或损坏均失败', () async {
    final dir = await root(),
        a = await _device(dir, 'a'),
        b = await _device(dir, 'b');
    final package = await b.crypto.createKeyPackage(
      b.identity,
      lastResort: true,
    );
    final roster = [
      '${a.identity.userId}:${a.identity.deviceId}',
      '${b.identity.userId}:${b.identity.deviceId}',
    ]..sort();
    final source = File('${a.root.path}/source'),
        cipher = File('${a.root.path}/cipher');
    const size = 2 * MlsAttachment.chunkBytes + 1;
    await source.writeAsBytes(List.filled(size, 7), flush: true);
    final bindings = MlsNativeBindings.load();
    var once = false;
    final hooked = MlsStateStore(
      a.store.directory,
      ownerUserId: a.identity.userId,
      debugCallJson: (r) {
        final result = bindings.callJson(bindings.store, r);
        if (r['action'] == 'confirm_attachment_chunk' && !once) {
          once = true;
          throw StateError('合成提交后中断');
        }
        return result;
      },
    );
    Future<ChatContent> seal(MlsAttachment engine) => engine.seal(
      attachmentId: 'file-1',
      byteSize: size,
      source: source,
      target: cipher,
      members: roster,
      keyPackages: [package],
      contentBuilder: (d) => _content(d, size),
    );
    await expectLater(seal(a.attachment(state: hooked)), throwsStateError);
    final bytes = await cipher.readAsBytes();
    await cipher.delete();
    await expectLater(seal(a.attachment()), throwsStateError);
    bytes[bytes.length - 1] ^= 1;
    await cipher.writeAsBytes(bytes, flush: true);
    await expectLater(seal(a.attachment()), throwsStateError);
    await source.writeAsBytes(List.filled(size, 8), flush: true);
    await expectLater(seal(a.attachment()), throwsA(isA<MlsNativeException>()));
  }, skip: skip);

  test('身份变化、跨CID存储与未知设备包不能生成附件帧', () async {
    final dir = await root(),
        a = await _device(dir, 'a'),
        b = await _device(dir, 'b');
    final package = await b.crypto.createKeyPackage(
      b.identity,
      lastResort: true,
    );
    final source = File('${a.root.path}/source'),
        target = File('${a.root.path}/cipher');
    await source.writeAsBytes([1, 2, 3], flush: true);
    final roster = [
      '${a.identity.userId}:${a.identity.deviceId}',
      '${b.identity.userId}:${b.identity.deviceId}',
    ]..sort();
    Future<ChatContent> send(MlsAttachment engine, List<String> members) =>
        engine.seal(
          attachmentId: 'file-1',
          byteSize: 3,
          source: source,
          target: target,
          members: members,
          keyPackages: [package],
          contentBuilder: (d) => _content(d, 3),
        );
    await expectLater(
      send(
        a.attachment(
          current: () async {
            throw StateError('合成身份已切换');
          },
        ),
        roster,
      ),
      throwsStateError,
    );
    expect(await target.exists(), false);
    await expectLater(
      send(
        a.attachment(
          state: MlsStateStore(a.store.directory, ownerUserId: 'CID-B'),
        ),
        roster,
      ),
      throwsStateError,
    );
    await expectLater(
      send(a.attachment(), [roster.first, 'CID-X:${'00' * 32}']),
      throwsStateError,
    );
    expect(await target.exists(), false);
  }, skip: skip);

  test('真实MLS拒绝篡改、帧错序、截断、伪造Welcome名册，拒绝附件Commit', () async {
    final dir = await root(), a = await _device(dir, 'a');
    final receivers = [
      await _device(dir, 'b'),
      await _device(dir, 'c'),
      await _device(dir, 'd'),
      await _device(dir, 'e'),
    ];
    final packages = <MlsKeyPackage>[];
    for (final receiver in receivers) {
      packages.add(
        await receiver.crypto.createKeyPackage(
          receiver.identity,
          lastResort: true,
        ),
      );
    }
    final roster = [
      a.identity,
      ...receivers.map((r) => r.identity),
    ].map((i) => '${i.userId}:${i.deviceId}').toList()..sort();
    const size = MlsAttachment.chunkBytes + 37;
    final source = File('${a.root.path}/source'),
        cipher = File('${a.root.path}/cipher');
    await source.writeAsBytes(List.generate(size, (i) => i % 241), flush: true);
    final control = await a.attachment().seal(
      attachmentId: 'file-1',
      byteSize: size,
      source: source,
      target: cipher,
      members: roster,
      keyPackages: packages,
      contentBuilder: (d) => _content(d, size),
    );
    final original = await cipher.readAsBytes();
    final boundary = 4 + ByteData.sublistView(original).getUint32(0);
    final variants = [
      Uint8List.fromList(original)..[boundary - 1] ^= 1,
      Uint8List.fromList([
        ...original.sublist(boundary),
        ...original.sublist(0, boundary),
      ]),
      Uint8List.fromList(original.sublist(0, original.length - 1)),
    ];
    for (var index = 0; index < variants.length; index++) {
      final receiver = receivers[index];
      final bad = File('${receiver.root.path}/bad');
      await bad.writeAsBytes(variants[index], flush: true);
      final payload = _copy(
        control,
        cipherByteSize: variants[index].length,
        cipherSha256: await MlsAttachment.digest(bad),
      );
      final target = File('${receiver.root.path}/plain');
      await expectLater(
        receiver.attachment().open(
          content: payload,
          cipher: bad,
          target: target,
        ),
        throwsA(isA<Exception>()),
      );
      final p = await receiver.store.attachmentAction('attachment_progress', {
        'group_id': control.attachmentGroupId!,
      });
      expect(p['next_chunk'], index == 2 ? 1 : 0);
      // 完整描述不同的重试也不能接管该接收链。
      await expectLater(
        receiver.attachment().open(
          content: control,
          cipher: cipher,
          target: target,
        ),
        throwsA(isA<MlsNativeException>()),
      );
    }
    final receiver = receivers.last;
    final lie = [...roster]
      ..remove(
        '${receivers.first.identity.userId}:${receivers.first.identity.deviceId}',
      );
    await expectLater(
      receiver.attachment().open(
        content: _copy(control, members: lie),
        cipher: cipher,
        target: File('${receiver.root.path}/plain'),
      ),
      throwsA(isA<MlsNativeException>()),
    );
    await expectLater(
      receivers[0].crypto.withMessage(
        '${control.attachmentGroupId!}:remove',
        () => receivers[0].crypto.removeMembers(control.attachmentGroupId!, [
          roster.first,
        ]),
      ),
      throwsA(isA<MlsNativeException>()),
    );
  }, skip: skip);

  test(
    '真实72MiB附件按块流式处理，归档状态不随文件正文增长',
    () async {
      final dir = await root(),
          a = await _device(dir, 'a'),
          b = await _device(dir, 'b');
      final package = await b.crypto.createKeyPackage(
        b.identity,
        lastResort: true,
      );
      final source = File('${a.root.path}/large'),
          target = File('${a.root.path}/cipher');
      final file = await source.open(mode: FileMode.write);
      final block = Uint8List.fromList(
        List.generate(MlsAttachment.chunkBytes, (i) => i % 251),
      );
      try {
        for (var i = 0; i < 72; i++) {
          await file.writeFrom(block);
        }
        await file.flush();
      } finally {
        await file.close();
      }
      final bindings = MlsNativeBindings.load();
      var confirmed = 0;
      final hooked = MlsStateStore(
        a.store.directory,
        ownerUserId: a.identity.userId,
        debugCallJson: (r) {
          final result = bindings.callJson(bindings.store, r);
          if (r['action'] == 'confirm_attachment_chunk') {
            confirmed++;
            expect(
              File('${a.store.path}/state.bin').lengthSync(),
              lessThan(256 * 1024),
            );
            final pending = bindings.callJson(bindings.store, {
              'state_store_dir': a.store.path,
              'user_id': a.identity.userId,
              'action': 'pending_results',
              'message_id': MlsAttachment.chunkMessageId(
                (r['attachment'] as Map)['group_id'] as String,
                confirmed - 1,
              ),
            });
            expect(pending['results'], isEmpty);
          }
          return result;
        },
      );
      final roster = [
        '${a.identity.userId}:${a.identity.deviceId}',
        '${b.identity.userId}:${b.identity.deviceId}',
      ]..sort();
      final control = await a
          .attachment(state: hooked)
          .seal(
            attachmentId: 'file-1',
            byteSize: 72 * MlsAttachment.chunkBytes,
            source: source,
            target: target,
            members: roster,
            keyPackages: [package],
            contentBuilder: (d) => _content(d, 72 * MlsAttachment.chunkBytes),
          );
      expect(confirmed, 72);
      final output = await b.attachment().open(
        content: control,
        cipher: target,
        target: File('${b.root.path}/plain'),
      );
      expect(await MlsAttachment.digest(output), control.plainSha256);
      await b.attachment().finish(control.attachmentGroupId!);
      // 72MiB真实FFI包含144次块验密和磁盘提交，给予有限独立预算，断言不变。
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
