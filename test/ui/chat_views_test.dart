import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  // 基准、宽屏视觉倍率和系统大字都须完整显示文案并保留真实菜单动作。
  for (final scenario in [
    (name: '基准', width: 411.0, scale: 1.0, textScale: 1.0),
    (name: '宽屏', width: 480.0, scale: 1.1, textScale: 1.0),
    (name: '大字', width: 300.0, scale: 1.0, textScale: 2.0),
  ]) {
    testWidgets('聊天菜单不溢出并保留动作：${scenario.name}', (tester) async {
      tester.view.physicalSize = Size(scenario.width, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const labels = ['扫一扫', '收付款', '发私信', '发群聊', '加好友'];
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scenario.textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: ChatSectionHeader<int>(
              style: ChatViewStyle(
                scaler: (_, value) => value * scenario.scale,
              ),
              onAction: (value) => selected = value,
              actions: [
                for (var i = 0; i < labels.length; i++)
                  ChatHeaderAction(
                    value: i,
                    label: labels[i],
                    icon: const Icon(Icons.chat),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('chat-add-button')));
      await tester.pumpAndSettle();
      for (final label in labels) {
        final text = find.text(label);
        final row = find.ancestor(of: text, matching: find.byType(InkWell));
        expect(row, findsOneWidget);
        final textRect = tester.getRect(text), rowRect = tester.getRect(row);
        expect(textRect.right, lessThanOrEqualTo(rowRect.right - 22 + 0.01));
        expect(textRect.top, greaterThanOrEqualTo(rowRect.top));
        expect(textRect.bottom, lessThanOrEqualTo(rowRect.bottom));
        expect(rowRect.left, greaterThanOrEqualTo(8));
        expect(rowRect.right, lessThanOrEqualTo(scenario.width - 8));
        expect(rowRect.height, greaterThanOrEqualTo(40 * scenario.scale));
        if (scenario.name == '基准') expect(rowRect.height, closeTo(40, 0.01));
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(labels.last));
      await tester.pumpAndSettle();
      expect(selected, 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'conversation controller keeps one optimistic message until send completes',
    (tester) async {
      final sendGate = Completer<void>();
      final controller = ChatConversationController(
        conversationId: 'direct-a-b',
        currentUserId: 'a',
        loadSnapshot: () async =>
            (messages: <ChatStoredMessage>[], integrityFailureCount: 0),
        onSendText: (_) => sendGate.future,
        onSendMedia: null,
        onSendSticker: null,
        onSync: null,
        onStartRealtime: null,
        onDownloadAttachment: null,
        onResolveMediaPaths: null,
        onMarkRead: null,
        isVisible: () => true,
      );
      addTearDown(controller.dispose);
      controller.start();
      await tester.pump();

      final sending = controller.sendText('hello');
      await tester.pump();
      expect(controller.optimisticMessageCount, 1);

      sendGate.complete();
      await sending;
      expect(controller.optimisticMessageCount, 0);
    },
  );

  testWidgets(
    'conversation list controller creates only one realtime subscription',
    (tester) async {
      var starts = 0;
      var stops = 0;
      final runtime = _Runtime(
        onStart: ({required onNotice, onDisconnected}) async {
          starts += 1;
          return () async => stops += 1;
        },
      );
      final controller = ChatConversationListController(
        sdk: runtime,
        onCoordinate: () async {},
        onRefresh: (_) async => true,
      );
      controller.start(visible: true);
      controller.configureScope('account-a');
      controller.configureScope('account-a');
      await tester.pump();
      expect(starts, 1);

      controller.dispose();
      await tester.pump();
      expect(stops, 1);
    },
  );

  test('conversation timestamps use local calendar buckets', () {
    final now = DateTime(2026, 8, 30, 18);
    expect(
      chatConversationTime(DateTime(2026, 8, 30, 9, 5), now: now),
      '09:05',
    );
    expect(chatConversationTime(DateTime(2026, 8, 29, 9), now: now), '昨天');
  });

  test('empty state is hidden during loading and errors', () {
    expect(shouldShowChatEmptyState(loading: false, error: null), isTrue);
    expect(shouldShowChatEmptyState(loading: true, error: null), isFalse);
    expect(
      shouldShowChatEmptyState(loading: false, error: 'integrity error'),
      isFalse,
    );
  });

  testWidgets('conversation overview renders cards and unread badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatConversationOverview(
            header: const SizedBox(height: 20),
            onRefresh: () async {},
            onSearch: () {},
            items: [
              ChatConversationListItem(
                id: 'direct-a-b',
                title: 'Alice',
                subtitle: 'Hello',
                updatedAt: DateTime(2026, 8, 30, 9),
                unreadCount: 2,
                leading: const CircleAvatar(child: Text('A')),
                onTap: () {},
                onDelete: () async {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('chat-conversation-direct-a-b')),
      findsOneWidget,
    );
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('search view renders injected sections', (tester) async {
    final controller = TextEditingController(text: 'hello');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatSearchView(
          controller: controller,
          query: 'hello',
          onQueryChanged: (_) {},
          onClear: () {},
          sections: [
            ChatSearchSection(
              title: '聊天记录',
              items: [
                ChatSearchItem(
                  key: const ValueKey('result-1'),
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: 'hello',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(find.text('聊天记录'), findsOneWidget);
    expect(find.byKey(const ValueKey('result-1')), findsOneWidget);
  });

  testWidgets('group creation reports generic user selection', (tester) async {
    final controller = TextEditingController(text: 'Group');
    addTearDown(controller.dispose);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatGroupCreateView(
          nameController: controller,
          users: const [
            ChatSelectableUser(userId: 'alice', displayName: 'Alice'),
          ],
          selectedUserIds: const <String>{},
          onSelectionChanged: (userId, value) {
            if (value) selected = userId;
          },
          canCreate: false,
          onCreate: () {},
        ),
      ),
    );

    await tester.tap(find.byType(CheckboxListTile));
    expect(selected, 'alice');
  });
}

typedef _RealtimeStart =
    Future<Future<void> Function()?> Function({
      required Future<void> Function() onNotice,
      Future<void> Function()? onDisconnected,
    });

class _Runtime extends ChatSdk {
  _Runtime({required this.onStart}) : super(host: _Host());

  final _RealtimeStart onStart;

  @override
  Future<int> retryOutgoing({
    String? recipientUserId,
    String? conversationId,
  }) async => 0;

  @override
  Future<Future<void> Function()?> startRealtimeSync({
    required Future<void> Function() onNotice,
    Future<void> Function()? onDisconnected,
    Future<void> Function(Map<String, dynamic> signal)? onSignal,
    bool retryOutgoingOnConnect = true,
  }) => onStart(onNotice: onNotice, onDisconnected: onDisconnected);
}

class _Host implements ChatRuntimeHost {

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

