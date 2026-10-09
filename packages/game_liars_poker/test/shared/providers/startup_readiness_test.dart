import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
import 'package:game_liars_poker/shared/models/game_state.dart';
import 'package:game_liars_poker/shared/providers/game_controller.dart';
import 'package:game_liars_poker/shared/services/command_service.dart';
import 'package:game_liars_poker/shared/services/game_service.dart';
import 'package:game_liars_poker/shared/services/query_service.dart';

void main() {
  var sessionNumber = 0;
  late ProviderContainer container;
  late _Query query;
  late _Reports reports;
  late LiarsPokerController game;
  void start() {
    query = _Query();
    reports = _Reports();
    container = ProviderContainer();
    final provider =
        NotifierProvider<LiarsPokerController, LiarsPokerGameState>(
          () => LiarsPokerController(
            roomCode: 'LPREADY${++sessionNumber}',
            uid: 'phone',
            service: LiarsPokerService(
              command: _Commands(),
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

  testWidgets('dealing prepares assets and reports ready before hands exist', (
    tester,
  ) async {
    start();
    var dataReady = false;
    unawaited(game.waitForInitialData().then((_) => dataReady = true));
    query.pub.add(_Event(_public('dealing')));
    await tester.pump();
    expect(
      dataReady,
      true,
      reason: 'Do not wait for a hand behind the ready barrier',
    );
    expect(game.isEntryDataReady, false);
    expect(game.players.keys, contains('phone'));
    final prepared = game.prepareScreen(() async {});
    await tester.pump();
    await tester.pump();
    await prepared;
    await tester.pump();
    expect(reports.ready, [true]);
    expect(game.localUsable, true);
    expect(
      game.recoverySession.canSend,
      false,
      reason: 'The server pause still blocks play',
    );
    expect(game.isEntryDataReady, false);
  });

  testWidgets(
    'joining a running game still waits for its matching private hand',
    (tester) async {
      start();
      var dataReady = false;
      unawaited(game.waitForInitialData().then((_) => dataReady = true));
      query.pub.add(_Event(_public('playing')));
      await tester.pump();
      expect(dataReady, false);
      query.priv.add(_Event(_private('old-game')));
      await tester.pump();
      expect(dataReady, false);
      query.priv.add(_Event(_private('liars-startup')));
      await tester.pump();
      expect(dataReady, true);
      expect(game.isEntryDataReady, true);
      expect(game.handCards, hasLength(1));
      final prepared = game.prepareScreen(() async {});
      await tester.pump();
      await tester.pump();
      await prepared;
      await tester.pump();
      expect(reports.ready, [true]);
    },
  );
  testWidgets(
    'play selection remains blocked through preparation and server pause',
    (tester) async {
      start();
      final value = _public('playing');
      (value['players'] as Map)['other'] = {
        'status': 'alive',
        'remainingCardCount': 5,
      };
      query.pub.add(_Event(value));
      query.priv.add(_Event(_private('liars-startup')));
      await tester.pump();
      expect(game.isEntryDataReady, true);
      expect(game.canSelectCards, false);
      final prepared = game.prepareScreen(() async {});
      await tester.pump();
      await tester.pump();
      await prepared;
      await tester.pump();
      expect(game.localUsable, true);
      expect(game.canSelectCards, false);
      query.pub.add(
        _Event({
          ...value,
          'revision': 2,
          'recovery': {'paused': false},
        }),
      );
      await tester.pump();
      expect(game.canSelectCards, true);
      game.recoverySession.transportConnected = false;
      game.recoverySession.changed();
      expect(game.canSelectCards, false);
      expect(game.canSubmitCards, false);
      expect(game.canCallLiar, false);
      expect(game.canFoldLastCardChallenge, false);
    },
  );
}

Map<String, dynamic> _public(String phase) => {
  'gameInstanceId': 'liars-startup',
  'phaseSeq': 1,
  'turnSeq': 1,
  'dataSeq': 1,
  'resumeEpoch': 1,
  'startedAt': 100,
  'revision': 1,
  'status': 'playing',
  'phase': phase,
  'gameType': 'liars_poker',
  'players': {
    'phone': {'status': 'alive', 'remainingCardCount': 5},
  },
  'recovery': {'paused': true, 'pauseId': 'startup'},
};

Map<String, dynamic> _private(String gameId) => {
  '_context': {
    'gameInstanceId': gameId,
    'phaseSeq': 1,
    'turnSeq': 1,
    'dataSeq': 1,
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

class _Commands extends Fake implements LiarsPokerCommandService {}

class _Reports extends Fake implements GameInterruptionCommandService {
  final ready = <bool>[];
  @override
  Future<Map<String, dynamic>> report({
    required String roomCode,
    required Map<String, dynamic> context,
    required int reportSeq,
    required bool ready,
  }) async {
    this.ready.add(ready);
    return {'status': 'accepted'};
  }
}
