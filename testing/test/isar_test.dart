import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_storage/chat_isar.dart';
import 'package:tatachat_testing/isar.dart';

void main() {
  useIsolatedChatIsar();
  test('隔离夹具使用真实库保存本测试的数据', () async {
    final database = await ChatIsar.instance.db();
    final route = ChatRouteCacheEntity()
      ..ownerUserId = 'fixture-owner'
      ..peerUserId = 'fixture-peer'
      ..routeDisplayName = 'fixture'
      ..deviceId = 'fixture-device'
      ..safetyNumber = 'fixture'
      ..createdAtMillis = 1
      ..updatedAtMillis = 1;
    await database.writeTxn(() => database.chatRouteCacheEntitys.put(route));
    expect(await database.chatRouteCacheEntitys.count(), 1);
  });
  test('下个测试实际读取不到前个测试的持久数据', () async {
    final database = await ChatIsar.instance.db();
    expect(await database.chatRouteCacheEntitys.count(), 0);
  });
}
