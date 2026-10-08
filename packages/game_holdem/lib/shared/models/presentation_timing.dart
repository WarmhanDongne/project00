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
}
