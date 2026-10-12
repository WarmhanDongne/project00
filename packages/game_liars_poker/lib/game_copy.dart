// [game_copy.dart] 라이어스 포커 화면에 표시하는 문구와
// 판정 문구의 표시 스타일을 한곳에서 관리하는 파일이다.

// ========================[ import ]==========================
import 'package:game_kit/game_flow/game_announcement.dart';
import 'package:game_kit/localization/game_locale.dart';

// ============================================================

/// Liar's Poker 화면에서 사용하는 사용자 문구입니다.
abstract final class LiarsPokerCopy {
  static String _t(String ko, String en, String zhHans, String zhHant) =>
      GameLocale.select(ko: ko, en: en, zhHans: zhHans, zhHant: zhHant);

  static String get waitingForOpponent => _t(
    '상대의 선택을 기다리는 중...',
    'Waiting for the other player…',
    '等待对方选择…',
    '等待對方選擇…',
  );
  static String get waitingForNextRound =>
      _t('다음 라운드를 기다려주세요', 'Wait for the next round', '请等待下一轮', '請等待下一輪');
  static String get eliminated => _t('탈락했습니다', 'Eliminated', '已淘汰', '已淘汰');
  static String get dealingOnTablet => _t(
    '태블릿에서 카드를 배분하는 중입니다',
    'The tablet is dealing cards',
    '平板正在发牌',
    '平板正在發牌',
  );
  static String get myPenaltyInProgress => _t(
    '내 벌칙을 진행 중입니다',
    'Your penalty is in progress',
    '正在进行你的惩罚',
    '正在進行你的懲罰',
  );
  static String get penaltyInProgress =>
      _t('벌칙을 진행 중입니다', 'Penalty in progress', '惩罚进行中', '懲罰進行中');
  static String get decideLastCard => _t(
    '마지막 카드가 라이어인지 결정하세요',
    'Decide whether the last play was a lie',
    '判断上一手是否在说谎',
    '判斷上一手是否在說謊',
  );
  static String get truthProven =>
      _t('진실이 증명되었습니다.', 'The claim was true.', '证明是真话。', '證明是真話。');
  static String get lieRevealed =>
      _t('거짓이 밝혀졌습니다.', 'The lie was exposed.', '谎言被揭穿了。', '謊言被揭穿了。');
  static String get challengeSucceeded =>
      _t('간파 성공!', 'Challenge won!', '识破成功！', '識破成功！');
  static String get challengeFailed =>
      _t('간파 실패!', 'Challenge lost!', '识破失败！', '識破失敗！');
  static String get noCards =>
      _t('내 손패 없음', 'No cards in hand', '手中无牌', '手中無牌');
  static String get penaltyTitle =>
      _t('벌칙 진행 중', 'Penalty in progress', '惩罚进行中', '懲罰進行中');

  /// 휴대폰 상단 팁 아이콘으로 여는 규칙 문구입니다.
  ///
  /// 플레이 화면과 관전 화면이 같은 문구를 씁니다. 마크다운을 지원하지 않는
  /// 일반 텍스트로 표시되므로 기호 없이 문장으로만 씁니다.
  static String get phoneRules => _t(
    '라운드마다 기준 카드가 A, K, Q 중 하나로 정해집니다.\n\n내 차례에는 손패에서 1~3장을 뒷면으로 냅니다. 낸 카드가 모두 기준 카드라고 주장하는 것이며, 다른 카드를 섞어 속여도 됩니다. 조커는 어떤 기준 카드로든 인정됩니다.\n\n다음 차례 사람은 카드를 내는 대신 LIAR를 외칠 수 있습니다. 직전에 낸 카드가 공개되어, 속인 것이 맞으면 카드를 낸 사람이, 진실이었으면 LIAR를 외친 사람이 벌칙 룰렛을 돌립니다.\n\n카드가 남은 사람이 나 혼자라면 LIAR 대신 FOLD를 골라, 의심을 접고 내가 룰렛을 돌릴 수 있습니다.\n\n룰렛에서 살아남아도 다음 룰렛은 더 불리해집니다. 세 번째 룰렛은 12칸 중 11칸이 탈락입니다.\n\n손패를 먼저 비우는 것은 승리가 아닙니다. 마지막까지 살아남은 한 명이 승리합니다.',
    'Each round uses A, K, or Q as the table rank.\n\nOn your turn, play 1–3 cards face down and claim they all match the table rank. You may bluff with other cards. Jokers match every rank.\n\nThe next player may call LIAR instead of playing. The previous cards are revealed. If it was a bluff, the player who played them spins the penalty roulette; if it was true, the challenger spins.\n\nIf you are the only player with cards, you may choose FOLD instead of LIAR and spin the roulette yourself.\n\nEach survived roulette becomes harder. On the third spin, 11 of 12 slots eliminate you.\n\nEmptying your hand does not win the game. The last surviving player wins.',
    '每轮会从 A、K、Q 中选定一个基准牌。\n\n轮到你时，将 1–3 张牌背面朝上打出，并声称它们都是基准牌。你也可以混入其他牌来诈唬。小丑牌可当作任意基准牌。\n\n下一位玩家可以不出牌而喊 LIAR。上一手牌会被公开；若确实诈唬，出牌者转惩罚轮盘；若说的是真话，质疑者转轮盘。\n\n如果只有你还有手牌，可以选择 FOLD，不再质疑并由自己转轮盘。\n\n每次幸存后，下一次轮盘会更危险。第三次轮盘有 12 格，其中 11 格会淘汰。\n\n先出完手牌并不代表获胜。最后存活的玩家获胜。',
    '每輪會從 A、K、Q 中選定一個基準牌。\n\n輪到你時，將 1–3 張牌背面朝上打出，並聲稱它們都是基準牌。你也可以混入其他牌來詐唬。鬼牌可當作任意基準牌。\n\n下一位玩家可以不出牌而喊 LIAR。上一手牌會被公開；若確實詐唬，出牌者轉懲罰輪盤；若說的是真話，質疑者轉輪盤。\n\n如果只有你還有手牌，可以選擇 FOLD，不再質疑並由自己轉輪盤。\n\n每次倖存後，下一次輪盤會更危險。第三次輪盤有 12 格，其中 11 格會淘汰。\n\n先出完手牌並不代表獲勝。最後存活的玩家獲勝。',
  );

  /// 태블릿 규칙 화면에서 Markdown으로 표시하는 전체 규칙입니다.
  static String get tabletRules => _t(
    '''
# 게임 목표

마지막 한 명이 될 때까지 살아남으면 승리합니다.
손패를 먼저 비우는 것은 승리가 아닙니다.

# 한 판의 흐름

라운드마다 **기준 카드**가 A, K, Q 중 하나로 정해집니다.

내 차례에는 손패에서 **1~3장**을 뒷면으로 냅니다.
이것은 "지금 낸 카드가 모두 기준 카드다"라고 주장하는 것입니다.
진실을 내도 되고, 다른 카드를 섞어 속여도 됩니다.

**조커**는 어떤 기준 카드로든 인정되는 만능 카드입니다.

## LIAR 외치기

다음 차례 사람은 카드를 내는 대신 **LIAR!** 를 외칠 수 있습니다.
직전에 낸 카드가 공개되고, 틀린 쪽이 벌칙 룰렛을 돌립니다.

- 속인 것이 맞으면 → **카드를 낸 사람**이 룰렛으로
- 진실이었으면 → **LIAR를 외친 사람**이 룰렛으로

## FOLD

카드가 남은 사람이 나 혼자라면 LIAR 대신 **FOLD**를 고를 수 있습니다.
의심을 접고 내가 룰렛을 돌리는 선택입니다.

## 벌칙 룰렛은 갈수록 불리해집니다

룰렛에서 살아남아도, 다음에 돌릴 룰렛의 탈락 칸이 늘어납니다.

1. 첫 번째 — 16칸 중 4칸이 탈락
2. 두 번째 — 15칸 중 5칸이 탈락
3. 세 번째 — 12칸 중 11칸이 탈락

세 번째 룰렛은 거의 탈락합니다. 룰렛을 돌리지 않는 것이 가장 좋습니다.
''',
    '''
# Goal

Survive until you are the last player. Emptying your hand does not win the game.

# Round flow

Each round selects **A, K, or Q** as the table rank. On your turn, play **1–3 cards** face down and claim they all match it. You may tell the truth or bluff. **Jokers** match every rank.

## Call LIAR

The next player may call **LIAR!** instead of playing. The previous cards are revealed and the losing side spins the penalty roulette.

- If it was a bluff → **the player who played the cards** spins
- If it was true → **the challenger** spins

## FOLD

If you are the only player with cards, you may choose **FOLD** instead of LIAR and spin the roulette yourself.

## The roulette gets harder

1. First spin — 4 elimination slots out of 16
2. Second spin — 5 elimination slots out of 15
3. Third spin — 11 elimination slots out of 12
''',
    '''
# 游戏目标

坚持到最后一人即可获胜。先出完手牌并不代表获胜。

# 回合流程

每轮从 **A、K、Q** 中选定基准牌。轮到你时，将 **1–3 张牌** 背面朝上打出，并声称它们都是基准牌。你可以说真话，也可以诈唬。**小丑牌**可当作任意基准牌。

## 喊 LIAR

下一位玩家可以不出牌而喊 **LIAR!**。上一手牌会被公开，判断错误的一方转惩罚轮盘。

- 确实诈唬 → **出牌者**转轮盘
- 说的是真话 → **质疑者**转轮盘

## FOLD

如果只有你还有手牌，可以选择 **FOLD**，由自己转轮盘。

## 轮盘会越来越危险

1. 第一次 — 16 格中 4 格淘汰
2. 第二次 — 15 格中 5 格淘汰
3. 第三次 — 12 格中 11 格淘汰
''',
    '''
# 遊戲目標

堅持到最後一人即可獲勝。先出完手牌並不代表獲勝。

# 回合流程

每輪從 **A、K、Q** 中選定基準牌。輪到你時，將 **1–3 張牌** 背面朝上打出，並聲稱它們都是基準牌。你可以說真話，也可以詐唬。**鬼牌**可當作任意基準牌。

## 喊 LIAR

下一位玩家可以不出牌而喊 **LIAR!**。上一手牌會被公開，判斷錯誤的一方轉懲罰輪盤。

- 確實詐唬 → **出牌者**轉輪盤
- 說的是真話 → **質疑者**轉輪盤

## FOLD

如果只有你還有手牌，可以選擇 **FOLD**，由自己轉輪盤。

## 輪盤會越來越危險

1. 第一次 — 16 格中 4 格淘汰
2. 第二次 — 15 格中 5 格淘汰
3. 第三次 — 12 格中 11 格淘汰
''',
  );

  static String winner(String nickname) => _t(
    '$nickname님이 승리했습니다',
    '$nickname wins',
    '$nickname 获胜',
    '$nickname 獲勝',
  );
  static String waitingForDecision(String nickname) => _t(
    '$nickname님의 결정을 기다리는 중',
    'Waiting for $nickname',
    '等待 $nickname 决定',
    '等待 $nickname 決定',
  );
  static String selectionLimit(int count) => _t(
    '최대 $count장만 선택할 수 있습니다',
    'You can select up to $count cards',
    '最多可选择 $count 张牌',
    '最多可選擇 $count 張牌',
  );

  static String table(String cardValue) => switch (cardValue.toUpperCase()) {
    'A' => 'ACE',
    'Q' => 'QUEEN',
    _ => 'KING',
  };

  static GameAnnouncementTone verdictTone(String message) {
    if (message == truthProven || message == challengeSucceeded) {
      return GameAnnouncementTone.positive;
    }
    if (message == lieRevealed || message == challengeFailed) {
      return GameAnnouncementTone.negative;
    }
    return GameAnnouncementTone.neutral;
  }
}

/// 이름의 마지막 글자에 받침이 있는지입니다. 한글이 아니면 받침이 없다고 봅니다.
bool _hasBatchim(String name) {
  if (name.isEmpty) return false;
  final code = name.codeUnitAt(name.length - 1);
  return code >= 0xAC00 && code <= 0xD7A3 && (code - 0xAC00) % 28 != 0;
}

/// `민준이` · `서아가`처럼 이름 뒤에 붙일 주격 조사입니다.
String liarsPokerSubjectParticle(String name) => _hasBatchim(name) ? '이' : '가';
