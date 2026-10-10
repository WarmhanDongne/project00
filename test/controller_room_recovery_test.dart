import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/models/room_session_identity.dart';
import 'package:game_kit/recovery/services/controller_room_session_store.dart';
import 'package:game_kit/recovery/services/room_recovery_batch.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const identity = RoomSessionIdentity(
    uid: 'tablet-recovery',
    role: 'controller',
    roomCode: 'ABCDE',
    roomInstanceId: 'room',
    connectionId: 'old',
    connectionSeq: 1,
    controllerSessionId: 'controller-session',
  );
  late _Functions functions;
  late _Database database;
  late RoomService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ControllerRoomSessionStore.instance.save(
      roomCode: identity.roomCode,
      sessionId: identity.controllerSessionId!,
    );
    await RoomSessionIdentityStore.instance.save(identity);
    functions = _Functions();
    database = _Database();
    service = RoomService(
      auth: _Auth(identity.uid),
      functions: functions,
      database: database,
    );
  });

  tearDown(() async {
    await RoomSessionIdentityStore.instance.clear(
      identity.uid,
      identity.role,
      identity.roomCode,
    );
    await ControllerRoomSessionStore.instance.clear();
  });

  test(
    'pending controller resume adopts the current server connection',
    () async {
      await RoomSessionIdentityStore.instance
          .savePending(identity.uid, identity.role, identity.roomCode, {
            'operationId': 'pending-resume',
            'roomCode': identity.roomCode,
            'roomInstanceId': identity.roomInstanceId,
            'expectedConnectionSeq': 1,
          });
      functions.reply = (name, data) async => {
        'roomInstanceId': identity.roomInstanceId,
        'connectionId': name == 'fetchRealtimeRoomSession'
            ? 'current'
            : 'replayed',
        'connectionSeq': name == 'fetchRealtimeRoomSession' ? 3 : 2,
      };

      expect(await service.restoreControllerRoom(), identity.roomCode);
      expect(functions.names, [
        'resumeRealtimeControllerRoom',
        'fetchRealtimeRoomSession',
      ]);
      final current = RoomSessionIdentityStore.instance.current(
        identity.uid,
        identity.role,
        identity.roomCode,
      )!;
      expect(current.connectionId, 'current');
      expect(current.connectionSeq, 3);
      expect(
        RoomSessionIdentityStore.instance.pending(
          identity.uid,
          identity.role,
          identity.roomCode,
        ),
        isNull,
      );
      expect(database.writes, [
        'rooms/ABCDE/connections/${identity.uid}/current',
      ]);
    },
  );

  test('late controller resume cannot replace the saved connection', () async {
    var elapsed = Duration.zero;
    final owner = RoomRecoveryBatch(elapsed: () => elapsed);
    final response = Completer<Map<String, dynamic>>();
    functions.reply = (_, _) => response.future;
    final operation = owner.run(
      service.restoreControllerRoom,
      isCurrent: () => true,
      retryable: (_) => false,
    );
    final assertion = expectLater(operation, throwsStateError);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    elapsed = const Duration(seconds: 31);
    response.complete({
      'roomInstanceId': identity.roomInstanceId,
      'connectionId': 'late',
      'connectionSeq': 2,
    });

    await assertion;
    expect(
      RoomSessionIdentityStore.instance
          .current(identity.uid, identity.role, identity.roomCode)!
          .connectionId,
      'old',
    );
    expect(
      RoomSessionIdentityStore.instance.pending(
        identity.uid,
        identity.role,
        identity.roomCode,
      ),
      isNotNull,
    );
    expect(database.writes, isEmpty);
  });
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
  final writes = <String>[];
  @override
  DatabaseReference ref([String? path]) => _Reference(this, path!);
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.database, this.path);
  final _Database database;
  @override
  final String path;

  @override
  Future<void> update(Map<String, Object?> value) async {
    database.writes.add(path);
  }

  @override
  OnDisconnect onDisconnect() => _Disconnect();
}

class _Disconnect extends Fake implements OnDisconnect {
  @override
  Future<void> update(Map<String, Object?> value) async {}
}
