import 'package:flutter/material.dart';
import 'package:project00/games/mafia/controllers/mafia_controller.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_day_view.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_phase_views.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_result_view.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';

//=======================태블릿 진행 단계==============================
/// 서버 단계를 태블릿 **연출 단위**로 옮긴 값입니다.
///
/// 서버 phase와 거의 1:1이지만, 태블릿이 해야 할 일(기다리기 / 발표하기)이
/// 다르므로 그 차이를 여기에 담습니다.
enum MafiaTabletStage {
  /// 첫 공개 상태를 기다립니다.
  connecting,

  /// 카드를 각 자리로 나눠 주는 연출입니다(T1). 카드는 뒷면 그대로입니다.
  roleDeal,

  /// 밤입니다. 마감까지 기다립니다.
  night,

  /// 아침 발표입니다. 사망자를 보여 준 뒤 낮으로 넘깁니다.
  morning,

  /// 낮 자유 토론입니다. 마감까지 기다립니다.
  day,

  /// 투표 중입니다. 마감까지 기다립니다.
  voting,

  /// 개표·처형 발표입니다.
  voteResult,

  /// 결과 화면입니다.
  finished;

  /// 제한시간이 끝나면 서버에 알려야 하는 단계인지입니다.
  bool get hasDeadline =>
      this == MafiaTabletStage.night ||
      this == MafiaTabletStage.day ||
      this == MafiaTabletStage.voting;

  /// 발표 연출을 보여 주는 시간입니다. 없으면 null입니다.
  ///
  /// 이 시간이 지나면 태블릿이 서버에 완료를 알려 다음 단계로 넘깁니다.
  ///
  /// 역할 배분(roleDeal)은 여기 없습니다 — 시간이 아니라 **전원 확인**으로
  /// 넘어갑니다(확정: 전원 확인 → 10초 → '밤이 됐습니다' 안내 → 밤).
  /// 그 흐름은 화면(tablet_game.dart)이 관리합니다.
  Duration? get announcementHold => switch (this) {
    // 사망자 발표를 읽을 시간입니다(확정: 8초).
    MafiaTabletStage.morning => const Duration(milliseconds: 8000),
    // 개표(4초) → 처형자 이름(4초) → 신분 공개(5초). 확정: 약 13초.
    MafiaTabletStage.voteResult => const Duration(milliseconds: 13000),
    _ => null,
  };

  /// 이 단계를 끝낼 때 부를 서버 명령입니다. 없으면 null입니다.
  Future<bool> Function()? advance(MafiaController game) => switch (this) {
    MafiaTabletStage.roleDeal => game.completeRoleReveal,
    MafiaTabletStage.night => game.timeoutNight,
    MafiaTabletStage.morning => game.completeMorning,
    MafiaTabletStage.day => game.timeoutDay,
    MafiaTabletStage.voting => game.timeoutVote,
    MafiaTabletStage.voteResult => game.completeVoteResult,
    _ => null,
  };
}

/// 서버 상태를 태블릿 단계로 옮깁니다. **이 판정은 여기 한 곳에만 둡니다.**
MafiaTabletStage resolveMafiaTabletStage(MafiaController game) {
  if (game.loading) return MafiaTabletStage.connecting;
  if (game.isFinished) return MafiaTabletStage.finished;
  return switch (game.phase) {
    'roleReveal' => MafiaTabletStage.roleDeal,
    'night' => MafiaTabletStage.night,
    'morning' => MafiaTabletStage.morning,
    'day' => MafiaTabletStage.day,
    'voting' => MafiaTabletStage.voting,
    'voteResult' => MafiaTabletStage.voteResult,
    _ => MafiaTabletStage.connecting,
  };
}

//=======================단계별 화면==============================
/// 단계에 맞는 태블릿 시안 화면을 그립니다.
///
/// 서버 상태 해석은 [resolveMafiaTabletStage] 한 곳에서만 합니다. 아래 위젯들은
/// 값을 받아 그리기만 합니다.
class MafiaTabletStageView extends StatelessWidget {
  const MafiaTabletStageView({
    super.key,
    required this.stage,
    required this.controller,
    required this.playerLayout,
    this.remainingSeconds,
    this.showsNightNotice = false,
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

  final VoidCallback? onRulebookPressed;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onRestart;
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      // 역할 배분은 태블릿 배경 위에서 공용 분배 연출을 돌립니다(확정 방식).
      // 카드는 뒷면 그대로입니다 — 태블릿에서 신분이 보이면 안 됩니다.
      MafiaTabletStage.roleDeal => MafiaTabletRoleDealView(
        players: controller.orderedPlayers,
        confirmedCount: controller.roleConfirmedCount,
        showsNightNotice: showsNightNotice,
        onRulebookPressed: onRulebookPressed,
        onSettingsPressed: onSettingsPressed,
      ),
      // 시안에 문구가 없어 진행 현황도 넣지 않습니다.
      MafiaTabletStage.night => MafiaTabletNightView(
        onRulebookPressed: onRulebookPressed,
        onSettingsPressed: onSettingsPressed,
      ),
      MafiaTabletStage.morning => MafiaTabletMorningView(
        result: controller.morningResult,
        players: controller.players,
        onRulebookPressed: onRulebookPressed,
        onSettingsPressed: onSettingsPressed,
      ),
      // 토론과 투표 시간은 같은 시안에서 가운데 그림만 다릅니다.
      MafiaTabletStage.day => MafiaTabletDayView(
        showBallotBox: false,
        remainingSeconds: remainingSeconds,
        onRulebookPressed: onRulebookPressed,
        onSettingsPressed: onSettingsPressed,
      ),
      MafiaTabletStage.voting => MafiaTabletDayView(
        showBallotBox: true,
        onRulebookPressed: onRulebookPressed,
        onSettingsPressed: onSettingsPressed,
      ),
      MafiaTabletStage.voteResult => _buildVoteResult(),
      MafiaTabletStage.finished => MafiaTabletResultView(
        winner: controller.winnerFaction,
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
  /// 넘어갑니다. 그 전환은 [MafiaTabletVoteResultSequence]가 셉니다.
  Widget _buildVoteResult() {
    final result = controller.voteResult;
    return MafiaTabletVoteResultSequence(
      key: ValueKey('voteResult_${controller.round}'),
      result: result,
      players: controller.players,
      executed: controller.executedPlayer,
      executedRole: result?.executedUid == null
          ? null
          : controller.revealedRoleOf(result!.executedUid!),
      onRulebookPressed: onRulebookPressed,
      onSettingsPressed: onSettingsPressed,
    );
  }
}
