import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import '../support/isar_test_env.dart';

const _ownerUserId = 'CN220-CTZN2-100000001-2026';
const _peerUserId = 'CN220-CTZN2-100000002-2026';
const _accountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _binding = ChatBinding(
  bindingScope:
      '0x4242424242424242424242424242424242424242424242424242424242424242',
  userId: _ownerUserId,
  bindingRevision: 1,
  accountId: _accountId,
);

void main() {
  useIsolatedChatIsar();

  test('Chat route cache creates, reads, and replaces route records', () async {
    final store = ChatStore();
    final bindingToken = await store.activateBindingFence(_binding);

    await store.upsertRouteRecord(
      _ownerUserId,
      const ChatRouteRecord(
        peerUserId: _peerUserId,
        routeDisplayName: 'Bob',
        deviceId: 'bob-phone',
        safetyNumber: '12 34',
        nearbyPeerHint: 'bob-nearby',
        note: 'first',
      ),
      bindingToken: bindingToken,
    );

    final created = await store.getRouteRecord(_ownerUserId, _peerUserId);
    expect(created, isNotNull);
    expect(created!.routeDisplayName, 'Bob');
    expect(created.nearbyPeerHint, 'bob-nearby');

    await store.upsertRouteRecord(
      _ownerUserId,
      ChatRouteRecord(
        peerUserId: _peerUserId,
        routeDisplayName: 'Bob New',
        deviceId: created.deviceId,
        safetyNumber: created.safetyNumber,
        nearbyPeerHint: created.nearbyPeerHint,
        createdAtMillis: created.createdAtMillis,
      ),
      bindingToken: bindingToken,
    );

    final routes = await store.readRouteRecords(_ownerUserId);
    expect(routes, hasLength(1));
    expect(routes.single.routeDisplayName, 'Bob New');
    expect(routes.single.createdAtMillis, created.createdAtMillis);
    expect(
      routes.single.updatedAtMillis,
      greaterThanOrEqualTo(created.updatedAtMillis ?? 0),
    );
  });
}
