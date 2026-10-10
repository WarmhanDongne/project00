import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/diagnostics/game_communication_log.dart';
import 'package:project00/platform/home/room/services/room_action_timing.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final log = GameCommunicationLog.instance;
  setUp(() {
    log.clear();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'real room service measures one callable for fresh create and close',
    () async {
      var now = Duration.zero;
      final calls = <String>[];
      final functions = _Functions((name) {
        calls.add(name);
        now += const Duration(milliseconds: 500);
      });
      final database = _Database((name) {
        calls.add(name);
        now += const Duration(milliseconds: 100);
      });
      final service = RoomService(
        auth: _Auth(),
        functions: functions,
        database: database,
      );

      await RoomActionTiming.run(RoomTimedAction.create, () async {
        expect(await service.createRoom(), 'ABCDE');
        return true;
      }, clock: () => now);
      final create = log.entries.reversed.toList();
      expect(calls, ['createRealtimeRoom', 'presence']);
      expect(create.last.detail, contains('total_ms=600 status=success'));
      for (final name in ['createRealtimeRoom']) {
        expect(
          create.where(
            (e) =>
                e.title.endsWith('callable:$name') &&
                e.detail.contains('elapsed_ms=500'),
          ),
          hasLength(1),
        );
      }
      expect(
        create.where(
          (e) =>
              e.title.endsWith('rtdb:presence_write') &&
              e.detail.contains('elapsed_ms=100'),
        ),
        hasLength(1),
      );

      calls.clear();
      log.clear();
      await RoomActionTiming.run(RoomTimedAction.close, () async {
        await service.closeControllerRoom('ABCDE');
        return true;
      }, clock: () => now);
      expect(calls, ['disconnect_cancel', 'closeRoom']);
      expect(log.entries.first.detail, contains('total_ms=600 status=success'));
      final text = [...create, ...log.entries].map((e) => e.asText).join('\n');
      for (final privateValue in [
        'ABCDE',
        'private-user',
        'private-room',
        'private-token',
        'private-connection',
      ]) {
        expect(text, isNot(contains(privateValue)));
      }
    },
  );

  test(
    'request failures keep their error and are not reported as successful timing',
    () async {
      final error = TimeoutException('private error payload');
      var now = Duration.zero;
      await expectLater(
        RoomActionTiming.run(RoomTimedAction.create, () async {
          await RoomActionTiming.measure<void>(
            'callable:createRealtimeRoom',
            () async {
              now = const Duration(seconds: 8);
              throw error;
            },
          );
          return true;
        }, clock: () => now),
        throwsA(same(error)),
      );
      expect(log.entries.first.level, GameCommunicationLevel.failure);
      expect(
        log.entries.first.detail,
        contains('total_ms=8000 status=failure'),
      );
      expect(
        log.entries.map((e) => e.asText).join(),
        isNot(contains('private error payload')),
      );
      expect(
        log.entries.where((e) => e.detail.contains('status=success')),
        isEmpty,
      );
    },
  );

  test(
    'late work and work outside an action cannot pollute another sample',
    () async {
      final pending = Completer<void>();
      late Future<void> lateWork;
      await RoomActionTiming.run(RoomTimedAction.create, () async {
        lateWork = RoomActionTiming.measure('late', () => pending.future);
        return false;
      });
      final firstTrace = log.entries.first.traceId;
      final firstCount = log.entries.length;
      await RoomActionTiming.run(RoomTimedAction.close, () async {
        pending.complete();
        await lateWork;
        await RoomActionTiming.measure('current', () async {});
        return true;
      });
      expect(
        log.entries.where((e) => e.traceId == firstTrace),
        hasLength(firstCount),
      );
      expect(log.entries.first.traceId, isNot(firstTrace));
      final before = log.entries.length;
      expect(await RoomActionTiming.measure('outside', () async => 42), 42);
      expect(log.entries.length, before);
    },
  );

  test(
    'only canonical failure codes enter timing, never message or details',
    () async {
      for (final code in ['failed-precondition', 'private-code']) {
        log.clear();
        final error = FirebaseFunctionsException(
          code: code,
          message: 'private-message',
          details: {'token': 'private-token'},
        );
        await expectLater(
          RoomActionTiming.run(RoomTimedAction.create, () async {
            await RoomActionTiming.measure<void>(
              'callable:createRealtimeRoom',
              () async {
                throw error;
              },
            );
            return true;
          }),
          throwsA(same(error)),
        );
        final text = log.entries.map((e) => e.asText).join();
        expect(
          text,
          contains(
            'error_code=${code == 'failed-precondition' ? code : 'unknown'}',
          ),
        );
        expect(text, isNot(contains('private-')));
      }
    },
  );
}

class _Functions extends Fake implements FirebaseFunctions {
  _Functions(this.called);
  final void Function(String) called;
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
    functions.called(name);
    final data = switch (name) {
      'createRealtimeRoom' || 'resumeRealtimeControllerRoom' => {
        'roomCode': 'ABCDE',
        'roomInstanceId': 'private-room',
        'controllerSessionId': 'private-token',
        'connectionId': 'private-connection',
        'connectionSeq': name == 'createRealtimeRoom' ? 1 : 2,
      },
      'game_common_operation_status' => {'status': 'notApplied'},
      'closeRoom' => {'success': true},
      _ => throw StateError('Unexpected callable $name'),
    };
    return _Result<T>(data as T);
  }
}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  _Result(this.data);
  @override
  final T data;
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _User extends Fake implements User {
  @override
  String get uid => 'private-user';
}

class _Database extends Fake implements FirebaseDatabase {
  _Database(this.called);
  final void Function(String) called;
  @override
  DatabaseReference ref([String? path]) => _Reference(called);
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.called);
  final void Function(String) called;
  @override
  Future<void> update(Map<String, Object?> value) async => called('presence');
  @override
  OnDisconnect onDisconnect() => _Disconnect(called);
}

class _Disconnect extends Fake implements OnDisconnect {
  _Disconnect(this.called);
  final void Function(String) called;
  @override
  Future<void> update(Map<String, Object?> value) async {}
  @override
  Future<void> cancel() async => called('disconnect_cancel');
}
