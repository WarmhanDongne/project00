/// Final Call 화면에서 사용하는 사용자 문구입니다.
abstract final class FinalCallCopy {
  static const selectFinalCombination = '최종 조합을 선택하세요';
  static const submit = '제출';
  static const selectCards = '카드 선택';
  static const newCard = '새 카드';
  static const discard = '버리기';
  static const replace = '교체';
  static const confirm = '확인';
  static const cardChange = '카드\n교체';
  static const turnSuffix = '님 차례입니다';

  /// 휴대폰 상단 팁 아이콘으로 여는 규칙 문구입니다.
  ///
  /// 마크다운을 지원하지 않는 일반 텍스트로 표시되므로 기호 없이 문장으로만
  /// 씁니다. 태블릿 룰북(`widgets/tablet/rolebook.dart`)과 내용이 어긋나지
  /// 않게 함께 고치세요.
  static const phoneRules =
      '4명이 2대2로 겨루는 팀전입니다. 마주 보고 앉은 사람이 내 팀이며, 빨간 '
      '하트 팀과 파란 하트 팀으로 자동 지정됩니다. 팀원 중 한 명이라도 하트 '
      '3개를 모두 잃으면 팀 전체가 패배합니다.\n\n'
      '점수는 손패 4장에서 같은 색 카드의 합과 같은 숫자 카드의 합 중 더 높은 '
      '쪽입니다. 빨강 7, 빨강 3, 파랑 7, 노랑 2를 들고 있다면 같은 색은 10, '
      '같은 숫자는 14이므로 내 점수는 14입니다.\n\n'
      '내 차례에는 카드 더미나 공개된 카드에서 한 장을 가져와, 손패 한 장과 '
      '교체하거나 그대로 버립니다.\n\n'
      'CALL을 선언하면 나머지 사람이 마지막 교체를 한 번 하고 모든 패가 '
      '공개됩니다. 점수가 가장 낮은 사람은 하트 1개를 잃고, CALL한 사람이 '
      '최하위였다면 2개를 잃습니다. 최하위가 여러 명이면 모두가 잃습니다.\n\n'
      '같은 숫자 4장(포카드)으로 CALL하면 점수를 비교하지 않고 상대 팀 두 명이 '
      '각각 하트 1개를 잃습니다. 포카드는 CALL한 본인에게만 효력이 있습니다.';
}
