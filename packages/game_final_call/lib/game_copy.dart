// [game_copy.dart] 는 파이널콜에서 사용하는 게임 화면에서 사용하는 문구를 모아 둔 파일이다.
//
// - [Package] : 파이널콜
// - [Copy] : 게임 화면에서 사용하는 문구를 한곳에서 관리
//
// 즉, 단계별 안내와 오류 문구를 한곳에서 일관되게 관리하기 위해 필요한 파일이다.

import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_kit/localization/game_locale.dart';

/// Final Call 화면에서 사용하는 사용자 문구입니다.
abstract final class FinalCallCopy {
  static String _t(String ko, String en, String zhHans, String zhHant) =>
      GameLocale.select(ko: ko, en: en, zhHans: zhHans, zhHant: zhHant);

  static String get myTurn => _t('내 차례!', 'Your turn!', '轮到你！', '輪到你！');
  static String get whereToDraw =>
      _t('어디서 가져올까요?', 'Where will you draw from?', '从哪里抽牌？', '從哪裡抽牌？');
  static String get deck => _t('덱', 'Deck', '牌堆', '牌堆');
  static String get publicCard => _t('공개 카드', 'Open card', '明牌', '明牌');
  static String get holdToCall =>
      _t('꾹 눌러서 선언', 'Hold to call', '长按宣布 CALL', '長按宣布 CALL');
  static String get pickOrDiscard => _t(
    '바꿀 카드를 고르거나 버리세요',
    'Choose a card to replace or discard the new card',
    '选择要替换的牌，或丢弃新牌',
    '選擇要替換的牌，或丟棄新牌',
  );
  static String get discardNewCard =>
      _t('새 카드 버리기', 'Discard new card', '丢弃新牌', '丟棄新牌');
  static String get pickCardToReplace =>
      _t('바꿀 카드를 고르세요', 'Choose a card to replace', '选择要替换的牌', '選擇要替換的牌');
  static String get replaceTarget =>
      _t('바꿀 카드', 'Card to replace', '要替换的牌', '要替換的牌');
  static String get ifReplaced => _t('바꾸면', 'After replacing', '替换后', '替換後');
  static String get pickToPreview => _t(
    '바꿀 카드를 고르면\n점수를 미리 보여 줘요',
    'Choose a card to preview\nyour new score',
    '选择要替换的牌\n即可预览分数',
    '選擇要替換的牌\n即可預覽分數',
  );
  static String get myScore => _t('내 점수', 'My score', '我的分数', '我的分數');
  static String get turnOrder => _t('차례 순서', 'Turn order', '行动顺序', '行動順序');
  static String get now => _t('지금', 'Now', '现在', '現在');
  static String get partner => _t('짝꿍', 'Partner', '队友', '隊友');
  static String get me => _t('나', 'Me', '我', '我');
  static String get lastSwap =>
      _t('마지막 교체 차례예요', 'This is your final swap', '这是最后一次换牌', '這是最後一次換牌');
  static String get presetBest => _t(
    '가장 높은 조합을 골라뒀어요',
    'Your highest combination is preselected',
    '已预选最高分组合',
    '已預選最高分組合',
  );
  static String get submitFinal => _t(
    '최종 조합을 골라 제출하세요',
    'Choose and submit your final combination',
    '选择并提交最终组合',
    '選擇並提交最終組合',
  );
  static String get submitted => _t('제출했어요', 'Submitted', '已提交', '已提交');
  static String get sameColorPartner => _t(
    '같은 색 = 맞은편 짝꿍',
    'Same color = partner opposite you',
    '同色 = 对面的队友',
    '同色 = 對面的隊友',
  );
  static String get swapping => _t('교체 중', 'Swapping', '换牌中', '換牌中');
  static String get turnBadge => _t('차례', 'Turn', '回合', '回合');

  static String turnOf(String nickname) =>
      _t('$nickname 차례예요', "$nickname's turn", '轮到 $nickname', '輪到 $nickname');
  static String callBy(String nickname) => '$nickname CALL!';
  static String callerOf(String nickname) =>
      _t('$nickname의', "$nickname's", '$nickname 的', '$nickname 的');
  static String deckCount(int count) =>
      _t('덱 $count', 'Deck $count', '牌堆 $count', '牌堆 $count');
  static String roundCaption(int round) => _t(
    '$round라운드 · $sameColorPartner',
    'Round $round · $sameColorPartner',
    '第 $round 轮 · $sameColorPartner',
    '第 $round 輪 · $sameColorPartner',
  );

  /// 숫자를 한자어로 읽을 때 받침이 있으면 '이랑', 없으면 '랑'을 붙입니다.
  static String replaceWith(String colorLabel, int value) {
    if (!GameLocale.isKorean) {
      return _t(
        '$colorLabel $value로 바꾸기',
        'Replace with $colorLabel $value',
        '换成 $colorLabel $value',
        '換成 $colorLabel $value',
      );
    }
    const vowelEnding = {2, 4, 5, 9};
    final particle = vowelEnding.contains(value) ? '랑' : '이랑';
    return '$colorLabel $value$particle 바꾸기';
  }

  static String teamWithPartner(String teamLabel, String partner) => _t(
    '$teamLabel · 짝꿍 $partner',
    '$teamLabel · Partner $partner',
    '$teamLabel · 队友 $partner',
    '$teamLabel · 隊友 $partner',
  );

  /// 손패 아래 묶음 꼬리표 문구입니다(예: 7 + 7 = 14점, 7 × 3 = 21점).
  static String combinationEquation(FinalCallCombination combination) {
    final cards = combination.cards;
    final score = combination.score;
    final point = _t('점', ' pts', '分', '分');
    if (cards.length <= 1) return '$score$point';
    if (combination.isSameNumber && cards.length >= 3) {
      return '${cards.first.value} × ${cards.length} = $score$point';
    }
    return '${cards.map((card) => card.value).join(' + ')} = $score$point';
  }

  /// 점수 패널의 조합 설명입니다(예: 같은 숫자 7 × 3).
  static String combinationName(
    FinalCallCombination combination,
    String Function(String color) colorLabel,
  ) {
    final cards = combination.cards;
    if (cards.isEmpty) return '';
    if (combination.isSameNumber) {
      return _t(
        '같은 숫자 ${cards.first.value} × ${cards.length}',
        'Same number ${cards.first.value} × ${cards.length}',
        '相同数字 ${cards.first.value} × ${cards.length}',
        '相同數字 ${cards.first.value} × ${cards.length}',
      );
    }
    final cardsText = cards.map((card) => card.value).join(' + ');
    final color = colorLabel(cards.first.color);
    return _t(
      '같은 색 $color $cardsText',
      'Same color $color $cardsText',
      '相同颜色 $color $cardsText',
      '相同顏色 $color $cardsText',
    );
  }

  static String get selectFinalCombination =>
      _t('최종 조합을 선택하세요', 'Select your final combination', '选择最终组合', '選擇最終組合');
  static String get submit => _t('제출', 'Submit', '提交', '提交');
  static String get selectCards => _t('카드 선택', 'Select cards', '选择卡牌', '選擇卡牌');
  static String get newCard => _t('새 카드', 'New card', '新牌', '新牌');
  static String get discard => _t('버리기', 'Discard', '丢弃', '丟棄');
  static String get replace => _t('교체', 'Replace', '替换', '替換');
  static String get confirm => _t('확인', 'Confirm', '确认', '確認');
  static String get cardChange =>
      _t('카드\n교체', 'Replace\ncard', '替换\n卡牌', '替換\n卡牌');
  static String get turnSuffix => _t('님 차례입니다', "'s turn", '的回合', '的回合');

  /// 태블릿 룰북과 휴대폰 규칙 화면이 함께 쓰는 전체 규칙입니다(Markdown).
  ///
  /// `# 제목`마다 한 항목으로 나뉩니다.
  static String get tabletRules => _t(
    '''
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
''',
    '''
# Goal

This is a team game: **2 vs 2 with four players, or three teams of two with six players**. The player opposite you is your partner.

If either teammate loses all hearts, **both teammates are eliminated**. The last surviving team wins. If all remaining teams are eliminated together, the game is a draw.

# Starting setup

- **3 hearts**
- **4 cards**
- 40 cards: four colors × values 1–10

# Scoring

Your score is the higher of the sum of cards with the **same color** and the sum of cards with the **same number**.

# Your turn

Draw one card from the deck or the open card. Replace one card in your hand or discard the drawn card.

# CALL

Declare **CALL** when you trust your hand. Everyone else gets one final swap, then all hands are revealed.

- The lowest scorer loses **1 heart**.
- If the caller is lowest, the caller loses **2 hearts**.
- All tied lowest scorers lose hearts.

## CALL with four of a kind

If the caller has four cards of one number, every surviving opponent loses **1 heart** and the caller's team loses none.
''',
    '''
# 游戏目标

这是团队赛：**4 人时 2 对 2，6 人时三队各 2 人**。坐在你对面的玩家是队友。

任一队员失去全部爱心时，**两名队员一起淘汰**。最后存活的队伍获胜。若剩余队伍同时淘汰，则为平局。

# 初始配置

- **3 颗爱心**
- **4 张手牌**
- 四种颜色 × 1–10，共 40 张牌

# 计分

比较**同色牌之和**与**同数字牌之和**，较高者为你的分数。

# 你的回合

从牌堆或明牌抽一张。用它替换一张手牌，或直接丢弃。

# 宣布 CALL

对手牌有信心时宣布 **CALL**。其他玩家各进行最后一次换牌，然后公开所有手牌。

- 最低分者失去 **1 颗爱心**。
- 若 CALL 的玩家最低，失去 **2 颗爱心**。
- 并列最低者都会失去爱心。

## 四条 CALL

CALL 的玩家若持有四张同数字牌，所有仍存活的对方队伍成员各失去 **1 颗爱心**，本队不受伤害。
''',
    '''
# 遊戲目標

這是團隊賽：**4 人時 2 對 2，6 人時三隊各 2 人**。坐在你對面的玩家是隊友。

任一隊員失去全部愛心時，**兩名隊員一起淘汰**。最後存活的隊伍獲勝。若剩餘隊伍同時淘汰，則為平手。

# 初始配置

- **3 顆愛心**
- **4 張手牌**
- 四種顏色 × 1–10，共 40 張牌

# 計分

比較**同色牌之和**與**同數字牌之和**，較高者為你的分數。

# 你的回合

從牌堆或明牌抽一張。用它替換一張手牌，或直接丟棄。

# 宣布 CALL

對手牌有信心時宣布 **CALL**。其他玩家各進行最後一次換牌，然後公開所有手牌。

- 最低分者失去 **1 顆愛心**。
- 若 CALL 的玩家最低，失去 **2 顆愛心**。
- 並列最低者都會失去愛心。

## 四條 CALL

CALL 的玩家若持有四張同數字牌，所有仍存活的對方隊伍成員各失去 **1 顆愛心**，本隊不受傷害。
''',
  );
}
