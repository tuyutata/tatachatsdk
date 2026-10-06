import 'dart:convert';

import 'mls_boundary.dart';
import 'mls_group_boundary.dart';

typedef ContactMlsExchange = Future<Map<String, dynamic>> Function(Map<String, Object?> request);
typedef ContactMlsApply = Future<void> Function(List<int> payload);

/// 同 CID 的真实 OpenMLS 组。只接受已有持久 MLS 身份，不调用聊天权益或宿主供钥。
/// 服务端预留公开操作，MLS 状态与操作结果原子提交，再传递和确认；网络失败只重放原结果。
final class MlsContactSync {
  MlsContactSync({required this.identity, required this.crypto, required this.exchange,
    required this.requireCurrent});
  final ChatDevice identity;
  final MlsGroupCrypto crypto;
  final ContactMlsExchange exchange;
  final Future<void> Function() requireCurrent;
  static final _devicePattern = RegExp(r'^[0-9a-f]{64}$');
  static final _operationPattern = RegExp(r'^[0-9a-f]{32}$');

  Future<Map<String, dynamic>> _request(Map<String, Object?> body) async {
    await requireCurrent();
    final result = await exchange(body);
    await requireCurrent();
    if (result['ok'] != true) throw StateError('通讯录 MLS 请求未确认');
    return result;
  }

  Future<List<List<int>>> synchronize({
    required Future<List<List<int>>> Function() snapshots,
    required ContactMlsApply apply,
  }) async {
    final package = await crypto.createKeyPackage(identity, lastResort: true);
    await _request({'action': 'publish', 'key_package': package.keyPackageHex});
    // 只确认本次成功公布的 KeyPackage 收据，避免无业务队列的协议结果积累。
    for (final record in await crypto.pendingMessageResults(null)) {
      final request = (record['request'] as Map).cast<String, dynamic>();
      final result = (record['result'] as Map).cast<String, dynamic>();
      final id = request['message_id'];
      if (id is String && id.startsWith('key-package:') &&
          result['key_package_hex'] == package.keyPackageHex) {
        await crypto.acknowledgeMessage(id);
      }
    }
    final completed = <List<int>>[];
    var sentSnapshots = false;
    final recoveryState = await _request({'action': 'state'});
    for (final record in await crypto.pendingMessageResults(null)) {
      final request = (record['request'] as Map).cast<String, dynamic>();
      final id = request['message_id'];
      if (id is! String || !id.startsWith('contacts.send:')) continue;
      final parts = id.split(':');
      if (parts.length != 3) throw const FormatException('通讯录发送收据无效');
      final kind = parts[2];
      final targets = kind == 'add'
          ? (request['expected_member_identities'] as List).cast<String>().map((id) => MlsMemberIdentity.parse(id).deviceId).toList()
          : kind == 'remove' ? (request['member_identities'] as List).cast<String>().map((id) => MlsMemberIdentity.parse(id).deviceId).toList()
          : <String>[];
      final sent = await _commit(recoveryState['group_id'] as String,
        {'operation_id': parts[1], 'operation_kind': kind, 'target_device_ids': targets}, recoveryState, null);
      if (sent != null) completed.add(sent);
    }
    for (var round = 0; round < 128; round++) {
      final state = await _request({'action': 'state'});
      final groupId = state['group_id'];
      final revision = state['group_revision'];
      if (groupId is! String || !_operationPattern.hasMatch(groupId) ||
          revision is! int || revision < 0) throw const FormatException('通讯录 MLS 组状态无效');
      final messages = state['messages'];
      if (messages is! List) throw const FormatException('通讯录 MLS 消息列表无效');
      if (messages.isNotEmpty) {
        for (final item in messages) {
          final message = (item as Map).cast<String, dynamic>();
          final operation = message['operation_id'];
          final type = message['message_type'];
          final sender = message['sender_device_id'];
          if (operation is! String || !_operationPattern.hasMatch(operation) ||
              !['welcome', 'commit', 'application'].contains(type) ||
              sender is! String || !_devicePattern.hasMatch(sender)) {
            throw const FormatException('通讯录 MLS 传递标识无效');
          }
          final nativeId = 'contacts.receive:' + operation + ':' + type.toString();
          final result = await crypto.withMessage(nativeId, () => crypto.groupProcess(
            MlsWireMessage(conversationId: groupId, wireBytes: _bytes(message['mls_message']))));
          if (!result.committed || result.isOutOfOrder || result.selfRemoved) {
            throw StateError('通讯录 MLS 消息尚未安全应用');
          }
          final records = await crypto.pendingMessageResults(nativeId);
          if (records.length != 1) throw StateError('通讯录 MLS 处理收据缺失');
          final stored = (records.single['result'] as Map).cast<String, dynamic>();
          if (stored['message_kind'] != type || stored['group_id'] != groupId) {
            throw const FormatException('通讯录 MLS 内容类型与传递不一致');
          }
          final roster = (await crypto.groupState(groupId)).memberIdentities;
          _members(roster);
          if (type != 'welcome' &&
              stored['sender_member_identity'] != identity.userId + ':' + sender) {
            throw const FormatException('通讯录 MLS 实际发送者不一致');
          }
          if (type == 'application' && records.single['acknowledged'] != true) {
            await requireCurrent();
            await apply(_applicationPayload(_bytes(stored['plaintext_hex']), operation));
            await requireCurrent();
          }
          // 业务落库后才确认 MLS 收据；随后设备队列确认，任一崩溃可精确重放。
          await crypto.acknowledgeMessage(nativeId);
          await _request({'action': 'ack', 'operation_id': operation, 'message_type': type});
        }
        continue;
      }
      if (state['busy'] == true) throw StateError('通讯录 MLS 有其他设备操作待确认');
      final members = _devices(state['member_device_ids']);
      final eligible = _devices(state['eligible_device_ids']);
      Map<String, dynamic>? pending = state['pending'] == null
          ? null : (state['pending'] as Map).cast<String, dynamic>();
      if (revision > 0 && !members.contains(identity.deviceId) && pending == null) {
        throw StateError('通讯录等待已有 MLS 成员的 Welcome；钱包不能恢复旧组');
      }
      String? kind;
      List<String> targets = [];
      List<int>? payload;
      if (pending == null) {
        if (revision == 0) {
          if (state['creator_device_id'] != identity.deviceId) throw StateError('通讯录等待组创建者');
          kind = 'create';
        } else {
          final removed = members.where((id) => !eligible.contains(id)).toList();
          final added = eligible.where((id) => !members.contains(id)).toList();
          if (removed.isNotEmpty) { kind = 'remove'; targets = removed; }
          else if (added.isNotEmpty) { kind = 'add'; targets = added; }
          else if (!sentSnapshots) {
            final currentSnapshots = await snapshots();
            if (currentSnapshots.isEmpty) return completed;
            // 每轮只预留一个 application；成功后从剩余快照继续，闭包由下方批次固定。
            for (final snapshot in currentSnapshots) {
              await requireCurrent();
              final latest = await _request({'action': 'state'});
              if ((latest['messages'] as List).isNotEmpty || latest['busy'] == true ||
                  latest['pending'] != null) throw StateError('通讯录同步期间组状态变化');
              final reserved = await _request({'action': 'reserve',
                'group_revision': latest['group_revision'], 'operation_kind': 'application',
                'target_device_ids': <String>[]});
              final sent = await _commit(groupId, reserved, latest, snapshot);
              if (sent != null) completed.add(sent);
            }
            sentSnapshots = true;
            return completed;
          } else { return completed; }
        }
        pending = await _request({'action': 'reserve', 'group_revision': revision,
          'operation_kind': kind, 'target_device_ids': targets});
      }
      kind = pending['operation_kind'] as String;
      if (kind == 'application') {
        final currentSnapshots = await snapshots();
        if (currentSnapshots.isEmpty) throw StateError('通讯录预留操作缺少业务快照');
        payload = currentSnapshots.first;
      }
      final sent = await _commit(groupId, pending, state, payload);
      if (sent != null) completed.add(sent);
    }
    throw StateError('通讯录 MLS 同步批次超过上限');
  }

  Future<List<int>?> _commit(String groupId, Map<String, dynamic> pending,
      Map<String, dynamic> state, List<int>? payload) async {
    final operation = pending['operation_id'];
    final kind = pending['operation_kind'];
    if (operation is! String || !_operationPattern.hasMatch(operation) ||
        !['create', 'add', 'remove', 'application'].contains(kind)) {
      throw const FormatException('通讯录 MLS 预留操作无效');
    }
    final nativeId = 'contacts.send:' + operation + ':' + kind.toString();
    final prior = await crypto.pendingMessageResults(nativeId);
    final original = prior.isEmpty ? null : (prior.single['request'] as Map).cast<String, dynamic>();
    final targets = _devices(pending['target_device_ids']);
    final envelopes = <Map<String, Object?>>[];
    List<String> next;
    if (kind == 'create') {
      await crypto.withMessage(nativeId, () => crypto.createGroup(groupId));
      next = [identity.deviceId];
    } else if (kind == 'add') {
      List<MlsKeyPackage> packages;
      if (original != null) {
        final identities = (original['expected_member_identities'] as List).cast<String>();
        final hex = (original['key_packages_hex'] as List).cast<String>();
        packages = [for (var i = 0; i < identities.length; i++)
          _package(MlsMemberIdentity.parse(identities[i]).deviceId, hex[i])];
      } else {
        final available = (state['key_packages'] as List).map((item) => (item as Map).cast<String, dynamic>());
        packages = [for (final target in targets)
          _package(target, available.singleWhere((item) => item['device_id'] == target)['key_package'] as String)];
      }
      final result = await crypto.withMessage(nativeId, () => crypto.addMembers(groupId, packages));
      final existing = _members(result.priorMemberIdentities).where((id) => id != identity.deviceId).toList();
      if (result.welcome == null) throw StateError('通讯录 MLS 缺少 Welcome');
      envelopes.add({'message_type': 'commit', 'device_ids': existing, 'mls_message': result.commit.wireHex});
      envelopes.add({'message_type': 'welcome', 'device_ids': targets, 'mls_message': result.welcome!.wireHex});
      next = _members((await crypto.groupState(groupId)).memberIdentities);
    } else if (kind == 'remove') {
      final result = await crypto.withMessage(nativeId, () => crypto.removeMembers(groupId,
        targets.map((id) => identity.userId + ':' + id).toList()));
      envelopes.add({'message_type': 'commit',
        'device_ids': _members(result.priorMemberIdentities).where((id) => id != identity.deviceId && !targets.contains(id)).toList(),
        'mls_message': result.commit.wireHex});
      next = _members((await crypto.groupState(groupId)).memberIdentities);
    } else {
      if (original == null && payload == null) throw StateError('通讯录操作缺少原业务载荷');
      final business = original == null ? payload! : _applicationPayload(_bytes(original['plaintext_hex']), operation);
      if (business.isEmpty || business.length > 32 * 1024) throw const FormatException('通讯录 MLS 明文批次超限');
      final plaintext = original == null ? utf8.encode(jsonEncode({
        'operation_id': operation, 'owner_cid_number': identity.userId,
        'payload_base64': base64.encode(business),
      })) : _bytes(original['plaintext_hex']);
      final result = await crypto.withMessage(nativeId, () => crypto.groupCreateMessage(groupId, plaintext));
      next = _members(await crypto.messageMemberIdentities(groupId, nativeId));
      envelopes.add({'message_type': 'application', 'device_ids': next.where((id) => id != identity.deviceId).toList(),
        'mls_message': result.wireHex});
      payload = business;
    }
    await requireCurrent();
    await _request({'action': 'commit', 'operation_id': operation,
      'member_device_ids': next, 'messages': envelopes});
    await crypto.acknowledgeMessage(nativeId);
    return kind == 'application' ? payload : null;
  }

  List<int> _applicationPayload(List<int> plaintext, String operation) {
    final decoded = jsonDecode(utf8.decode(plaintext));
    if (decoded is! Map<String, dynamic> || decoded.length != 3 ||
        decoded['operation_id'] != operation || decoded['owner_cid_number'] != identity.userId ||
        decoded['payload_base64'] is! String) throw const FormatException('通讯录MLS内部操作或属主不一致');
    final encoded = decoded['payload_base64'] as String;
    final payload = base64.decode(encoded);
    if (payload.isEmpty || payload.length > 32 * 1024 || base64.encode(payload) != encoded) {
      throw const FormatException('通讯录MLS业务载荷编码无效');
    }
    return payload;
  }

  List<String> _members(List<String> values) {
    final result = <String>[];
    for (final value in values) {
      final member = MlsMemberIdentity.parse(value);
      if (member.userId != identity.userId || !_devicePattern.hasMatch(member.deviceId) ||
          result.contains(member.deviceId)) throw const FormatException('通讯录 MLS 包含其他 CID 或重复叶子');
      result.add(member.deviceId);
    }
    return result..sort();
  }

  static List<String> _devices(Object? value) {
    if (value is! List || value.length > 32 ||
        value.any((id) => id is! String || !_devicePattern.hasMatch(id)) ||
        value.toSet().length != value.length) throw const FormatException('通讯录设备集合无效');
    return value.cast<String>()..sort();
  }

  MlsKeyPackage _package(String device, String hex) => MlsKeyPackage(
    userId: identity.userId, deviceId: device, keyPackageRef: '', keyPackageBytes: _bytes(hex),
    cipherSuite: '', notBeforeMillis: 0, notAfterMillis: 0, lastResort: true);

  static List<int> _bytes(Object? value) {
    if (value is! String || value.isEmpty || value.length.isOdd ||
        !RegExp(r'^[0-9a-f]+$').hasMatch(value)) throw const FormatException('通讯录 MLS 字节编码无效');
    return [for (var index = 0; index < value.length; index += 2)
      int.parse(value.substring(index, index + 2), radix: 16)];
  }
}
