import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/attachment.dart';
import 'package:tatachat_sdk/ui.dart';

void main() {
  test('语音单条唯一上限为三分钟', () {
    expect(VoiceRecorder.defaultMaximumDuration, const Duration(minutes: 3));
  });

  testWidgets('未到达的语音气泡显示下载入口并走既有附件回调', (tester) async {
    var downloads = 0;
    const message =
        Message.audio(
              id: 'audio-1',
              authorId: 'peer',
              source: '',
              duration: Duration(seconds: 12),
            )
            as AudioMessage;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceMessagePlayer(
            message: message,
            isSentByMe: false,
            onRequestDownload: () async => downloads += 1,
          ),
        ),
      ),
    );

    expect(find.text('12″'), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-audio-audio-1')));
    await tester.pump();
    expect(downloads, 1);
  });
}
