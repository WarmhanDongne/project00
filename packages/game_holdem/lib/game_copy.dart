import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/widgets/card_view.dart';
import 'package:game_kit/localization/game_locale.dart';

abstract final class HoldemCopy {
  static String _t(String ko, String en, String zhHans, String zhHant) =>
      GameLocale.select(ko: ko, en: en, zhHans: zhHans, zhHant: zhHant);

  static String get waiting =>
      _t('다른 플레이어를 기다리는 중', 'Waiting for other players', '等待其他玩家', '等待其他玩家');
  static String get eliminated =>
      _t('칩을 모두 잃어 탈락했어요', 'You are out of chips', '筹码耗尽，已淘汰', '籌碼耗盡，已淘汰');
  static String get eliminatedHint => _t(
    '남은 플레이어의 승부를 태블릿에서 지켜보세요',
    'Watch the remaining players on the tablet',
    '请在平板上观看剩余玩家的对局',
    '請在平板上觀看剩餘玩家的對局',
  );
  static String get dealing =>
      _t('카드를 나눠 주는 중', 'Dealing cards', '正在发牌', '正在發牌');
  static String get result =>
      _t('팟을 정산하고 있어요', 'Settling the pot', '正在结算底池', '正在結算底池');
  static String get folded =>
      _t('이번 판은 폴드했어요', 'You folded this hand', '本手已弃牌', '本手已棄牌');
  static String get checkTablet =>
      _t('태블릿을 확인하세요', 'Check the tablet', '请查看平板', '請查看平板');
  static String get peekHint =>
      _t('카드를 눌러 확인', 'Hold to view cards', '按住查看手牌', '按住查看手牌');
  static String get peekRelease =>
      _t('손을 떼면 가려져요', 'Release to hide them', '松开后会隐藏', '放開後會隱藏');
  static String get vibrateTitle => _t(
    '내 차례가 되면 진동으로 알려드려요',
    'Your phone vibrates when it is your turn',
    '轮到你时手机会振动提醒',
    '輪到你時手機會震動提醒',
  );
  static String get vibrateHint => _t(
    '카드는 손을 떼면 다시 가려져요',
    'Cards hide again when you release',
    '松开后手牌会再次隐藏',
    '放開後手牌會再次隱藏',
  );
  static String get myTurn => _t('내 차례예요', 'Your turn', '轮到你', '輪到你');
  static String get raiseTitle =>
      _t('얼마나 올릴까요?', 'How much will you raise?', '加注多少？', '加注多少？');
  static String get nextHand =>
      _t('다음 판 준비 중', 'Preparing the next hand', '准备下一手', '準備下一手');
  static String get player => _t('플레이어', 'Player', '玩家', '玩家');
  static String get myChips => _t('내 칩', 'My chips', '我的筹码', '我的籌碼');
  static String get table => _t('테이블', 'Table', '牌桌', '牌桌');
  static String get myCards => _t('내 카드', 'My cards', '我的牌', '我的牌');
  static String get close => _t('닫기', 'Close', '关闭', '關閉');
  static String thinking(String nickname) => _t(
    '$nickname 님이 고민 중',
    '$nickname is thinking',
    '$nickname 正在思考',
    '$nickname 正在思考',
  );
  static String thinkingSeconds(int value) => _t(
    '고민 중 · $value초',
    'Thinking · ${value}s',
    '思考中 · $value秒',
    '思考中 · $value秒',
  );
  static String seconds(int value) =>
      _t('$value초', '${value}s', '$value 秒', '$value 秒');
  static String chipsOwned(String amount) =>
      _t('보유 칩 $amount', 'Chips $amount', '持有筹码 $amount', '持有籌碼 $amount');
  static String get phoneRules => _t(
    '각 플레이어는 홀 카드 2장을 받고, 테이블의 공용 카드 5장과 조합해 가장 강한 5장을 만듭니다.\n\n프리플롭, 플롭, 턴, 리버마다 폴드·체크·콜·베트·레이즈·올인 중 서버가 허용한 행동을 선택합니다.\n\n한 명을 제외한 모두가 폴드하면 남은 플레이어가 팟을 받습니다. 둘 이상 남으면 쇼다운에서 족보와 키커를 비교합니다.\n\n1,000칩으로 시작하며 블라인드는 10/20에서 시작해 5핸드마다 두 배로 오릅니다. 칩이 0이면 탈락하고 마지막 한 명이 우승합니다.',
    'Each player receives two hole cards and combines them with five community cards to make the best five-card hand.\n\nOn the preflop, flop, turn, and river, choose one of the actions allowed by the server: fold, check, call, bet, raise, or all-in.\n\nIf everyone but one player folds, the remaining player wins the pot. Otherwise, hands and kickers are compared at showdown.\n\nEveryone starts with 1,000 chips. Blinds begin at 10/20 and double every five hands. Players with no chips are eliminated; the last player wins.',
    '每位玩家获得 2 张底牌，并与桌面上的 5 张公共牌组成最强的 5 张牌。\n\n在翻牌前、翻牌、转牌和河牌阶段，从服务器允许的弃牌、过牌、跟注、下注、加注或全下中选择行动。\n\n若除一人外所有玩家都弃牌，剩余玩家获得底池。若仍有多人，则在摊牌时比较牌型与踢脚牌。\n\n每人以 1,000 筹码开始，盲注从 10/20 起，每 5 手翻倍。筹码为 0 即淘汰，最后一人获胜。',
    '每位玩家獲得 2 張底牌，並與桌面上的 5 張公共牌組成最強的 5 張牌。\n\n在翻牌前、翻牌、轉牌和河牌階段，從伺服器允許的棄牌、過牌、跟注、下注、加注或全下中選擇行動。\n\n若除一人外所有玩家都棄牌，剩餘玩家獲得底池。若仍有多人，則在攤牌時比較牌型與踢腳牌。\n\n每人以 1,000 籌碼開始，盲注從 10/20 起，每 5 手翻倍。籌碼為 0 即淘汰，最後一人獲勝。',
  );
  static String get tabletRules => _t(
    '''
# 텍사스 홀덤

각 플레이어는 비공개 홀 카드 2장과 공개 커뮤니티 카드 5장 중 가장 강한 5장 조합을 만듭니다.

## 베팅

프리플롭·플롭·턴·리버마다 폴드, 체크, 콜, 베트, 레이즈, 올인을 선택합니다. 행동 제한은 1분이며 체크가 가능하면 자동 체크, 아니면 자동 폴드됩니다.

## 토너먼트

모두 1,000칩으로 시작합니다. 블라인드는 10/20에서 시작해 5핸드마다 두 배로 오르며 최대 160/320입니다. 리바이는 없고 마지막 한 명이 승리합니다.
''',
    '''
# Texas Hold'em

Each player uses two private hole cards and five public community cards to make the best five-card hand.

## Betting

Choose fold, check, call, bet, raise, or all-in on the preflop, flop, turn, and river. The action limit is one minute; timeout checks when possible and otherwise folds.

## Tournament

Everyone starts with 1,000 chips. Blinds begin at 10/20, double every five hands, and cap at 160/320. There are no rebuys; the last player wins.
''',
    '''
# 德州扑克

每位玩家使用 2 张私人底牌与 5 张公共牌组成最强的 5 张牌。

## 下注

在翻牌前、翻牌、转牌和河牌阶段选择弃牌、过牌、跟注、下注、加注或全下。行动限时 1 分钟；超时后可过牌则自动过牌，否则自动弃牌。

## 锦标赛

每人以 1,000 筹码开始。盲注从 10/20 起，每 5 手翻倍，最高 160/320。不可重购，最后一人获胜。
''',
    '''
# 德州撲克

每位玩家使用 2 張私人底牌與 5 張公共牌組成最強的 5 張牌。

## 下注

在翻牌前、翻牌、轉牌和河牌階段選擇棄牌、過牌、跟注、下注、加注或全下。行動限時 1 分鐘；逾時後可過牌則自動過牌，否則自動棄牌。

## 錦標賽

每人以 1,000 籌碼開始。盲注從 10/20 起，每 5 手翻倍，最高 160/320。不可重購，最後一人獲勝。
''',
  );

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
    'fold' => _t('폴드', 'Fold', '弃牌', '棄牌'),
    'check' => _t('체크', 'Check', '过牌', '過牌'),
    'call' => _t('콜', 'Call', '跟注', '跟注'),
    'bet' => _t('벳', 'Bet', '下注', '下注'),
    'raise' => _t('레이즈', 'Raise', '加注', '加注'),
    'allIn' => _t('올인', 'All-in', '全下', '全下'),
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
    return _t(
      '$nickname 님이 $shown$label 했어요',
      '$nickname $shown$label',
      '$nickname $shown$label',
      '$nickname $shown$label',
    );
  }

  /// 휴대폰·결과 화면의 족보 설명입니다. 예: `원 페어 · K`, `스페이드 플러시 · A 하이`.
  static String handLabel(String category, List<HoldemCardModel> bestCards) {
    final name = HoldemCopy.category(category);
    final ranks = _rankGroups(bestCards);
    if (ranks.isEmpty) return name;
    String rank(int value) => _rankName(value);
    final suit = bestCards.isEmpty
        ? ''
        : '${HoldemSuit.from(bestCards.first.suit).localizedLabel} ';
    return switch (category) {
      'straightFlush' when _straightHigh(ranks) == 14 =>
        '$suit${_t('로열 플러시', 'Royal flush', '皇家同花顺', '皇家同花順')}',
      'straightFlush' =>
        '$suit$name · ${rank(_straightHigh(ranks))} ${_t('하이', 'high', '高', '高')}',
      'flush' =>
        '$suit$name · ${rank(ranks.first)} ${_t('하이', 'high', '高', '高')}',
      'straight' =>
        '$name · ${rank(_straightHigh(ranks))} ${_t('하이', 'high', '高', '高')}',
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
    'straightFlush' => _t('스트레이트 플러시', 'Straight flush', '同花顺', '同花順'),
    'fourOfAKind' => _t('포카드', 'Four of a kind', '四条', '四條'),
    'fullHouse' => _t('풀하우스', 'Full house', '葫芦', '葫蘆'),
    'flush' => _t('플러시', 'Flush', '同花', '同花'),
    'straight' => _t('스트레이트', 'Straight', '顺子', '順子'),
    'threeOfAKind' => _t('트리플', 'Three of a kind', '三条', '三條'),
    'twoPair' => _t('투 페어', 'Two pair', '两对', '兩對'),
    'onePair' => _t('원 페어', 'One pair', '一对', '一對'),
    _ => _t('하이 카드', 'High card', '高牌', '高牌'),
  };
}
