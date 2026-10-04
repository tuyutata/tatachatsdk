import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/ui.dart';

void main() {
  test('应用内录像唯一上限为三分钟', () {
    expect(CameraCapturePage.maximumVideoDuration, const Duration(minutes: 3));
  });

  testWidgets('拍摄页明确展示点按拍照和长按录像手势', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CameraCapturePage()));
    await tester.pump();
    expect(find.text('点按拍照，长按录像'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-camera-shutter')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
