import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
import 'package:game_kit/penalty/roulette.dart';
import 'package:game_liars_poker/shared/models/game_state.dart';
import 'package:game_liars_poker/shared/providers/game_controller.dart';
import 'package:game_liars_poker/shared/services/command_service.dart';
import 'package:game_liars_poker/shared/services/game_service.dart';
import 'package:game_liars_poker/shared/services/query_service.dart';

void main() {
  var number = 0;
  late ProviderContainer container;
  late _Query query;
  late _Reports reports;
  late _Commands commands;
  late LiarsPokerController game;
  void start({bool failFirst = false, String? room, int minimumSeq = 0}) {
    query = _Query();
    reports = _Reports()
      ..failFirst = failFirst
      ..minimumSeq = minimumSeq;
    commands = _Commands();
    container = ProviderContainer();
    final provider =
        NotifierProvider<LiarsPokerController, LiarsPokerGameState>(
          () => LiarsPokerController(
            roomCode: room ?? 'LPPROBE${++number}',
            uid: 'phone',
            service: LiarsPokerService(
              command: commands,
              query: query,
              interruption: reports,
            ),
          ),
        );
    container.listen(provider, (_, _) {});
    game = container.read(provider.notifier);
  }

  tearDown(() async {
    container.dispose();
    await query.pub.close();
    await query.priv.close();
  });
  Future<void> ready(WidgetTester tester) async {
    query.pub.add(_Event(_public()));
    query.priv.add(_Event(_private()));
    await tester.pump();
    game.reportScreenReady(assetsReady: true);
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'controller recreation on the same connection cannot reuse an old report sequence',
    (tester) async {
      start();
      await ready(tester);
      final previousSeq = reports.lastSeq;
      final room = game.roomCode;
      container.dispose();
      unawaited(query.pub.close());
      unawaited(query.priv.close());
      await tester.pump();
      start(room: room, minimumSeq: previousSeq);
      await ready(tester);
      expect(reports.lastSeq, greaterThan(previousSeq));
      expect(game.recoverySession.canSend, true);
    },
  );
  testWidgets(
    'same penalty public revision preserves exactly one roulette completion',
    (tester) async {
      start();
      await ready(tester);
      expect(game.recoverySession.canSend, true);
      expect(await game.prepareRoulette(), RouletteResult.safe);
      expect(game.isResolvingPenalty, true);
      query.pub.add(_Event({..._public(), 'revision': 2}));
      await tester.pump();
      expect(game.isResolvingPenalty, true);
      await game.resolveRoulette(RouletteResult.safe);
      expect(commands.resolveCalls, 1);
      expect(game.phase, 'penalty');
    },
  );
  testWidgets(
    'final ready failure exposes retry without requiring another event',
    (tester) async {
      start(failFirst: true);
      await ready(tester);
      expect(game.localUsable, false);
      expect(reports.calls, 2);
      expect(game.recoverySession.serverConfirmed, false);
      await tester.pump(const Duration(seconds: 31));
      expect(reports.calls, 2);
      expect(game.recoverySession.canSend, false);
      expect(game.errorMessage, isNotNull);
    },
  );
  testWidgets(
    'pause preserves draw and defers completed animation until ready',
    (tester) async {
      start();
      await ready(tester);
      final scope = game.rouletteScope;
      await game.prepareRoulette(scope: scope);
      query.pub.add(
        _Event({
          ..._public(),
          'revision': 2,
          'recovery': {'paused': true, 'pauseId': 'pause'},
        }),
      );
      await tester.pump();
      await tester.pump();
      await game.resolveRoulette(RouletteResult.safe, scope: scope);
      expect(commands.resolveCalls, 0);
      query.pub.add(_Event({..._public(), 'revision': 3}));
      await tester.pump();
      await tester.pump();
      expect(commands.resolveCalls, 1);
      expect(commands.prepareCalls, 1);
      await game.resolveRoulette(RouletteResult.safe, scope: scope);
      expect(commands.resolveCalls, 1);
    },
  );
  testWidgets('failed resolve retries the same draw without another prepare', (
    tester,
  ) async {
    start();
    await ready(tester);
    commands.failResolve = true;
    await game.prepareRoulette();
    await game.resolveRoulette(RouletteResult.safe);
    expect(game.errorMessage, isNotNull);
    commands.failResolve = false;
    expect(await game.prepareRoulette(), RouletteResult.safe);
    await game.resolveRoulette(RouletteResult.safe);
    expect(commands.prepareCalls, 1);
    expect(commands.resolveCalls, 2);
  });
  testWidgets('old prepare and animation cannot change a new penalty', (
    tester,
  ) async {
    start();
    await ready(tester);
    commands.delayedPrepare = Completer<Map<String, dynamic>>();
    final oldScope = game.rouletteScope;
    final prepare = game.prepareRoulette(scope: oldScope);
    query.pub.add(
      _Event({
        ..._public(),
        'revision': 2,
        'phaseSeq': 3,
        'turnSeq': 3,
        'dataSeq': 3,
        'penaltyTargetUid': 'other',
      }),
    );
    query.priv.add(
      _Event({
        '_context': {
          'gameInstanceId': 'probe-game',
          'phaseSeq': 3,
          'turnSeq': 3,
          'dataSeq': 3,
        },
        'hand': {},
      }),
    );
    await tester.pump();
    await tester.pump();
    commands.delayedPrepare!.complete({
      'resolutionId': 'old',
      'result': 'safe',
    });
    expect(await prepare, isNull);
    await game.resolveRoulette(RouletteResult.safe, scope: oldScope);
    expect(commands.resolveCalls, 0);
    expect(game.penaltyTargetUid, 'other');
    expect(game.isResolvingPenalty, false);
    expect(game.errorMessage, isNull);
  });
  testWidgets(
    'late resolve failure cannot mark ended game or new game as failed',
    (tester) async {
      start();
      await ready(tester);
      await game.prepareRoulette();
      commands.delayedResolve = Completer<Map<String, dynamic>>();
      final resolve = game.resolveRoulette(RouletteResult.safe);
      query.pub.add(
        _Event({
          ..._public(),
          'revision': 2,
          'status': 'finished',
          'phase': 'finished',
        }),
      );
      await tester.pump();
      commands.delayedResolve!.completeError(TimeoutException('late'));
      await resolve;
      expect(game.errorMessage, isNull);
      expect(game.isResolvingPenalty, false);
      expect(game.rouletteRetry, 0);
    },
  );
}

Map<String, dynamic> _public() => {
  'gameInstanceId': 'probe-game',
  'phaseSeq': 2,
  'turnSeq': 2,
  'dataSeq': 2,
  'resumeEpoch': 1,
  'startedAt': 100,
  'revision': 1,
  'status': 'playing',
  'phase': 'penalty',
  'gameType': 'liars_poker',
  'penaltyTargetUid': 'phone',
  'players': {
    'phone': {'status': 'alive', 'remainingCardCount': 5},
    'other': {'status': 'alive', 'remainingCardCount': 5},
  },
  'recovery': {'paused': false},
};
Map<String, dynamic> _private() => {
  '_context': {
    'gameInstanceId': 'probe-game',
    'phaseSeq': 2,
    'turnSeq': 2,
    'dataSeq': 2,
  },
  'hand': {
    'card-1': {'rank': 'K'},
  },
};

class _Snapshot extends Fake implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
  @override
  bool get exists => value != null;
}

class _Event extends Fake implements DatabaseEvent {
  _Event(Object? value) : snapshot = _Snapshot(value);
  @override
  final DataSnapshot snapshot;
}

class _Query extends Fake implements LiarsPokerQueryService {
  final pub = StreamController<DatabaseEvent>.broadcast();
  final priv = StreamController<DatabaseEvent>.broadcast();
  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) => pub.stream;
  @override
  Stream<DatabaseEvent> watchPrivatePlayer({
    required String roomCode,
    required String uid,
  }) => priv.stream;
  @override
  Future<DataSnapshot> readPublicGame(String roomCode) async => _Snapshot(null);
}

class _Commands extends Fake implements LiarsPokerCommandService {
  int resolveCalls = 0, prepareCalls = 0;
  bool failResolve = false;
  Completer<Map<String, dynamic>>? delayedPrepare, delayedResolve;
  @override
  Future<Map<String, dynamic>> preparePenalty({
    required String roomCode,
  }) async {
    prepareCalls++;
    return delayedPrepare?.future ??
        {'resolutionId': 'probe-resolution', 'result': 'safe', 'success': true};
  }

  @override
  Future<Map<String, dynamic>> resolvePenalty({
    required String roomCode,
    required String resolutionId,
  }) async {
    resolveCalls++;
    if (failResolve) {
      throw TimeoutException('lost resolve');
    }
    return delayedResolve?.future ?? {'success': true};
  }
}

class _Reports extends Fake implements GameInterruptionCommandService {
  int calls = 0, lastSeq = 0, minimumSeq = 0;
  bool failFirst = false;
  @override
  Future<Map<String, dynamic>> report({
    required String roomCode,
    required Map<String, dynamic> context,
    required int reportSeq,
    required bool ready,
  }) async {
    calls++;
    lastSeq = reportSeq;
    if (failFirst && calls == 1) {
      throw TimeoutException('Simulated lost ready acknowledgment');
    }
    return {'status': reportSeq > minimumSeq ? 'accepted' : 'ignored'};
  }
}
