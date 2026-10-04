import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import '../support/isar_test_env.dart';
import '../support/native_probe.dart';

final Uint8List _testStateKey = Uint8List.fromList(
  List<int>.generate(32, (index) => index),
);
const _aliceUserId = 'CN220-CTZN2-100000001-2026';
const _bobUserId = 'CN220-CTZN2-100000002-2026';
const _aliceAccountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _bobAccountId =
    '0x2222222222222222222222222222222222222222222222222222222222222222';
const _genesisHash =
    '0x4242424242424242424242424242424242424242424242424242424242424242';
const _alice = ChatDevice(userId: _aliceUserId, deviceId: 'alice-phone');
const _bob = ChatDevice(userId: _bobUserId, deviceId: 'bob-phone');

void main() {
  useIsolatedChatIsar();

  final skip = chatSdkNativeSkipReason();

  test('native KeyPackage 私有材料严格绑定当前 user ID 状态所有者', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-owner-');
    addTearDown(() => root.delete(recursive: true));
    final crypto = NativeMlsCrypto(
      identity: _alice,
      stateStore: _stateStore(root, 'alice', _aliceUserId),
    );

    final package = await crypto.createKeyPackage(_alice, lastResort: true);
    expect(package.userId, _aliceUserId);
    expect(package.lastResort, isTrue);
    await expectLater(
      crypto.createKeyPackage(_bob, lastResort: true),
      throwsA(
        isA<MlsNativeException>().having(
          (error) => error.code,
          'code',
          MlsNativeErrorCode.stateOwnerMismatch,
        ),
      ),
    );
  }, skip: skip);

  test('native OpenMLS 双人群在进程重建后继续收发', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-openmls-');
    addTearDown(() => root.delete(recursive: true));
    final aliceStore = _stateStore(root, 'alice', _aliceUserId);
    final bobStore = _stateStore(root, 'bob', _bobUserId);
    final aliceCrypto = NativeMlsCrypto(
      identity: _alice,
      stateStore: aliceStore,
    );
    final bobCrypto = NativeMlsCrypto(identity: _bob, stateStore: bobStore);
    const conversationId = 'dm:alice:bob:openmls';

    final bobPackage = await bobCrypto.createKeyPackage(_bob, lastResort: true);
    await aliceCrypto.createGroup(conversationId);
    final add = await aliceCrypto.addMembers(conversationId, <MlsKeyPackage>[
      bobPackage,
    ]);
    final joined = await bobCrypto.groupProcess(add.welcome!);
    expect(joined.kind, GroupInboundKind.welcome);

    final first = await aliceCrypto.groupCreateMessage(
      conversationId,
      utf8.encode('第一条消息'),
    );
    final firstInbound = await bobCrypto.groupProcess(first);
    expect(utf8.decode(firstInbound.plaintext!), '第一条消息');

    final restartedAlice = NativeMlsCrypto(
      identity: _alice,
      stateStore: aliceStore,
    );
    final restartedBob = NativeMlsCrypto(identity: _bob, stateStore: bobStore);
    final second = await restartedAlice.groupCreateMessage(
      conversationId,
      utf8.encode('重建后的第二条消息'),
    );
    final secondInbound = await restartedBob.groupProcess(second);
    expect(utf8.decode(secondInbound.plaintext!), '重建后的第二条消息');
  }, skip: skip);

  test('native OpenMLS 密文经设备邮箱边界落入接收端本机', () async {
    final root = await Directory.systemTemp.createTemp('gmb-chat-flow-');
    addTearDown(() => root.delete(recursive: true));
    final aliceCrypto = NativeMlsCrypto(
      identity: _alice,
      stateStore: _stateStore(root, 'alice', _aliceUserId),
    );
    final bobCrypto = NativeMlsCrypto(
      identity: _bob,
      stateStore: _stateStore(root, 'bob', _bobUserId),
    );
    const conversationId = 'dm:alice:bob:flow';
    final bobPackage = await bobCrypto.createKeyPackage(_bob, lastResort: true);
    await aliceCrypto.createGroup(conversationId);
    final add = await aliceCrypto.addMembers(conversationId, <MlsKeyPackage>[
      bobPackage,
    ]);
    await bobCrypto.groupProcess(add.welcome!);

    final relayed = <List<int>>[];
    final senderStore = ChatStore();
    final senderBinding = await senderStore.activateBindingFence(
      const ChatDataBinding(
        keyDomain: _genesisHash,
        userId: _aliceUserId,
        bindingRevision: 1,
        accountId: _aliceAccountId,
      ),
    );
    final sender = ChatFlow(
      ownerUserId: _aliceUserId,
      currentAccountId: _aliceAccountId,
      crypto: aliceCrypto,
      store: senderStore,
      bindingToken: senderBinding,
      deliverer: (message, bytes, recipientUserId, recipientDeviceId) async {
        expect(recipientUserId, _bobUserId);
        expect(recipientDeviceId, 'bob-phone');
        relayed.add(List<int>.from(bytes));
        return ChatDeliveryResult(
          messageId: message.messageId,
          transportType: ChatTransportType.server,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );

    await sender.sendText(
      conversationId: conversationId,
      senderUserId: _aliceUserId,
      recipientUserId: _bobUserId,
      senderDeviceId: 'alice-phone',
      recipientKeyPackages: <MlsKeyPackage>[bobPackage],
      text: '瞬时直达',
    );
    expect(relayed, hasLength(1));

    await ChatIsar.instance.resetForTest();
    final receiverStore = ChatStore();
    final receiverBinding = await receiverStore.activateBindingFence(
      const ChatDataBinding(
        keyDomain: _genesisHash,
        userId: _bobUserId,
        bindingRevision: 1,
        accountId: _bobAccountId,
      ),
    );
    final receiver = ChatFlow(
      ownerUserId: _bobUserId,
      currentAccountId: _bobAccountId,
      crypto: bobCrypto,
      store: receiverStore,
      bindingToken: receiverBinding,
      deliverer: (_, __, ___, ____) => throw StateError('接收端不得重新投递'),
    );
    await receiver.processIncomingMessageBytes(relayed.single);

    final messages = await receiverStore.readMessages(
      ownerUserId: _bobUserId,
      currentAccountId: _bobAccountId,
      conversationId: conversationId,
    );
    final message = ChatPayloadCodec.decode(messages.single.plaintext ?? '');
    expect(message.kind, ChatMessageKind.text);
    expect(message.text, '瞬时直达');
    expect(messages.single.direction, 'incoming');
  }, skip: skip);
}

MlsStateStore _stateStore(Directory root, String name, String ownerUserId) =>
    MlsStateStore(
      Directory('${root.path}/$name'),
      ownerUserId: ownerUserId,
      stateKey: Uint8List.fromList(_testStateKey),
    );
