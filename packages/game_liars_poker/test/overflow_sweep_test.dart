import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/penalty/roulette.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
import 'package:game_liars_poker/phone/phone_board.dart';
import 'package:game_liars_poker/phone/screens/game_screen.dart';
import 'package:game_liars_poker/phone/widgets/spectator.dart';
import 'package:game_liars_poker/shared/models/game_state.dart';
import 'package:game_liars_poker/shared/providers/game_controller.dart';
import 'package:game_liars_poker/shared/services/command_service.dart';
import 'package:game_liars_poker/shared/services/game_service.dart';
import 'package:game_liars_poker/shared/services/query_service.dart';
import 'package:game_liars_poker/tablet/providers/game_stage.dart';
import 'package:game_liars_poker/tablet/screens/game_penalty.dart';
import 'package:game_liars_poker/tablet/tablet_board.dart';
import 'package:game_liars_poker/tablet/widgets/liar_reveal_overlay.dart';
import 'package:game_liars_poker/tablet/widgets/penalty_panels.dart';
import 'package:game_liars_poker/tablet/widgets/result.dart';
import 'package:game_liars_poker/tablet/widgets/seat_plate.dart';

import 'support/overflow_sweep.dart';

// 최대 6명, 닉네임 최대 8자로 가장 긴 경우를 만듭니다.
const _names = [
  '가나다라마바사아',
  '서윤서윤서윤서윤',
  'ABCDEFGH',
  'WWWWWWWW',
  '하린하린하린하린',
  '도윤도윤도윤도윤',
];

String _uid(int i) => i == 0 ? 'phone' : 'p$i';

Map<String, Object?> _player(int i, {bool out = false, int cards = 5}) => {
  'uid': _uid(i),
  'seatIndex': i,
  'nickname': _names[i],
  'characterId': 'frog',
  'status': out ? 'eliminated' : 'alive',
  'remainingCardCount': out ? 0 : cards,
  'penaltyCount': i % 3,
};

Map<String, Object?> _public(
  String phase, {
  int count = 6,
  String turnUid = 'phone',
  Set<int> out = const {},
  Map<String, Object?> extra = const {},
}) => {
  'gameInstanceId': 'g1',
  'phaseSeq': 2,
  'turnSeq': 3,
  'dataSeq': 3,
  'resumeEpoch': 1,
  'startedAt': 100,
  'revision': 3,
  'status': 'playing',
  'phase': phase,
  'gameType': 'liars_poker',
  'table': 'K',
  'round': 2,
  'turnUid': turnUid,
  'turnDeadlineAt': DateTime.now().millisecondsSinceEpoch + 24000,
  'players': {
    for (var i = 0; i < count; i++)
      _uid(i): _player(
        i,
        out: out.contains(i),
        cards: phase == 'lastCardChallenge' ? 1 : 5,
      ),
  },
  ...extra,
};

final _private = {
  '_context': {
    'gameInstanceId': 'g1',
    'phaseSeq': 2,
    'turnSeq': 3,
    'dataSeq': 3,
  },
  'hand': {
    'c1': {'rank': 'K'},
    'c2': {'rank': 'Q'},
    'c3': {'rank': 'A'},
    'c4': {'rank': 'A'},
    'c5': {'rank': 'JOKER'},
  },
};

final _cases = <String, Map<String, Object?>>{
  '내 차례 3명': _public('playing', count: 3),
  '다른 차례 6명': _public('playing', turnUid: 'p4'),
  '마지막 카드': _public('lastCardChallenge', count: 2),
  '벌칙 대상': _public(
    'penalty',
    extra: {
      'penaltyTargetUid': 'phone',
      'lastPlay': {
        'playId': 'play1',
        'playerUid': 'phone',
        'revealed': true,
        'cardCount': 3,
        'actualRanks': ['K', 'Q', 'A'],
      },
    },
  ),
  '벌칙 결과': _public(
    'penalty',
    turnUid: 'p2',
    extra: {
      'penaltyTargetUid': 'p2',
      'penaltyResult': {'targetUid': 'p2', 'result': 'safe', 'resolvedAt': 1},
    },
  ),
};

Future<(LiarsPokerController, ProviderContainer, _Query)> _controller(
  WidgetTester tester,
  Map<String, Object?> public,
) async {
  final query = _Query();
  final container = ProviderContainer();
  final provider = NotifierProvider<LiarsPokerController, LiarsPokerGameState>(
    () => LiarsPokerController(
      roomCode: 'R1',
      uid: 'phone',
      service: LiarsPokerService(
        command: _Commands(),
        query: query,
        interruption: _Reports(),
      ),
    ),
  );
  container.listen(provider, (_, _) {});
  final game = container.read(provider.notifier);
  query.pub.add(_Event(public));
  query.priv.add(_Event(_private));
  await tester.pump();
  return (game, container, query);
}

List<TabletSeatInfo> _seats(int count) => [
  for (var i = 0; i < count; i++)
    TabletSeatInfo(
      nickname: _names[i],
      characterId: 'frog',
      penaltyCount: i % 3,
      remainingCardCount: i == 3 ? 0 : 5,
      eliminated: i == 3,
    ),
];

void main() {
  testWidgets('라이어스 포커 휴대폰 화면은 모든 휴대폰 크기·방향에서 넘치지 않는다', (tester) async {
    await loadSweepFonts(tester);
    addTearDown(tester.view.reset);
    final sweep = OverflowSweep()..start();
    addTearDown(sweep.stop);
    for (final device in [...sweepPhones, ...sweepPhonesLandscape]) {
      applySweepDevice(tester, device);
      for (final MapEntry(key: name, value: public) in _cases.entries) {
        sweep.where = '휴대폰 $device $name';
        final (game, container, query) = await _controller(tester, public);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (_, _) => MaterialApp(
                theme: sweepTheme(),
                home: LiarsPokerPhoneGameScreen(
                  controller: game,
                  flowConfig: buildLiarsPokerPhoneFlowConfig(
                    roundNumber: 2,
                    tableCardValue: 'K',
                  ),
                ),
              ),
            ),
          ),
        );
        // 게임 시작·라운드 안내가 끝난 뒤에 손패를 누를 수 있습니다.
        for (var i = 0; i < 48; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        // 손패는 눌러야 펼쳐집니다.
        final size = tester.view.physicalSize / tester.view.devicePixelRatio;
        await tester.tapAt(size.center(Offset.zero));
        for (var i = 0; i < 24; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        sweep.scanText(tester);
        await sweep.shot(tester, sweep.where);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await query.close();
      }
      // 탈락 뒤 관전 목록입니다.
      sweep.where = '휴대폰 $device 관전';
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            theme: sweepTheme(),
            home: Scaffold(
              body: PhoneSpectator(
                players: [
                  for (var i = 0; i < 6; i++)
                    PhoneGamePlayer.fromMap(_uid(i), _player(i, out: i == 0)),
                ],
                meUid: 'phone',
                turnUid: 'p2',
                provider: _Room(),
                onExitRoom: () async => true,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      sweep.scanText(tester);
      await sweep.shot(tester, sweep.where);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    sweep.stop();
    expect(sweep.problems.toList()..sort(), isEmpty);
  });

  testWidgets('라이어스 포커 태블릿 화면은 모든 태블릿 크기에서 넘치지 않는다', (tester) async {
    await loadSweepFonts(tester);
    addTearDown(tester.view.reset);
    final sweep = OverflowSweep()..start();
    addTearDown(sweep.stop);
    final screens = <String, Widget Function()>{
      '테이블 6명': () => LiarsPokerTabletGameLayer(
        stage: LiarsPokerTabletStage.playing,
        flowConfig: buildLiarsPokerTabletFlowConfig(roundNumber: 2),
        playerCount: 6,
        playerSeatIndexes: const [0, 1, 2, 3, 4, 5],
        dealPlayerSeatIndexes: const [0, 1, 2, 4, 5],
        cardsPerPlayer: 5,
        roundNumber: 2,
        cardPileVersion: 1,
        table: 'K',
        seats: _seats(6),
        currentTurnPlayerIndex: 4,
        turnDeadlineAt: DateTime.now().millisecondsSinceEpoch + 24000,
        claimPlayerIndex: 2,
        claimCount: 3,
        onDealCompleted: () {},
        onRoundRevealCompleted: () {},
        onRestartGame: () {},
        onExitToLobby: () {},
        winnerPlayer: null,
      ),
      'LIAR 공개': () => const TabletLiarRevealOverlay(
        tableCardValue: 'K',
        cardValues: ['A', 'Q', 'JOKER'],
        caught: TabletRevealPerson(
          nickname: '가나다라마바사아',
          characterId: 'frog',
          penaltyCount: 2,
        ),
        caller: TabletRevealPerson(nickname: '서윤서윤서윤서윤', characterId: 'frog'),
      ),
      '룰렛': () => LiarsPokerTabletGamePenalty(
        attemptCount: 2,
        characterId: 'frog',
        isResolving: false,
        onPrepareResult: () async => null,
        onResult: (_) {},
        layout: TabletPenaltyLayout(
          seats: _seats(6),
          seatIndexes: const [0, 1, 2, 3, 4, 5],
          targetIndex: 1,
        ),
      ),
      '룰렛 생존': () => LiarsPokerTabletGamePenalty(
        attemptCount: 2,
        characterId: 'frog',
        isResolving: false,
        onPrepareResult: () async => null,
        onResult: (_) {},
        layout: TabletPenaltyLayout(
          seats: _seats(6),
          seatIndexes: const [0, 1, 2, 3, 4, 5],
          targetIndex: 1,
        ),
        result: RouletteResult.safe,
      ),
      '룰렛 탈락': () => LiarsPokerTabletGamePenalty(
        attemptCount: 3,
        characterId: 'frog',
        isResolving: false,
        onPrepareResult: () async => null,
        onResult: (_) {},
        layout: TabletPenaltyLayout(
          seats: _seats(6),
          seatIndexes: const [0, 1, 2, 3, 4, 5],
          targetIndex: 4,
        ),
        result: RouletteResult.eliminated,
      ),
      '우승': () => Result(
        winnerPlayer: const PlayerLayoutPlayer(
          uid: 'p1',
          nickname: '서윤서윤서윤서윤',
          characterId: 'frog',
          seatIndex: 1,
        ),
        onRestartGame: () {},
        onExitToLobby: () {},
      ),
    };
    for (final device in sweepTablets) {
      applySweepDevice(tester, device);
      for (final MapEntry(key: name, value: build) in screens.entries) {
        sweep.where = '태블릿 $device $name';
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(1194, 834),
            builder: (_, _) => MaterialApp(
              theme: sweepTheme(),
              home: Scaffold(body: build()),
            ),
          ),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        sweep.scanText(tester);
        await sweep.shot(tester, sweep.where);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    sweep.stop();
    expect(sweep.problems.toList()..sort(), isEmpty);
  });
}

class _Room extends Fake implements GameRoomContext {}

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
  Future<void> close() async {
    await pub.close();
    await priv.close();
  }
}

class _Commands extends Fake implements LiarsPokerCommandService {}

class _Reports extends Fake implements GameInterruptionCommandService {
  @override
  Future<Map<String, dynamic>> report({
    required String roomCode,
    required Map<String, dynamic> context,
    required int reportSeq,
    required bool ready,
  }) async => {'status': 'accepted'};
}
