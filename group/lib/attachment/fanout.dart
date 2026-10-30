import 'package:tatachat_mls/mls_group_boundary.dart';
import 'package:tatachat_mls/mls_session.dart';
import 'package:tatachat_protocol/message.dart';

import '../message/fanout.dart';

/// 群附件保留独立入口，复用群内统一设备扇出；不参与私聊流程。
final class GroupAttachmentFanout {
  GroupAttachmentFanout._();

  static List<EncryptedMessage> fanOut({
    required MlsWireMessage wire,
    required Iterable<MlsMemberIdentity> recipients,
    required String senderUserId,
    required String senderDeviceId,
    required int createdAtMillis,
  }) {
    return GroupMessageFanout.fanOut(
      wire: wire,
      recipients: recipients,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      createdAtMillis: createdAtMillis,
    );
  }
}
