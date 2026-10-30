import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_core/chat_content.dart';
import 'package:tatachat_core/chat_message.dart';
import 'package:tatachat_mls/mls_attachment.dart';
import 'package:tatachat_mls/mls_boundary.dart';
import 'package:tatachat_mls/mls_native.dart';
import 'package:tatachat_mls/mls_state_store.dart';

bool _probed = false;

/// 真实MLS回归必须加载本轮独立宿主库；缺件使套件失败，不允许跳过。
void requireChatSdkNative() {
  if (_probed) return;
  NativeMlsCrypto();
  _probed = true;
}

MlsAuthenticationRequest createAuthenticationRequest({
  String origin = 'https://api.example.test',
  String target = '/auth/session',
  String method = 'POST',
  String? challenge,
  int? expiry,
  List<int> body = const [1, 2, 3],
}) => MlsAuthenticationRequest(
  serviceOrigin: origin,
  nonceId: challenge ?? '0x${List.filled(32, '22').join()}',
  expiresAt: expiry ?? DateTime.now().millisecondsSinceEpoch + 120000,
  httpMethod: method,
  requestTarget: target,
  bodyBytes: body,
);





class TestMlsDevice {
  TestMlsDevice(this.store, this.identity, this.root);
  final MlsStateStore store;
  final ChatDevice identity;
  final Directory root;
  NativeMlsCrypto get crypto =>
      NativeMlsCrypto(identity: identity, stateStore: store);
  MlsAttachment attachment({
    MlsStateStore? state,
    Future<void> Function()? current,
  }) => MlsAttachment(
    crypto: NativeMlsCrypto(identity: identity, stateStore: state ?? store),
    store: state ?? store,
    identity: identity,
    protectedRoot: root,
    mutate: <T>(operation) => operation(),
    requireCurrent: current ?? () async {},
  );
}

Future<TestMlsDevice> createTestMlsDevice(
  Directory parent,
  String name, {
  String cid = 'CID-A',
}) async {
  final root = await Directory('${parent.path}/$name').create();
  final store = MlsStateStore(root, ownerUserId: cid);
  return TestMlsDevice(store, await store.prepareIdentity(), root);
}

ChatContent createTestMediaContent(
  MlsAttachmentDescriptor d,
  int bytes, {
  String id = 'file-1',
}) => ChatContent.media(
  kind: ChatMessageKind.file,
  attachmentId: id,
  fileName: 'source.bin',
  mime: 'application/octet-stream',
  byteSize: bytes,
  attachmentChatEpoch: 1,
  attachmentGroupId: d.groupId,
  attachmentWelcome: base64UrlEncode(d.welcome).replaceAll('=', ''),
  attachmentMemberIdentities: d.members,
  senderIdentity: d.sender,
  attachmentChunkCount: d.chunkCount,
  plainSha256: d.plainSha256,
  cipherByteSize: d.cipherByteSize,
  cipherSha256: d.cipherSha256,
);

ChatContent copyTestMediaContent(
  ChatContent c, {
  String? cipherSha256,
  int? cipherByteSize,
  List<String>? members,
}) => ChatContent.media(
  kind: c.kind,
  attachmentId: c.attachmentId!,
  fileName: c.fileName!,
  mime: c.mime!,
  byteSize: c.byteSize!,
  attachmentChatEpoch: c.attachmentChatEpoch!,
  attachmentGroupId: c.attachmentGroupId!,
  attachmentWelcome: c.attachmentWelcome!,
  attachmentMemberIdentities: members ?? c.attachmentMemberIdentities!,
  senderIdentity: c.senderIdentity!,
  attachmentChunkCount: c.attachmentChunkCount!,
  plainSha256: c.plainSha256!,
  cipherByteSize: cipherByteSize ?? c.cipherByteSize!,
  cipherSha256: cipherSha256 ?? c.cipherSha256!,
);



  Future<Directory> createMlsTestDirectory() async {
    final temp = await Directory.systemTemp.createTemp('mls_attachment_');
    final dir = Directory(await temp.resolveSymbolicLinks());
    addTearDown(() => dir.delete(recursive: true));
    return dir;
  }



class TestContactRelay {
  final group = '11' * 16;
  final eligible = <String>{};
  final packages = <String, String>{};
  final queues = <String, List<Map<String, dynamic>>>{};
  final receipts = <String, Map<String, Object?>>{};
  List<String> members = [];
  Map<String, dynamic>? pending;
  String? creator;
  int revision = 0;
  int serial = 0;
  bool loseCommitReply = false;
  String? rejectNextAckFor;
  bool busy = false;
  Future<Map<String, dynamic>> call(
    String device,
    Map<String, Object?> request,
  ) async {
    switch (request['action']) {
      case 'publish':
        creator ??= device;
        eligible.add(device);
        packages[device] = request['key_package'] as String;
        return {'ok': true};
      case 'state':
        return {
          'ok': true,
          'group_id': group,
          'group_revision': revision,
          'creator_device_id': creator,
          'member_device_ids': members.toList(),
          'eligible_device_ids': eligible.toList(),
          'key_packages': packages.entries
              .where((entry) => eligible.contains(entry.key))
              .map(
                (entry) => {'device_id': entry.key, 'key_package': entry.value},
              )
              .toList(),
          'messages': List<Map<String, dynamic>>.from(queues[device] ?? []),
          'pending': pending?['device'] == device ? pending : null,
          'busy': busy || (pending != null && pending?['device'] != device),
        };
      case 'reserve':
        if (pending != null && pending!['device'] != device) {
          throw StateError('busy');
        }
        pending ??= {
          'operation_id': (++serial).toRadixString(16).padLeft(32, '0'),
          'operation_kind': request['operation_kind'],
          'group_revision': revision,
          'target_device_ids': request['target_device_ids'],
          'device': device,
        };
        return {'ok': true, ...pending!};
      case 'commit':
        final operation = request['operation_id'] as String;
        if (!receipts.containsKey(operation)) {
          if (pending?['operation_id'] != operation) {
            throw StateError('conflict');
          }
          receipts[operation] = Map<String, Object?>.from(request);
          revision++;
          members = (request['member_device_ids'] as List).cast<String>();
          var index = 0;
          for (final value in request['messages'] as List) {
            final message = (value as Map).cast<String, dynamic>();
            for (final recipient
                in (message['device_ids'] as List).cast<String>()) {
              (queues[recipient] ??= []).add({
                'operation_id': operation,
                'message_type': message['message_type'],
                'mls_message': message['mls_message'],
                'sender_device_id': device,
                'sequence': revision * 2 + index,
              });
            }
            index++;
          }
          pending = null;
        }
        if (loseCommitReply) {
          loseCommitReply = false;
          throw StateError('synthetic lost reply');
        }
        return {'ok': true, 'group_revision': revision};
      case 'ack':
        if (rejectNextAckFor == device &&
            request['message_type'] == 'application') {
          rejectNextAckFor = null;
          throw StateError('synthetic ack not delivered');
        }
        queues[device]?.removeWhere(
          (message) =>
              message['operation_id'] == request['operation_id'] &&
              message['message_type'] == request['message_type'],
        );
        return {'ok': true};
    }
    throw StateError('unexpected action');
  }
}

