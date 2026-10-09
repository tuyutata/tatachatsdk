import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

void main() {
  test('公开入口接收完整 WSS 地址并派生同源 HTTPS 分块', () {
    final access = ChatAccess(
      realtimeUrl: Uri.parse('wss://chat.example.com/api/tatachat/realtime'),
      accessToken: 'test-token',
      expiresAtMillis: 200000,
    );
    access.validate(1000);
    expect(
      access.realtimeUrl.toString(),
      'wss://chat.example.com/api/tatachat/realtime',
    );
  });

  test('启动调用运行时且并发只建立一次同步，停止关闭全部登记资源', () async {
    final chat = _Runtime();
    var notices = 0;
    await Future.wait<void>([
      chat.start(
        onNotice: () async {
          notices++;
        },
      ),
      chat.start(),
      chat.start(),
    ]);
    expect(chat.starts, 1);
    expect(notices, 1);
    expect(chat.isRunning, isTrue);
    await Future.wait<void>([chat.stop(), chat.close(), chat.stop()]);
    expect(chat.closedResources, 3);
    expect(chat.isRunning, isFalse);
    await expectLater(chat.start(), throwsStateError);
  });

  test('启动失败不标记运行且允许在同一未停止实例重试', () async {
    final chat = _Runtime()..failStart = true;
    await expectLater(chat.start(), throwsStateError);
    expect(chat.isRunning, isFalse);
    chat.failStart = false;
    await chat.start();
    expect(chat.starts, 2);
    await chat.stop();
  });

  test('关闭失败可以重试，已成功关闭的资源不重复关闭', () async {
    final chat = _Runtime();
    var attempts = 0;
    chat.debugRegisterContextDisposerForTest(() async {
      attempts++;
      if (attempts == 1) throw StateError('test close failure');
    });
    await chat.start();
    await expectLater(chat.stop(), throwsStateError);
    expect(chat.isRunning, isFalse);
    await chat.stop();
    expect(attempts, 2);
    expect(chat.closedResources, 3);
  });

  test('读取宿主账户期间停止，不允许迟到的账户重建实时运行态', () async {
    final account = Completer<ChatRuntimeAccount?>();
    final host = _Host(account: account);
    final chat = ChatSdk(host: host);
    final starting = expectLater(chat.start(), throwsStateError);
    var finished = false;
    final stopping = chat.stop().then((_) {
      finished = true;
    });
    await Future<void>.value();
    expect(finished, isFalse);
    account.complete(
      const ChatRuntimeAccount(
        hostIndex: 0,
        bindingScope: 'example',
        userId: 'user',
        bindingRevision: 1,
        accountId: 'account',
        displayName: 'User',
      ),
    );
    await starting;
    await stopping;
    expect(host.reads, 1);
    expect(chat.isRunning, isFalse);
  });

  test('停止实例不删除已有聊天文件，也不关闭其它实例', () async {
    final directory = await Directory.systemTemp.createTemp('chat-lifecycle-');
    addTearDown(() => directory.delete(recursive: true));
    final history = File('${directory.path}/history');
    await history.writeAsString('local-history');
    final chat = ChatSdk(
      host: _Host(),
      documentsDirectoryProvider: () async => directory,
    );
    final other = _Runtime();
    await other.start();
    await chat.stop();
    expect(await history.readAsString(), 'local-history');
    expect(other.isRunning, isTrue);
    await other.stop();
  });

  test('真实宿主未提供账户时拒绝启动', () async {
    final chat = ChatSdk(host: _Host());
    await expectLater(chat.start(), throwsStateError);
    expect(chat.isRunning, isFalse);
    await chat.stop();
  });
}

class _Runtime extends ChatSdk {
  _Runtime() : super(host: _Host());
  int starts = 0;
  int closedResources = 0;
  bool failStart = false;

  @override
  Future<Future<void> Function()?> startRealtimeSync({
    required Future<void> Function() onNotice,
    Future<void> Function()? onDisconnected,
    bool retryOutgoingOnConnect = true,
  }) async {
    starts++;
    if (failStart) throw StateError('test start failure');
    final stop = debugRegisterRealtimeSessionForTest(
      stopSocket: () async {
        closedResources++;
      },
      cancelWakeSubscription: () async {
        closedResources++;
      },
      cancelTokenSubscription: () async {
        closedResources++;
      },
    );
    await onNotice();
    return stop;
  }
}

class _Host implements ChatRuntimeHost {
  _Host({this.account});
  final Completer<ChatRuntimeAccount?>? account;
  int reads = 0;
  @override
  Future<ChatRuntimeAccount?> currentAccount({
    String? expectedAccountId,
  }) async {
    reads++;
    return account == null ? null : await account!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected host operation');
}
