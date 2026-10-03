/// Mafia 태블릿 조율판.
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
import 'package:game_mafia/shared/widgets/trial_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';
import 'package:game_kit/sound/sound_effects.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/recovery/services/game_progress_command.dart';
import 'package:game_kit/game_flow/game_presentation_clock.dart';
import 'package:game_kit/recovery/widgets/game_request_notice.dart';
import 'package:game_kit/recovery/widgets/game_connecting_overlay.dart';
import 'package:game_mafia/shared/models/presentation_timing.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/sound/countdown_tick_cue.dart';
import 'package:game_kit/sound/game_background_music.dart';
import 'package:game_kit/recovery/widgets/game_interruption_layer.dart';
import 'package:game_kit/shared/widgets/game_route_exit.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown.dart';
import 'package:game_kit/tablet/widgets/game_rulebook_dialog.dart';
import 'package:game_kit/tablet/widgets/game_settings_dialog.dart';
import 'package:game_mafia/game_copy.dart';
import 'package:game_mafia/game_sounds.dart';
import 'package:game_mafia/shared/animations/announcement_reveal.dart';
import 'package:game_mafia/shared/animations/phase_transition.dart';
import 'package:game_mafia/shared/animations/role_deal_toss_animation.dart';
import 'package:game_mafia/shared/models/game_state.dart';
import 'package:game_mafia/shared/models/role_catalog.dart';
import 'package:game_mafia/shared/providers/game_controller.dart';
import 'package:game_mafia/shared/providers/session_provider.dart';
import 'package:game_mafia/shared/services/asset_preloader.dart';
import 'package:game_mafia/shared/services/game_service.dart';
import 'package:game_mafia/tablet/providers/game_stage.dart';
import 'package:game_mafia/tablet/screens/day_view.dart';
import 'package:game_mafia/tablet/screens/game_layout.dart';
import 'package:game_mafia/tablet/screens/phase_views.dart';
import 'package:game_mafia/tablet/screens/result_view.dart';
import 'package:game_mafia/tablet/services/bgm_plan.dart';
import 'package:game_mafia/tablet/services/night_cue_speaker.dart';

part 'src/board_state.dart';

// ============================================================================
// 화면 흐름·연출 설정
// ============================================================================

/// 태블릿 발표·효과음 시간입니다.
/// 전원 신분 확인 → 시작 안내 → nightNoticeDelay → 밤 안내 → 서버 밤 시작 요청.
/// 대기시간을 늘리면 밤 시작 요청도 늦어집니다. 실제 서버 마감은 바꾸지 않습니다.
abstract final class MafiaTabletTiming {
  /// 승부 없이 종료할 때 화면을 닫기 전 안내를 유지하는 시간입니다.
  static const closingRouteDelay = MafiaPresentationTiming.closing;
  static const howlEarliest = Duration(seconds: 10);
  static const howlLatestBeforeEnd = Duration(seconds: 12);
  static const nightNoticeDelay = Duration(seconds: 10);
  static const nightNoticeHold = Duration(milliseconds: 2500);
  static const gameStartNoticeHold = Duration(milliseconds: 2500);
  static const winVoiceDelay = Duration(milliseconds: 800);
}

// ---------------------------------------------------------------------------
// 단계별 연출 — 라이어스포커·파이널콜과 같은 자리
// ---------------------------------------------------------------------------
/// 마피아 태블릿의 단계별 화면·연출 시간·진행 방식입니다.
///
/// 다른 두 게임과 같은 표입니다. 다만 마피아는 발표 길이가 판 결과에 따라
/// 달라지므로(사망자 수·처형 여부·게임 종료) 상태를 받아 만듭니다.
///
/// **숫자를 새로 적지 않습니다.** 모든 값은 실제 연출이 쓰는 상수와
/// [MafiaTabletStage]에서 그대로 가져옵니다. 이 표는 "어느 단계가 무엇을
/// 몇 초 보여 주고, 그 값은 어디서 고치는가"를 한눈에 보는 자리입니다.
///
///   발표 길이      tablet/screens/phase_views.dart (holdOf)
///   단계 전환      shared/animations/phase_transition.dart
///   카드 분배      shared/animations/role_deal_toss_animation.dart
///   다음 단계 명령  tablet/providers/game_stage.dart (advance)
GameFlowConfig<MafiaTabletStage> buildMafiaTabletFlowConfig(
  MafiaController game,
) {
  // 끝낼 때 서버 명령이 있는 단계는 연출(또는 마감) 뒤 태블릿이 알리고,
  // 없는 단계는 서버가 바꿔 주기를 기다립니다.
  GameFlowAdvancePolicy policyOf(MafiaTabletStage stage) =>
      stage.advance(game) == null
      ? GameFlowAdvancePolicy.waitsForServer
      : GameFlowAdvancePolicy.clientCallbackThenServer;

  Duration holdOf(MafiaTabletStage stage) =>
      stage.announcementHoldOf(game) ?? Duration.zero;

  const phaseTransition = GameFlowAnimationConfig(
    widget: MafiaPhaseTransition,
    duration: MafiaPhaseTransition.enterDuration,
  );

  return GameFlowConfig<MafiaTabletStage>(
    steps: {
      // ── 1. 서버 연결 ──────────────────────────────────────────────
      MafiaTabletStage.connecting: GameFlowStep<MafiaTabletStage>(
        stage: MafiaTabletStage.connecting,
        description: '첫 공개 상태를 기다린다',
        showScreen: false,
        advancePolicy: policyOf(MafiaTabletStage.connecting),
      ),

      // ── 2. 역할 분배 ──────────────────────────────────────────────
      // 시간이 아니라 **전원 확인**으로 넘어갑니다. 확인 뒤 안내 순서는
      // [MafiaTabletTiming](시작 안내 → 대기 → 밤 안내)이 정합니다.
      MafiaTabletStage.roleDeal: GameFlowStep<MafiaTabletStage>(
        stage: MafiaTabletStage.roleDeal,
        description: '카드를 뒷면 그대로 각 자리로 나눠 주고 전원 확인을 기다린다',
        screenWidget: MafiaTabletRoleDealView,
        showScreen: true,
        animation: GameFlowAnimationConfig(
          widget: MafiaRoleDealTossAnimation,
          duration: MafiaRoleDealTossAnimation.totalDuration(
            game.orderedPlayers.length,
          ),
        ),
        advancePolicy: policyOf(MafiaTabletStage.roleDeal),
      ),

      // ── 3. 밤 ─────────────────────────────────────────────────────
      MafiaTabletStage.night: GameFlowStep<MafiaTabletStage>(
        stage: MafiaTabletStage.night,
        description: '밤 — 마감까지 기다린다(진행 현황은 보여 주지 않는다)',
        screenWidget: MafiaTabletNightView,
        showScreen: true,
        animation: phaseTransition,
        advancePolicy: policyOf(MafiaTabletStage.night),
      ),

      // ── 4. 아침 발표 ──────────────────────────────────────────────
      MafiaTabletStage.morning: GameFlowStep<MafiaTabletStage>(
        stage: MafiaTabletStage.morning,
        description: "'아침이 되었습니다' → 사망자 발표 → '토론을 시작합니다'",
        screenWidget: MafiaTabletMorningSequence,
        showScreen: true,
        animation: GameFlowAnimationConfig(
          widget: MafiaTabletMorningSequence,
          duration: holdOf(MafiaTabletStage.morning),
        ),
        advancePolicy: policyOf(MafiaTabletStage.morning),
      ),

      // ── 5. 낮 토론 · 6. 투표 ─────────────────────────────────────
      // 토론과 투표는 **같은 화면**입니다. 삽화가 크기를 유지한 채 투표함만
      // 떠올라야 해서, 단계가 바뀌어도 전환 연출을 다시 돌리지 않습니다.
      MafiaTabletStage.day: GameFlowStep<MafiaTabletStage>(
        stage: MafiaTabletStage.day,
        description: '낮 자유 토론 — 마감까지 기다린다',
        screenWidget: MafiaTabletDayView,
        sharedWith: const [MafiaTabletStage.voting],
        showScreen: true,
        animation: phaseTransition,
        advancePolicy: policyOf(MafiaTabletStage.day),
      ),
      MafiaTabletStage.voting: GameFlowStep<MafiaTabletStage>(
        stage: MafiaTabletStage.voting,
        description: '투표 — 토론 화면 그대로 투표함이 떠오르고 투표지가 날아든다',
        screenWidget: MafiaTabletDayView,
        showScreen: true,
        advancePolicy: policyOf(MafiaTabletStage.voting),
      ),

      // ── 7. 개표 · 처형 발표 ──────────────────────────────────────
      MafiaTabletStage.voteResult: GameFlowStep<MafiaTabletStage>(
        stage: MafiaTabletStage.voteResult,
        description: "개표 → 처형자 이름·신분 공개 → '밤이 되었습니다'",
        screenWidget: MafiaTabletVoteResultSequence,
        showScreen: true,
        animation: GameFlowAnimationConfig(
          widget: MafiaTabletVoteResultSequence,
          duration: holdOf(MafiaTabletStage.voteResult),
        ),
        advancePolicy: policyOf(MafiaTabletStage.voteResult),
      ),

      // ── 8. 결과 ───────────────────────────────────────────────────
      MafiaTabletStage.finished: GameFlowStep<MafiaTabletStage>(
        stage: MafiaTabletStage.finished,
        description: '승리 진영 포스터와 다시하기·HOME을 보여 준다',
        screenWidget: MafiaTabletResultView,
        showScreen: true,
        animation: phaseTransition,
        advancePolicy: policyOf(MafiaTabletStage.finished),
      ),
    },
  );
}

// ============================================================================
// 역할 분배 → 밤 → 아침 → 낮 → 투표 → 개표 → 결과: 실제 화면 연결
// ============================================================================

class MafiaTabletStageView extends StatelessWidget {
  const MafiaTabletStageView({
    super.key,
    required this.stage,
    required this.controller,
    required this.playerLayout,
    this.remainingSeconds,
    this.showsNightNotice = false,
    this.showsGameStartNotice = false,
    this.onRulebookPressed,
    this.onSettingsPressed,
    this.onRestart,
    this.onHome,
  });

  final MafiaTabletStage stage;
  final MafiaController controller;
  final PlayerLayoutModel playerLayout;

  /// 남은 시간(초)입니다. 토론 타이머가 씁니다.
  final int? remainingSeconds;

  /// 역할 배분 화면 위에 '밤이 됐습니다' 안내를 덮을지입니다.
  final bool showsNightNotice;

  /// '게임을 시작하겠습니다' 안내를 덮어 보여 줄지입니다(전원 확인 직후).
  final bool showsGameStartNotice;

  final VoidCallback? onRulebookPressed;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onRestart;
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 해는 아침·낮·투표에 걸쳐 **같은 자리에 그대로 있습니다.** 화면마다
        // 따로 그리면 단계가 바뀔 때 해가 사라졌다 다시 떠 산만해집니다.
        // 개표는 흰 개표판이 해를 덮는 시안이라 제외합니다(처형 발표 화면은
        // 개표 뒤에 오므로 자기 해를 직접 그립니다).
        if (_showsPersistentSun) const MafiaTabletSun(),
        // 단계가 바뀔 때 있던 요소가 빠지고 새 요소가 들어옵니다(확정 2026-08).
        // key가 단계 이름이라 같은 단계 안의 상태 변화로는 다시 시작하지 않습니다.
        MafiaPhaseTransition(
          child: KeyedSubtree(
            key: ValueKey(_transitionKey),
            child: _buildStage(),
          ),
        ),
        // 룰북·설정 아이콘은 단계와 무관하게 **늘 같은 자리에 있습니다.**
        // 각 화면이 따로 그리면 단계마다 아이콘이 깜빡여 화면 전체가 새로
        // 그려지는 느낌이 납니다. 결과 화면은 자체 버튼이 있어 제외합니다.
        if (stage != MafiaTabletStage.finished)
          MafiaTabletChrome(
            onRulebookPressed: onRulebookPressed,
            onSettingsPressed: onSettingsPressed,
          ),
      ],
    );
  }

  /// 화면 전환에서 이 단계를 무엇으로 볼지입니다.
  ///
  /// 토론과 투표는 **같은 화면**으로 둡니다(확정 2026-08). 삽화가 크기를
  /// 유지한 채 투표함만 떠올라야 하는데, 페이지 전환이 끼면 삽화가 사라졌다
  /// 다시 나타납니다. 이 관계는 [buildMafiaTabletFlowConfig]의 `sharedWith`에
  /// 적혀 있고, 여기서는 그 화면의 주인 단계를 key로 씁니다.
  String get _transitionKey =>
      buildMafiaTabletFlowConfig(controller).widgetOwnerOf(stage).stage.name;

  /// 해를 상위에서 계속 그리는 단계인지입니다.
  bool get _showsPersistentSun =>
      stage == MafiaTabletStage.morning ||
      stage == MafiaTabletStage.day ||
      stage == MafiaTabletStage.voting;

  Widget _buildStage() {
    final trial = controller.ruleState;
    if (stage == MafiaTabletStage.voting && trial.trialStage != null) {
      return MafiaTrialView(
        candidate: controller.players[trial.candidateUid]?.nickname ?? '후보',
        defending: trial.trialStage == 'defense',
        isTablet: true,
        remainingSeconds: remainingSeconds,
      );
    }
    // 기자가 취재한 사람입니다. 아침 발표가 이 사람의 카드를 뒤집습니다.
    final exposedUid = controller.morningResult?.exposedUid;

    return switch (stage) {
      // 역할 배분은 태블릿 배경 위에서 공용 분배 연출을 돌립니다(확정 방식).
      // 카드는 뒷면 그대로입니다 — 태블릿에서 신분이 보이면 안 됩니다.
      MafiaTabletStage.roleDeal => MafiaTabletRoleDealView(
        players: controller.orderedPlayers,
        confirmedCount: controller.roleConfirmedCount,
        showsNightNotice: showsNightNotice,
        showsGameStartNotice: showsGameStartNotice,
      ),
      // 시안에 문구가 없어 진행 현황도 넣지 않습니다.
      MafiaTabletStage.night => MafiaTabletNightView(),
      MafiaTabletStage.morning => MafiaTabletMorningSequence(
        result: controller.morningResult,
        players: controller.players,
        // 기자가 취재에 성공한 아침이면 그 사람의 신분이 공개됩니다.
        exposedRole: exposedUid == null
            ? null
            : controller.revealedRoleOf(exposedUid),
      ),
      // 토론과 투표 시간은 같은 시안에서 가운데 그림만 다릅니다.
      // 확정(2026-08): 과반수 투표로 토론이 끝나면 안내를 띄운 뒤 투표로
      // 넘어갑니다(서버가 낮 마감을 안내 길이만큼으로 줄여 둡니다).
      MafiaTabletStage.day when controller.isDayEndedByVote =>
        const MafiaAnnouncementReveal(
          child: MafiaTabletNotice.day(text: MafiaCopy.discussionSkippedNotice),
        ),
      MafiaTabletStage.day => MafiaTabletDayView(
        showBallotBox: false,
        remainingSeconds: remainingSeconds,
      ),
      MafiaTabletStage.voting => MafiaTabletDayView(
        showBallotBox: true,
        // 투표지가 그 사람 좌석에서 출발하도록 좌석 정보를 함께 넘깁니다.
        voteSubmittedUids: controller.voteSubmittedUids,
        seatIndexes: _seatIndexes,
        boardSeatCount: _boardSeatCount,
      ),
      MafiaTabletStage.voteResult => _buildVoteResult(),
      MafiaTabletStage.finished => MafiaTabletResultView(
        winner: controller.winnerFaction,
        // 중립은 이긴 **역할**로 포스터가 갈립니다(광대/처형자/연쇄살인마/교단).
        winnerRoleIds: controller.winnerRoleIds,
        // 그림이 없는 승리에서만 쓰는 대비 문구입니다.
        winnerLabel: controller.winnerLabel,
        players: controller.players,
        revealedRoles: {
          for (final entry in controller.players.keys)
            entry: controller.revealedRoleOf(entry),
        },
        onRestart: onRestart,
        onHome: onHome,
      ),
      MafiaTabletStage.connecting => const SizedBox.shrink(),
    };
  }

  /// 개표 → 처형 발표 순서입니다.
  ///
  /// 서버가 `voteResult` 하나로만 알려 주므로 개표판을 먼저 보여 준 뒤 발표로
  /// `uid → 좌석 번호`입니다.
  Map<String, int> get _seatIndexes => {
    for (final player in controller.players.values)
      player.uid: player.seatIndex,
  };

  /// 방의 전체 좌석 수입니다. 좌석 번호는 방 기준이라 인원수보다 클 수
  /// 있어(12인 방에 4명), 가장 큰 번호까지 담기는 크기를 씁니다.
  int get _boardSeatCount {
    var maxSeat = 0;
    for (final player in controller.players.values) {
      if (player.seatIndex > maxSeat) maxSeat = player.seatIndex;
    }
    return maxSeat + 1;
  }

  /// 넘어갑니다. 그 전환은 [MafiaTabletVoteResultSequence]가 셉니다.
  Widget _buildVoteResult() {
    final result = controller.voteResult;
    return MafiaTabletVoteResultSequence(
      limitedDisclosure: controller.ruleState.rules.executionReveal != 'role',
      revealedFaction: controller.ruleState.rules.executionReveal == 'faction'
          ? controller.ruleState.revealedFactions[controller
                .voteResult
                ?.executedUid]
          : null,
      key: ValueKey('voteResult_${controller.round}'),
      result: result,
      players: controller.players,
      executed: controller.executedPlayer,
      executedRole: result?.executedUid == null
          ? null
          : controller.revealedRoleOf(result!.executedUid!),
    );
  }
}

// ============================================================================
// 게임 화면 진입점
// ============================================================================

class MafiaTabletGame extends ConsumerStatefulWidget {
  const MafiaTabletGame({
    super.key,
    required this.roomCode,
    required this.gameService,
    required this.playerLayout,
    required this.provider,
  });

  final String roomCode;
  final MafiaService gameService;
  final PlayerLayoutModel playerLayout;
  final GameRoomContext provider;

  @override
  ConsumerState<MafiaTabletGame> createState() => _MafiaTabletGameState();
}
