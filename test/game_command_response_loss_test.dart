import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/game_final_call.dart';
import 'package:game_holdem/game_holdem.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'package:game_kit/recovery/models/room_session_identity.dart';
import 'package:game_kit/recovery/services/callable_retry_policy.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
import 'package:game_kit/recovery/services/room_recovery_batch.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';
import 'package:game_kit/services/game_command_service.dart';
import 'package:game_kit/template_game.dart';
import 'package:game_liars_poker/game_liars_poker.dart';
import 'package:game_liars_poker/shared/providers/penalty_coordinator.dart';
import 'package:game_liars_poker/shared/services/command_service.dart';
import 'package:game_mafia/game_mafia.dart';
import 'package:project00/platform/home/tablet/tablet_game_start.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _identity = RoomSessionIdentity(
  uid: 'test-tablet',
  role: 'controller',
  roomCode: 'ABCDE',
  roomInstanceId: 'room-current',
  connectionId: 'connection-one',
  connectionSeq: 1,
  controllerSessionId: 'controller-session',
);
const _channel = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
  StandardMessageCodec(),
);
const _shortPolicy = CallableRetryPolicy(
  attemptTimeout: Duration(milliseconds: 30),
  totalBudget: Duration(milliseconds: 30),
  baseDelay: Duration.zero,
);

List<Object?> _error(String code, String message) => [
  'firebase_functions',
  message,
  {'code': code, 'message': message},
];

void _user(String uid) {
  FirebaseAuthPlatform.instanceFor(
    app: Firebase.app(),
    pluginConstants: {
      'APP_CURRENT_USER': [
        InternalUserInfo(
          uid: uid,
          isAnonymous: false,
          isEmailVerified: true,
        ).encode(),
        <Map<Object?, Object?>>[],
      ],
    },
  );
  expect(FirebaseAuth.instance.currentUser?.uid, uid);
}

GameRecoveryContext _context(String id, int phase) => GameRecoveryContext(
  gameInstanceId: id,
  phaseSeq: phase,
  turnSeq: phase,
  dataSeq: phase,
  resumeEpoch: 1,
);

class _Calls {
  final requests = <Map<String, dynamic>>[];
  late Future<Object?> Function(String name, Map<String, dynamic> data) reply;
  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler(_channel, (call) {
          final request = Map<String, dynamic>.from(
            (call as List).single as Map,
          );
          requests.add(
            Map<String, dynamic>.from(jsonDecode(jsonEncode(request)) as Map),
          );
          return reply(
            request['functionName'] as String,
            Map<String, dynamic>.from(request['parameters'] as Map),
          );
        });
  }

  List<Map<String, dynamic>> forName(String name) => requests
      .where((request) => request['functionName'] == name)
      .map((request) => Map<String, dynamic>.from(request['parameters'] as Map))
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(MockFirebaseApp());
  setUpAll(() async => Firebase.initializeApp());
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _user(_identity.uid);
    await RoomSessionIdentityStore.instance.clear(
      _identity.uid,
      'controller',
      'ABCDE',
    );
    await RoomSessionIdentityStore.instance.save(_identity);
    final session = GameRecoverySession.forRoom('ABCDE', _identity.uid);
    session
      ..context = _context('previous-game', 1)
      ..localUsable = true
      ..serverConfirmed = true
      ..paused = false
      ..leaving = false
      ..retryCommand = null;
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler(_channel, null);
    _user(_identity.uid);
    await RoomSessionIdentityStore.instance.clear(
      _identity.uid,
      'controller',
      'ABCDE',
    );
    GameRecoverySession.forRoom('ABCDE', _identity.uid).retryCommand = null;
  });

  test(
    'ready retry preserves operation and report sequence and retrieves saved response',
    () async {
      final session = GameRecoverySession.forRoom('ABCDE', _identity.uid);
      session.preparationBatch = RoomRecoveryBatch(wait: (_) async {});
      session.transportRecovering = false;
      session.transportConnected = true;
      var reports = 0;
      final calls = _Calls()
        ..reply = (name, data) async {
          if (name == 'game_common_operation_status') {
            return [
              {'status': 'applied'},
            ];
          }
          if (++reports == 1) {
            return _error('unavailable', 'lost acknowledgment');
          }
          return [
            {'status': 'accepted'},
          ];
        };
      calls.install();
      final result =
          await GameInterruptionCommandService(
            retryPolicy: _shortPolicy,
          ).report(
            roomCode: 'ABCDE',
            context: {
              ...session.context!.envelope,
              'connectionId': _identity.connectionId,
              'connectionSeq': _identity.connectionSeq,
            },
            reportSeq: 7,
            ready: true,
          );
      expect(result['status'], 'accepted');
      final sent = calls.forName('game_common_recovery_report');
      expect(sent.length, 2);
      expect(sent.last, sent.first);
      expect(sent.first['reportSeq'], 7);
      expect(
        calls
            .forName('game_common_operation_status')
            .map((p) => p['operationId']),
        everyElement(sent.first['commandId']),
      );
    },
  );
  test(
    'ready transient failures stop after six attempts in the same owner',
    () async {
      final session = GameRecoverySession.forRoom('ABCDE', _identity.uid);
      session.preparationBatch = RoomRecoveryBatch(wait: (_) async {});
      session.transportRecovering = false;
      session.transportConnected = true;
      final calls = _Calls()
        ..reply = (name, data) async => name == 'game_common_operation_status'
            ? [
                {'status': 'notApplied'},
              ]
            : _error('unavailable', 'offline');
      calls.install();
      await expectLater(
        GameInterruptionCommandService(retryPolicy: _shortPolicy).report(
          roomCode: 'ABCDE',
          context: session.context!.envelope,
          reportSeq: 8,
          ready: true,
        ),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      final sent = calls.forName('game_common_recovery_report');
      expect(sent.length, 6);
      expect(sent.map((p) => p['commandId']).toSet().length, 1);
      expect(sent.map((p) => p['reportSeq']).toSet(), {8});
    },
  );

  for (final game in <TemplateGame>[
    const LiarsPokerGame(),
    const FinalCallGame(),
    const MafiaGame(),
    const HoldemGame(),
  ]) {
    test(
      '${game.id}: real TemplateGame services reuse lost start ID and skip seat writes',
      () async {
        final calls = _Calls();
        final name = 'game_${game.id}_start_game';
        var attempts = 0;
        calls.reply = (function, data) async {
          if (function == 'game_common_operation_status') {
            return [
              {'status': 'applied'},
            ];
          }
          expect(function, name);
          if (++attempts == 1) {
            return _error('deadline-exceeded', 'response lost after commit');
          }
          return [
            {'success': true, 'revision': 1},
          ];
        };
        calls.install();
        final options = game.id == 'mafia'
            ? <String, Object?>{
                'composition': <String, int>{'citizen': 4, 'mafia': 2},
                'rules': <String, Object>{'discussionSeconds': 60},
              }
            : null;
        var seatWrites = 0;
        Future<bool> prepare() => prepareTabletGameStart(
          roomCode: 'ABCDE',
          saveSeats: () async {
            seatWrites++;
            return true;
          },
          startGame: () => game.startGame('ABCDE', options: options),
          isCurrent: () => true,
        );
        await expectLater(
          prepare(),
          throwsA(isA<FirebaseFunctionsException>()),
        );
        final original = calls.forName(name).single;
        final restarted = RoomSessionIdentityStore();
        await restarted.load();
        expect(
          restarted.pendingGameStart(
            _identity.uid,
            'controller',
            'ABCDE',
          )?['payload'],
          original,
        );
        GameRecoverySession.forRoom('ABCDE', _identity.uid)
          ..context = _context('started-game', 2)
          ..paused = true;
        await RoomSessionIdentityStore.instance.save(
          const RoomSessionIdentity(
            uid: 'test-tablet',
            role: 'controller',
            roomCode: 'ABCDE',
            roomInstanceId: 'room-current',
            connectionId: 'connection-two',
            connectionSeq: 2,
            controllerSessionId: 'controller-session',
          ),
        );
        expect(await prepare(), true);
        expect(seatWrites, 1);
        final replay = calls.forName(name).last;
        expect(replay['commandId'], original['commandId']);
        expect(replay['gameInstanceId'], 'previous-game');
        expect(replay['connectionId'], 'connection-two');
        expect(replay['connectionSeq'], 2);
        expect(
          calls.forName('game_common_operation_status').single['operationId'],
          original['commandId'],
        );
        expect(await hasPendingTabletGameStart('ABCDE'), false);
      },
    );
  }

  test(
    'start timeout then notApplied replays original ID; late response cannot clear newer intent',
    () async {
      final calls = _Calls();
      final late = Completer<Object?>();
      var attempts = 0;
      calls.reply = (name, data) async {
        if (name == 'game_common_operation_status') {
          return [
            {'status': 'notApplied'},
          ];
        }
        if (++attempts == 1) return late.future;
        return [
          {'success': true},
        ];
      };
      calls.install();
      await expectLater(_Command().start(), throwsA(isA<TimeoutException>()));
      final first = calls.forName('game_liars_poker_start_game').single;
      expect((await _Command().start())['success'], true);
      expect(
        calls.forName('game_liars_poker_start_game').last['commandId'],
        first['commandId'],
      );
      final newer = await RoomSessionIdentityStore.instance.retainGameStart(
        _identity,
        'game_liars_poker_start_game',
        {'roomCode': 'ABCDE'},
        {..._identity.envelope, 'commandId': 'newer-start'},
      );
      late.complete([
        {'success': true},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(
        RoomSessionIdentityStore.instance.pendingGameStart(
          _identity.uid,
          'controller',
          'ABCDE',
        )?['payload'],
        newer,
      );
    },
  );

  test(
    'pending start rejects changed game/options and keeps ID after retry already-exists',
    () async {
      final calls = _Calls();
      var attempts = 0;
      calls.reply = (name, data) async {
        if (name == 'game_common_operation_status') {
          return [
            {'status': 'notApplied'},
          ];
        }
        return _error(
          ++attempts == 1 ? 'deadline-exceeded' : 'already-exists',
          'uncertain',
        );
      };
      calls.install();
      await expectLater(
        _Command().start(),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      final first = calls.forName('game_liars_poker_start_game').single;
      await expectLater(
        _Command().start(options: {'restart': true}),
        throwsStateError,
      );
      await expectLater(
        const HoldemGame().startGame('ABCDE'),
        throwsStateError,
      );
      expect(calls.requests.length, 1);
      await expectLater(
        _Command().start(),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      expect(
        RoomSessionIdentityStore.instance.pendingGameStart(
          _identity.uid,
          'controller',
          'ABCDE',
        )?['payload']['commandId'],
        first['commandId'],
      );
    },
  );

  test(
    'definitive first rejection clears start intent; storage failure prevents transmission',
    () async {
      final calls = _Calls()
        ..reply = (name, data) async => _error('aborted', 'changed seats');
      calls.install();
      await expectLater(
        _Command().start(),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      expect(await hasPendingTabletGameStart('ABCDE'), false);
      final originalStorage = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _FailingPreferences();
      addTearDown(
        () => SharedPreferencesStorePlatform.instance = originalStorage,
      );
      await expectLater(_Command().start(), throwsStateError);
      expect(calls.requests.length, 1);
      expect(await hasPendingTabletGameStart('ABCDE'), false);
      final restartedAfterFailure = RoomSessionIdentityStore();
      await restartedAfterFailure.load();
      expect(
        restartedAfterFailure.pendingGameStart(
          _identity.uid,
          'controller',
          'ABCDE',
        ),
        isNull,
      );
      SharedPreferencesStorePlatform.instance = originalStorage;
    },
  );

  test(
    'captured retry cannot transmit under another UID or reused room instance',
    () async {
      final calls = _Calls()
        ..reply = (name, data) async => _error('deadline-exceeded', 'lost');
      calls.install();
      await expectLater(
        _Command().start(),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      final retry = GameRecoverySession.forRoom(
        'ABCDE',
        _identity.uid,
      ).retryCommand!;
      _user('different-tablet');
      await expectLater(retry(), throwsStateError);
      _user(_identity.uid);
      await RoomSessionIdentityStore.instance.save(
        const RoomSessionIdentity(
          uid: 'test-tablet',
          role: 'controller',
          roomCode: 'ABCDE',
          roomInstanceId: 'reused-room',
          connectionId: 'new-connection',
          connectionSeq: 1,
          controllerSessionId: 'new-controller-session',
        ),
      );
      await expectLater(retry(), throwsStateError);
      expect(calls.requests.length, 1);
    },
  );

  test(
    'LP coordinator recovers prepare and resolve responses with exact IDs and envelopes',
    () async {
      final calls = _Calls();
      final pendingPrepare = Completer<Object?>(),
          pendingResolve = Completer<Object?>();
      var prepares = 0, resolves = 0;
      calls.reply = (name, data) async {
        if (name == 'game_common_operation_status') {
          return [
            {'status': 'applied'},
          ];
        }
        if (name == 'game_liars_poker_prepare_penalty') {
          if (++prepares == 1) return pendingPrepare.future;
          return [
            {
              'success': true,
              'resolutionId': data['commandId'],
              'result': 'safe',
            },
          ];
        }
        if (++resolves == 1) {
          GameRecoverySession.forRoom('ABCDE', _identity.uid)
            ..context = _context('previous-game', 2)
            ..paused = true;
          return pendingResolve.future;
        }
        return [
          {'success': true, 'type': 'penaltyResolved'},
        ];
      };
      calls.install();
      final coordinator = LiarsPokerPenaltyCoordinator(
        roomCode: 'ABCDE',
        commandService: LiarsPokerCommandService(retryPolicy: _shortPolicy),
      );
      await expectLater(
        coordinator.prepare(),
        throwsA(isA<TimeoutException>()),
      );
      expect((await coordinator.prepare()).name, 'safe');
      final draw = calls.forName('game_liars_poker_prepare_penalty').first;
      expect(calls.forName('game_liars_poker_prepare_penalty').last, draw);
      await expectLater(
        coordinator.complete(),
        throwsA(isA<TimeoutException>()),
      );
      await coordinator.complete();
      final finish = calls.forName('game_liars_poker_resolve_penalty').first;
      expect(finish['resolutionId'], draw['commandId']);
      expect(finish['commandId'], isNot(draw['commandId']));
      expect(calls.forName('game_liars_poker_resolve_penalty').last, finish);
      pendingPrepare.complete([
        {'success': true, 'resolutionId': draw['commandId'], 'result': 'safe'},
      ]);
      pendingResolve.complete([
        {'success': true},
      ]);
    },
  );
}

class _Command extends GameCommandService {
  _Command() : super(retryPolicy: _shortPolicy);
  Future<Map<String, dynamic>> start({
    Map<String, dynamic> options = const {},
  }) =>
      invoke('game_liars_poker_start_game', {'roomCode': 'ABCDE', ...options});
}

class _FailingPreferences extends InMemorySharedPreferencesStore {
  _FailingPreferences() : super.empty();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}
