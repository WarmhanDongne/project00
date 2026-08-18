import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_layer.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_stage.dart';

void main() {
  Widget buildLayer({required int round, required VoidCallback onCompleted}) {
    return MaterialApp(
      home: Scaffold(
        body: LiarsPokerTabletGameLayer(
          stage: LiarsPokerTabletStage.dealing,
          playerCount: 2,
          playerSeatIndexes: const [0, 1],
          cardsPerPlayer: 1,
          roundNumber: round,
          cardPileVersion: 1,
          table: 'A',
          remainingCardCounts: const [1, 1],
          currentTurnPlayerIndex: 0,
          onDealCompleted: onCompleted,
          onRoundRevealCompleted: () {},
          onRestartGame: () {},
          onExitToLobby: () {},
          winnerPlayer: null,
        ),
      ),
    );
  }

  testWidgets('첫 라운드 카드 배분은 덱을 누르기 전까지 시작하지 않는다', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      buildLayer(round: 1, onCompleted: () => completed = true),
    );
    await tester.pumpAndSettle();

    expect(completed, isFalse);
  });

  testWidgets('2라운드부터 ROUND 안내 후 카드 배분이 자동 진행된다', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      buildLayer(round: 2, onCompleted: () => completed = true),
    );
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });
}
