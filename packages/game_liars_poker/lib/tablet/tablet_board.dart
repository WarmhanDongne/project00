// [tablet_board.dart] 라이어스 포커 태블릿 화면의 진입부터 종료까지,
// 단계별 화면·문구·애니메이션·소리·연출 시간을 조율하는 파일이다.
// 세부 UI는 tablet/screens·animations·widgets, 서버 상태는 shared에서 관리한다.

library;

// ========================[ import ]==========================
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';
import 'package:game_kit/core/sound/sound_effects.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/game_flow/game_announcement.dart';
import 'package:game_kit/game_flow/game_flow_auto_complete.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/game_flow/game_progress_command.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/player_layouts/player_layout_model.dart';
import 'package:game_kit/shared/animations/mat_unroll_animation.dart';
import 'package:game_kit/sound/game_background_music.dart';
import 'package:game_kit/tablet/animations/card_deal_animation.dart';
import 'package:game_kit/widgets/game_announcement_layer.dart';
import 'package:game_kit/widgets/game_interruption_layer.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_liars_poker/game_sounds.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_liars_poker/shared/models/game_state.dart';
import 'package:game_liars_poker/shared/providers/game_controller.dart';
import 'package:game_liars_poker/shared/providers/session_provider.dart';
import 'package:game_liars_poker/shared/services/asset_preloader.dart';
import 'package:game_liars_poker/shared/services/game_service.dart';
import 'package:game_liars_poker/tablet/animations/card_play_animation.dart';
import 'package:game_liars_poker/tablet/animations/game_animation.dart';
import 'package:game_liars_poker/tablet/animations/round_start_reveal.dart';
import 'package:game_liars_poker/tablet/providers/game_stage.dart';
import 'package:game_liars_poker/tablet/screens/game_helper.dart';
import 'package:game_liars_poker/tablet/screens/game_overlay.dart';
import 'package:game_liars_poker/tablet/screens/game_penalty.dart';
import 'package:game_liars_poker/tablet/widgets/result.dart';

// ============================================================

// LiarsPokerTabletGame
// │
// ├─ ① Timing → 분배·제출·공개·벌칙 시간
// ├─ ② FlowConfig → 서버 상태와 화면 단계 연결
// ├─ ③ GameLayer → 단계별 실제 화면 선택
// └─ ④ board_state → 세션·카드 더미·타임아웃·종료 관리

part 'src/board_state.dart';
part 'screens/game_layer.dart';

// ============================================================================
// 화면 흐름·연출 설정
// ============================================================================

abstract final class LiarsPokerTabletTiming {
  /// 게임 화면 매트가 펼쳐지는 시간입니다. 값이 클수록 진입 연출이 느려집니다.
  static const gameEntry = Duration(milliseconds: 900);

  /// 게임 화면 매트를 말아 로비로 돌아가는 시간입니다.
  static const gameExit = Duration(milliseconds: 820);

  /// 생존 플레이어 좌석으로 카드를 분배하는 총 시간입니다.
  static const cardDeal = Duration(milliseconds: 2800);

  /// ROUND N 안내 문구가 유지되는 시간입니다.
  static const roundAnnouncement = Duration(milliseconds: 1900);

  /// 라운드 테이블·잔여 카드·턴 표시가 등장하는 시간입니다.
  static const roundBoardReveal = Duration(milliseconds: 980);

  /// 제출한 카드가 좌석에서 중앙 더미로 날아가는 시간입니다.
  static const cardPlayFlight = Duration(milliseconds: 540);

  /// 마지막 제출 카드를 뒤집어 공개하는 시간입니다.
  static const cardRevealFlip = Duration(milliseconds: 900);

  /// 공개된 카드와 판정을 확인한 뒤 벌칙 룰렛으로 넘어가기 전 유지 시간입니다.
  static const revealedCardsHold = Duration(seconds: 3);

  /// 벌칙 룰렛이 나타나고 사라지는 전환 시간입니다.
  static const penaltySwitch = Duration(milliseconds: 720);

  /// 인원 부족 안내 후 태블릿 게임 화면을 닫기 전 대기 시간입니다.
  static const closingRouteDelay = Duration(seconds: 1);
}

// ---------------------------------------------------------------------------
// 단계별 연출

// ---------------------------------------------------------------------------
/// 라이어스포커 태블릿의 단계별 화면·문구·애니메이션·소리 설정입니다.
GameFlowConfig<LiarsPokerTabletStage> buildLiarsPokerTabletFlowConfig({
  required int roundNumber,
}) {
  return GameFlowConfig<LiarsPokerTabletStage>(
    steps: {
      // ── 1. 서버 데이터 연결 ──────────────────────────────────────────
      // - status/phase: 첫 game/public 상태를 아직 받지 못한 시점
      // - 입력: 조작 화면 없음
      // - 다음 단계: 서버 dealing 또는 현재 phase 수신을 기다림
      LiarsPokerTabletStage.waiting: const GameFlowStep<LiarsPokerTabletStage>(
        stage: LiarsPokerTabletStage.waiting,
        description: '첫 서버 상태를 기다린다',
        screenWidget: GameAnnouncementLayer,
        showScreen: false,
        showAnnouncement: true,
        announcementId: 'liars-poker-preparing',
        announcementKind: GameAnnouncementKind.persistent,
        announcement: GameFlowCopy.preparingGame,
        animation: GameFlowAnimationConfig.disabled(),
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ── 2. 카드 분배 ────────────────────────────────────────────────
      // - status/phase: 서버 phase == dealing
      // - 1라운드: 중앙 덱 탭으로 시작 / 2라운드부터: ROUND N 후 자동 시작
      // - 입력: 문구 중 차단, 첫 라운드에는 덱 탭만 허용
      // - 다음 단계: 완료 후 completeDealing callable, 서버 상태를 기다림
      LiarsPokerTabletStage.dealing: GameFlowStep<LiarsPokerTabletStage>(
        stage: LiarsPokerTabletStage.dealing,
        description: '생존 좌석으로 카드를 나눠 준다',
        screenWidget: CardDealAnimation,
        showScreen: true,
        showAnnouncement: roundNumber > 1,
        announcementId: 'liars-poker-round-$roundNumber',
        announcementKind: GameAnnouncementKind.round,
        announcement: GameFlowCopy.round(roundNumber),
        announcementDuration: LiarsPokerTabletTiming.roundAnnouncement,
        animation: const GameFlowAnimationConfig(
          widget: CardDealAnimation,
          duration: LiarsPokerTabletTiming.cardDeal,
        ),
        blocksInteraction: roundNumber > 1,
        advancePolicy: GameFlowAdvancePolicy.clientCallbackThenServer,
      ),

      // ── 3. 라운드 보드 등장 ─────────────────────────────────────────
      // - 화면: 테이블 랭크, 잔여 카드, 현재 턴 조명
      // - 입력: 표시 전용 레이어라 포인터를 받지 않음
      // - 다음 단계: 완료 콜백이 로컬 stage만 playing으로 변경
      //
      // **이 단계가 보드 위젯의 주인입니다.** 아래 sharedWith 의 세 단계는
      // 같은 인스턴스를 그대로 쓰며, 등장 시간도 이 단계 값을 씁니다. 단계마다
      // 따로 선언하면 카드를 낼 때마다 보드가 다시 등장합니다.
      LiarsPokerTabletStage.roundStarting:
          const GameFlowStep<LiarsPokerTabletStage>(
            stage: LiarsPokerTabletStage.roundStarting,
            description: '라운드 보드(테이블·잔여 카드·턴)를 펼친다',
            screenWidget: RoundStartReveal,
            sharedWith: [
              LiarsPokerTabletStage.playing,
              LiarsPokerTabletStage.cardsPlaying,
              LiarsPokerTabletStage.cardsRevealing,
            ],
            showScreen: true,
            animation: GameFlowAnimationConfig(
              widget: RoundStartReveal,
              duration: LiarsPokerTabletTiming.roundBoardReveal,
            ),
            blocksInteraction: true,
            advancePolicy: GameFlowAdvancePolicy.clientPresentation,
          ),

      // ── 4. 플레이 ───────────────────────────────────────────────────
      // - status/phase: 서버 playing 또는 lastCardChallenge
      // - 입력: 휴대폰에서 제출/LIAR/FOLD 명령 가능
      // - 다음 단계: 서버 제출 이벤트, LIAR 판정 또는 다음 round를 기다림
      LiarsPokerTabletStage.playing: const GameFlowStep<LiarsPokerTabletStage>(
        stage: LiarsPokerTabletStage.playing,
        description: '플레이어가 카드를 내거나 LIAR을 선언한다',
        screenWidget: RoundStartReveal,
        showScreen: true,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ── 5. 제출 카드 이동 ───────────────────────────────────────────
      // - status/event: 새 public cardPlayEvent 수신
      // - 제출음은 카드가 실제로 날아가는 프레임에서 위젯이 냅니다.
      // - 다음 단계: 이동 완료 후 로컬 stage를 playing으로 복원
      LiarsPokerTabletStage.cardsPlaying:
          const GameFlowStep<LiarsPokerTabletStage>(
            stage: LiarsPokerTabletStage.cardsPlaying,
            description: '제출한 카드가 좌석에서 중앙 더미로 날아간다',
            screenWidget: RoundStartReveal,
            showScreen: true,
            animation: GameFlowAnimationConfig(
              widget: CardPlayAnimation,
              duration: LiarsPokerTabletTiming.cardPlayFlight,
            ),
            advancePolicy: GameFlowAdvancePolicy.clientPresentation,
          ),

      // ── 6. LIAR 카드 공개 ───────────────────────────────────────────
      // - status/event: LIAR 판정과 실제 카드 랭크 수신
      // - 입력: 판정 확인 단계라 게임 명령을 제공하지 않음
      // - 다음 단계: 서버가 penalty면 룰렛, 아니면 playing
      LiarsPokerTabletStage.cardsRevealing:
          const GameFlowStep<LiarsPokerTabletStage>(
            stage: LiarsPokerTabletStage.cardsRevealing,
            description: '마지막 제출 카드를 뒤집어 진실/거짓을 공개한다',
            screenWidget: RoundStartReveal,
            showScreen: true,
            animation: GameFlowAnimationConfig(
              name: '카드 뒤집기',
              duration: LiarsPokerTabletTiming.cardRevealFlip,
            ),
            // '라이어!' 나레이션. 방 가운데 태블릿에서만 냅니다.
            sound: LiarsPokerSounds.voiceLiar,
            afterDelay: LiarsPokerTabletTiming.revealedCardsHold,
            blocksInteraction: true,
            advancePolicy: GameFlowAdvancePolicy.waitsForServer,
          ),

      // ── 7. 벌칙 룰렛 ────────────────────────────────────────────────
      // - status/phase: 서버 phase == penalty
      // - 화면: 기본 테이블을 숨기고 상위 룰렛 레이어만 남김
      // - 다음 단계: 룰렛 결과 callable 후 서버 dealing/result를 기다림
      LiarsPokerTabletStage.penalty: const GameFlowStep<LiarsPokerTabletStage>(
        stage: LiarsPokerTabletStage.penalty,
        description: '벌칙 대상자를 정하는 룰렛을 돌린다',
        showScreen: true,
        animation: GameFlowAnimationConfig(
          name: '룰렛 진입·퇴장 전환',
          duration: LiarsPokerTabletTiming.penaltySwitch,
        ),
        advancePolicy: GameFlowAdvancePolicy.clientCallbackThenServer,
      ),

      // ── 8. 최종 결과 ────────────────────────────────────────────────
      // - status: 정상 승자가 확정된 finished
      // - 승리음은 '정상 승부로 끝났을 때 한 번만' 조건이 붙어 화면 코드가 냅니다.
      // - 다음 단계: restart/end callable의 서버 결과를 기다림
      LiarsPokerTabletStage.result: const GameFlowStep<LiarsPokerTabletStage>(
        stage: LiarsPokerTabletStage.result,
        description: '우승자와 다시하기·HOME을 보여 준다',
        screenWidget: Result,
        showScreen: true,
        sound: LiarsPokerSounds.win,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ── 9. 게임 종료 안내 ───────────────────────────────────────────
      // - status: 결과 화면 이외의 종료 표현이 필요한 로컬 단계
      // - 다음 단계: 상위 화면의 종료/라우트 처리를 기다림
      LiarsPokerTabletStage.finished: const GameFlowStep<LiarsPokerTabletStage>(
        stage: LiarsPokerTabletStage.finished,
        description: '결과 화면 없이 끝났음을 알린다',
        screenWidget: GameAnnouncementLayer,
        showScreen: false,
        showAnnouncement: true,
        announcementId: 'liars-poker-finished',
        announcementKind: GameAnnouncementKind.persistent,
        announcement: GameFlowCopy.gameFinished,
        animation: GameFlowAnimationConfig.disabled(),
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),
    },
  );
}

// ============================================================================
// 단계별 실제 화면 연결 (위젯 생성)
// ============================================================================

class LiarsPokerTabletGameLayer extends StatelessWidget {
  const LiarsPokerTabletGameLayer({
    super.key,
    required this.stage,
    required this.flowConfig,
    required this.playerCount,
    required this.playerSeatIndexes,
    required this.dealPlayerSeatIndexes,
    required this.cardsPerPlayer,
    required this.roundNumber,
    required this.cardPileVersion,
    required this.table,
    required this.remainingCardCounts,
    required this.currentTurnPlayerIndex,
    required this.onDealCompleted,
    required this.onRoundRevealCompleted,
    required this.onRestartGame,
    required this.onExitToLobby,
    required this.winnerPlayer,
  });

  final LiarsPokerTabletStage stage;
  final GameFlowConfig<LiarsPokerTabletStage> flowConfig;
  final int playerCount;
  final List<int> playerSeatIndexes;
  final List<int> dealPlayerSeatIndexes;
  final int cardsPerPlayer;
  final int roundNumber;
  final int cardPileVersion;
  final String table;
  final List<int> remainingCardCounts;
  final int? currentTurnPlayerIndex;
  final VoidCallback onDealCompleted;
  final VoidCallback onRoundRevealCompleted;
  final VoidCallback onRestartGame;
  final VoidCallback onExitToLobby;
  final PlayerLayoutPlayer? winnerPlayer;
  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      LiarsPokerTabletStage.waiting => GameAnnouncementLayer(
        announcement: flowConfig.stepFor(stage).buildAnnouncement(),
        style: const GameAnnouncementStyle.tablet(),
      ),
      // key에 좌석 목록을 넣지 않습니다. 분배 도중 플레이어 상태가 바뀌어
      // 좌석 집합이 변하면 애니메이션이 처음부터 재생성되고, 1라운드는 시작
      // 탭을 다시 기다리게 되어 분배가 영원히 끝나지 않을 수 있습니다.
      LiarsPokerTabletStage.dealing => _RoundDealLayer(
        key: ValueKey('deal-$roundNumber-$cardPileVersion'),
        roundNumber: roundNumber,
        boardSeatCount: playerCount,
        playerSeatIndexes: dealPlayerSeatIndexes,
        cardsPerPlayer: cardsPerPlayer,
        flowStep: flowConfig.stepFor(stage),
        onCompleted: onDealCompleted,
      ),
      LiarsPokerTabletStage.roundStarting ||
      LiarsPokerTabletStage.playing ||
      LiarsPokerTabletStage.cardsPlaying ||
      LiarsPokerTabletStage.cardsRevealing => RoundStartReveal(
        key: ValueKey('round-$roundNumber'),
        tableAsset: tableAssetForValue(table),
        playerCount: playerCount,
        playerSeatIndexes: playerSeatIndexes,
        remainingCardCounts: remainingCardCounts,
        activePlayerIndex: currentTurnPlayerIndex,
        tableWidth: 300,
        // 이 보드는 네 단계가 같은 인스턴스를 공유합니다. 어느 단계에서 그리든
        // 등장 시간은 **주인 단계**(roundStarting) 값을 씁니다. 현재 stage의
        // 카드 이동 시간으로 덮으면 재접속 시 보드 속도가 달라집니다.
        // 공유 관계는 game_liars_poker.dart 의 sharedWith 에 선언돼 있습니다.
        duration: flowConfig.widgetOwnerOf(stage).animation.enabled
            ? flowConfig.widgetOwnerOf(stage).animation.duration
            : Duration.zero,
        onCompleted: onRoundRevealCompleted,
      ),
      // 벌칙 중에는 테이블을 숨기고 상위 룰렛 레이어만 남깁니다.
      // 룰렛 진행 중에는 배경 위에 룰렛만 남기고 테이블과 잔여 카드는
      // 그리지 않습니다. 룰렛은 상위 LiarsPokerTabletGamePenalty 레이어가 담당합니다.
      LiarsPokerTabletStage.penalty => const SizedBox.shrink(),
      LiarsPokerTabletStage.result => Result(
        winnerPlayer: winnerPlayer,
        onRestartGame: onRestartGame,
        onExitToLobby: onExitToLobby,
      ),
      LiarsPokerTabletStage.finished => GameAnnouncementLayer(
        announcement: flowConfig.stepFor(stage).buildAnnouncement(),
        style: const GameAnnouncementStyle.tablet(),
      ),
    };
  }
}

// ============================================================================
// 게임 화면 진입점
// ============================================================================

class LiarsPokerTabletGame extends ConsumerStatefulWidget {
  const LiarsPokerTabletGame({
    super.key,
    required this.playerLayout,
    required this.provider,
    required this.roomCode,
    required this.gameService,
  });

  final PlayerLayoutModel playerLayout;
  final GameRoomContext provider;
  final String roomCode;
  final LiarsPokerService gameService;

  @override
  ConsumerState<LiarsPokerTabletGame> createState() =>
      _LiarsPokerTabletGameState();
}
