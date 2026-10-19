import 'dart:async';
import 'package:game_kit/core/diagnostics/startup_measurements.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'package:game_kit/session/controller_room_session_store.dart';
import 'package:game_kit/core/diagnostics/game_communication_log.dart';
import 'package:project00/platform/home/room/services/room_action_timing.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
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

  test(
    'pending cancellation cannot delay authoritative close or mutate a new room',
    () async {
      await h.service.createRoom();
      h.calls.clear();
      h.cancelGate = Completer<void>();
      h.closeGate = Completer<void>();
      final measurement = StartupMeasurements(enabled: true);
      StartupMeasurements.testInstance = measurement;
      addTearDown(() => StartupMeasurements.testInstance = null);
      measurement.control({
        'op': 'arm',
        'capture': 'test',
        'trial': 'one',
        'scenario': 'room_reset',
        'role': 'tablet',
        'key': 'a' * 64,
      });
      measurement.beginAction('room_reset');
      final log = GameCommunicationLog.instance;
      log.clear();
      final closing = RoomActionTiming.run(RoomTimedAction.close, () async {
        await h.service.closeControllerRoom('ABCDE');
        return true;
      });
      await h.closeEntered.future;
      expect(h.intentAtCancel, 'awaitingResult');
      expect(
        RoomSessionIdentityStore.instance.current(h.uid, 'controller', 'ABCDE'),
        isNotNull,
      );
      expect(h.cancelGate!.isCompleted, false);
      h.closeGate!.complete();
      await closing.timeout(const Duration(seconds: 2));
      final entries = log.entries.length;
      expect(
        (measurement.control({'op': 'drain'})['events'] as List).where(
          (e) => e['event'] == 'disconnect_cancel_end',
        ),
        isEmpty,
      );
      await h.replaceIdentity('new-room', 'new-connection');
      final session = GameRecoverySession.forRoom('ABCDE', h.uid)
        ..leaving = false;
      h.cancelGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(h.cancelPaths, everyElement(endsWith('/connection-initial')));
      expect(
        RoomSessionIdentityStore.instance
            .current(h.uid, 'controller', 'ABCDE')!
            .roomInstanceId,
        'new-room',
      );
      expect(session.leaving, false);
      expect(log.entries.length, entries);
      final journal = (measurement.control({'op': 'drain'})['events'] as List);
      expect(
        journal.where((e) => e['event'] == 'disconnect_cancel_end'),
        hasLength(1),
      );
      expect(
        journal.singleWhere(
          (e) => e['event'] == 'disconnect_cancel_end',
        )['value'],
        1,
      ); // no late successful timing sample
    },
  );

  test('cancel error does not fail a confirmed close', () async {
    await h.service.createRoom();
    h.failCancel = true;
    await h.service.closeControllerRoom('ABCDE');
    expect(h.calls.last, 'closeRoom');
    expect(
      RoomSessionIdentityStore.instance.current(h.uid, 'controller', 'ABCDE'),
      isNull,
    );
  });

  test(
    'unresolved cancellation does not block retry with original operation ID',
    () async {
      await h.service.createRoom();
      h.calls.clear();
      h.payloads.clear();
      h.cancelGate = Completer<void>();
      h.failClose = true;
      await expectLater(
        h.service.closeControllerRoom('ABCDE'),
        throwsException,
      );
      final payload = Map.of(h.payloads.single);
      h.failClose = false;
      h.status = 'applied';
      await h
          .newService()
          .closeControllerRoom('ABCDE')
          .timeout(const Duration(seconds: 2));
      expect(h.calls, ['closeRoom', 'game_common_operation_status']);
      expect(h.payloads.last, payload);
      h.cancelGate!.complete();
    },
  );

  test(
    'late old registration is cancelled again without cancelling resumed connection',
    () async {
      h.registrationGate = Completer<void>();
      await h.service.createRoom();
      expect(h.disconnectRegistrations, 1);
      await h.newService().closeControllerRoom('ABCDE');
      await h.replaceIdentity('replacement-room', 'replacement-connection');
      final oldRegistration = h.registrationGate!;
      h.registrationGate = null;
      await h.service.markControllerConnected('ABCDE');
      expect(h.disconnectRegistrations, 2);
      oldRegistration.complete();
      await Future<void>.delayed(Duration.zero);
      expect(h.disconnectCancellations, 2);
      expect(h.cancelPaths, everyElement(endsWith('/connection-initial')));
    },
  );

  test(
    'close intent storage failure sends neither cancellation nor close',
    () async {
      await h.service.createRoom();
      h.calls.clear();
      final original = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _IntentPreferences(fail: true);
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
      await expectLater(
        h.service.closeControllerRoom('ABCDE'),
        throwsStateError,
      );
      expect(h.calls, isEmpty);
      expect(h.disconnectCancellations, 0);
      expect(
        RoomSessionIdentityStore.instance.current(h.uid, 'controller', 'ABCDE'),
        isNotNull,
      );
    },
  );

  test(
    'identity replaced during durable intent write does not invalidate new session',
    () async {
      await h.service.createRoom();
      final original = SharedPreferencesStorePlatform.instance;
      final disk = _IntentPreferences(fail: false);
      SharedPreferencesStorePlatform.instance = disk;
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
      final closing = h.service.closeControllerRoom('ABCDE');
      await disk.entered.future;
      SharedPreferencesStorePlatform.instance = original;
      await h.replaceIdentity('replacement-room', 'replacement-connection');
      final session = GameRecoverySession.forRoom('ABCDE', h.uid)
        ..leaving = false
        ..localUsable = true
        ..serverConfirmed = true;
      disk.release.complete();
      await closing;
      expect(session.leaving, false);
      expect(session.localUsable, true);
      expect(session.serverConfirmed, true);
      expect(
        RoomSessionIdentityStore.instance
            .current(h.uid, 'controller', 'ABCDE')!
            .roomInstanceId,
        'replacement-room',
      );
      expect(h.payloads.last['roomInstanceId'], 'room-${h.uid}');
      expect(h.payloads.last['controllerSessionId'], 'controller-${h.uid}');
      expect(
        ControllerRoomSessionStore.instance.sessionIdForRoom('ABCDE'),
        'replacement-session',
      );
      expect(h.cancelPaths, everyElement(endsWith('/connection-initial')));
    },
  );

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
        // presenceProtocol은 전송 시점에만 붙는 값이라 저장된 payload에는 없습니다.
        expect(
          persisted.pendingFor(h.uid).single['payload'],
          Map.of(original)..remove('presenceProtocol'),
        );
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
  Completer<void>? cancelGate, registrationGate, closeGate;
  final closeEntered = Completer<void>();
  bool failCancel = false;
  String? intentAtCancel;
  final cancelPaths = <String>[];
  Future<void> replaceIdentity(String room, String connection) async {
    await RoomSessionIdentityStore.instance.save(
      RoomSessionIdentity(
        uid: uid,
        role: 'controller',
        roomCode: 'ABCDE',
        roomInstanceId: room,
        controllerSessionId: 'replacement-session',
        connectionId: connection,
        connectionSeq: 10,
      ),
    );
    await ControllerRoomSessionStore.instance.save(
      roomCode: 'ABCDE',
      sessionId: 'replacement-session',
    );
  }

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
    if (name == 'closeRoom') {
      if (!closeEntered.isCompleted) closeEntered.complete();
      if (closeGate != null) await closeGate!.future;
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
  OnDisconnect onDisconnect() => _Disconnect(h, path);
}

class _Disconnect extends Fake implements OnDisconnect {
  _Disconnect(this.h, this.path);
  final _Harness h;
  final String path;
  @override
  Future<void> update(Map<String, Object?> value) async {
    h.disconnectRegistrations++;
    if (h.registrationGate != null) await h.registrationGate!.future;
  }

  @override
  Future<void> cancel() async {
    h.disconnectCancellations++;
    h.cancelPaths.add(path);
    final persisted = DurableRoomOperationStore();
    await persisted.load();
    h.intentAtCancel =
        persisted
                .recordsFor(h.uid)
                .where((r) => r['kind'] == 'close')
                .firstOrNull?['state']
            as String?;
    if (h.cancelGate != null) await h.cancelGate!.future;
    if (h.failCancel) throw StateError('auxiliary failure');
  }
}

class _IntentPreferences extends InMemorySharedPreferencesStore {
  _IntentPreferences({required this.fail}) : super.empty();
  final bool fail;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.contains('mosigame_room_operations')) {
      if (!entered.isCompleted) entered.complete();
      if (fail) return false;
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}
