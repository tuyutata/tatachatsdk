import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/ui.dart';

void main() {
  testWidgets('direct chat exposes seven actions', (tester) async {
    final actions = <ChatComposerAction>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComposerActionPanel(isGroup: false, onAction: actions.add),
        ),
      ),
    );
    expect(find.byType(InkWell), findsNWidgets(7));
    await tester.tap(find.byKey(const ValueKey('chat-action-gallery')));
    expect(actions, [ChatComposerAction.gallery]);
  });

  testWidgets('group chat hides transfer and disables calls', (tester) async {
    final actions = <ChatComposerAction>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComposerActionPanel(isGroup: true, onAction: actions.add),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('chat-action-transfer')), findsNothing);
    final callButton = tester.widget<InkWell>(
      find.byKey(const ValueKey('chat-action-videoCall')),
    );
    expect(callButton.onTap, isNull);
    expect(actions, isEmpty);
  });
}
