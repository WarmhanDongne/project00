//=======================마피아 진행 시간==============================
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

  /// 생존 인원에 맞는 토론 시간입니다. 표 밖의 인원은 양 끝 값을 씁니다.
  static Duration discussion(int aliveCount) {
    final clamped = aliveCount.clamp(2, 12);
    return Duration(seconds: discussionSecondsByAliveCount[clamped] ?? 300);
  }
}
