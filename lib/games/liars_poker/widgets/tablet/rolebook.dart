import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/tablet_game_rulebook_dialog.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

const _liarsPokerRules = '''
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
''';

class RoleBook extends StatelessWidget {
  const RoleBook({super.key, required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    return TabletGameRulebookDialog(
      title: provider.selectedGame?.name ?? "Liar's Poker",
      markdown: _liarsPokerRules,
      videoUrl: provider.selectedGame?.ruleVideoUrl,
      cardImages: [
        Assets.games.liarsPoker.images.cards.whiteA,
        Assets.games.liarsPoker.images.cards.whiteK,
        Assets.games.liarsPoker.images.cards.whiteQ,
        Assets.games.liarsPoker.images.cards.whiteJoker,
      ],
    );
  }
}
