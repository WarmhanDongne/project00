import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/models/room_session_identity.dart';
import 'package:game_kit/recovery/services/room_recovery_batch.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var number = 0;
  late RoomSessionIdentity identity;
  late _Functions functions;
  late _Database database;
  late RoomService service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    identity = RoomSessionIdentity(
      uid: 'restore-${++number}',
      role: 'player',
      roomCode: 'ABCDE',
      roomInstanceId: 'room',
      membershipId: 'member',
      connectionId: 'old',
      connectionSeq: 1,
    );
    await RoomSessionIdentityStore.instance.save(identity);
    await RoomSessionIdentityStore.instance
        .savePending(identity.uid, 'player', 'ABCDE', {
          'operationId': 'pending',
          'roomCode': 'ABCDE',
          'roomInstanceId': 'room',
          'membershipId': 'member',
          'preserveProfile': true,
        });
    functions = _Functions();
    database = _Database();
    service = RoomService(
      auth: _Auth(identity.uid),
      functions: functions,
      database: database,
    );
  });
  tearDown(
    () async => RoomSessionIdentityStore.instance.clear(
      identity.uid,
      'player',
      'ABCDE',
    ),
  );
  Future<void> restore() => service.restorePlayerConnection(
    roomCode: 'ABCDE',
    nickname: 'Tester',
    characterId: 'frog',
  );
  test(
    'fresh join reads room and membership concurrently before sending',
    () async {
      await RoomSessionIdentityStore.instance.save(
        identity,
        completedOperationId: 'pending',
      );
      final room = Completer<DataSnapshot>();
      final player = Completer<DataSnapshot>();
      database.pendingReads['rooms/ABCDE/roomInstanceId'] = room;
      database.pendingReads['rooms/ABCDE/players/${identity.uid}'] = player;
      functions.reply = (_, data) async {
        expect(data['roomInstanceId'], 'room');
        expect(data['membershipId'], 'member');
        expect(data['expectedConnectionSeq'], 1);
        return {
          'roomInstanceId': 'room',
          'membershipId': 'member',
          'connectionId': 'new',
          'connectionSeq': 2,
        };
      };
      final operation = service.updateRoomPlayerProfile(
        'ABCDE',
        'Updated',
        characterId: 'frog',
      );
      await Future<void>.delayed(Duration.zero);
      expect(database.reads, hasLength(2));
      expect(functions.names, isEmpty);
      player.complete(
        _Snapshot({'membershipId': 'member', 'connectionSeq': 1}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(functions.names, isEmpty);
      room.complete(_Snapshot('room'));
      await operation;
      expect(functions.names, ['joinRealtimeRoom']);
    },
  );
  test(
    'a different explicit profile edit follows replay as its own request',
    () async {
      database.values['rooms/ABCDE/roomInstanceId'] = 'room';
      database.values['rooms/ABCDE/players/${identity.uid}'] = {
        'status': 'active',
        'membershipId': 'member',
        'connectionSeq': 3,
      };
      var joins = 0;
      functions.reply = (name, data) async {
        if (name == 'joinRealtimeRoom') joins++;
        if (joins == 2) {
          expect(data['nickname'], 'Updated');
          expect(data['expectedConnectionSeq'], 3);
        }
        return {
          'roomInstanceId': 'room',
          'membershipId': 'member',
          'connectionId': joins == 2 ? 'updated' : 'current',
          'connectionSeq': joins == 2 ? 4 : 3,
        };
      };
      await service.updateRoomPlayerProfile(
        'ABCDE',
        'Updated',
        characterId: 'frog',
      );
      expect(functions.names, [
        'joinRealtimeRoom',
        'fetchRealtimeRoomSession',
        'joinRealtimeRoom',
      ]);
      expect(
        RoomSessionIdentityStore.instance
            .current(identity.uid, 'player', 'ABCDE')!
            .connectionId,
        'updated',
      );
    },
  );
  test(
    'successful pending replay adopts current server connection without another allocation',
    () async {
      functions.reply = (name, data) async => {
        'roomInstanceId': 'room',
        'membershipId': 'member',
        'connectionId': name == 'joinRealtimeRoom' ? 'replayed-old' : 'current',
        'connectionSeq': name == 'joinRealtimeRoom' ? 2 : 3,
      };
      await restore();
      expect(functions.names, ['joinRealtimeRoom', 'fetchRealtimeRoomSession']);
      expect(database.reads, isEmpty);
      final current = RoomSessionIdentityStore.instance.current(
        identity.uid,
        'player',
        'ABCDE',
      )!;
      expect(current.connectionId, 'current');
      expect(current.connectionSeq, 3);
      expect(
        RoomSessionIdentityStore.instance.pending(
          identity.uid,
          'player',
          'ABCDE',
        ),
        isNull,
      );
      await service.heartbeatPlayer('ABCDE');
      expect(
        database.writes.single,
        'rooms/ABCDE/connections/${identity.uid}/current',
      );
    },
  );
  test('replayed allocation cannot rejoin a removed membership', () async {
    functions.reply = (name, data) async {
      if (name == 'fetchRealtimeRoomSession') {
        throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'removed',
        );
      }
      return {};
    };
    await expectLater(restore(), throwsA(isA<FirebaseFunctionsException>()));
    expect(functions.names, ['joinRealtimeRoom', 'fetchRealtimeRoomSession']);
    expect(
      RoomSessionIdentityStore.instance
          .current(identity.uid, 'player', 'ABCDE')!
          .connectionId,
      'old',
    );
  });
  test(
    'late replay after its owner deadline cannot save or clear intent',
    () async {
      var elapsed = Duration.zero;
      final owner = RoomRecoveryBatch(elapsed: () => elapsed);
      final pending = Completer<Map<String, dynamic>>();
      functions.reply = (name, data) => pending.future;
      final operation = owner.run(
        restore,
        isCurrent: () => true,
        retryable: (_) => false,
      );
      final assertion = expectLater(operation, throwsStateError);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      elapsed = const Duration(seconds: 31);
      pending.complete({
        'connectionId': 'late',
        'connectionSeq': 2,
        'roomInstanceId': 'room',
        'membershipId': 'member',
      });
      await assertion;
      expect(functions.names, ['joinRealtimeRoom']);
      expect(
        RoomSessionIdentityStore.instance
            .current(identity.uid, 'player', 'ABCDE')!
            .connectionId,
        'old',
      );
      expect(
        RoomSessionIdentityStore.instance.pending(
          identity.uid,
          'player',
          'ABCDE',
        )!['operationId'],
        'pending',
      );
    },
  );
  test(
    'heartbeat permission classification survives service wrapping',
    () async {
      database.denied = true;
      await expectLater(
        service.heartbeatPlayer('ABCDE'),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    },
  );
}

class _Functions extends Fake implements FirebaseFunctions {
  final names = <String>[];
  late Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  reply;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _Callable(this, name);
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.functions, this.name);
  final _Functions functions;
  final String name;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    functions.names.add(name);
    return _Result<T>(
      await functions.reply(name, Map<String, dynamic>.from(parameters as Map))
          as T,
    );
  }
}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  _Result(this.data);
  @override
  final T data;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(String uid) : currentUser = _User(uid);
  @override
  final User currentUser;
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Database extends Fake implements FirebaseDatabase {
  final pendingReads = <String, Completer<DataSnapshot>>{};
  bool denied = false;
  final values = <String, Object>{};
  final reads = <String>[], writes = <String>[];
  @override
  DatabaseReference ref([String? path]) => _Reference(this, path!);
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.database, this.path);
  final _Database database;
  @override
  final String path;
  @override
  Future<DataSnapshot> get() async {
    database.reads.add(path);
    if (database.pendingReads[path] case final pending?) return pending.future;
    if (database.values.containsKey(path)) {
      return _Snapshot(database.values[path]);
    }
    throw StateError('Unexpected read');
  }

  @override
  Future<void> update(Map<String, Object?> value) async {
    if (database.denied) {
      throw FirebaseException(
        plugin: 'firebase_database',
        code: 'permission-denied',
      );
    }
    database.writes.add(path);
  }
}

class _Snapshot extends Fake implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
}
