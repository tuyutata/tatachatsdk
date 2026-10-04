// 私密小群(MLS 群)的 Dart 侧边界模型与接口。
//
// 只定义可测的数据边界与注入点;真正的 OpenMLS 群加解密由 Rust native
// (native/src/mls.rs 的 6 个 group FFI)实现,这里禁止自研密码学。
// 行为由本边界测试和 Rust FFI 接口共同固定。

import 'mls_boundary.dart';

/// MLS BasicCredential 中的标准 TataChatSDK 设备身份。
class MlsMemberIdentity {
  const MlsMemberIdentity({required this.userId, required this.deviceId});

  final String userId;
  final String deviceId;

  String get wireValue => '$userId:$deviceId';

  static MlsMemberIdentity parse(String identity) {
    final index = identity.indexOf(':');
    if (index <= 0 || index == identity.length - 1) {
      throw const FormatException('MLS 成员身份格式不合法');
    }
    return MlsMemberIdentity(
      userId: identity.substring(0, index),
      deviceId: identity.substring(index + 1),
    );
  }
}

/// 群成员标识 = "user_id:device_id"（MLS BasicCredential 内容）。
/// 扇出/名册以 用户身份 为单位，故从标识取 用户身份 段。
String userIdFromMemberIdentity(String identity) {
  return MlsMemberIdentity.parse(identity).userId;
}

List<MlsMemberIdentity> membersFromMemberIdentities(
  Iterable<String> identities,
) => identities.map(MlsMemberIdentity.parse).toList(growable: false);

/// 一批成员标识 → 去重 用户身份 集合（可选排除自己）。
List<String> userIdsFromMemberIdentities(
  Iterable<String> identities, {
  String? excludeUserId,
}) {
  final seen = <String>{};
  final result = <String>[];
  for (final identity in identities) {
    final userId = userIdFromMemberIdentity(identity);
    if (userId.isEmpty || userId == excludeUserId) {
      continue;
    }
    if (seen.add(userId)) {
      result.add(userId);
    }
  }
  return result;
}

/// `group_process` 返回的 epoch 判定状态。
enum GroupProcessStatus {
  applied('applied'),
  outOfOrder('out_of_order'),
  stale('stale'),
  unknown('unknown');

  const GroupProcessStatus(this.wireName);

  final String wireName;

  static GroupProcessStatus fromWireName(String value) {
    for (final status in values) {
      if (status.wireName == value) {
        return status;
      }
    }
    return GroupProcessStatus.unknown;
  }
}

/// 入站群消息的内容类型。
enum GroupInboundKind {
  welcome('welcome'),
  commit('commit'),
  application('application'),
  unknown('unknown');

  const GroupInboundKind(this.wireName);

  final String wireName;

  static GroupInboundKind fromWireName(String value) {
    for (final kind in values) {
      if (kind.wireName == value) {
        return kind;
      }
    }
    return GroupInboundKind.unknown;
  }
}

/// 建群结果。
class GroupCreated {
  const GroupCreated({required this.groupId, required this.epoch});

  final String groupId;
  final int epoch;
}

/// 加人/删人产生的 Commit 束。
///
/// add:`commit` 发给现有成员,`welcome` 发给全部新人(单条覆盖 N 人)。
/// remove:仅 `commit`,发给剩余成员 + 被删者;`removedUserIds` 为被删 用户身份。
class GroupCommitBundle {
  const GroupCommitBundle({
    required this.groupId,
    required this.epoch,
    required this.commit,
    this.welcome,
    this.removedUserIds = const [],
  });

  final String groupId;
  final int epoch;
  final MlsWireMessage commit;
  final MlsWireMessage? welcome;
  final List<String> removedUserIds;
}

/// `group_process` 处理入站群消息的结果。
class GroupInbound {
  const GroupInbound({
    required this.groupId,
    required this.kind,
    required this.status,
    required this.messageEpoch,
    required this.groupEpoch,
    required this.selfRemoved,
    this.plaintext,
    this.memberIdentities,
  });

  final String groupId;
  final GroupInboundKind kind;
  final GroupProcessStatus status;
  final int messageEpoch;
  final int groupEpoch;

  /// 本机是否在该 Commit 中被移除(被删/退群生效)。
  final bool selfRemoved;

  /// application 明文(仅 application applied 非空)。
  final List<int>? plaintext;

  /// 应用 Commit / 入群 Welcome 后的 MLS 权威名册(标识,含设备段)。
  final List<String>? memberIdentities;

  bool get isApplied => status == GroupProcessStatus.applied;

  bool get isOutOfOrder => status == GroupProcessStatus.outOfOrder;
}

/// 只读群状态(名册对账 + 上限守)。
class GroupState {
  const GroupState({
    required this.groupId,
    required this.epoch,
    required this.memberIdentities,
  });

  final String groupId;
  final int epoch;
  final List<String> memberIdentities;

  int get memberCount => memberIdentities.length;
}

/// OpenMLS 群 FFI 边界接口(可注入,单测用 fake)。
///
/// 实现必须调用成熟 OpenMLS native,不允许在 Dart 中自研群密码学。
abstract class MlsGroupCrypto {
  /// 为当前设备生成一枚由 OpenMLS 保存私有材料的 Last Resort KeyPackage。
  Future<MlsKeyPackage> createKeyPackage(
    ChatDevice identity, {
    bool lastResort = true,
  });

  /// 建群,创建者为唯一成员。
  Future<GroupCreated> createGroup(String groupId);

  /// 批量加人:1 Commit(现有成员)+ 1 Welcome(全部新人)。
  Future<GroupCommitBundle> addMembers(
    String groupId,
    List<MlsKeyPackage> keyPackages,
  );

  /// 删人：Commit（剩余成员 + 被删者）。按 用户身份 移除（含其全部设备叶子）。
  Future<GroupCommitBundle> removeMembers(
    String groupId,
    List<String> memberUserIds,
  );

  /// 群 application message(单次加密,Dart 侧扇出)。
  Future<MlsWireMessage> groupCreateMessage(
    String groupId,
    List<int> plaintext,
  );

  /// 处理入站群消息(Welcome / Commit / Application)。
  Future<GroupInbound> groupProcess(MlsWireMessage wire);

  /// 只读群状态(epoch + 名册)。
  Future<GroupState> groupState(String groupId);
}
