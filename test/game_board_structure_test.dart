import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/game_final_call.dart';
import 'package:game_final_call/phone/phone_board.dart';
import 'package:game_final_call/phone/providers/game_stage.dart';
import 'package:game_final_call/tablet/tablet_board.dart';
import 'package:game_final_call/tablet/providers/game_stage.dart';
import 'package:game_liars_poker/game_liars_poker.dart';
import 'package:game_liars_poker/phone/phone_board.dart';
import 'package:game_liars_poker/phone/providers/game_stage.dart';
import 'package:game_liars_poker/tablet/tablet_board.dart';
import 'package:game_liars_poker/tablet/providers/game_stage.dart';
import 'package:game_liars_poker/tablet/widgets/seat_plate.dart';
import 'package:game_mafia/game_mafia.dart';
import 'package:game_mafia/phone/phone_board.dart';
import 'package:game_mafia/phone/providers/game_stage.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/game_flow/game_screen_phase.dart';
import 'package:game_kit/game_flow/phone_game_shell.dart';
import 'package:game_kit/game_flow/phone_game_flow_config.dart';
import 'package:game_kit/core/layout/app_orientation.dart';

void main() {
  test('패키지 진입점은 기존 게임 ID·인원·기기 방향을 보존한다', () {
    expect(const FinalCallGame().id, 'final_call');
    expect(const FinalCallGame().supportedPlayerCounts, [4, 6]);
    expect(
      const FinalCallGame().phoneOrientation,
      PhoneGameOrientation.landscapeOnly,
    );
    expect(const LiarsPokerGame().id, 'liars_poker');
    expect(
      const LiarsPokerGame().phoneOrientation,
      PhoneGameOrientation.portraitAndLandscape,
    );
    expect(const MafiaGame().id, 'mafia');
  });

  test('기기별 board가 모든 기존 단계와 안내시간을 제공한다', () {
    final finalCall = buildFinalCallTabletFlowConfig(closingMessage: '종료');
    for (final stage in FinalCallTabletStage.values) {
      expect(finalCall.stepFor(stage).stage, stage);
    }
    expect(
      finalCall.stepFor(FinalCallTabletStage.dealing).animation.duration,
      const Duration(milliseconds: 2800),
    );
    final poker = buildLiarsPokerTabletFlowConfig(roundNumber: 2);
    for (final stage in LiarsPokerTabletStage.values) {
      expect(poker.stepFor(stage).stage, stage);
    }
    expect(
      poker.widgetOwnerOf(LiarsPokerTabletStage.cardsRevealing).stage,
      LiarsPokerTabletStage.roundStarting,
    );
    expect(
      buildLiarsPokerTabletFlowConfig(
        roundNumber: 1,
      ).stepFor(LiarsPokerTabletStage.dealing).showAnnouncement,
      isFalse,
    );
    expect(
      poker.stepFor(LiarsPokerTabletStage.dealing).showAnnouncement,
      isTrue,
    );
    final finalCallPhone = buildFinalCallPhoneFlowConfig(roundNumber: 3);
    for (final stage in FinalCallPhoneStage.values) {
      expect(finalCallPhone.stepFor(stage).stage, stage);
    }
    expect(
      finalCallPhone.stepFor(FinalCallPhoneStage.roundIntro).announcement,
      'ROUND 3',
    );
    expect(
      finalCallPhone
          .stepFor(FinalCallPhoneStage.gameStart)
          .announcementDuration,
      const Duration(milliseconds: 1700),
    );

    final mafiaPhone = buildMafiaPhoneFlowConfig();
    for (final stage in MafiaPhoneStage.values) {
      expect(mafiaPhone.stepFor(stage).stage, stage);
    }

    final pokerPhone = buildLiarsPokerPhoneFlowConfig(
      roundNumber: 3,
      tableCardValue: 'K',
    );
    for (final stage in LiarsPokerPhoneStage.values) {
      expect(pokerPhone.stepFor(stage).stage, stage);
    }
    expect(
      pokerPhone.stepFor(LiarsPokerPhoneStage.gameStart).announcementDuration,
      LiarsPokerPhoneTiming.gameStartAnnouncement,
    );
  });

  testWidgets('태블릿 라운드 안내와 분배 연출 OFF도 서버 완료 콜백을 유지한다', (tester) async {
    var completed = 0;
    final base = buildLiarsPokerTabletFlowConfig(roundNumber: 2);
    final config = GameFlowConfig<LiarsPokerTabletStage>(
      steps: {
        ...base.steps,
        LiarsPokerTabletStage.dealing: const GameFlowStep(
          stage: LiarsPokerTabletStage.dealing,
          showScreen: true,
          showAnnouncement: false,
          animation: GameFlowAnimationConfig.disabled(),
          advancePolicy: GameFlowAdvancePolicy.clientCallbackThenServer,
        ),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiarsPokerTabletGameLayer(
            stage: LiarsPokerTabletStage.dealing,
            flowConfig: config,
            playerCount: 2,
            playerSeatIndexes: const [0, 1],
            dealPlayerSeatIndexes: const [0, 1],
            cardsPerPlayer: 5,
            roundNumber: 2,
            cardPileVersion: 1,
            table: 'K',
            seats: const [
              TabletSeatInfo(
                nickname: 'A',
                characterId: 'frog',
                penaltyCount: 0,
                remainingCardCount: 5,
              ),
              TabletSeatInfo(
                nickname: 'B',
                characterId: 'frog',
                penaltyCount: 0,
                remainingCardCount: 5,
              ),
            ],
            currentTurnPlayerIndex: 0,
            onDealCompleted: () => completed++,
            onRoundRevealCompleted: () {},
            onRestartGame: () {},
            onExitToLobby: () {},
            winnerPlayer: null,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(completed, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  for (final phase in [GameScreenPhase.intro, GameScreenPhase.roundIntro]) {
    testWidgets('문구 OFF여도 $phase 완료가 정확히 한 번 전달된다', (tester) async {
      var intro = 0;
      var round = 0;
      final base = buildPhoneGameFlowConfig(roundNumber: 2);
      final config = GameFlowConfig<GameScreenPhase>(
        steps: {
          ...base.steps,
          phase: GameFlowStep(
            stage: phase,
            showScreen: false,
            showAnnouncement: false,
            afterDelay: const Duration(milliseconds: 100),
            advancePolicy: GameFlowAdvancePolicy.clientPresentation,
          ),
        },
      );
      Widget app() => MaterialApp(
        home: PhoneGameShell<GameScreenPhase>(
          stage: phase,
          stageRole: phase == GameScreenPhase.intro
              ? PhoneGameShellStageRole.intro
              : PhoneGameShellStageRole.roundIntro,
          roundNumber: 2,
          flowConfig: config,
          background: const ColoredBox(color: Colors.black),
          content: const SizedBox(),
          onIntroCompleted: () => intro++,
          onRoundIntroCompleted: () => round++,
        ),
      );
      await tester.pumpWidget(app());
      expect(intro + round, 0);
      await tester.pump(const Duration(milliseconds: 101));
      expect(intro, phase == GameScreenPhase.intro ? 1 : 0);
      expect(round, phase == GameScreenPhase.roundIntro ? 1 : 0);
      await tester.pumpWidget(app());
      await tester.pump(const Duration(seconds: 1));
      expect(intro + round, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
