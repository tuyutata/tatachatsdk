import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import '../support/isar_test_env.dart';

const _device =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _account = ChatRuntimeAccount(
  hostIndex: 0,
  bindingScope:
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  userId: 'user-a',
  bindingRevision: 1,
  accountId: 'account-a',
  displayName: 'A',
);

final class _Token implements ChatPushToken {
  @override
  String get provider => 'fcm';
  @override
  String get token => 'synthetic-token';
  @override
  String? get apnsEnvironment => null;
  @override
  String get registrationCacheValue => 'fcm:synthetic-token';
}

final class _Push implements ChatPushBridge {
  @override
  Stream<ChatPushWake> get wakes => const Stream.empty();
  @override
  Stream<ChatPushToken> get tokenChanges => const Stream.empty();
  @override
  Future<ChatPushToken> initialize() async => _Token();
  @override
  Future<bool> takePendingWake() async => false;
  @override
  Future<void> clearConversationNotifications(String conversationId) async {}
  @override
  Future<void> dispose() async {}
}

final class _Host implements ChatRuntimeHost {
  ChatRuntimeAccount account = _account;
  Completer<ChatAccess>? access;
  final enteredAccess = Completer<void>();
  @override
  ChatPushBridge get push => _Push();
  @override
  ChatMediaLimitPolicy get mediaLimits => const ChatUnlimitedMediaLimitPolicy();
  @override
  Future<bool> canSend(String userId) async => true;
  @override
  Future<ChatRuntimeAccount?> currentAccount({
    String? expectedAccountId,
  }) async => account;
  @override
  Future<ChatAccess> requestChatAccess({
    required ChatRuntimeAccount account,
    required ChatDevice identity,
  }) async {
    if (!enteredAccess.isCompleted) enteredAccess.complete();
    return access == null
        ? ChatAccess(
            realtimeUrl: Uri.parse(
              'wss://chat.example.test/api/tatachat/realtime',
            ),
            accessToken: 'synthetic-token',
            expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
          )
        : access!.future;
  }

  @override
  Future<void> invalidateAccount(String accountId) async {}
}

final class _Crypto implements MlsGroupCrypto {
  int processed = 0;
  @override
  Future<MlsKeyPackage> createKeyPackage(
    ChatDevice identity, {
    bool lastResort = true,
  }) async => MlsKeyPackage(
    userId: identity.userId,
    deviceId: identity.deviceId,
    keyPackageRef: 'synthetic-ref',
    keyPackageBytes: [1],
    cipherSuite: 'synthetic',
    notBeforeMillis: 1,
    notAfterMillis: 4102444800000,
    lastResort: true,
  );
  @override
  Future<GroupInbound> groupProcess(MlsWireMessage wire) async {
    processed++;
    if (wire.wireBytes.first == 255) {
      throw StateError('synthetic decrypt failure');
    }
    return GroupInbound(
      groupId: wire.conversationId,
      kind: GroupInboundKind.application,
      status: GroupProcessStatus.applied,
      messageEpoch: 0,
      groupEpoch: 0,
      selfRemoved: false,
      plaintext: wire.wireBytes,
      senderMemberIdentity: 'user-b:device-b',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected crypto operation');
}

final class _Message implements ChatMailboxMessage {
  _Message(int index, {bool poison = false})
    : message = EncryptedMessage(
        messageId: 'message-$index',
        senderUserId: 'user-b',
        senderDeviceId: 'device-b',
        conversationId: ChatSdk.directConversationId('user-a', 'user-b'),
        deliveries: [
          EncryptedDelivery(
            recipient: Recipient(userId: 'user-a', deviceId: _device),
            openmlsCiphertext: poison
                ? [255]
                : utf8.encode(
                    ChatPayloadCodec.encode(ChatContent.text('text-$index')),
                  ),
          ),
        ],
        createdAtMillis: Int64(index + 1),
      );
  final EncryptedMessage message;
  @override
  String get messageId => message.messageId;
  @override
  String get senderUserId => message.senderUserId;
  @override
  String get recipientUserId => message.recipientUserId;
  @override
  String get recipientDeviceId => message.recipientDeviceId;
  @override
  String get conversationId => message.conversationId;
  @override
  List<int> get messageBytes => message.writeToBuffer();
  @override
  int get createdAtMillis => message.createdAtMillis.toInt();
}

final class _Transport implements ChatServiceTransport {
  _Transport(this.provider, this.store);
  final ChatAccessProvider provider;
  final ChatStore store;
  final messages = <ChatMailboxMessage>[];
  final acknowledged = <List<String>>[];
  final published = <MlsKeyPackage>[];
  Completer<List<ChatMailboxMessage>>? fetch;
  Completer<void>? enteredFetch;
  Future<void> Function(ChatServiceEvent)? onEvent;
  int fetches = 0,
      activeFetches = 0,
      maximumActive = 0,
      pageSize = 100,
      closes = 0;
  @override
  ChatTransportType get type => ChatTransportType.server;
  @override
  String? lastRealtimeDiagnosticCode;
  @override
  Future<void> connect() async {
    await provider();
  }

  @override
  Future<void> dispose() async {
    closes++;
  }

  @override
  Future<void> publishKeyPackage(MlsKeyPackage keyPackage) async {
    published.add(keyPackage);
  }

  @override
  Future<void> registerPushEndpoint({
    required String pushProvider,
    required String pushToken,
    required String? apnsEnvironment,
    required int expiresAtMillis,
  }) async {}
  @override
  Future<List<ChatMailboxMessage>> fetchMailbox() async {
    fetches++;
    activeFetches++;
    if (activeFetches > maximumActive) maximumActive = activeFetches;
    if (enteredFetch != null && !enteredFetch!.isCompleted) {
      enteredFetch!.complete();
    }
    try {
      return fetch == null
          ? messages.take(pageSize).toList()
          : await fetch!.future;
    } finally {
      activeFetches--;
    }
  }

  @override
  Future<void> acknowledgeMailbox(List<String> ids) async {
    final stored = await store.readMessages(
      ownerUserId: 'user-a',
      currentAccountId: 'account-a',
      conversationId: ChatSdk.directConversationId('user-a', 'user-b'),
    );
    // 真实 Isar 查询证明 ACK 时已经落库，不以字符串合同替代。
    expect(
      stored.map((message) => message.messageId).toSet().containsAll(ids),
      isTrue,
    );
    expect(ids.length, lessThanOrEqualTo(100));
    acknowledged.add(List.of(ids));
    messages.removeWhere((message) => ids.contains(message.messageId));
  }

  @override
  Future<Future<void> Function()> connectRealtime({
    required Future<void> Function(ChatServiceEvent event) onEvent,
    Future<void> Function()? onDisconnected,
  }) async {
    this.onEvent = onEvent;
    return () async {
      this.onEvent = null;
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected transport operation');
}

final class _Fixture {
  _Fixture(this.root, this.host, this.crypto, this.store);
  final Directory root;
  final _Host host;
  final _Crypto crypto;
  final ChatStore store;
  late _Transport transport;
  late final ChatRuntimeCore runtime = ChatRuntimeCore(
    host: host,
    store: store,
    documentsDirectoryProvider: () async => root,
    stateStoreFactory: (user) async => MlsStateStore(
      root,
      ownerUserId: user,
      debugCallJson: (input) => {
        'user_id': user,
        'device_id': _device,
        'public_key': '0x$_device',
      },
    ),
    cryptoFactory: (_, _) => crypto,
    transportFactory: ({required identity, required accessProvider}) =>
        transport = _Transport(accessProvider, store),
  );
  static Future<_Fixture> create() async {
    final temporary = await Directory.systemTemp.createTemp(
      'chat-runtime-sync-',
    );
    final fixture = _Fixture(
      Directory(await temporary.resolveSymbolicLinks()),
      _Host(),
      _Crypto(),
      ChatStore(),
    );
    addTearDown(() async {
      await fixture.runtime.close();
      await fixture.root.delete(recursive: true);
    });
    return fixture;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedChatIsar();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('停止最后实时订阅后，旧补拉不落库不ACK；重连重发同一KeyPackage', () async {
    final fixture = await _Fixture.create();
    final stop = await fixture.runtime.startRealtimeSync(
      onNotice: () async {},
      retryOutgoingOnConnect: false,
    );
    expect(stop, isNotNull);
    final original = fixture.transport.published.first.keyPackageRef;
    fixture.transport.fetch = Completer<List<ChatMailboxMessage>>();
    fixture.transport.enteredFetch = Completer<void>();
    final event = fixture.transport.onEvent!(
      const ChatMessageAvailableEvent(
        messageId: 'message-1',
        conversationId: 'conversation',
        serverTimeMillis: 1,
      ),
    );
    await fixture.transport.enteredFetch!.future;
    final stopping = stop!();
    fixture.transport.fetch!.complete([_Message(1)]);
    await event;
    await stopping;
    expect(fixture.crypto.processed, 0);
    expect(fixture.transport.acknowledged, isEmpty);
    fixture.transport.fetch = null;
    fixture.transport.enteredFetch = null;
    final stopAgain = await fixture.runtime.startRealtimeSync(
      onNotice: () async {},
      retryOutgoingOnConnect: false,
    );
    expect(
      fixture.transport.published.map((key) => key.keyPackageRef),
      everyElement(original),
    );
    expect(fixture.transport.published.length, greaterThanOrEqualTo(2));
    await stopAgain!();
  });

  test('超过100条及字节裁剪短批持续补拉，ACK 前真实落库', () async {
    final fixture = await _Fixture.create();
    await fixture.runtime.ensureReady('account-a');
    fixture.transport.messages.addAll(List.generate(205, (i) => _Message(i)));
    fixture.transport.pageSize = 37; // 模拟控制帧预算裁剪，不得按少于100提前退出。
    await fixture.runtime.handleWake();
    expect(fixture.transport.messages, isEmpty);
    expect(fixture.transport.acknowledged.expand((ids) => ids), hasLength(205));
    expect(fixture.transport.fetches, 7);
    expect(fixture.crypto.processed, 205);
  });

  test('并发 wake 共用一次补拉链，毒化密文无进展后停止', () async {
    final fixture = await _Fixture.create();
    await fixture.runtime.ensureReady('account-a');
    fixture.transport.messages.add(_Message(1, poison: true));
    await Future.wait([
      fixture.runtime.handleWake(),
      fixture.runtime.handleWake(),
      fixture.runtime.handleWake(),
    ]);
    expect(fixture.transport.maximumActive, 1);
    expect(fixture.transport.fetches, 1);
    expect(fixture.transport.acknowledged, isEmpty);
    expect(
      fixture.transport.lastRealtimeDiagnosticCode,
      'chat_mailbox_no_progress',
    );
    await fixture.runtime.close(); // 取消有界补拉 Timer，停止后不再访问邮箱。
  });

  for (final terminal in ['binding', 'clear', 'close']) {
    test('补拉等待期间$terminal发生，晚到密文不落库不ACK', () async {
      final fixture = await _Fixture.create();
      await fixture.runtime.ensureReady('account-a');
      fixture.transport.fetch = Completer<List<ChatMailboxMessage>>();
      fixture.transport.enteredFetch = Completer<void>();
      final rejected = expectLater(
        fixture.runtime.handleWake(),
        throwsStateError,
      );
      await fixture.transport.enteredFetch!.future;
      Future<void>? closing;
      if (terminal == 'binding') {
        fixture.host.account = const ChatRuntimeAccount(
          hostIndex: 0,
          bindingScope: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          userId: 'user-a',
          bindingRevision: 2,
          accountId: 'account-a',
          displayName: 'A',
        );
      } else if (terminal == 'clear') {
        await fixture.runtime.clearAllForUserId(
          userId: 'user-a',
          accountId: 'account-a',
        );
      } else {
        closing = fixture.runtime.close();
      }
      fixture.transport.fetch!.complete([_Message(1)]);
      await rejected;
      if (closing != null) await closing;
      expect(fixture.transport.acknowledged, isEmpty);
      expect(fixture.crypto.processed, 0);
    });
  }

  test('许可请求返回前换绑，不能交付旧许可，失败 transport 被回收', () async {
    final fixture = await _Fixture.create();
    fixture.host.access = Completer<ChatAccess>();
    final rejected = expectLater(
      fixture.runtime.ensureReady('account-a'),
      throwsStateError,
    );
    await fixture.host.enteredAccess.future;
    fixture.host.account = const ChatRuntimeAccount(
      hostIndex: 0,
      bindingScope:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      userId: 'user-a',
      bindingRevision: 2,
      accountId: 'account-a',
      displayName: 'A',
    );
    fixture.host.access!.complete(
      ChatAccess(
        realtimeUrl: Uri.parse('wss://chat.example.test/api/tatachat/realtime'),
        accessToken: 'synthetic-token',
        expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
      ),
    );
    await rejected;
    expect(fixture.transport.closes, 1);
    expect(fixture.transport.published, isEmpty);
  });
}
