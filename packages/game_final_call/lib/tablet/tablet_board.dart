/// FinalCall 태블릿 조율판.
///
/// 이 파일에서 단계별 화면 연결, 문구, 애니메이션과 연출 시간을 수정합니다.
/// 세부 화면은 screens/, 세부 연출은 animations/를 열어 수정하세요.
/// 서버 상태 구독과 게임 명령은 shared/providers와 shared/services가 소유합니다.
/// 실제 턴 제한시간·승패 규칙은 서버가 결정하며 연출 시간과 구분합니다.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_final_call/game_copy.dart';
import 'package:game_final_call/game_sounds.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/models/game_state.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/shared/providers/session_provider.dart';
import 'package:game_final_call/shared/services/asset_preloader.dart';
import 'package:game_final_call/shared/services/game_service.dart';
import 'package:game_final_call/shared/widgets/card_view.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';
import 'package:game_final_call/tablet/animations/center_card_reveal.dart';
import 'package:game_final_call/tablet/animations/call_and_discard_animation.dart';
import 'package:game_final_call/tablet/providers/game_stage.dart';
import 'package:game_final_call/tablet/screens/seat_geometry.dart';
import 'package:game_final_call/tablet/screens/game_overlay.dart';
import 'package:game_final_call/tablet/widgets/result_overlay.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';
import 'package:game_kit/sound/sound_effects.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/game_flow/game_announcement.dart';
import 'package:game_kit/game_flow/game_flow_auto_complete.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/recovery/services/game_progress_command.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';
import 'package:game_kit/shared/animations/one_shot_timeline.dart';
import 'package:game_kit/shared/animations/progress_sound_cue.dart';
import 'package:game_kit/sound/game_background_music.dart';
import 'package:game_kit/tablet/animations/board_element_entrance.dart';
import 'package:game_kit/tablet/animations/card_deal_animation.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown.dart';
import 'package:game_kit/shared/widgets/game_announcement_layer.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';
import 'package:game_kit/shared/widgets/game_route_exit.dart';

part 'src/board_state.dart';
part 'screens/game_layer.dart';

// ============================================================================
// 화면 흐름·연출 설정
// ============================================================================

abstract final class FinalCallTabletTiming {
  /// 중앙 덱에서 생존 좌석으로 카드가 분배되는 총 시간입니다.
  static const cardDeal = Duration(milliseconds: 2800);

  /// 라운드 결과 공개를 마친 뒤 `nextRound` 명령 전까지 결과를 유지하는 시간입니다.
  static const roundResultAfterDelay = Duration(milliseconds: 900);

  /// 인원 부족 종료 문구를 보여준 뒤 태블릿 게임 화면을 닫기 전 대기시간입니다.
  static const closingRouteDelay = Duration(seconds: 1);

  //---- 라운드 결과 공개 타임라인 ----
  // 아래 값들이 모여 roundResult 단계의 총 시간을 만듭니다. 총 시간은 공개할
  // 플레이어 수와 카드 수에 따라 달라져서 단계 선언에 고정값으로 적을 수
  // 없습니다(그래서 그 단계의 animation.duration 은 Duration.zero 입니다).

  /// 결과 카드가 움직이기 전 모든 뒷면 카드를 확인하는 시간입니다.
  static const roundResultInitialHold = Duration(milliseconds: 900);

  /// 공개할 한 플레이어의 손패를 확대하는 시간입니다.
  static const roundResultFocus = Duration(milliseconds: 520);

  /// 한 장씩 공개할 때 다음 카드까지의 간격입니다.
  static const roundResultCardStep = Duration(milliseconds: 900);

  /// 카드 한 장의 뒤집기 애니메이션 시간입니다.
  static const roundResultCardFlip = Duration(milliseconds: 680);

  /// 한 플레이어의 손패 공개 후 원래 크기로 돌아오는 시간입니다.
  static const roundResultSettle = Duration(milliseconds: 520);

  /// 패배 플레이어의 하트가 깨지는 연출 시간입니다.
  static const roundResultHeartLoss = Duration(milliseconds: 1500);
}

// ---------------------------------------------------------------------------
// 단계별 연출

// ---------------------------------------------------------------------------
/// 파이널콜 태블릿의 단계별 화면·문구·애니메이션·소리 설정입니다.
///
/// `FinalCallTabletGame._resolveStage`가 서버 상태를 typed stage로 번역하고,
/// 이 설정은 해당 stage에서 무엇을 보여줄지만 결정합니다.
GameFlowConfig<FinalCallTabletStage> buildFinalCallTabletFlowConfig({
  required String closingMessage,
}) {
  return GameFlowConfig<FinalCallTabletStage>(
    steps: {
      // ── 1. 서버 데이터 연결 ──────────────────────────────────────────
      // - status/phase: 첫 public game 상태를 아직 받지 못한 시점
      // - 문구: persistent라 시간 제한 없이 서버 상태가 올 때까지 유지
      // - 입력: 게임 Screen을 그리지 않아 조작할 수 없음
      // - 다음 단계: 서버 phase 수신을 기다림
      FinalCallTabletStage.connecting: const GameFlowStep<FinalCallTabletStage>(
        stage: FinalCallTabletStage.connecting,
        description: '첫 서버 상태를 기다린다',
        screenWidget: GameAnnouncementLayer,
        showScreen: false,
        showAnnouncement: true,
        announcementId: 'final-call-preparing',
        announcementKind: GameAnnouncementKind.persistent,
        announcement: GameFlowCopy.preparingGame,
        animation: GameFlowAnimationConfig.disabled(),
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ── 2. 카드 분배 ────────────────────────────────────────────────
      // - status/phase: 서버 phase == dealing
      // - 입력: 첫 라운드는 중앙 덱 탭, 2라운드부터 자동 시작
      // - 다음 단계: 애니메이션 완료 후 completeDealing callable을 보내고
      //   서버가 다음 phase를 확정할 때까지 기다림
      FinalCallTabletStage.dealing: const GameFlowStep<FinalCallTabletStage>(
        stage: FinalCallTabletStage.dealing,
        description: '중앙 덱에서 생존 좌석으로 카드를 나눠 준다',
        screenWidget: CardDealAnimation,
        showScreen: true,
        animation: GameFlowAnimationConfig(
          widget: CardDealAnimation,
          duration: FinalCallTabletTiming.cardDeal,
        ),
        advancePolicy: GameFlowAdvancePolicy.clientCallbackThenServer,
      ),

      // ── 3. 플레이 ───────────────────────────────────────────────────
      // - status/phase: draw, callerSubmit, finalTurns, finalSubmit 등 진행 상태
      // - 화면: 중앙 카드, 팀별 하트, CALL/버림 애니메이션, 공용 사이드바
      // - 입력: 휴대폰 명령을 허용하며 태블릿은 서버 상태를 표현
      // - 소리: CALL 나레이션은 단계 진입이 아니라 CALL 이벤트에 붙어 있어
      //   여기 선언하지 않습니다(화면 코드가 냅니다).
      // - 다음 단계: 서버 phase 또는 roundResult 수신
      FinalCallTabletStage.playing: const GameFlowStep<FinalCallTabletStage>(
        stage: FinalCallTabletStage.playing,
        description: '카드를 뽑고 내며 CALL을 노린다',
        showScreen: true,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ── 4. 라운드 판정 ──────────────────────────────────────────────
      // - status/phase: roundResult 데이터가 존재하거나 phase == roundResult
      // - 화면: 전원 제출 카드 순차 공개, 점수 계산, 패배 팀 하트 소멸
      // - 소리: 하트 깨지는 소리는 타임라인 안의 특정 프레임에서 납니다.
      // - 입력: 결과 확인 단계라 게임 행동을 제공하지 않음
      // - 다음 단계: 연출 완료 후 서버가 next round 또는 finished를 확정
      FinalCallTabletStage.roundResult:
          const GameFlowStep<FinalCallTabletStage>(
            stage: FinalCallTabletStage.roundResult,
            description: '제출 카드를 순서대로 공개하고 하트를 정산한다',
            screenWidget: OneShotTimeline,
            showScreen: true,
            animation: GameFlowAnimationConfig(
              widget: OneShotTimeline,
              // 총 시간은 공개 플레이어·카드 수에 따라 달라져 고정할 수 없습니다.
              // 구성 값은 FinalCallTabletTiming 의 roundResult* 를 보세요.
              duration: Duration.zero,
            ),
            afterDelay: FinalCallTabletTiming.roundResultAfterDelay,
            blocksInteraction: true,
            advancePolicy: GameFlowAdvancePolicy.clientCallbackThenServer,
          ),

      // ── 5. 최종 결과 ────────────────────────────────────────────────
      // - status: 정상 승자 또는 무승부가 확정된 finished
      // - 소리: 승리음은 '정상 승부로 끝났고, 마지막 공개 연출이 끝난 뒤,
      //   한 번만' 조건이 붙어 재생 시점은 화면 코드가 정합니다.
      // - 입력: 다시하기·HOME 허용, 각 버튼의 callable 결과를 기다림
      FinalCallTabletStage.result: const GameFlowStep<FinalCallTabletStage>(
        stage: FinalCallTabletStage.result,
        description: '승리 팀과 다시하기·HOME을 보여 준다',
        screenWidget: FinalCallResultOverlay,
        showScreen: true,
        sound: FinalCallSounds.win,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ── 6. 인원 부족 종료 ───────────────────────────────────────────
      // - status: insufficientPlayers/interruptionVoteExpired로 끝난 finished
      // - 문구: persistent, 별도 유지시간 없이 라우트 종료까지 유지
      // - 다음 단계: closingRouteDelay 후 태블릿 게임 라우트를 닫음
      FinalCallTabletStage.closing: GameFlowStep<FinalCallTabletStage>(
        stage: FinalCallTabletStage.closing,
        description: '인원이 모자라 게임을 끝낸다',
        screenWidget: GameAnnouncementLayer,
        showScreen: false,
        showAnnouncement: true,
        announcementId: 'final-call-closing',
        announcementKind: GameAnnouncementKind.persistent,
        announcement: closingMessage,
        animation: const GameFlowAnimationConfig.disabled(),
        afterDelay: FinalCallTabletTiming.closingRouteDelay,
        blocksInteraction: true,
        showScrim: true,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),
    },
  );
}

// ============================================================================
// 단계별 실제 화면 연결 (위젯 생성)
// ============================================================================

class FinalCallTabletGameLayer extends StatelessWidget {
  const FinalCallTabletGameLayer({
    super.key,
    required this.controller,
    required this.stage,
    required this.flowConfig,
    required this.onRoundRevealCompleted,
    required this.onDealingCompleted,
  });

  final FinalCallController controller;
  final FinalCallTabletStage stage;
  final GameFlowConfig<FinalCallTabletStage> flowConfig;
  final VoidCallback onRoundRevealCompleted;
  final VoidCallback onDealingCompleted;

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      FinalCallTabletStage.connecting ||
      FinalCallTabletStage.result ||
      FinalCallTabletStage.closing => const SizedBox.shrink(),
      FinalCallTabletStage.dealing => _buildDealing(context),
      FinalCallTabletStage.playing => _buildPlayingTable(),
      FinalCallTabletStage.roundResult => _buildRoundResult(),
    };
  }

  Widget _buildDealing(BuildContext context) {
    final players =
        controller.players.values
            .where((player) => player.status == 'alive')
            .toList()
          ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
    if (players.isEmpty) return const SizedBox.shrink();

    // ========================================================================
    // 2. 카드 분배 (DEALING)
    // ========================================================================
    // 생존 플레이어의 실제 seatIndex만 전달해야 탈락자의 빈자리를 건너뛰고
    // 원래 자리 배치에 맞춰 카드가 날아갑니다.
    final activeSeatIndexes = players
        .map((player) => player.seatIndex)
        .toList(growable: false);
    final flowStep = flowConfig.stepFor(stage);
    if (!flowStep.animation.enabled) {
      return GameFlowAutoComplete(
        key: ValueKey((
          'deal-skipped',
          controller.gameStartedAt,
          controller.round,
        )),
        delay: flowStep.beforeDelay + flowStep.afterDelay,
        onCompleted: onDealingCompleted,
      );
    }
    return CardDealAnimation(
      key: ValueKey(
        'final-call-deal-${controller.gameStartedAt}-${controller.round}-${activeSeatIndexes.join('-')}',
      ),
      playerCount: players.length,
      boardSeatCount: controller.players.length,
      playerSeatIndexes: activeSeatIndexes,
      cardsPerPlayer: 4,
      // 테이블 가운데 덱과 같은 Party Pop 뒷면을 날립니다. 공용 연출의
      // 바탕 상자 모서리(7)에 맞춰 둥글기를 줄입니다.
      cardBuilder: (context, playerIndex, cardIndex) =>
          const FinalCallCardBack(width: 120, radius: 7),
      cardWidth: 120,
      duration: flowStep.animation.duration,
      beforeDelay: flowStep.beforeDelay,
      afterDelay: flowStep.afterDelay,
      // 첫 라운드만 중앙 덱을 눌러 시작하고, 이후 라운드는 서버가 dealing에
      // 진입하면 라이어스 포커와 동일하게 자동 분배합니다.
      autoplay: controller.round > 1,
      tapToStart: controller.round == 1,
      onCompleted: onDealingCompleted,
    );
  }

  Widget _buildPlayingTable() {
    final players = controller.players.values.toList(growable: false)
      ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
    final visibleDiscard =
        controller.discardEvent?.previousCard ?? controller.discardCard;
    final hideDiscardWhileTaken =
        controller.pendingDrawUid != null &&
        controller.pendingDrawSource == 'discard';
    final hideDiscardDuringThrow =
        controller.discardEvent?.drawSource == 'discard';
    // 카드 분배가 끝난 뒤 중앙 카드와 좌석 이름표가 Liar's Poker의 잔여 카드
    // 등장 연출과 같은 곡선으로 바닥에서 솟아오릅니다. 라운드가 바뀔 때만
    // 다시 재생되도록 라운드를 key로 씁니다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.biggest;
        final scale = finalCallTabletScale(boardSize);
        final cardWidth = finalCallCenterCardWidth(boardSize);
        final cardHeight = cardWidth * finalCallCardHeightRatio;
        final gap = finalCallCenterCardGap(boardSize);
        final center = boardSize.center(Offset.zero);
        final callInProgress =
            controller.callerUid != null &&
            (controller.phase == 'callerSubmit' ||
                controller.phase == 'finalTurns' ||
                controller.phase == 'finalSubmit');
        return Stack(
          fit: StackFit.expand,
          children: [
            BoardElementEntrance(
              key: ValueKey('center-card-entrance-${controller.round}'),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: FinalCallCenterCardReveal(
                      key: ValueKey('center-card-${controller.round}'),
                      card: visibleDiscard,
                      cardWidth: cardWidth,
                      gap: gap,
                      showRevealedCard:
                          !hideDiscardWhileTaken && !hideDiscardDuringThrow,
                    ),
                  ),
                  // 덱 장수와 공개 카드 이름표입니다.
                  Positioned(
                    left: center.dx - cardWidth - gap / 2,
                    top: center.dy + cardHeight / 2 + 12 * scale,
                    width: cardWidth * 2 + gap,
                    child: Row(
                      children: [
                        for (final label in [
                          FinalCallCopy.deckCount(
                            controller.deckRemainingCount,
                          ),
                          FinalCallCopy.publicCard,
                        ]) ...[
                          if (label == FinalCallCopy.publicCard)
                            SizedBox(width: gap),
                          SizedBox(
                            width: cardWidth,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: finalCallPopText(
                                16 * scale,
                                color: FinalCallColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: center.dy + cardHeight / 2 + 40 * scale,
                    child: Text(
                      FinalCallCopy.roundCaption(controller.round),
                      textAlign: TextAlign.center,
                      style: finalCallPopText(
                        15 * scale,
                        color: FinalCallColors.muted,
                      ),
                    ),
                  ),
                  // CALL 이후에는 가운데에 CALL 폭발이 뜨므로 차례 알약을 숨깁니다.
                  if (!callInProgress && controller.turnPlayer != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom:
                          boardSize.height -
                          center.dy +
                          cardHeight / 2 +
                          18 * scale,
                      child: Center(
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.bottomCenter,
                          child: _FinalCallTurnPill(
                            player: controller.turnPlayer!,
                            deadline: controller.turnDeadlineAt,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            BoardElementEntrance(
              key: ValueKey('lives-entrance-${controller.round}'),
              child: _FinalCallSeatPlates(
                players: players,
                turnUid: controller.turnUid,
                callerUid: callInProgress ? controller.callerUid : null,
                pendingDrawUid: controller.pendingDrawUid,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoundResult() {
    final result = controller.roundResult;
    if (result == null) return const SizedBox.shrink();
    final flowStep = flowConfig.stepFor(stage);
    if (!flowStep.animation.enabled) {
      return GameFlowAutoComplete(
        key: ValueKey('round-result-skipped-${controller.round}'),
        delay: flowStep.beforeDelay,
        onCompleted: onRoundRevealCompleted,
      );
    }
    return _RevealedTable(
      key: ValueKey('round-result-${controller.round}'),
      controller: controller,
      result: result,
      onCompleted: onRoundRevealCompleted,
    );
  }
}

// ============================================================================
// 게임 화면 진입점
// ============================================================================

class FinalCallTabletGame extends ConsumerStatefulWidget {
  const FinalCallTabletGame({
    super.key,
    required this.roomCode,
    required this.gameService,
    required this.provider,
  });

  final String roomCode;
  final FinalCallService gameService;
  final GameRoomContext provider;

  @override
  ConsumerState<FinalCallTabletGame> createState() =>
      _FinalCallTabletGameState();
}
