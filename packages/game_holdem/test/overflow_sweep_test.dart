import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/phone/screens/game_screen.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_holdem/tablet/screens/table_screen.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';

import 'support/fixtures.dart';
import 'support/overflow_sweep.dart';

// 닉네임 최대 8자와 큰 칩 숫자로 가장 긴 글자를 만듭니다.
const _names = [
  '가나다라마바사아',
  '민지',
  '하준',
  'ABCDEFGH',
  '서윤서윤서윤서윤',
  '도윤',
  '지우',
  '하린하린하린',
];

Map<String, HoldemPlayerModel> _crowd() => {
  for (var i = 0; i < 8; i++)
    i == 0 ? 'me' : 'p$i': player(
      i == 0 ? 'me' : 'p$i',
      _names[i],
      i,
      stack: 1234567 - i * 1111,
      streetContribution: i.isOdd ? 123400 : 0,
      handStatus: i == 3 ? 'folded' : (i == 5 ? 'allIn' : 'active'),
    ),
};

PlayerLayoutModel _layoutFor(Map<String, HoldemPlayerModel> players) =>
    PlayerLayoutModel(
      players: [
        for (final p in players.values)
          PlayerLayoutPlayer(
            uid: p.uid,
            nickname: p.nickname,
            characterId: 'frog',
            seatIndex: p.seatIndex,
          ),
      ],
    );

HoldemHandResultModel _result(String winner) => HoldemHandResultModel(
  reason: 'showdown',
  winnerUids: [winner],
  awards: {winner: 1234567},
  revealedHands: {
    winner: [card('k', 'diamonds'), card('q', 'diamonds')],
  },
  handCategories: {winner: 'straightFlush'},
  bestCards: {
    winner: [
      card('k', 'diamonds'),
      card('q', 'diamonds'),
      card('j', 'diamonds'),
      card('10', 'diamonds'),
      card('9', 'diamonds'),
    ],
  },
);

Map<String, HoldemGameState> _states() {
  final crowd = _crowd();
  return {
    '내 차례': playingState(legalActions: callOrRaise),
    '상대 차례': playingState(turnUid: 'rival'),
    '분배': playingState(phase: 'dealing', turnUid: null),
    '폴드': playingState(
      turnUid: 'rival',
      players: {
        'me': player('me', '민지', 0, handStatus: 'folded'),
        'rival': player('rival', '하준', 1),
      },
    ),
    '8명 내 차례': playingState(legalActions: callOrRaise, players: crowd),
    '8명 상대 차례': playingState(turnUid: 'p4', players: crowd),
    '승리': playingState(
      phase: 'handResult',
      turnUid: null,
      result: _result('me'),
    ),
    '패배': playingState(
      phase: 'handResult',
      turnUid: null,
      result: _result('rival'),
    ),
    '8명 결과': playingState(
      phase: 'handResult',
      turnUid: null,
      players: crowd,
      result: _result('p4'),
    ),
  };
}

void main() {
  late GameAssetStore previousStore;
  setUp(() {
    previousStore = GameAssetStore.instance;
    GameAssetStore.instance = FakeHoldemAssetStore();
  });
  tearDown(() => GameAssetStore.instance = previousStore);

  testWidgets('홀덤 휴대폰 화면은 모든 휴대폰 크기에서 넘치지 않는다', (tester) async {
    await loadSweepFonts(tester);
    addTearDown(tester.view.reset);
    final sweep = OverflowSweep()..start();
    addTearDown(sweep.stop);
    for (final device in sweepPhones) {
      applySweepDevice(tester, device);
      for (final MapEntry(key: name, value: state) in _states().entries) {
        sweep.where = '휴대폰 $device $name';
        await tester.pumpWidget(
          MaterialApp(
            theme: sweepTheme(),
            home: Scaffold(
              body: HoldemPhoneGameScreen(
                game: state,
                uid: 'me',
                onAction: (_, {amount}) async => true,
              ),
            ),
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        sweep.scanText(tester);
        if (name.endsWith('내 차례')) {
          final raise = find.bySemanticsLabel(RegExp('금액 고르기'));
          if (raise.evaluate().isNotEmpty) {
            sweep.where = '휴대폰 $device $name 레이즈 시트';
            await tester.tap(raise.first, warnIfMissed: false);
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            sweep.scanText(tester);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    sweep.stop();
    expect(sweep.problems.toList()..sort(), isEmpty);
  });

  testWidgets('홀덤 태블릿 화면은 모든 태블릿 크기에서 넘치지 않는다', (tester) async {
    await loadSweepFonts(tester);
    addTearDown(tester.view.reset);
    final sweep = OverflowSweep()..start();
    addTearDown(sweep.stop);
    for (final device in sweepTablets) {
      applySweepDevice(tester, device);
      for (final MapEntry(key: name, value: state) in _states().entries) {
        sweep.where = '태블릿 $device $name';
        await tester.pumpWidget(
          MaterialApp(
            theme: sweepTheme(),
            home: HoldemTableScreen(
              game: state,
              playerLayout: _layoutFor(state.players),
            ),
          ),
        );
        for (var i = 0; i < 16; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        sweep.scanText(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    sweep.stop();
    expect(sweep.problems.toList()..sort(), isEmpty);
  });
}
