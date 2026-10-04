// epoch 有序处理:乱序 Commit 缓冲 + 回放(纯逻辑,注入 process/buffer seam,可测)。
//
// MLS 群解密链要求 Commit 按 epoch 顺序应用;零存储瞬时中转不保证到达序。
// 规则(Rust `group_process` 已给出 status 判定):
//   applied    + commit → 成功应用,epoch 前进;回放缓冲中"下一个 epoch"的项
//   out_of_order        → 该消息 epoch > 当前 epoch,缓冲待补
//   stale               → epoch 已过(密钥已 ratchet),丢弃
// epoch 状态机由本模块测试固定。

import '../mls/mls_group_boundary.dart';
import '../mls/mls_session.dart';
import '../protocol/message.dart';

/// 处理一条 wire,返回 [GroupInbound]。
typedef GroupProcessSeam = Future<GroupInbound> Function(MlsWireMessage wire);

/// 缓冲一条乱序 message(键:groupId + messageEpoch)。
typedef GroupBufferPut =
    Future<void> Function(
      String groupId,
      int messageEpoch,
      EncryptedMessage message,
    );

/// 取出并删除某 (groupId, messageEpoch) 下最早的一条缓冲 message;无则 null。
typedef GroupBufferTake =
    Future<EncryptedMessage?> Function(String groupId, int messageEpoch);

/// 从 message 还原 wire(用于回放)。
typedef WireFromMessage = MlsWireMessage Function(EncryptedMessage message);

/// 每条 message 完成 epoch 判定后的串行回调；调用方只对 applied 内容落库，
/// 并可把 applied/stale 记录为已处理以回复内部设备确认。
typedef GroupProcessedCallback =
    Future<void> Function(EncryptedMessage message, GroupInbound result);

class GroupEpochOrdering {
  const GroupEpochOrdering._();

  /// 有序处理一条入站 message:
  /// - out_of_order → 缓冲,返回该结果(调用方据此提示"等待前序")
  /// - applied 且是 Commit → 应用后回放缓冲(填补 epoch 缺口)
  /// - 其余 → 直接返回
  static Future<GroupInbound> processOrdered({
    required MlsWireMessage wire,
    required EncryptedMessage message,
    required GroupProcessSeam process,
    required GroupBufferPut bufferPut,
    required GroupBufferTake bufferTake,
    required WireFromMessage wireFromMessage,
    GroupProcessedCallback? onProcessed,
  }) async {
    final result = await process(wire);
    if (result.status == GroupProcessStatus.outOfOrder) {
      await bufferPut(result.groupId, result.messageEpoch, message);
      await onProcessed?.call(message, result);
      return result;
    }
    await onProcessed?.call(message, result);
    if (result.status == GroupProcessStatus.applied &&
        result.kind == GroupInboundKind.commit) {
      await _drain(
        groupId: result.groupId,
        fromEpoch: result.groupEpoch,
        process: process,
        bufferPut: bufferPut,
        bufferTake: bufferTake,
        wireFromMessage: wireFromMessage,
        onProcessed: onProcessed,
      );
    }
    return result;
  }

  /// 回放缓冲:从 [fromEpoch] 起,取该 epoch 下缓冲项依次重放。
  /// application 应用后 epoch 不变(继续取同 epoch);Commit 应用后 epoch+1
  /// (移到下一 epoch 继续)。取空即止;每次取出即删除,必然收敛。
  static Future<void> _drain({
    required String groupId,
    required int fromEpoch,
    required GroupProcessSeam process,
    required GroupBufferPut bufferPut,
    required GroupBufferTake bufferTake,
    required WireFromMessage wireFromMessage,
    GroupProcessedCallback? onProcessed,
  }) async {
    var current = fromEpoch;
    while (true) {
      final buffered = await bufferTake(groupId, current);
      if (buffered == null) {
        break;
      }
      final result = await process(wireFromMessage(buffered));
      switch (result.status) {
        case GroupProcessStatus.applied:
          await onProcessed?.call(buffered, result);
          // Commit 前进 epoch;application 不变。
          current = result.groupEpoch;
        case GroupProcessStatus.outOfOrder:
          // 理论上不会发生(取的就是当前 epoch);稳妥起见放回并停止,避免丢失。
          await bufferPut(result.groupId, result.messageEpoch, buffered);
          await onProcessed?.call(buffered, result);
          return;
        case GroupProcessStatus.stale:
          await onProcessed?.call(buffered, result);
          continue;
        case GroupProcessStatus.unknown:
          // 丢弃,继续取同 epoch 下一条。
          await onProcessed?.call(buffered, result);
          break;
      }
    }
  }
}
