import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'package:game_kit/recovery/models/room_session_identity.dart';
import 'package:game_kit/recovery/services/controller_room_session_store.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var nextUser = 0;
  late _Harness h;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    h = _Harness('removal-fast-path-${++nextUser}');
    await ControllerRoomSessionStore.instance.save(
      roomCode: 'ABCDE',
      sessionId: h.identity.controllerSessionId!,
    );
  });

  tearDown(() async {
    await ControllerRoomSessionStore.instance.clear();
  });

  test('lobby removal sends once without reading absent game state', () async {
    await h.cacheIdentity();
    expect(GameRecoverySession.forRoom('ABCDE', h.uid).context, isNull);

    await h.service.removePlayer('ABCDE', 'player-to-remove');

    expect(h.calls, ['removeRealtimeRoomPlayer']);
    h.expectRemovalPayload(h.payloads.single);
    expect(h.referencePaths, isEmpty);
    expect(h.readPaths, isEmpty);
  });

  test('cached game context is unnecessary for room removal', () async {
    await h.cacheIdentity();
    const context = GameRecoveryContext(
      gameInstanceId: 'cached-game',
      phaseSeq: 3,
      turnSeq: 4,
      dataSeq: 5,
      resumeEpoch: 2,
    );
    final session = GameRecoverySession.forRoom('ABCDE', h.uid)
      ..context = context;

    await h.service.removePlayer('ABCDE', 'player-to-remove');

    expect(h.calls, ['removeRealtimeRoomPlayer']);
    h.expectRemovalPayload(h.payloads.single);
    expect(session.context, same(context));
    expect(h.referencePaths, isEmpty);
    expect(h.readPaths, isEmpty);
  });

  test('missing identity is fetched and saved before removal', () async {
    expect(
      RoomSessionIdentityStore.instance.current(h.uid, 'controller', 'ABCDE'),
      isNull,
    );

    await h.service.removePlayer('ABCDE', 'player-to-remove');

    expect(h.calls, ['fetchRealtimeRoomSession', 'removeRealtimeRoomPlayer']);
    expect(h.payloads.first, {
      'roomCode': 'ABCDE',
      'controllerSessionId': h.identity.controllerSessionId,
      'presenceProtocol': 2,
    });
    h.expectRemovalPayload(h.payloads.last);
    expect(
      RoomSessionIdentityStore.instance
          .current(h.uid, 'controller', 'ABCDE')!
          .toJson(),
      h.identity.toJson(),
    );
    expect(h.referencePaths, isEmpty);
    expect(h.readPaths, isEmpty);
  });

  test('identity lookup failure prevents removal', () async {
    final error = FirebaseFunctionsException(
      code: 'unavailable',
      message: 'Session lookup unavailable',
    );
    h.fetchError = error;

    await expectLater(
      h.service.removePlayer('ABCDE', 'player-to-remove'),
      throwsA(same(error)),
    );

    expect(h.calls, ['fetchRealtimeRoomSession']);
    expect(
      RoomSessionIdentityStore.instance.current(h.uid, 'controller', 'ABCDE'),
      isNull,
    );
    expect(h.referencePaths, isEmpty);
    expect(h.readPaths, isEmpty);
  });

  for (final code in ['permission-denied', 'failed-precondition']) {
    test('server $code is preserved without retrying removal', () async {
      await h.cacheIdentity();
      final error = FirebaseFunctionsException(
        code: code,
        message: 'Removal rejected',
      );
      h.removeError = error;

      await expectLater(
        h.service.removePlayer('ABCDE', 'player-to-remove'),
        throwsA(same(error)),
      );

      expect(h.calls, ['removeRealtimeRoomPlayer']);
      h.expectRemovalPayload(h.payloads.single);
      expect(
        RoomSessionIdentityStore.instance
            .current(h.uid, 'controller', 'ABCDE')!
            .toJson(),
        h.identity.toJson(),
      );
      expect(h.referencePaths, isEmpty);
      expect(h.readPaths, isEmpty);
    });
  }

  test('unauthenticated removal sends no network request', () async {
    h.auth.currentUid = null;

    await expectLater(
      h.service.removePlayer('ABCDE', 'player-to-remove'),
      throwsA(isA<RoomCommandException>()),
    );

    expect(h.calls, isEmpty);
    expect(h.referencePaths, isEmpty);
    expect(h.readPaths, isEmpty);
  });
}

class _Harness {
  _Harness(this.uid) {
    auth = _Auth(uid);
    service = RoomService(
      auth: auth,
      functions: _Functions(this),
      database: _Database(this),
    );
  }

  final String uid;
  late final _Auth auth;
  late final RoomService service;
  final calls = <String>[];
  final payloads = <Map<String, dynamic>>[];
  final referencePaths = <String>[];
  final readPaths = <String>[];
  FirebaseFunctionsException? fetchError, removeError;

  RoomSessionIdentity get identity => RoomSessionIdentity(
    uid: uid,
    role: 'controller',
    roomCode: 'ABCDE',
    roomInstanceId: 'room-$uid',
    controllerSessionId: 'controller-$uid',
    connectionId: 'connection-$uid',
    connectionSeq: 7,
  );

  Future<void> cacheIdentity() =>
      RoomSessionIdentityStore.instance.save(identity);

  void expectRemovalPayload(Map<String, dynamic> payload) {
    final operationId = payload['operationId'];
    expect(operationId, matches(RegExp(r'^room_[0-9a-f]{32}$')));
    expect(payload, {
      ...identity.envelope,
      'operationId': operationId,
      'playerUid': 'player-to-remove',
    });
  }

  Future<Map<String, dynamic>> respond(
    String name,
    Map<String, dynamic> payload,
  ) async {
    calls.add(name);
    payloads.add(Map.of(payload));
    if (name == 'fetchRealtimeRoomSession') {
      if (fetchError != null) throw fetchError!;
      return identity.toJson();
    }
    if (name == 'removeRealtimeRoomPlayer') {
      if (removeError != null) throw removeError!;
      return {'success': true};
    }
    throw StateError('Unexpected callable $name');
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.currentUid);
  String? currentUid;

  @override
  User? get currentUser => currentUid == null ? null : _User(currentUid!);
}

class _User extends Fake implements User {
  _User(this.uid);

  @override
  final String uid;
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

class _Database extends Fake implements FirebaseDatabase {
  _Database(this.h);
  final _Harness h;

  @override
  DatabaseReference ref([String? path]) {
    h.referencePaths.add(path ?? '');
    return _Reference(h, path ?? '');
  }
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.h, this.path);
  final _Harness h;

  @override
  final String path;

  @override
  Future<DataSnapshot> get() async {
    h.readPaths.add(path);
    throw StateError('Room removal must not read RTDB: $path');
  }
}
