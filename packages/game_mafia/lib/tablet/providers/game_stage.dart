import 'package:game_mafia/shared/providers/game_controller.dart';
import 'package:game_mafia/tablet/screens/phase_views.dart';

// [game_stage.dart] 는 마피아에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [TabletScreen] : 태블릿에서 보이는 공용 게임 진행 화면을 구성함
//
// 즉, 모든 플레이어가 함께 보는 진행 상태와 연출을 표시하기 위해 필요한 파일이다.

// ========================[ import ]==========================
// ============================================================

// ---------------------------------------------------------------------------
// 태블릿 진행 단계
// ---------------------------------------------------------------------------
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
  /// 시간은 각 연출이 스스로 정한 박자의 합입니다. 한쪽만 바꾸면 안내가
  /// 잘리거나 빈 화면이 남으므로 연출 쪽 상수를 그대로 가져옵니다.
  ///
  /// 확정(2026-08): 이 발표로 게임이 끝나면 마지막 안내(다음 단계 예고)를
  /// 건너뛰므로 그만큼 짧습니다. 그래서 상태를 받아 계산합니다.
  Duration? announcementHoldOf(MafiaController game) => switch (this) {
    // '아침이 되었습니다'(2.5초) → 사망자 발표(8초) → '토론을 시작합니다'(2.5초).
    MafiaTabletStage.morning => MafiaTabletMorningSequence.holdOf(
      game.morningResult,
    ),
    // 개표(4초) → 처형자 이름·신분 공개(9초) → '밤이 되었습니다'(2.5초).
    MafiaTabletStage.voteResult => MafiaTabletVoteResultSequence.holdOf(
      game.voteResult,
    ),
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

// ---------------------------------------------------------------------------
// 단계별 화면
// ---------------------------------------------------------------------------
/// 단계에 맞는 태블릿 시안 화면을 그립니다.
///
/// 서버 상태 해석은 [resolveMafiaTabletStage] 한 곳에서만 합니다. 아래 위젯들은
/// 값을 받아 그리기만 합니다.
