// 群控制消息(走既有 E2E application 通道,不改 proto、不进 ChatMessageKind)。
//
// 用户载荷以 `kind` 为唯一判别字段，控制载荷以 `op` 为唯一判别字段；
// 两者都没有额外 type/version 别名。出现 `op` 后必须精确匹配目标结构，
// 坏数据或未知操作失败关闭，绝不伪装成普通消息。

import 'dart:convert';

/// 群控制操作。
enum GroupControlOp {
  /// 创建者/管理员广播群名(补 Welcome 不带名的缺口)。
  rename('rename'),

  /// 退群者请求群 admin 代提交移除(密码学后向保密由 admin 的 removeMembers 保证)。
  leaveRequest('leave_request');

  const GroupControlOp(this.wireName);

  final String wireName;

  static GroupControlOp? fromWireName(String value) {
    for (final op in values) {
      if (op.wireName == value) {
        return op;
      }
    }
    return null;
  }
}

/// 群控制消息。
class GroupControl {
  const GroupControl._(this.op, this.groupName);

  factory GroupControl.rename(String name) =>
      GroupControl._(GroupControlOp.rename, name);

  const GroupControl.leaveRequest() : this._(GroupControlOp.leaveRequest, null);

  final GroupControlOp op;

  /// op=rename 携带的群名。
  final String? groupName;
}

class GroupControlCodec {
  GroupControlCodec._();

  static String encode(GroupControl control) {
    final map = <String, Object?>{'op': control.op.wireName};
    if (control.op == GroupControlOp.rename) {
      map['name'] = control.groupName ?? '';
    }
    final encoded = jsonEncode(map);
    tryDecode(encoded);
    return encoded;
  }

  /// 用户消息（无 `op`）返回 null 交给 [ChatPayloadCodec]；一旦存在
  /// `op`，未知操作、多字段、缺字段和类型错误都抛 [FormatException]。
  static GroupControl? tryDecode(String raw) {
    // TataChatSDK 第一类消息是 protobuf 的规范 base64url；只有 JSON 对象前缀才可能
    // 是群控制或媒体载荷，避免控制解码器抢先拒绝合法 basic 消息。
    if (!raw.startsWith('{')) return null;
    late final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('群消息载荷必须是完整 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('群消息载荷必须是 JSON 对象');
    }
    if (!decoded.containsKey('op')) return null;
    final opRaw = decoded['op'];
    if (opRaw is! String) {
      throw const FormatException('群控制 op 必须是字符串');
    }
    final op = GroupControlOp.fromWireName(opRaw);
    if (op == null) {
      throw FormatException('未知群控制 op：$opRaw');
    }
    return switch (op) {
      GroupControlOp.rename => _decodeRename(decoded),
      GroupControlOp.leaveRequest => _decodeLeaveRequest(decoded),
    };
  }

  static GroupControl _decodeRename(Map<String, dynamic> map) {
    _requireExactFieldSet(map, const <String>{'op', 'name'});
    final name = map['name'];
    if (name is! String || name.isEmpty) {
      throw const FormatException('群改名 name 必须是非空字符串');
    }
    return GroupControl.rename(name);
  }

  static GroupControl _decodeLeaveRequest(Map<String, dynamic> map) {
    _requireExactFieldSet(map, const <String>{'op'});
    return const GroupControl.leaveRequest();
  }

  // 严格要求群控制载荷字段集合完全一致，拒绝缺失字段和未声明字段。
  static void _requireExactFieldSet(
    Map<String, dynamic> map,
    Set<String> expected,
  ) {
    if (map.length != expected.length ||
        !map.keys.toSet().containsAll(expected)) {
      throw const FormatException('群控制载荷字段集不匹配');
    }
  }
}
