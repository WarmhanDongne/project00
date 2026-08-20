import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/liars_poker/liars_poker_flow_config.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_layer.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/shared/game_flow/game_flow_config.dart';

void main() {
  Widget buildLayer({
    required int round,
    required VoidCallback onCompleted,
    bool enableAnimation = true,
  }) {
    final defaultConfig = buildLiarsPokerTabletFlowConfig(roundNumber: round);
    final flowConfig = enableAnimation
        ? defaultConfig
        : GameFlowConfig<LiarsPokerTabletStage>(
            steps: {
              ...defaultConfig.steps,
              LiarsPokerTabletStage
                  .dealing: GameFlowStep<LiarsPokerTabletStage>(
                stage: LiarsPokerTabletStage.dealing,
                showScreen: true,
                animation: const GameFlowAnimationConfig.disabled(),
                advancePolicy: GameFlowAdvancePolicy.clientCallbackThenServer,
              ),
            },
          );
    return MaterialApp(
      home: Scaffold(
        body: LiarsPokerTabletGameLayer(
          stage: LiarsPokerTabletStage.dealing,
          flowConfig: flowConfig,
          playerCount: 2,
          playerSeatIndexes: const [0, 1],
          dealPlayerSeatIndexes: const [0, 1],
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

  testWidgets('탈락자가 생겨도 생존자의 원래 좌석 번호로 분배한다', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiarsPokerTabletGameLayer(
            stage: LiarsPokerTabletStage.dealing,
            flowConfig: buildLiarsPokerTabletFlowConfig(roundNumber: 2),
            playerCount: 4,
            playerSeatIndexes: const [0, 1, 2, 3],
            dealPlayerSeatIndexes: const [0, 2, 3],
            cardsPerPlayer: 1,
            roundNumber: 2,
            cardPileVersion: 2,
            table: 'A',
            remainingCardCounts: const [1, 0, 1, 1],
            currentTurnPlayerIndex: 0,
            onDealCompleted: () => completed = true,
            onRoundRevealCompleted: () {},
            onRestartGame: () {},
            onExitToLobby: () {},
            winnerPlayer: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(completed, isTrue);
  });

  testWidgets('카드 분배 Animation을 꺼도 완료 콜백으로 흐름이 멈추지 않는다', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      buildLayer(
        round: 1,
        enableAnimation: false,
        onCompleted: () => completed = true,
      ),
    );
    await tester.pump();

    expect(completed, isTrue);
  });
}
