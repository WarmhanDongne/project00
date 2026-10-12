/// 태블릿 연출 시간과 휴대폰 진행 막대가 함께 쓰는 값입니다.
abstract final class HoldemTiming {
  /// 카드 배분 연출 뒤 첫 행동을 여는 시간입니다.
  // 중앙 덱 등장·좌석별 2장 분배(2950ms)가 끝난 뒤 첫 턴을 엽니다.
  static const dealing = Duration(milliseconds: 3350);

  /// 판 결과를 보여 준 뒤 다음 판으로 넘어가는 시간입니다.
  ///
  /// 쇼다운은 모든 플레이어의 공개 카드를 확인할 시간을 확보합니다.
  static Duration handResult(String? reason) => reason == 'showdown'
      ? const Duration(seconds: 12)
      : const Duration(milliseconds: 3000);

  /// 쇼다운 첫 카드를 뒤집기 전 숨 고르는 시간입니다.
  static const showdownRevealStart = Duration(milliseconds: 900);

  /// 한 사람의 카드 두 장을 뒤집는 시간입니다.
  static const showdownFlip = Duration(milliseconds: 700);

  /// 쇼다운 카드를 한 사람씩 뒤집는 간격입니다. 사람이 많을수록 짧아집니다.
  static Duration showdownRevealGap(int count) {
    if (count <= 1) return const Duration(milliseconds: 1400);
    final ms = (4200 / count).round().clamp(700, 1400);
    return Duration(milliseconds: ms);
  }

  /// [order]번째(0부터) 사람의 카드를 뒤집기 시작하는 시점입니다.
  static Duration showdownRevealAt(int order, int count) =>
      showdownRevealStart + showdownRevealGap(count) * order;

  /// 모든 카드가 뒤집히고 잠깐 뒤 승자를 알리는 시점입니다.
  ///
  /// 태블릿과 휴대폰이 같은 값을 써서 휴대폰이 승자를 먼저 알려 주지 않습니다.
  static Duration showdownWinnerAt(int count) {
    if (count <= 0) return Duration.zero;
    final afterLast =
        showdownRevealAt(count - 1, count) +
        showdownFlip +
        const Duration(milliseconds: 1000);
    const least = Duration(milliseconds: 4200);
    return afterLast < least ? least : afterLast;
  }
}
