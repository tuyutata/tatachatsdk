import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  test('完整会话页只依赖 SDK 与显式宿主边界', () {
    final page = ChatConversationPage(
      sdk: ChatSdk(host: _Host()),
      conversationId: 'conversation',
      currentUserId: 'owner',
      accountId: '0x${'1' * 64}',
      peerUserId: 'peer',
      title: 'Peer',
      host: ChatConversationHost(
        style: const ChatViewStyle(),
        mediaLimits: const ChatUnlimitedMediaLimitPolicy(),
        canSend: (_) => true,
        unavailableMessage: (_) => 'unavailable',
        errorMessage: (error) => error.toString(),
        headerBuilder: (_, header) => throw UnimplementedError(),
        resolveUser: (userId, _, _) async => User(id: userId),
      ),
    );

    expect(page.conversationId, 'conversation');
    expect(page.currentUserId, 'owner');
    expect(page.host.canSend('owner'), isTrue);
  });
  Future<void> page(
    WidgetTester tester,
    _PageSdk sdk, {
    Future<void> Function(String)? prepare,
    Future<ChatMediaDraft?> Function()? pick,
    String account = 'account',
    ChatMediaLimitPolicy limits = const ChatUnlimitedMediaLimitPolicy(),
    Future<Object?> Function(MethodCall)? recorder,
  }) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          recorder ?? (_) async => null,
        );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatConversationPage(
          sdk: sdk,
          conversationId: 'conversation',
          currentUserId: 'owner',
          accountId: account,
          peerUserId: 'peer',
          title: 'Peer',
          pickMedia: pick,
          host: ChatConversationHost(
            style: const ChatViewStyle(),
            mediaLimits: limits,
            canSend: (_) => true,
            unavailableMessage: (_) => 'unavailable',
            errorMessage: (e) => e.toString(),
            headerBuilder: (_, _) => const SizedBox.shrink(),
            resolveUser: (id, _, _) async => User(id: id),
            prepareAttachment: prepare,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> gallery(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('chat-actions-toggle')));
    await tester.pump();
    await tester.tap(find.text('相册'));
    await tester.pump();
  }

  testWidgets('打开页面和文字发送不调用附件准备', (tester) async {
    final sdk = _PageSdk();
    var checks = 0;
    await page(
      tester,
      sdk,
      prepare: (_) async {
        checks++;
      },
    );
    expect(checks, 0);
    tester.widget<ComposerBar>(find.byType(ComposerBar)).onSendText('text');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(sdk.texts, 1);
    expect(checks, 0);
  });
  testWidgets('附件先等待宿主，再选取并发送；发送前再次复核', (tester) async {
    final sdk = _PageSdk(), gate = Completer<void>();
    var checks = 0, picks = 0;
    await page(
      tester,
      sdk,
      prepare: (_) {
        checks++;
        return gate.future;
      },
      pick: () async {
        picks++;
        return draft;
      },
    );
    await gallery(tester);
    expect(checks, 1);
    expect(picks, 0);
    expect(sdk.media, 0);
    gate.complete();
    await tester.pumpAndSettle();
    expect(picks, 1);
    expect(checks, 2);
    expect(sdk.media, 1);
  });
  testWidgets('宿主拒绝时不选取或发送附件', (tester) async {
    final sdk = _PageSdk();
    var picks = 0;
    await page(
      tester,
      sdk,
      prepare: (_) async {
        throw StateError('denied');
      },
      pick: () async {
        picks++;
        return draft;
      },
    );
    await gallery(tester);
    await tester.pumpAndSettle();
    expect(picks, 0);
    expect(sdk.media, 0);
    expect(find.textContaining('denied'), findsOneWidget);
  });
  testWidgets('长时间选取后宿主失效，发送前复核拒绝', (tester) async {
    final sdk = _PageSdk();
    var checks = 0;
    await page(
      tester,
      sdk,
      prepare: (_) async {
        if (++checks == 2) throw StateError('expired');
      },
      pick: () async => draft,
    );
    await gallery(tester);
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(sdk.media, 0);
    expect(find.textContaining('expired'), findsOneWidget);
  });
  testWidgets('附件准备期间页面退出，迟到结果不继续选取', (tester) async {
    final sdk = _PageSdk(), gate = Completer<void>();
    var picks = 0;
    await page(
      tester,
      sdk,
      prepare: (_) => gate.future,
      pick: () async {
        picks++;
        return draft;
      },
    );
    await gallery(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete();
    await tester.pump();
    expect(picks, 0);
    expect(sdk.media, 0);
  });
  testWidgets('准备期间切换账户，旧动作不继续选取', (tester) async {
    final sdk = _PageSdk(), gate = Completer<void>();
    var picks = 0;
    await page(
      tester,
      sdk,
      prepare: (_) => gate.future,
      pick: () async {
        picks++;
        return draft;
      },
    );
    await gallery(tester);
    await page(tester, sdk, account: 'other-account', prepare: (_) async {});
    gate.complete();
    await tester.pumpAndSettle();
    expect(picks, 0);
    expect(sdk.media, 0);
  });
  testWidgets('录音启动先等待宿主，拒绝时不请求麦克风', (tester) async {
    final sdk = _PageSdk(), gate = Completer<void>();
    var permissions = 0;
    await page(
      tester,
      sdk,
      prepare: (_) => gate.future,
      recorder: (call) async {
        if (call.method == 'hasPermission') permissions++;
        return null;
      },
    );
    tester.widget<ComposerBar>(find.byType(ComposerBar)).onVoicePressStart();
    await tester.pump();
    expect(permissions, 0);
    gate.completeError(StateError('voice-denied'));
    await tester.pumpAndSettle();
    expect(permissions, 0);
    expect(sdk.media, 0);
  });
  testWidgets('录音完成后重新授权，过期拒绝且删除临时文件', (tester) async {
    final sdk = _PageSdk();
    var checks = 0;
    String? recorded;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
    await page(
      tester,
      sdk,
      prepare: (_) async {
        if (++checks == 2) throw StateError('voice-expired');
      },
      recorder: (call) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['recorderId'];
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                MethodChannel('com.llfbandit.record/events/$id'),
                (_) async => null,
              );
        }
        if (call.method == 'hasPermission') return true;
        if (call.method == 'start') {
          recorded = (call.arguments as Map)['path'] as String;
          File(recorded!).writeAsBytesSync([1]);
        }
        if (call.method == 'stop') return recorded;
        return null;
      },
    );
    tester.widget<ComposerBar>(find.byType(ComposerBar)).onVoicePressStart();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(recorded, isNotNull);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 900)),
    );
    tester.widget<ComposerBar>(find.byType(ComposerBar)).onVoicePressEnd(false);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(sdk.media, 0);
    // onVoicePressEnd沿UI的void回调异步收尾；排空实际文件I/O后验证删除。
    for (var i = 0; i < 5 && File(recorded!).existsSync(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(File(recorded!).existsSync(), isFalse);
  });
  for (final tooLong in [false, true]) {
    testWidgets('异步准备后保留原${tooLong ? '时长' : '大小'}限制', (tester) async {
      final sdk = _PageSdk();
      await page(
        tester,
        sdk,
        prepare: (_) async {},
        limits: const _SmallLimit(),
        pick: () async => ChatMediaDraft(
          kind: ChatMessageKind.video,
          fileName: 'test.mp4',
          contentType: 'video/mp4',
          sourcePath: '/not-read',
          byteSize: tooLong ? 1 : 11,
          durationMs: tooLong ? 180001 : 1,
        ),
      );
      await gallery(tester);
      await tester.pumpAndSettle();
      expect(sdk.media, 0);
      expect(
        find.text(tooLong ? '语音、视频消息每条最长 3 分钟' : '附件超过当前允许的大小'),
        findsOneWidget,
      );
    });
  }
}

class _Host implements ChatRuntimeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const draft = ChatMediaDraft(
  kind: ChatMessageKind.file,
  fileName: 'test.bin',
  contentType: 'application/octet-stream',
  sourcePath: '/synthetic/not-read',
  byteSize: 1,
);

class _PageStore implements ChatStore {
  @override
  Future<ChatMessageDisplayBatch> readMessagesForDisplay({
    required String ownerUserId,
    required String currentAccountId,
    required String conversationId,
  }) async =>
      const ChatMessageDisplayBatch(messages: [], integrityFailureCount: 0);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// UI测试只模拟存储/运行时端口，不替代App原生库、服务端授权或链验真。
class _PageSdk extends ChatSdk {
  _PageSdk() : super(host: _Host(), store: _PageStore());
  int texts = 0, media = 0;
  @override
  Future<int> retryOutgoing({
    String? recipientUserId,
    String? conversationId,
  }) async => 0;
  @override
  Future<Future<void> Function()?> startRealtimeSync({
    required Future<void> Function() onNotice,
    Future<void> Function()? onDisconnected,
    bool retryOutgoingOnConnect = true,
  }) async => null;
  @override
  Future<Map<String, String>> resolveCachedMediaPaths({
    required String conversationId,
    required List<ChatContent> contents,
  }) async => {};
  @override
  Future<void> markConversationRead({
    required String conversationId,
    required int readThroughMillis,
  }) async {}
  @override
  Future<List<ChatDeliveryResult>> sendText({
    required String peerUserId,
    required String conversationId,
    required String text,
  }) async {
    texts++;
    return [];
  }

  @override
  Future<List<ChatDeliveryResult>> sendMedia({
    required String peerUserId,
    required String conversationId,
    required ChatMediaDraft media,
    ChatMediaLocalCommitNotifier? onLocalCommitted,
  }) async {
    this.media++;
    await onLocalCommitted?.call();
    return [];
  }
}

class _SmallLimit implements ChatMediaLimitPolicy {
  const _SmallLimit();
  @override
  int limitForKind(ChatMessageKind kind) => 10;
  @override
  int limitForMime(String mime) => 10;
  @override
  bool exceedsForKind(ChatMessageKind kind, int byteSize) => byteSize > 10;
}
