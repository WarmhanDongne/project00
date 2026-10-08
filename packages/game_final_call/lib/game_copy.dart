// [game_copy.dart] 는 파이널콜에서 사용하는 게임 화면에서 사용하는 문구를 모아 둔 파일이다.
//
// - [Package] : 파이널콜
// - [Copy] : 게임 화면에서 사용하는 문구를 한곳에서 관리
//
// 즉, 단계별 안내와 오류 문구를 한곳에서 일관되게 관리하기 위해 필요한 파일이다.

import 'package:game_final_call/shared/models/game_models.dart';

/// Final Call 화면에서 사용하는 사용자 문구입니다.
abstract final class FinalCallCopy {
  static const myTurn = '내 차례!';
  static const whereToDraw = '어디서 가져올까요?';
  static const deck = '덱';
  static const publicCard = '공개 카드';
  static const holdToCall = '꾹 눌러서 선언';
  static const pickOrDiscard = '바꿀 카드를 고르거나 버리세요';
  static const discardNewCard = '새 카드 버리기';
  static const pickCardToReplace = '바꿀 카드를 고르세요';
  static const replaceTarget = '바꿀 카드';
  static const ifReplaced = '바꾸면';
  static const pickToPreview = '손패에서 카드를 고르면\n바뀐 점수를 보여 줘요';
  static const myScore = '내 점수';
  static const turnOrder = '차례 순서';
  static const now = '지금';
  static const partner = '짝꿍';
  static const me = '나';
  static const lastSwap = '마지막 교체 차례예요';
  static const presetBest = '가장 높은 조합을 골라뒀어요';
  static const submitFinal = '최종 조합을 골라 제출하세요';
  static const submitted = '제출했어요';
  static const sameColorPartner = '같은 색 = 맞은편 짝꿍';
  static const swapping = '교체 중';
  static const turnBadge = '차례';

  static String turnOf(String nickname) => '$nickname 차례예요';
  static String callBy(String nickname) => '$nickname CALL!';
  static String callerOf(String nickname) => '$nickname의';
  static String deckCount(int count) => '덱 $count';
  static String roundCaption(int round) => '$round라운드 · $sameColorPartner';

  /// 숫자를 한자어로 읽을 때 받침이 있으면 '이랑', 없으면 '랑'을 붙입니다.
  static String replaceWith(String colorLabel, int value) {
    const vowelEnding = {2, 4, 5, 9};
    final particle = vowelEnding.contains(value) ? '랑' : '이랑';
    return '$colorLabel $value$particle 바꾸기';
  }

  static String turnsLater(int count) => '$count번째 뒤';
  static String teamWithPartner(String teamLabel, String partner) =>
      '$teamLabel · 짝꿍 $partner';

  /// 손패 아래 묶음 꼬리표 문구입니다(예: 7 + 7 = 14점, 7 × 3 = 21점).
  static String combinationEquation(FinalCallCombination combination) {
    final cards = combination.cards;
    final score = combination.score;
    if (cards.length <= 1) return '$score점';
    if (combination.isSameNumber && cards.length >= 3) {
      return '${cards.first.value} × ${cards.length} = $score점';
    }
    return '${cards.map((card) => card.value).join(' + ')} = $score점';
  }

  /// 점수 패널의 조합 설명입니다(예: 같은 숫자 7 × 3).
  static String combinationName(
    FinalCallCombination combination,
    String Function(String color) colorLabel,
  ) {
    final cards = combination.cards;
    if (cards.isEmpty) return '';
    if (combination.isSameNumber) {
      return '같은 숫자 ${cards.first.value} × ${cards.length}';
    }
    return '같은 색 ${colorLabel(cards.first.color)} '
        '${cards.map((card) => card.value).join(' + ')}';
  }

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
  /// 씁니다.
  static const phoneRules =
      '4명은 2대2, 6명은 2대2대2로 겨룹니다. 마주 보고 앉은 사람이 내 팀이며, '
      '레드·블루팀에 6인에서는 그린팀이 추가됩니다. 팀원 중 한 명이라도 하트 '
      '3개를 모두 잃으면 두 명 모두 탈락합니다. 마지막까지 남은 팀이 승리하고, '
      '남은 팀이 동시에 모두 탈락하면 무승부입니다.\n\n'
      '점수는 손패 4장에서 같은 색 카드의 합과 같은 숫자 카드의 합 중 더 높은 '
      '쪽입니다. 빨강 7, 빨강 3, 파랑 7, 노랑 2를 들고 있다면 같은 색은 10, '
      '같은 숫자는 14이므로 내 점수는 14입니다.\n\n'
      '내 차례에는 카드 더미나 공개된 카드에서 한 장을 가져와, 손패 한 장과 '
      '교체하거나 그대로 버립니다.\n\n'
      'CALL을 선언하면 나머지 사람이 마지막 교체를 한 번 하고 모든 패가 '
      '공개됩니다. 점수가 가장 낮은 사람은 하트 1개를 잃고, CALL한 사람이 '
      '최하위였다면 2개를 잃습니다. 최하위가 여러 명이면 모두가 잃습니다.\n\n'
      '같은 숫자 4장(포카드)으로 CALL하면 점수를 비교하지 않고 생존한 상대 팀 전원이 '
      '각각 하트 1개를 잃습니다. 포카드는 CALL한 본인에게만 효력이 있습니다.';

  /// 태블릿 규칙 화면에서 Markdown으로 표시하는 전체 규칙입니다.
  static const tabletRules = '''
# 게임 목표

**4명은 2대2, 6명은 2대2대2로** 겨루는 팀전입니다. 마주 보고 앉은 사람이 내 팀입니다.

팀원 중 **한 명이라도** 하트를 모두 잃으면 **팀 두 명 모두 탈락**합니다.
탈락한 팀은 관전하며, 남은 팀끼리 계속해 **마지막 한 팀이 승리**합니다.
남은 팀이 동시에 모두 탈락하면 무승부입니다.
4인은 레드·블루팀, 6인은 레드·블루·그린팀으로 구성됩니다.

# 시작할 때

- 하트 **3개**
- 손패 **4장**
- 카드는 4가지 색 × 1~10, 모두 40장

# 점수 계산

손패 4장으로 만들 수 있는 두 가지 합 중 **더 높은 쪽**이 내 점수입니다.

- **같은 색** 카드의 합
- **같은 숫자** 카드의 합

예를 들어 빨강 7, 빨강 3, 파랑 7, 노랑 2를 들고 있다면
같은 색은 빨강 7+3=**10**, 같은 숫자는 7+7=**14**이므로 내 점수는 14입니다.

# 내 차례

카드 더미 또는 공개된 카드에서 **한 장**을 가져옵니다.
가져온 카드는 손패 한 장과 **교체**하거나 그대로 **버립니다**.

# CALL 선언

패에 자신이 있으면 **CALL**을 선언합니다.
나머지 사람은 마지막으로 한 번 더 교체하고, 모든 패가 공개됩니다.

- 점수가 가장 낮은 사람이 하트 **1개**를 잃습니다.
- CALL한 사람이 최하위였다면 하트 **2개**를 잃습니다.
- 최하위가 여러 명이면 해당하는 사람 모두가 잃습니다.

## 포카드로 CALL

같은 숫자 **4장**을 들고 CALL하면 점수를 비교하지 않습니다.
**생존한 상대 팀 전원이 각각 하트 1개**를 잃고, 내 팀은 아무도 잃지 않습니다.

포카드는 CALL한 본인에게만 효력이 있습니다.
남이 CALL한 라운드에 포카드를 들고 있어도 평소처럼 점수로만 겨룹니다.
''';
}
