import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_kit/recovery/models/room_session_identity.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const identity = RoomSessionIdentity(
    uid: 'user-a',
    role: 'player',
    roomCode: 'ABCDE',
    roomInstanceId: 'room-one',
    membershipId: 'member-one',
    connectionId: 'connection-one',
    connectionSeq: 1,
  );

  test(
    'process restart preserves identity and the same unresolved allocation',
    () async {
      final first = RoomSessionIdentityStore();
      await first.save(identity);
      await first.savePending(identity.uid, identity.role, identity.roomCode, {
        'operationId': 'operation-one',
        'expectedConnectionSeq': 1,
      });
      final restarted = RoomSessionIdentityStore();
      await restarted.load();
      expect(
        restarted.current('user-a', 'player', 'abcde')?.membershipId,
        'member-one',
      );
      expect(
        restarted.pending('user-a', 'player', 'ABCDE')?['operationId'],
        'operation-one',
      );
      expect(restarted.current('user-b', 'player', 'ABCDE'), isNull);
      expect(restarted.pending('user-b', 'player', 'ABCDE'), isNull);
    },
  );

  test('old cleanup cannot remove a newly reused room session', () async {
    final store = RoomSessionIdentityStore();
    await store.save(identity);
    await store.clear(
      'user-a',
      'player',
      'ABCDE',
      onlyRoomInstanceId: 'room-old',
    );
    expect(store.current('user-a', 'player', 'ABCDE'), isNotNull);
    await store.clear(
      'user-a',
      'player',
      'ABCDE',
      onlyRoomInstanceId: 'room-one',
    );
    expect(store.current('user-a', 'player', 'ABCDE'), isNull);
  });

  test(
    'serialized writes preserve different accounts and clear pending on acknowledgment',
    () async {
      final store = RoomSessionIdentityStore();
      await Future.wait([
        store.save(identity),
        store.savePending('user-b', 'controller', 'BCDEF', {
          'operationId': 'operation-b',
        }),
      ]);
      await store.savePending('user-a', 'player', 'ABCDE', {
        'operationId': 'operation-a',
      });
      await store.save(identity, completedOperationId: 'operation-a');
      expect(store.pending('user-a', 'player', 'ABCDE'), isNull);
      expect(
        store.pending('user-b', 'controller', 'BCDEF')?['operationId'],
        'operation-b',
      );
    },
  );
  test(
    'failed identity persistence cannot replace the current connection or clear pending work',
    () async {
      final prefs = await SharedPreferences.getInstance();
      var fail = false;
      final store = RoomSessionIdentityStore(
        storageKey: 'identity-write-failure',
        persist: (key, value) async =>
            fail ? false : prefs.setString(key, value),
      );
      await store.save(identity);
      await store.savePending('user-a', 'player', 'ABCDE', {
        'operationId': 'unresolved',
      });
      fail = true;
      await expectLater(
        store.clear('user-a', 'player', 'ABCDE'),
        throwsStateError,
      );
      expect(store.current('user-a', 'player', 'ABCDE')!.connectionSeq, 1);
      expect(
        store.pending('user-a', 'player', 'ABCDE')!['operationId'],
        'unresolved',
      );
    },
  );
  test(
    'controller room and token discovery remain scoped to the owning account and role',
    () async {
      final store = RoomSessionIdentityStore();
      final controller = RoomSessionIdentity.fromJson({
        ...identity.toJson(),
        'role': 'controller',
        'controllerSessionId': 'controller-secret',
      });
      await store.save(controller);
      await store.save(identity);
      expect(
        store.latestFor('user-a', 'controller')!.controllerSessionId,
        'controller-secret',
      );
      expect(store.latestFor('user-a', 'player')!.controllerSessionId, isNull);
      expect(store.latestFor('user-b', 'controller'), isNull);
    },
  );
}
