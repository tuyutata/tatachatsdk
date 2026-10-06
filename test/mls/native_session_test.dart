import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import '../support/native_probe.dart';

void main() {
  final skip = chatSdkNativeSkipReason();
  test('MLS发送和接收在宿主落库前中断，重建后仍恢复相同结果', () async {
    final root = await Directory.systemTemp.createTemp(
      'tatachat_native_session_',
    );
    addTearDown(() => root.delete(recursive: true));
    Future<MlsStateStore> fixture(String user) async {
      final directory = await Directory('${root.path}/$user').create();
      final store = MlsStateStore(
        Directory(await directory.resolveSymbolicLinks()),
        ownerUserId: user,
      );
      await store.initializeIdentity();
      return store;
    }

    final aStore = await fixture('alice'), bStore = await fixture('bob');
    final aId = await aStore.readIdentity(), bId = await bStore.readIdentity();
    final a = NativeMlsCrypto(identity: aId, stateStore: aStore),
        b = NativeMlsCrypto(identity: bId, stateStore: bStore);
    final package = await b.createKeyPackage(bId, lastResort: true);
    await a.withMessage('create', () => a.createGroup('group'));
    final added = await a.withMessage(
      'add',
      () => a.addMembers('group', [package]),
    );
    await b.withMessage('welcome', () => b.groupProcess(added.welcome!));
    // 群已建立后签认证证明，快照逐字不变；随后继续真实MLS发送和重启恢复。
    final snapshot = File('${aStore.path}/state.bin');
    final beforeAuthentication = await snapshot.readAsBytes();
    final authentication = await aStore.signAuthentication(
      accountId: '0x${List.filled(32, '11').join()}',
      bindingRevision: 1,
      request: MlsAuthenticationRequest(
        serviceOrigin: 'https://api.example.test',
        challenge: '0x${List.filled(32, '22').join()}',
        expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 120000,
        method: 'POST',
        requestTarget: '/auth/session',
        bodyBytes: utf8.encode('synthetic request'),
      ),
    );
    expect(authentication.deviceId, aId.deviceId);
    expect(await snapshot.readAsBytes(), beforeAuthentication);
    final first = await a.withMessage(
      'message-a',
      () => a.groupCreateMessage('group', utf8.encode('合成消息')),
    );
    final restarted = NativeMlsCrypto(
      identity: await aStore.readIdentity(),
      stateStore: aStore,
    );
    final retry = await restarted.withMessage(
      'message-a',
      () => restarted.groupCreateMessage('group', utf8.encode('合成消息')),
    );
    expect(retry.wireHex, first.wireHex);
    final result = await b.withMessage(
      'message-b',
      () => b.groupProcess(first),
    );
    expect(utf8.decode(result.plaintext!), '合成消息');
    expect(result.senderMemberIdentity, 'alice:' + aId.deviceId);
    final restartedReceiver = NativeMlsCrypto(
      identity: await bStore.readIdentity(),
      stateStore: bStore,
    );
    final recovered = await restartedReceiver.withMessage(
      'message-b',
      () => restartedReceiver.groupProcess(first),
    );
    expect(recovered.plaintext, result.plaintext);
    expect(recovered.senderMemberIdentity, result.senderMemberIdentity);
    await restartedReceiver.acknowledgeMessage('message-b');
    final duplicate = await restartedReceiver.withMessage(
      'message-b',
      () => restartedReceiver.groupProcess(first),
    );
    expect(duplicate.status, GroupProcessStatus.stale);
    expect(duplicate.committed, isTrue);
    expect(duplicate.plaintext, isNull);
    await expectLater(a.groupCreateMessage('group', [1]), throwsStateError);
    await expectLater(
      restarted.withMessage(
        'message-a',
        () => restarted.groupCreateMessage('group', [2]),
      ),
      throwsA(isA<MlsNativeException>()),
    );
  }, skip: skip);
}
