import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/widgets/card_view.dart';

abstract final class HoldemCopy {
  static const waiting = '다른 플레이어를 기다리는 중';
  static const eliminated = '칩을 모두 잃어 탈락했어요';
  static const eliminatedHint = '남은 플레이어의 승부를 태블릿에서 지켜보세요';
  static const dealing = '카드를 나눠 주는 중';
  static const result = '팟을 정산하고 있어요';
  static const folded = '이번 판은 폴드했어요';
  static const checkTablet = '태블릿을 확인하세요';
  static const peekHint = '카드를 눌러 확인';
  static const peekRelease = '손을 떼면 가려져요';
  static const vibrateTitle = '내 차례가 되면 진동으로 알려드려요';
  static const vibrateHint = '카드는 손을 떼면 다시 가려져요';
  static const myTurn = '내 차례예요';
  static const raiseTitle = '얼마나 올릴까요?';
  static const nextHand = '다음 판 준비 중';
  static const phoneRules =
      '각 플레이어는 홀 카드 2장을 받고, 테이블의 공용 카드 5장과 조합해 가장 강한 5장을 만듭니다.\n\n'
      '프리플롭, 플롭, 턴, 리버마다 폴드·체크·콜·베트·레이즈·올인 중 서버가 허용한 행동을 선택합니다.\n\n'
      '한 명을 제외한 모두가 폴드하면 남은 플레이어가 팟을 받습니다. 둘 이상 남으면 쇼다운에서 족보와 키커를 비교합니다.\n\n'
      '1,000칩으로 시작하며 블라인드는 10/20에서 시작해 5핸드마다 두 배로 오릅니다. 칩이 0이면 탈락하고 마지막 한 명이 우승합니다.';
  static const tabletRules = '''
# 텍사스 홀덤

각 플레이어는 비공개 홀 카드 2장과 공개 커뮤니티 카드 5장 중 가장 강한 5장 조합을 만듭니다.

## 베팅

프리플롭·플롭·턴·리버마다 폴드, 체크, 콜, 베트, 레이즈, 올인을 선택합니다. 행동 제한은 20초이며 체크가 가능하면 자동 체크, 아니면 자동 폴드됩니다.

## 토너먼트

모두 1,000칩으로 시작합니다. 블라인드는 10/20에서 시작해 5핸드마다 두 배로 오르며 최대 160/320입니다. 리바이는 없고 마지막 한 명이 승리합니다.
''';

  static String phase(String value) => switch (value) {
    'preflop' => 'PREFLOP',
    'flop' => 'FLOP',
    'turn' => 'TURN',
    'river' => 'RIVER',
    'handResult' => 'SHOWDOWN',
    'dealing' => 'PREFLOP',
    _ => value.toUpperCase(),
  };

  static String action(String kind) => switch (kind) {
    'fold' => '폴드',
    'check' => '체크',
    'call' => '콜',
    'bet' => '벳',
    'raise' => '레이즈',
    'allIn' => '올인',
    _ => '',
  };

  /// "하준 님이 400 벳 했어요"처럼 마지막 공개 행동을 문장으로 바꿉니다.
  static String actionSentence(String nickname, String kind, int amount) {
    final label = action(kind);
    if (label.isEmpty) return '';
    final shown = switch (kind) {
      'fold' || 'check' => '',
      _ => amount > 0 ? '$amount ' : '',
    };
    return '$nickname 님이 $shown$label 했어요';
  }

  /// 휴대폰·결과 화면의 족보 설명입니다. 예: `원 페어 · K`, `스페이드 플러시 · A 하이`.
  static String handLabel(String category, List<HoldemCardModel> bestCards) {
    final name = HoldemCopy.category(category);
    final ranks = _rankGroups(bestCards);
    if (ranks.isEmpty) return name;
    String rank(int value) => _rankName(value);
    final suit = bestCards.isEmpty
        ? ''
        : '${HoldemSuit.from(bestCards.first.suit).label} ';
    return switch (category) {
      'straightFlush' when _straightHigh(ranks) == 14 => '$suit로열 플러시',
      'straightFlush' => '$suit$name · ${rank(_straightHigh(ranks))} 하이',
      'flush' => '$suit$name · ${rank(ranks.first)} 하이',
      'straight' => '$name · ${rank(_straightHigh(ranks))} 하이',
      'twoPair' ||
      'fullHouse' => '$name · ${rank(ranks[0])}, ${rank(ranks[1])}',
      'highCard' => '$name · ${rank(ranks.first)}',
      _ => '$name · ${rank(ranks.first)}',
    };
  }

  /// 태블릿 좌석의 짧은 족보입니다. 예: `플러시`, `트리플 K`.
  static String shortHandLabel(
    String category,
    List<HoldemCardModel> bestCards,
  ) {
    final name = HoldemCopy.category(category);
    final ranks = _rankGroups(bestCards);
    if (ranks.isEmpty) return name;
    return switch (category) {
      'onePair' ||
      'threeOfAKind' ||
      'fourOfAKind' => '$name ${_rankName(ranks.first)}',
      _ => name,
    };
  }

  static const _rankValues = {
    '2': 2,
    '3': 3,
    '4': 4,
    '5': 5,
    '6': 6,
    '7': 7,
    '8': 8,
    '9': 9,
    '10': 10,
    'j': 11,
    'q': 12,
    'k': 13,
    'a': 14,
  };

  /// 같은 rank가 많은 순, 높은 rank 순으로 정렬한 rank 값입니다.
  static List<int> _rankGroups(List<HoldemCardModel> cards) {
    final counts = <int, int>{};
    for (final card in cards) {
      final value = _rankValues[card.rank.toLowerCase()];
      if (value != null) counts[value] = (counts[value] ?? 0) + 1;
    }
    final values = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : b.compareTo(a);
      });
    return values;
  }

  static int _straightHigh(List<int> values) =>
      values.contains(14) && values.contains(5) && !values.contains(13)
      ? 5
      : values.reduce((a, b) => a > b ? a : b);

  static String _rankName(int value) => switch (value) {
    14 => 'A',
    13 => 'K',
    12 => 'Q',
    11 => 'J',
    _ => '$value',
  };

  static String category(String value) => switch (value) {
    'straightFlush' => '스트레이트 플러시',
    'fourOfAKind' => '포카드',
    'fullHouse' => '풀하우스',
    'flush' => '플러시',
    'straight' => '스트레이트',
    'threeOfAKind' => '트리플',
    'twoPair' => '투 페어',
    'onePair' => '원 페어',
    _ => '하이 카드',
  };
}
