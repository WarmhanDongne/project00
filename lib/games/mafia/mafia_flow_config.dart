//=======================마피아 흐름 설정==============================
// 다른 게임과 같은 자리(`<게임>_flow_config.dart`)입니다. 다만 담는 값이
// 조금 다릅니다.
//
// | 게임 | 이 파일에 있는 것 |
// |---|---|
// | 라이어스 포커·파이널 콜 | **연출 시간**(카드 이동·문구 유지 등) |
// | 마피아 | **단계 제한시간의 서버 사본**(아래) |
//
// 마피아의 연출 시간은 연출마다 그 위젯에 있습니다. 찾을 때 여기서 출발하세요.
//
//   단계 유지 시간   screens/tablet/tablet_game_stage.dart (announcementHold)
//   발표 등장·퇴장   animations/announcement_reveal.dart
//   문구 내려찍기    animations/ejection_text.dart
//   단계 전환        animations/mafia_phase_transition.dart
//   카드 분배        animations/role_deal_toss_animation.dart
//   개표·투표지      screens/tablet/tablet_tally_view.dart · animations/ballot_animations.dart
//   배경음악         sound/mafia_bgm_plan.dart

/// 단계별 제한시간입니다.
///
/// ⚠️ **원본은 서버입니다**(`functions/src/mafia/types.ts`). 실제 마감은 서버가
/// 정한 `turnDeadlineAt`을 따르고, 이 표는 연습장(로컬 가짜 서버)이 같은
/// 흐름을 재현하는 데 씁니다. 두 값이 갈리지 않도록
/// `functions/test/mafia-discussion-parity.test.mjs`가 대조합니다.
abstract final class MafiaTiming {
  /// 낮 자유 토론 시간입니다(초). **생존 인원** 기준입니다(확정 2026-08).
  ///
  /// 사람이 줄면 할 말도 줄어듭니다. 인원과 무관하게 같은 시간을 주면 적은
  /// 인원에서는 침묵이 길어집니다.
  static const Map<int, int> discussionSecondsByAliveCount = {
    2: 90,
    3: 90,
    4: 120,
    5: 150,
    6: 180,
    7: 210,
    8: 240,
    9: 300,
    10: 300,
    11: 300,
    12: 300,
  };

  /// 신분 확인 제한시간입니다(확정: 약 1분).
  ///
  /// 서버 원본은 `MAFIA_ROLE_REVEAL_MS`입니다. 휴대폰이 이 값으로 단계가
  /// 시작된 시각을 되짚어(마감 − 이 시간) 분배 연출이 끝나는 순간을 셉니다.
  static const Duration roleReveal = Duration(seconds: 60);

  //=======================밤의 순위 구간 (확정 2026-08)==============================
  //
  //   1~4순위(60초) → 5~8순위(60초) → 9~14순위(50초)
  //   → 마무리(10초) → 아침
  //
  // 해당 구간의 실제 행동 역할이 없거나 전원이 일찍 제출하면 남은
  // 시간을 버리고 곧바로 다음 구간이 열립니다.
  // 서버가 구간을 정하고(`nightStage`), 화면은 그 값을 따릅니다.

  /// 도둑·교주·마담·건달(1~4순위) 구간입니다.
  static const Duration nightPriority = Duration(seconds: 60);

  /// 자경단원·마피아·짐승인간·연쇄살인마(5~8순위) 구간입니다.
  static const Duration nightAttack = Duration(seconds: 60);

  /// 보호·정보·조사 역할(9~14순위) 구간입니다.
  static const Duration nightSupport = Duration(seconds: 50);

  /// 행동이 모두 끝난 뒤 아침이 오기까지 기다리는 시간입니다(확정: 10초).
  ///
  /// 서버 원본은 `MAFIA_NIGHT_WAIT_MS`입니다.
  static const Duration nightWait = Duration(seconds: 10);

  //=======================종료 후 화면 닫기==============================
  /// 승부 없이 끝난 판에서 태블릿 게임 화면을 닫기 전 대기시간입니다.
  ///
  /// ⚠️ 위의 값들과 달리 이것은 **서버 사본이 아니라 클라이언트 연출 시간**입니다.
  /// 라이어스 포커 `LiarsPokerFlowTiming.closingRouteDelay`, 파이널 콜
  /// `FinalCallFlowTiming.closingRouteDelay`와 같은 1초로 맞춥니다.
  static const Duration closingRouteDelay = Duration(seconds: 1);

  /// 밤 전체 최대 시간입니다(3분).
  static Duration get night =>
      nightPriority + nightAttack + nightSupport + nightWait;

  /// 생존 인원에 맞는 토론 시간입니다. 표 밖의 인원은 양 끝 값을 씁니다.
  static Duration discussion(int aliveCount) {
    final clamped = aliveCount.clamp(2, 12);
    return Duration(seconds: discussionSecondsByAliveCount[clamped] ?? 300);
  }
}
