import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/tablet_game_rulebook_dialog.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

const _liarsPokerRules = '''
# 기본 규칙

자신의 차례가 되면 **1~3장**의 카드를 냅니다.

- 선언은 진실일 수도 있습니다.
- 선언은 거짓일 수도 있습니다.
- 다음 플레이어는 **LIAR!** 를 외칠 수 있습니다.

## 승리 조건

마지막까지 살아남는 플레이어가 승리합니다.
모든 카드를 먼저 버리거나 마지막까지 살아남으면 승리합니다.
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
