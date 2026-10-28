import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatachat_sdk/mls/mls_attachment.dart';
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

final class _Host implements ChatRuntimeHost, ChatAttachmentAuthorizationHost {
  ChatRuntimeAccount account = _account;
  ChatMediaLimitPolicy limits = const ChatUnlimitedMediaLimitPolicy();
  final checks = <({bool refresh, String? device})>[];
  Future<bool> Function()? authorizeAttachment;
  @override
  Future<bool> prepareAttachment(
    ChatRuntimeAccount account, {
    required bool allowRefresh,
    String? expectedDeviceId,
  }) async {
    checks.add((refresh: allowRefresh, device: expectedDeviceId));
    return await authorizeAttachment?.call() ?? true;
  }

  Completer<ChatAccess>? access;
  final enteredAccess = Completer<void>();
  @override
  ChatPushBridge get push => _Push();
  @override
  ChatMediaLimitPolicy get mediaLimits => limits;
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
  Completer<void>? emptyMailbox;
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
      final result = fetch == null
          ? messages.take(pageSize).toList()
          : await fetch!.future;
      if (result.isEmpty &&
          emptyMailbox != null &&
          !emptyMailbox!.isCompleted) {
        emptyMailbox!.complete();
      }
      return result;
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

  int uploads = 0, downloads = 0, resolutions = 0;
  List<MlsKeyPackage> remotePackages = [];
  Future<void> Function()? onUpload, onDownload;
  @override
  Future<void> uploadEncryptedAttachment({
    required String attachmentId,
    required List<String> recipientUserIds,
    required File cipherFile,
    required int cipherByteSize,
    required String cipherSha256,
    required int createdAtMillis,
  }) async {
    uploads++;
    await onUpload?.call();
    throw StateError('synthetic paused upload');
  }

  @override
  Future<void> downloadEncryptedAttachment({
    required String attachmentId,
    required File target,
    required int expectedByteSize,
    required String expectedSha256,
  }) async {
    downloads++;
    await onDownload?.call();
    throw StateError('synthetic paused download');
  }

  @override
  Future<List<MlsKeyPackage>> resolveKeyPackages(String userId) async {
    resolutions++;
    return userId == 'user-a' ? published : remotePackages;
  }

  @override
  Future<ChatDeliveryResult> sendEncryptedMessage({
    required String messageId,
    required List<int> messageBytes,
    required String recipientUserId,
    required String recipientDeviceId,
  }) async => ChatDeliveryResult(
    messageId: messageId,
    transportType: ChatTransportType.server,
    state: ChatMessageDeliveryState.sent,
  );

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
  int transportCreates = 0;
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
    transportFactory: ({required identity, required accessProvider}) {
      transportCreates++;
      return transport = _Transport(accessProvider, store);
    },
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

// 仅延迟真实Rust MLS已生成的附件帧；不替代任何密码学、受众或存储检查。
class _SlowNative extends NativeMlsCrypto {
  _SlowNative({required super.identity, required super.stateStore});
  Completer<void>? release;
  final encrypted = Completer<void>();
  String? attachmentGroup;
  @override
  Future<MlsWireMessage> groupCreateMessage(
    String groupId,
    List<int> plaintext,
  ) async {
    final result = await super.groupCreateMessage(groupId, plaintext);
    if (groupId.startsWith('attachment:') && release != null) {
      attachmentGroup = groupId;
      if (!encrypted.isCompleted) encrypted.complete();
      await release!.future;
    }
    return result;
  }
}

const _conversation = 'dm:user-a:user-b';
ChatContent _media() => ChatContent.media(
  kind: ChatMessageKind.file,
  attachmentId: 'attachment-a',
  fileName: 'source.bin',
  mime: 'application/octet-stream',
  byteSize: 1,
  attachmentChatEpoch: 1,
  attachmentGroupId: MlsAttachment.groupId('user-a:$_device', 'attachment-a'),
  attachmentWelcome: 'AQ',
  attachmentMemberIdentities: ['user-a:$_device', 'user-b:${'b' * 64}'],
  senderIdentity: 'user-a:$_device',
  attachmentChunkCount: 1,
  plainSha256: 'a' * 64,
  cipherByteSize: 2,
  cipherSha256: 'b' * 64,
);
ChatBinding get _binding => ChatBinding(
  userId: _account.userId,
  accountId: _account.accountId,
  bindingRevision: _account.bindingRevision,
  bindingScope: _account.bindingScope,
);
Future<ChatBindingFenceToken> _seedMedia(
  _Fixture fixture, {
  bool group = false,
  bool text = false,
}) async {
  await fixture.runtime.ensureReady(_account.accountId);
  final token = await fixture.store.captureBindingFenceToken(_binding),
      conversation = group ? 'grp:test' : _conversation;
  await fixture.store.savePendingOutgoingMessage(
    bindingToken: token,
    ownerUserId: _account.userId,
    currentAccountId: _account.accountId,
    localMessageId: 'pending:attachment-a',
    conversationId: conversation,
    recipientUserId: group ? conversation : 'user-b',
    messageKind: ChatMessageKind.file,
    payload: ChatPayloadCodec.encode(_media()),
    createdAtMillis: DateTime.now().millisecondsSinceEpoch,
  );
  if (text) {
    await fixture.store.savePendingOutgoingMessage(
      bindingToken: token,
      ownerUserId: _account.userId,
      currentAccountId: _account.accountId,
      localMessageId: 'pending:text',
      conversationId: _conversation,
      recipientUserId: 'user-b',
      messageKind: ChatMessageKind.text,
      payload: ChatPayloadCodec.encode(ChatContent.text('ordinary text')),
      createdAtMillis: DateTime.now().millisecondsSinceEpoch + 1,
    );
  }
  return token;
}

class _ZeroLimit implements ChatMediaLimitPolicy {
  const _ZeroLimit();
  @override
  int limitForKind(ChatMessageKind kind) => 0;
  @override
  int limitForMime(String type) => 0;
  @override
  bool exceedsForKind(ChatMessageKind kind, int bytes) => bytes > 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedChatIsar();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final group in [false, true]) {
    test('运行时${group ? '群聊' : '单聊'}发送先等待授权，拒绝不处理/落盘/上传', () async {
      final f = await _Fixture.create(), gate = Completer<bool>();
      f.host.authorizeAttachment = () => gate.future;
      const draft = ChatMediaDraft(
        kind: ChatMessageKind.file,
        fileName: 'source.bin',
        contentType: 'application/octet-stream',
        sourcePath: '/not-read',
        byteSize: 1,
      );
      final pending = group
          ? f.runtime.sendGroupAttachment(groupId: 'grp:test', media: draft)
          : f.runtime.sendMedia(
              peerUserId: 'user-b',
              conversationId: _conversation,
              media: draft,
            );
      final denied = expectLater(pending, throwsA(isA<StateError>()));
      await Future<void>.delayed(Duration.zero);
      expect(f.host.checks.map((c) => c.refresh), [true]);
      expect(f.transportCreates, 0);
      gate.complete(false);
      await denied;
      expect(f.transportCreates, 0);
    });
    test('运行时${group ? '群聊' : '单聊'}授权返回后仍执行原大小限制', () async {
      final f = await _Fixture.create();
      f.host.authorizeAttachment = () async {
        f.host.limits = const _ZeroLimit();
        return true;
      };
      const draft = ChatMediaDraft(
        kind: ChatMessageKind.file,
        fileName: 'source.bin',
        contentType: 'application/octet-stream',
        sourcePath: '/not-read',
        byteSize: 1,
      );
      await expectLater(
        group
            ? f.runtime.sendGroupAttachment(groupId: 'grp:test', media: draft)
            : f.runtime.sendMedia(
                peerUserId: 'user-b',
                conversationId: _conversation,
                media: draft,
              ),
        throwsA(isA<ChatMediaTooLargeException>()),
      );
      expect(f.transportCreates, 0);
    });
    test('自动${group ? '群聊' : '单聊'}附件无有效缓存保持队列，禁止主动刷新及上传', () async {
      final f = await _Fixture.create(),
          token = await _seedMedia(f, group: group, text: !group);
      f.host.authorizeAttachment = () async => false;
      await f.runtime.retryOutgoing();
      expect(f.transport.uploads, 0);
      expect(f.host.checks, isNotEmpty);
      expect(
        f.host.checks.every((c) => !c.refresh && c.device == _device),
        isTrue,
      );
      final pending = await f.store.readPendingOutgoingMessages(
        bindingToken: token,
        ownerUserId: _account.userId,
        currentAccountId: _account.accountId,
      );
      expect(
        pending.any((p) => p.localMessageId == 'pending:attachment-a'),
        isTrue,
      );
      if (!group) {
        expect(
          f.transport.resolutions,
          greaterThan(0),
          reason: '未知附件不阻止后续普通文字走原流程',
        );
      }
    });
  }
  test('授权等待期间账户revision变化，旧结果不继续加密', () async {
    final f = await _Fixture.create(), gate = Completer<bool>();
    f.host.authorizeAttachment = () => gate.future;
    final pending = f.runtime.sendMedia(
      peerUserId: 'user-b',
      conversationId: _conversation,
      media: const ChatMediaDraft(
        kind: ChatMessageKind.file,
        fileName: 'x',
        contentType: 'application/octet-stream',
        sourcePath: '/not-read',
        byteSize: 1,
      ),
    );
    final rejected = expectLater(pending, throwsA(isA<StateError>()));
    await Future<void>.delayed(Duration.zero);
    f.host.account = const ChatRuntimeAccount(
      hostIndex: 0,
      bindingScope: 'changed',
      userId: 'user-a',
      bindingRevision: 2,
      accountId: 'account-a',
      displayName: 'A',
    );
    gate.complete(true);
    await rejected;
    expect(f.transportCreates, 0);
  });
  test('主动下载等待授权且核对设备，拒绝时无对象读取', () async {
    final f = await _Fixture.create();
    f.host.authorizeAttachment = () async => false;
    await expectLater(
      f.runtime.downloadAttachment(
        conversationId: _conversation,
        controlPlaintext: ChatPayloadCodec.encode(_media()),
      ),
      throwsA(isA<StateError>()),
    );
    expect(f.host.checks.single.refresh, isTrue);
    expect(f.host.checks.single.device, _device);
    expect(f.transport.downloads, 0);
  });
  test('页面自动补取缺缓存不刷新不下载', () async {
    final f = await _Fixture.create();
    f.host.authorizeAttachment = () async => false;
    await f.runtime.resolveCachedMediaPaths(
      conversationId: _conversation,
      contents: [_media()],
    );
    await f.runtime.close();
    expect(f.host.checks, isNotEmpty);
    expect(f.host.checks.every((c) => !c.refresh), isTrue);
    expect(f.transport.downloads, 0);
  });
  test('自动补取有缓存才下载，失效后停止原重试且不刷新', () async {
    final f = await _Fixture.create();
    var allowed = true;
    f.host.authorizeAttachment = () async => allowed;
    await f.runtime.ensureReady(_account.accountId);
    final entered = Completer<void>();
    f.transport.onDownload = () async {
      allowed = false;
      if (!entered.isCompleted) entered.complete();
    };
    await f.runtime.resolveCachedMediaPaths(
      conversationId: _conversation,
      contents: [_media()],
    );
    await entered.future.timeout(const Duration(seconds: 5));
    await f.runtime.close();
    expect(f.transport.downloads, 1);
    expect(f.host.checks.every((c) => !c.refresh), isTrue);
  });
  test('普通文字持久入口不调用附件授权', () async {
    final f = await _Fixture.create();
    f.host.authorizeAttachment = () async => throw StateError('must not ask');
    await f.runtime.sendText(
      peerUserId: 'user-b',
      conversationId: _conversation,
      text: 'ordinary',
    );
    expect(f.host.checks, isEmpty);
  });
  test('真实MLS长处理后再次授权，拒绝不落待发记录且清理未提交密文', () async {
    final temp = await Directory.systemTemp.createTemp('runtime-auth-real-'),
        root = Directory(await temp.resolveSymbolicLinks());
    final host = _Host(), store = ChatStore();
    late _Transport transport;
    late _SlowNative slow;
    final peerStore = MlsStateStore(
      await Directory('${root.path}/peer').create(),
      ownerUserId: 'user-b',
    );
    final peerIdentity = await peerStore.prepareIdentity();
    final peerPackage = await NativeMlsCrypto(
      identity: peerIdentity,
      stateStore: peerStore,
    ).createKeyPackage(peerIdentity, lastResort: true);
    final selfStore = MlsStateStore(
      await Directory('${root.path}/self').create(),
      ownerUserId: 'user-a',
    );
    final selfIdentity = await selfStore.prepareIdentity();
    final runtime = ChatRuntimeCore(
      host: host,
      store: store,
      documentsDirectoryProvider: () async => root,
      stateStoreFactory: (_) async => selfStore,
      cryptoFactory: (identity, state) =>
          slow = _SlowNative(identity: identity, stateStore: state),
      transportFactory: ({required identity, required accessProvider}) =>
          transport = _Transport(accessProvider, store)
            ..remotePackages = [peerPackage],
    );
    addTearDown(() async {
      await runtime.close();
      await root.delete(recursive: true);
    });
    await runtime.ensureReady(_account.accountId);
    slow.release = Completer<void>();
    final file = await File('${root.path}/source.bin').writeAsBytes([1, 2, 3]);
    host.authorizeAttachment = () async => host.checks.length == 1;
    final rejected = expectLater(
      runtime.sendMedia(
        peerUserId: 'user-b',
        conversationId: _conversation,
        media: ChatMediaDraft(
          kind: ChatMessageKind.file,
          fileName: 'source.bin',
          contentType: 'application/octet-stream',
          sourcePath: file.path,
          byteSize: 3,
        ),
      ),
      throwsA(isA<StateError>()),
    );
    await slow.encrypted.future.timeout(const Duration(seconds: 10));
    expect(host.checks.length, 1);
    final attachmentId = slow.attachmentGroup!.substring(
      'attachment:user-a:${selfIdentity.deviceId}:'.length,
    );
    expect(RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(attachmentId), isTrue);
    slow.release!.complete();
    await rejected;
    expect(host.checks.map((c) => c.refresh), [true, true]);
    expect(transport.uploads, 0);
    final token = await store.captureBindingFenceToken(_binding);
    expect(
      await store.readPendingOutgoingMessages(
        bindingToken: token,
        ownerUserId: 'user-a',
        currentAccountId: 'account-a',
      ),
      isEmpty,
    );
    expect(
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.cipher')),
      isEmpty,
    );
  });
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
    fixture.transport.emptyMailbox = Completer<void>();
    await fixture.runtime.handleWake();
    // 真实落库在并发测试中可能达到15秒批次预算；等待自动续拉实际读到空批。
    await fixture.transport.emptyMailbox!.future.timeout(
      const Duration(seconds: 30),
    );
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
          bindingScope:
              '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
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
