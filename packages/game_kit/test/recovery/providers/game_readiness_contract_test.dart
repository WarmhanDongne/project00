import 'dart:async';
import 'package:game_kit/core/diagnostics/recovery_metrics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/models/game_session_state.dart';
import 'package:game_kit/recovery/providers/game_session_controller.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
import 'package:game_kit/services/game_query_service.dart';

Map<String, dynamic> public(
  int seq, {
  bool paused = true,
  int started = 100,
  String game = 'current-game',
  String status = 'alive',
}) => {
  'gameInstanceId': game,
  'phaseSeq': 1,
  'turnSeq': 1,
  'dataSeq': seq,
  'resumeEpoch': 1,
  'startedAt': started,
  'revision': seq,
  'status': 'playing',
  'phase': 'night',
  'gameType': 'mafia',
  'players': {
    'readiness-user': {'status': status},
  },
  'recovery': {'paused': paused},
};
Map<String, dynamic> private(int seq, {String game = 'current-game'}) => {
  '_context': {
    'gameInstanceId': game,
    'phaseSeq': 1,
    'turnSeq': 1,
    'dataSeq': seq,
  },
  'role': 'citizen',
};
void main() {
  var sessionNumber = 0;
  late _Query query;
  late _Commands commands;
  late ProviderContainer container;
  late NotifierProvider<_Controller, _State> provider;
  void start() {
    RecoveryMetrics.instance.finish(success: false);
    query = _Query();
    commands = _Commands();
    container = ProviderContainer();
    provider = NotifierProvider(
      () => _Controller(query, commands, 'READY${++sessionNumber}'),
    );
    container.listen(provider, (_, _) {});
  }

  tearDown(() async {
    container.dispose();
    await query.pub.close();
    // A close started inside testWidgets belongs to its FakeAsync zone.
    // Its onDone has already been pumped; do not await that Future again here.
    if (!query.priv.isClosed) {
      await query.priv.close();
    }
  });
  testWidgets(
    'private before public waits for decoded assets and a frame; pause still blocks input',
    (tester) async {
      start();
      final game = container.read(provider.notifier);
      query.priv.add(_Event(private(1)));
      await tester.pump();
      expect(game.recoverySession.localUsable, false);
      query.pub.add(_Event(public(1)));
      await tester.pump();
      expect(game.recoverySession.localUsable, false);
      final assets = Completer<void>();
      final preparation = game.prepareScreen(() => assets.future);
      await tester.pump();
      expect(commands.reports, isEmpty);
      assets.complete();
      await tester.pump();
      await tester.pump();
      await preparation;
      await tester.pump();
      expect(game.decoded, 1);
      expect(game.recoverySession.localUsable, true);
      expect(game.recoverySession.canSend, false);
      expect(
        commands.reports.where((report) => report['ready'] == true).length,
        1,
      );
      query.pub.add(_Event(public(1, paused: false)));
      await tester.pump();
      expect(game.recoverySession.canSend, true);
    },
  );
  testWidgets(
    'new public waits for matching private and stale snapshots cannot regress readiness',
    (tester) async {
      start();
      final game = container.read(provider.notifier);
      query.pub.add(_Event(public(1, paused: false)));
      query.priv.add(_Event(private(1)));
      await tester.pump();
      final preparation = game.prepareScreen(() async {});
      await tester.pump();
      await tester.pump();
      await preparation;
      await tester.pump();
      query.pub.add(_Event(public(2, paused: false)));
      await tester.pump();
      expect(game.recoverySession.canSend, false);
      query.priv.add(_Event(private(2)));
      await tester.idle();
      expect(game.recoverySession.canSend, false);
      await tester.pump();
      expect(game.recoverySession.canSend, true);
      expect(game.decoded, 2);
      query.priv.add(_Event(private(1)));
      query.pub.add(_Event(public(1, paused: false)));
      await tester.pump();
      expect(game.recoverySession.canSend, true);
      expect(game.recoverySession.context!.dataSeq, 2);
      expect(game.decoded, 2);
      game.retrySession();
      await tester.pump();
      expect(game.recoverySession.canSend, false);
      query.priv.add(_Event(private(2)));
      query.pub.add(_Event(public(2, paused: false)));
      await tester.pump();
      await tester.pump();
      expect(game.recoverySession.canSend, true);
    },
  );
  testWidgets(
    'asset failure reports failed; explicit retry prepares assets again before releasing input',
    (tester) async {
      start();
      final game = container.read(provider.notifier);
      query.pub.add(_Event(public(1)));
      query.priv.add(_Event(private(1)));
      await tester.pump();
      var preparations = 0;
      await game.prepareScreen(() async {
        preparations++;
        if (preparations == 1) throw StateError('missing asset');
      });
      await tester.pump();
      expect(game.recoverySession.localUsable, false);
      expect(commands.reports.single['ready'], false);
      final retry = game.retryRecovery();
      await tester.pump();
      await tester.pump();
      await retry;
      query.pub.add(_Event(public(1)));
      query.priv.add(_Event(private(1)));
      await tester.idle();
      await tester.pump();
      expect(preparations, 2);
      expect(game.recoverySession.localUsable, true);
      expect(game.recoverySession.canSend, false);
    },
  );
  testWidgets(
    'eliminated phone has local protection without becoming a required private barrier',
    (tester) async {
      start();
      final game = container.read(provider.notifier);
      query.pub.add(_Event(public(1, paused: false, status: 'dead')));
      await tester.pump();
      final prepared = game.prepareScreen(() async {});
      await tester.pump();
      await tester.pump();
      await prepared;
      await tester.pump();
      expect(game.recoverySession.localUsable, true);
      expect(game.recoverySession.canSend, true);
      expect(game.decoded, 0);
    },
  );
  testWidgets(
    'input waits for server ready acknowledgement and ordinary state changes do not create a new barrier report',
    (tester) async {
      start();
      final game = container.read(provider.notifier);
      commands.readyResult = Completer<Map<String, dynamic>>();
      query.pub.add(_Event(public(1, paused: false)));
      query.priv.add(_Event(private(1)));
      await tester.pump();
      final preparation = game.prepareScreen(() async {});
      await tester.pump();
      await tester.pump();
      await preparation;
      await tester.pump();
      expect(game.recoverySession.localUsable, true);
      expect(game.recoverySession.canSend, false);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      commands.readyResult!.complete({'status': 'accepted'});
      await tester.pump();
      expect(game.recoverySession.canSend, true);
      final summary = RecoveryMetrics.instance.summaries.last;
      expect(
        summary.stages[RecoveryStage.input]! >=
            summary.stages[RecoveryStage.ready]!,
        true,
      );
      query.pub.add(_Event(public(2, paused: false)));
      query.priv.add(_Event(private(2)));
      await tester.idle();
      expect(game.recoverySession.canSend, false);
      await tester.pump();
      expect(game.recoverySession.canSend, true);
      expect(
        commands.reports.where((report) => report['ready'] == true).length,
        1,
      );
    },
  );
  testWidgets(
    'persistent private mismatch uses one thirty-second deadline across newer public states and late data needs explicit retry',
    (tester) async {
      start();
      final game = container.read(provider.notifier);
      query.pub.add(_Event(public(1, paused: false)));
      await tester.pump();
      final preparation = game.prepareScreen(() async {});
      await tester.pump();
      await tester.pump();
      await preparation;
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));
      query.pub.add(_Event(public(2, paused: false)));
      await tester.pump();
      expect(
        commands.reports.where((report) => report['ready'] == false),
        isEmpty,
      );
      await tester.pump(const Duration(seconds: 11));
      expect(game.recoverySession.canSend, false);
      expect(query.reads, greaterThan(0));
      expect(
        commands.reports.where((report) => report['ready'] == false).length,
        1,
      );
      query.priv.add(_Event(private(2)));
      await tester.pump();
      await tester.pump();
      expect(game.recoverySession.localUsable, false);
      game.retrySession();
      query.pub.add(_Event(public(2, paused: false)));
      query.priv.add(_Event(private(2)));
      await tester.pump();
      await tester.pump();
      expect(game.recoverySession.canSend, true);
    },
  );
  testWidgets(
    'matching private resolves preparation wait and obsolete deadline cannot report failure',
    (tester) async {
      start();
      final game = container.read(provider.notifier);
      query.pub.add(_Event(public(1, paused: false)));
      await tester.pump();
      final prepared = game.prepareScreen(() async {});
      await tester.pump();
      await tester.pump();
      await prepared;
      await tester.pump(const Duration(seconds: 20));
      query.priv.add(_Event(private(1)));
      await tester.pump();
      await tester.pump();
      expect(game.recoverySession.canSend, true);
      await tester.pump(const Duration(seconds: 15));
      expect(
        commands.reports.where((report) => report['ready'] == false),
        isEmpty,
      );
      expect(game.recoverySession.canSend, true);
    },
  );
  testWidgets(
    'unexpected stream completion reports failure and keeps input protected',
    (tester) async {
      start();
      final game = container.read(provider.notifier);
      query.pub.add(_Event(public(1, paused: false)));
      query.priv.add(_Event(private(1)));
      await tester.pump();
      final prepared = game.prepareScreen(() async {});
      await tester.pump();
      await tester.pump();
      await prepared;
      await tester.pump();
      expect(game.recoverySession.canSend, true);
      unawaited(query.priv.close());
      await tester.pump();
      expect(game.recoverySession.canSend, false);
      expect(commands.reports.last['ready'], false);
    },
  );
}

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

class _Query extends Fake implements GameQueryService {
  final pub = StreamController<DatabaseEvent>.broadcast(),
      priv = StreamController<DatabaseEvent>.broadcast();
  int reads = 0;
  @override
  Future<DataSnapshot> readPublicGame(String roomCode) async {
    reads++;
    return _Snapshot(null);
  }

  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) => pub.stream;
  @override
  Stream<DatabaseEvent> watchPrivatePlayer({
    required String roomCode,
    required String uid,
  }) => priv.stream;
}

class _Commands extends Fake implements GameInterruptionCommandService {
  final reports = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? readyResult;
  @override
  Future<Map<String, dynamic>> report({
    required String roomCode,
    required Map<String, dynamic> context,
    required int reportSeq,
    required bool ready,
  }) async {
    reports.add({...context, 'reportSeq': reportSeq, 'ready': ready});
    return ready && readyResult != null
        ? readyResult!.future
        : {'status': 'accepted'};
  }
}

class _State implements GameSessionState<_State> {
  const _State();
  @override
  bool get commandInFlight => false;
  @override
  String? get errorMessage => null;
  @override
  _State markCommandStarted() => this;
  @override
  _State markCommandFinished() => this;
  @override
  _State withError(String? message) => this;
  @override
  _State asRemovedGame() => this;
}

class _Controller extends GameSessionController<_State> {
  _Controller(this.query, this.interruptionCommands, this.roomCode);
  @override
  final GameQueryService query;
  @override
  final GameInterruptionCommandService interruptionCommands;
  @override
  final String roomCode;
  @override
  String get uid => 'readiness-user';
  @override
  GameInterruption? get interruption => null;
  @override
  String get commandCrashReason => 'readiness';
  int decoded = 0;
  @override
  _State build() {
    startSession(watchPrivate: true);
    return const _State();
  }

  @override
  void applyPublicValue(Object? value) {
    state = const _State();
  }

  @override
  void handlePrivateEvent(DatabaseEvent event) {
    decoded = ((event.snapshot.value as Map)['_context']['dataSeq'] as num)
        .toInt();
  }
}
