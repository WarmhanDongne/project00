import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/services/durable_room_operation_store.dart';
import 'package:game_kit/recovery/models/room_session_identity.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var nextUser = 0;
  late _Harness h;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = _Harness('fast-path-${++nextUser}');
  });

  test(
    'fresh create keeps initial connection; actual restore allocates a new one',
    () async {
      expect(await h.service.createRoom(), 'ABCDE');
      expect(h.calls, ['createRealtimeRoom']);
      expect(h.paths.single, endsWith('/connection-initial'));
      expect(h.disconnectRegistrations, 1);
      expect((await h.service.roomIdentity('ABCDE')).connectionSeq, 1);
      h.calls.clear();
      expect(await h.service.restoreControllerRoom(), 'ABCDE');
      expect(h.calls, ['resumeRealtimeControllerRoom']);
      expect(h.paths.last, endsWith('/connection-resumed'));
      expect((await h.service.roomIdentity('ABCDE')).connectionSeq, 2);
    },
  );

  test(
    'unknown creation response replays original ID and still resumes',
    () async {
      h.failCreate = true;
      await expectLater(h.service.createRoom(), throwsException);
      final firstId = h.payloads.first['operationId'];
      h.failCreate = false;
      expect(await h.newService().createRoom(), 'ABCDE');
      expect(h.calls, [
        'createRealtimeRoom',
        'createRealtimeRoom',
        'resumeRealtimeControllerRoom',
      ]);
      expect(h.payloads[1]['operationId'], firstId);
      expect(h.paths.single, endsWith('/connection-resumed'));
    },
  );

  test('advanced create connection cannot use the fresh fast path', () async {
    h.createdSequence = 2;
    await h.service.createRoom();
    expect(h.calls, ['createRealtimeRoom', 'resumeRealtimeControllerRoom']);
  });

  test('first close sends once without status lookup', () async {
    await h.service.createRoom();
    h.calls.clear();
    await h.service.closeControllerRoom('ABCDE');
    expect(h.calls, ['closeRoom']);
    expect(h.disconnectCancellations, 1);
  });

  Future<void> player() => RoomSessionIdentityStore.instance.save(
    RoomSessionIdentity(
      uid: h.uid,
      role: 'player',
      roomCode: 'ABCDE',
      roomInstanceId: 'room-${h.uid}',
      membershipId: 'member-${h.uid}',
      connectionId: 'player-connection',
      connectionSeq: 1,
    ),
  );
  Future<void> leave() => h.service.leaveGame(
    cloudFunctionName: 'game_final_call_leave_game',
    roomCode: 'ABCDE',
  );

  test('fresh leave sends once and persists intent before sending', () async {
    await player();
    await leave();
    expect(h.calls, ['game_final_call_leave_game']);
    expect(h.disconnectCancellations, 1);
    expect(h.intentAtLeave, 'awaitingResult');
    expect(
      RoomSessionIdentityStore.instance.current(h.uid, 'player', 'ABCDE'),
      isNull,
    );
    await leave();
    expect(h.calls, ['game_final_call_leave_game']);
  });

  for (final result in ['applied', 'stale', 'notApplied']) {
    test(
      'unknown leave retains identity and reuses ID after $result',
      () async {
        await player();
        h.failLeave = true;
        await expectLater(leave(), throwsException);
        expect(
          RoomSessionIdentityStore.instance.current(h.uid, 'player', 'ABCDE'),
          isNotNull,
        );
        final payload = h.payloads.single;
        h.failLeave = false;
        h.status = result;
        await h.newService().leaveGame(
          cloudFunctionName: 'game_final_call_leave_game',
          roomCode: 'ABCDE',
        );
        expect(h.calls, [
          'game_final_call_leave_game',
          'game_common_operation_status',
          if (result == 'notApplied') 'game_final_call_leave_game',
        ]);
        expect(
          h.payloads.every(
            (value) => value['operationId'] == payload['operationId'],
          ),
          isTrue,
        );
      },
    );
  }

  test('failed initial presence stays pending and resumes on retry', () async {
    h.failPresence = true;
    await expectLater(h.service.createRoom(), throwsException);
    expect(h.disconnectRegistrations, 0);
    h.failPresence = false;
    expect(await h.newService().createRoom(), 'ABCDE');
    expect(h.calls, [
      'createRealtimeRoom',
      'createRealtimeRoom',
      'resumeRealtimeControllerRoom',
    ]);
    expect(h.paths.last, endsWith('/connection-resumed'));
  });

  for (final result in ['applied', 'stale', 'notApplied']) {
    test(
      'unknown close response checks $result with the original durable ID',
      () async {
        await h.service.createRoom();
        h.calls.clear();
        h.payloads.clear();
        h.failClose = true;
        await expectLater(
          h.service.closeControllerRoom('ABCDE'),
          throwsException,
        );
        expect(h.calls, ['closeRoom']);
        final original = Map<String, dynamic>.from(h.payloads.single);
        final persisted = DurableRoomOperationStore();
        await persisted.load();
        expect(persisted.pendingFor(h.uid).single['payload'], original);
        h.failClose = false;
        h.status = result;
        await h.newService().closeControllerRoom('ABCDE');
        expect(h.calls, [
          'closeRoom',
          'game_common_operation_status',
          if (result == 'notApplied') 'closeRoom',
        ]);
        for (final payload in h.payloads) {
          expect(payload, original);
        }
      },
    );
  }
}

class _Harness {
  _Harness(this.uid) {
    service = newService();
  }
  final String uid;
  late final RoomService service;
  final calls = <String>[];
  final payloads = <Map<String, dynamic>>[];
  final paths = <String>[];
  bool failCreate = false;
  bool failClose = false;
  bool failPresence = false;
  bool failLeave = false;
  String? intentAtLeave;
  int createdSequence = 1;
  int disconnectRegistrations = 0;
  int disconnectCancellations = 0;
  String status = 'notApplied';
  RoomService newService() => RoomService(
    auth: _Auth(uid),
    functions: _Functions(this),
    database: _Database(this),
  );
  Future<Map<String, dynamic>> respond(
    String name,
    Map<String, dynamic> payload,
  ) async {
    calls.add(name);
    payloads.add(Map.from(payload));
    if (name == 'game_final_call_leave_game') {
      final persisted = DurableRoomOperationStore();
      await persisted.load();
      intentAtLeave = persisted.pendingFor(uid).single['state'] as String;
    }
    if ((name == 'createRealtimeRoom' && failCreate) ||
        (name == 'closeRoom' && failClose) ||
        (name == 'game_final_call_leave_game' && failLeave)) {
      // An unknown result that does not trigger the outer automatic retry.
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'response unavailable',
      );
    }
    return switch (name) {
      'createRealtimeRoom' || 'resumeRealtimeControllerRoom' => {
        'roomCode': 'ABCDE',
        'roomInstanceId': 'room-$uid',
        'controllerSessionId': 'controller-$uid',
        'connectionId': name == 'createRealtimeRoom'
            ? 'connection-initial'
            : 'connection-resumed',
        'connectionSeq': name == 'createRealtimeRoom'
            ? createdSequence
            : createdSequence + 1,
      },
      'closeRoom' => {'success': true},
      'game_final_call_leave_game' => {'status': 'applied'},
      'game_common_operation_status' => {'status': status},
      _ => throw StateError('Unexpected $name'),
    };
  }
}

class _Functions extends Fake implements FirebaseFunctions {
  _Functions(this.h);
  final _Harness h;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _Callable(h, name);
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.h, this.name);
  final _Harness h;
  final String name;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async => _Result(
    await h.respond(name, Map<String, dynamic>.from(parameters as Map)) as T,
  );
}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  _Result(this.data);
  @override
  final T data;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.uid);
  final String uid;
  @override
  User get currentUser => _User(uid);
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Database extends Fake implements FirebaseDatabase {
  _Database(this.h);
  final _Harness h;
  @override
  DatabaseReference ref([String? path]) => _Reference(h, path!);
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.h, this.path);
  final _Harness h;
  @override
  final String path;
  @override
  Future<void> update(Map<String, Object?> value) async {
    if (h.failPresence) {
      throw FirebaseException(
        plugin: 'firebase_database',
        code: 'permission-denied',
      );
    }
    h.paths.add(path);
  }

  @override
  OnDisconnect onDisconnect() => _Disconnect(h);
}

class _Disconnect extends Fake implements OnDisconnect {
  _Disconnect(this.h);
  final _Harness h;
  @override
  Future<void> update(Map<String, Object?> value) async {
    h.disconnectRegistrations++;
  }

  @override
  Future<void> cancel() async {
    h.disconnectCancellations++;
  }
}
