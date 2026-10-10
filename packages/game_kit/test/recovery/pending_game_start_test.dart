import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_kit/recovery/models/room_session_identity.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';

const _identity = RoomSessionIdentity(
  uid: 'tablet',
  role: 'controller',
  roomCode: 'ABCDE',
  roomInstanceId: 'room-current',
  connectionId: 'connection-one',
  connectionSeq: 1,
  controllerSessionId: 'controller-session',
);
const _function = 'game_mafia_start_game';
const _input = {
  'roomCode': 'ABCDE',
  'composition': {'citizen': 4, 'mafia': 2},
};
Map<String, dynamic> _payload(String id) => {
  ..._identity.envelope,
  'commandId': id,
  'gameInstanceId': 'finished-game',
  'phaseSeq': 4,
  ..._input,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'process restart preserves start ID, options and original envelope',
    () async {
      final store = RoomSessionIdentityStore();
      await store.save(_identity);
      await store.retainGameStart(
        _identity,
        _function,
        _input,
        _payload('start-one'),
      );
      final restarted = RoomSessionIdentityStore();
      await restarted.load();
      expect(
        await restarted.retainGameStart(_identity, _function, {
          'composition': {'mafia': 2, 'citizen': 4},
          'roomCode': 'ABCDE',
        }, _payload('fresh-id')),
        _payload('start-one'),
      );
      expect(
        restarted.pendingGameStart('different-uid', 'controller', 'ABCDE'),
        isNull,
      );
      expect(restarted.pendingGameStart('tablet', 'player', 'ABCDE'), isNull);
    },
  );

  test(
    'concurrent services reserve one ID without overwriting the first intent',
    () async {
      final store = RoomSessionIdentityStore();
      await store.save(_identity);
      final payloads = await Future.wait([
        store.retainGameStart(
          _identity,
          _function,
          _input,
          _payload('first-id'),
        ),
        store.retainGameStart(
          _identity,
          _function,
          _input,
          _payload('second-id'),
        ),
      ]);
      expect(payloads[0], payloads[1]);
      expect(payloads.first['commandId'], 'first-id');
    },
  );

  test(
    'connection resume keeps start while membership or room replacement drops it',
    () async {
      final store = RoomSessionIdentityStore();
      await store.save(_identity);
      await store.retainGameStart(
        _identity,
        _function,
        _input,
        _payload('start-one'),
      );
      const resumed = RoomSessionIdentity(
        uid: 'tablet',
        role: 'controller',
        roomCode: 'ABCDE',
        roomInstanceId: 'room-current',
        connectionId: 'connection-two',
        connectionSeq: 2,
        controllerSessionId: 'controller-session',
      );
      await store.save(resumed);
      expect(
        store.pendingGameStart('tablet', 'controller', 'ABCDE')?['payload'],
        _payload('start-one'),
      );
      const replacement = RoomSessionIdentity(
        uid: 'tablet',
        role: 'controller',
        roomCode: 'ABCDE',
        roomInstanceId: 'room-new',
        connectionId: 'connection-three',
        connectionSeq: 1,
        controllerSessionId: 'controller-new',
      );
      await store.save(replacement);
      expect(store.pendingGameStart('tablet', 'controller', 'ABCDE'), isNull);
      await expectLater(
        store.retainGameStart(
          _identity,
          _function,
          _input,
          _payload('late-old'),
        ),
        throwsStateError,
      );
      expect(
        store.current('tablet', 'controller', 'ABCDE')?.roomInstanceId,
        'room-new',
      );
    },
  );

  test(
    'late acknowledgment cannot clear a newer ID; explicit room cleanup removes intent',
    () async {
      final store = RoomSessionIdentityStore();
      await store.save(_identity);
      await store.retainGameStart(
        _identity,
        _function,
        _input,
        _payload('start-one'),
      );
      await store.completeGameStart(_identity, 'start-one');
      await store.retainGameStart(
        _identity,
        _function,
        _input,
        _payload('start-two'),
      );
      await store.completeGameStart(_identity, 'start-one');
      expect(
        store.pendingGameStart(
          'tablet',
          'controller',
          'ABCDE',
        )?['payload']['commandId'],
        'start-two',
      );
      await store.clear(
        'tablet',
        'controller',
        'ABCDE',
        onlyRoomInstanceId: 'room-current',
      );
      final restarted = RoomSessionIdentityStore();
      await restarted.load();
      expect(
        restarted.pendingGameStart('tablet', 'controller', 'ABCDE'),
        isNull,
      );
    },
  );

  test('changed options or game cannot replace unresolved start', () async {
    final store = RoomSessionIdentityStore();
    await store.save(_identity);
    await store.retainGameStart(
      _identity,
      _function,
      _input,
      _payload('start-one'),
    );
    await expectLater(
      store.retainGameStart(_identity, _function, {
        'roomCode': 'ABCDE',
        'composition': {'citizen': 5, 'mafia': 1},
      }, _payload('new-options')),
      throwsStateError,
    );
    await expectLater(
      store.retainGameStart(
        _identity,
        'game_holdem_start_game',
        _input,
        _payload('other-game'),
      ),
      throwsStateError,
    );
    expect(
      store.pendingGameStart('tablet', 'controller', 'ABCDE')?['payload'],
      _payload('start-one'),
    );
  });

  test(
    'failed persistence retains old intent; retry cannot replace its ID',
    () async {
      var fail = false;
      final prefs = await SharedPreferences.getInstance();
      final store = RoomSessionIdentityStore(
        persist: (key, value) async =>
            fail ? false : prefs.setString(key, value),
      );
      await store.save(_identity);
      fail = true;
      await expectLater(
        store.retainGameStart(
          _identity,
          _function,
          _input,
          _payload('not-sent'),
        ),
        throwsStateError,
      );
      expect(store.pendingGameStart('tablet', 'controller', 'ABCDE'), isNull);
      fail = false;
      await store.retainGameStart(
        _identity,
        _function,
        _input,
        _payload('start-one'),
      );
      fail = true;
      await expectLater(
        store.completeGameStart(_identity, 'start-one'),
        throwsStateError,
      );
      expect(
        store.pendingGameStart(
          'tablet',
          'controller',
          'ABCDE',
        )?['payload']['commandId'],
        'start-one',
      );
      final restarted = RoomSessionIdentityStore();
      await restarted.load();
      expect(
        restarted.pendingGameStart(
          'tablet',
          'controller',
          'ABCDE',
        )?['payload']['commandId'],
        'start-one',
      );
    },
  );
}
