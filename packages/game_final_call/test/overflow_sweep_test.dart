import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/phone/screens/game_screen.dart';
import 'package:game_final_call/phone/widgets/top_bar.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/models/game_state.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/shared/services/command_service.dart';
import 'package:game_final_call/shared/services/game_service.dart';
import 'package:game_final_call/shared/services/query_service.dart';
import 'package:game_final_call/tablet/providers/game_stage.dart';
import 'package:game_final_call/tablet/tablet_board.dart';
import 'package:game_final_call/tablet/widgets/result_overlay.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';

import 'support/overflow_sweep.dart';

// 닉네임 최대 8자로 가장 긴 이름을 만듭니다.
const _names = ['가나다라마바사아', '서윤서윤서윤서윤', 'ABCDEFGH', '하린하린하린하린', '도윤', '지우'];

Map<String, Object?> _card(String color, int value) => {
  'id': '${color}_$value',
  'color': color,
  'value': value,
};

Map<String, Object?> _players(int count, {Set<int> eliminated = const {}}) => {
  for (var i = 0; i < count; i++)
    i == 0 ? 'me' : 'p$i': {
      'uid': i == 0 ? 'me' : 'p$i',
      'nickname': _names[i],
      'characterId': 'frog',
      'seatIndex': i,
      'team': ['red', 'blue', 'green'][count == 4 ? i % 2 : i % 3],
      'status': eliminated.contains(i) ? 'eliminated' : 'alive',
      'lives': eliminated.contains(i) ? 0 : 3 - i % 3,
    },
};

Map<String, Object?> _public({
  required String phase,
  int count = 4,
  String? turnUid = 'me',
  String? callerUid,
  String? pendingDrawUid,
  List<String> finalPending = const [],
  Map<String, Object?>? roundResult,
}) => {
  'gameInstanceId': 'g1',
  'phaseSeq': 2,
  'turnSeq': 3,
  'dataSeq': 3,
  'resumeEpoch': 1,
  'revision': 3,
  'status': 'playing',
  'phase': phase,
  'gameType': 'final_call',
  'round': 2,
  'turnUid': turnUid,
  'turnDeadlineAt': DateTime.now().millisecondsSinceEpoch + 24000,
  'deckRemainingCount': 24,
  'discardCard': _card('green', 7),
  'callerUid': callerUid,
  'pendingDrawUid': pendingDrawUid,
  'pendingDrawSource': pendingDrawUid == null ? null : 'deck',
  'finalTurnPendingUids': finalPending,
  'players': _players(count),
  'roundResult': roundResult,
};

Map<String, Object?> _private({bool pending = false}) => {
  '_context': {
    'gameInstanceId': 'g1',
    'phaseSeq': 2,
    'turnSeq': 3,
    'dataSeq': 3,
  },
  'hand': {
    for (final card in [
      _card('red', 7),
      _card('red', 3),
      _card('blue', 10),
      _card('yellow', 2),
    ])
      card['id']: card,
  },
  if (pending) 'pendingDraw': _card('green', 10),
};

Map<String, Object?> _result(int count) => {
  'scores': {for (var i = 0; i < count; i++) i == 0 ? 'me' : 'p$i': 10 + i},
  'lifeLosses': {'p1': 2, 'p3': 1},
  'revealedHands': {
    for (var i = 0; i < count; i++)
      i == 0 ? 'me' : 'p$i': [
        _card('red', 10),
        _card('blue', 10),
        _card('yellow', 10),
        _card('green', 9),
      ],
  },
};

final _cases = <String, (Map<String, Object?>, Map<String, Object?>)>{
  '4명 내 차례': (_public(phase: 'playing'), _private()),
  '4명 새 카드': (
    _public(phase: 'playing', pendingDrawUid: 'me'),
    _private(pending: true),
  ),
  '4명 다른 차례': (_public(phase: 'playing', turnUid: 'p1'), _private()),
  '6명 다른 차례': (_public(phase: 'playing', count: 6, turnUid: 'p4'), _private()),
  '6명 CALL 이후': (
    _public(
      phase: 'finalTurns',
      count: 6,
      turnUid: 'me',
      callerUid: 'p1',
      finalPending: ['me', 'p3'],
    ),
    _private(),
  ),
  '6명 라운드 결과': (
    _public(
      phase: 'roundResult',
      count: 6,
      turnUid: null,
      callerUid: 'p1',
      roundResult: _result(6),
    ),
    _private(),
  ),
};

Future<(FinalCallController, ProviderContainer, _Query)> _controller(
  WidgetTester tester,
  (Map<String, Object?>, Map<String, Object?>) data,
) async {
  final query = _Query();
  final container = ProviderContainer();
  final provider = NotifierProvider<FinalCallController, FinalCallGameState>(
    () => FinalCallController(
      roomCode: 'R1',
      uid: 'me',
      service: FinalCallService(
        command: _Commands(),
        query: query,
        interruption: _Reports(),
      ),
    ),
  );
  container.listen(provider, (_, _) {});
  final game = container.read(provider.notifier);
  query.pub.add(_Event(data.$1));
  query.priv.add(_Event(data.$2));
  await tester.pump();
  return (game, container, query);
}

void main() {
  testWidgets('파이널콜 휴대폰 화면은 모든 가로 휴대폰 크기에서 넘치지 않는다', (tester) async {
    await loadSweepFonts(tester);
    addTearDown(tester.view.reset);
    final sweep = OverflowSweep()..start();
    addTearDown(sweep.stop);
    for (final device in sweepPhonesLandscape) {
      applySweepDevice(tester, device);
      for (final MapEntry(key: name, value: data) in _cases.entries) {
        sweep.where = '휴대폰 $device $name';
        final (game, container, query) = await _controller(tester, data);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: sweepTheme(),
              // 공용 셸처럼 게임 화면 위 안전 영역에 상단바를 겹쳐 그립니다.
              home: Stack(
                children: [
                  Positioned.fill(
                    child: FinalCallPhoneGameScreen(
                      controller: game,
                      handRevealed: true,
                      selectedCardId: name.contains('새 카드') ? 'red_3' : null,
                      selectedFinalCardIds: const {},
                      visibleCallerUid: data.$1['callerUid'] as String?,
                      onRevealStarted: () {},
                      onRevealCompleted: () {},
                      onSelectedCardChanged: (_) {},
                      onFinalCardSelected: (_) {},
                      onCompleteTurn: (_) async {},
                      replacingCardId: null,
                      replacementInProgress: false,
                      onExitRoom: () {},
                      regions: const PhoneGameRegions(
                        showTopBar: true,
                        showHand: true,
                        showTimer: true,
                        showActions: true,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: FinalCallPhoneTopBar(
                        controller: game,
                        onExitRoom: () {},
                        onRulesPressed: (_) {},
                        visibleCallerUid: data.$1['callerUid'] as String?,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        sweep.scanText(tester);
        await sweep.shot(tester, sweep.where);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await query.close();
      }
    }
    sweep.stop();
    expect(sweep.problems.toList()..sort(), isEmpty);
  });

  testWidgets('파이널콜 태블릿 화면은 모든 태블릿 크기에서 넘치지 않는다', (tester) async {
    await loadSweepFonts(tester);
    addTearDown(tester.view.reset);
    final sweep = OverflowSweep()..start();
    addTearDown(sweep.stop);
    for (final device in sweepTablets) {
      applySweepDevice(tester, device);
      for (final MapEntry(key: name, value: data) in _cases.entries) {
        final stage = name.contains('라운드 결과')
            ? FinalCallTabletStage.roundResult
            : FinalCallTabletStage.playing;
        sweep.where = '태블릿 $device $name';
        final (game, container, query) = await _controller(tester, data);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: sweepTheme(),
              home: Scaffold(
                body: FinalCallTabletGameLayer(
                  controller: game,
                  stage: stage,
                  flowConfig: buildFinalCallTabletFlowConfig(
                    closingMessage: '',
                  ),
                  onRoundRevealCompleted: () {},
                  onDealingCompleted: () {},
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        sweep.scanText(tester);
        await sweep.shot(tester, sweep.where);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await query.close();
      }
      // 최종 우승 화면(이름이 긴 두 사람).
      sweep.where = '태블릿 $device 우승';
      await tester.pumpWidget(
        MaterialApp(
          theme: sweepTheme(),
          home: FinalCallResultOverlay(
            winners: [
              for (final (i, name) in _names.take(2).indexed)
                FinalCallPlayer(
                  uid: 'w$i',
                  nickname: name,
                  characterId: 'frog',
                  seatIndex: i,
                  team: FinalCallTeam.green,
                  status: 'alive',
                  lives: 3,
                ),
            ],
            winningTeam: FinalCallTeam.green,
            onRestart: () {},
            onHome: () {},
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      sweep.scanText(tester);
      await sweep.shot(tester, sweep.where);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    sweep.stop();
    expect(sweep.problems.toList()..sort(), isEmpty);
  });
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

class _Query extends Fake implements FinalCallQueryService {
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
  Future<void> close() async {
    await pub.close();
    await priv.close();
  }
}

class _Commands extends Fake implements FinalCallCommandService {
  @override
  Future<void> warmUpGameplayCommands() async {}
}

class _Reports extends Fake implements GameInterruptionCommandService {
  @override
  Future<Map<String, dynamic>> report({
    required String roomCode,
    required Map<String, dynamic> context,
    required int reportSeq,
    required bool ready,
  }) async => {'status': 'accepted'};
}
