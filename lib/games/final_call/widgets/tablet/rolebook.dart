import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/tablet_game_rulebook_dialog.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

const _finalCallRules = '''
# 기본 규칙

각 플레이어는 생명 **3개**와 카드 **4장**으로 시작합니다.

- 자신의 턴에는 공개 카드 또는 덱의 카드 한 장을 가져옵니다.
- 가져온 카드는 손패 한 장과 교체하거나 그대로 버릴 수 있습니다.
- 자신의 패가 충분히 높다고 판단하면 **CALL**을 선언합니다.

## 점수 계산

- 같은 숫자 카드의 합
- 같은 색 카드의 합

두 값 중 더 높은 숫자가 최종 점수입니다.

## CALL 이후

CALL을 선언한 플레이어를 제외한 모든 플레이어는 마지막 교체를 한 번 진행합니다.
가장 낮은 점수의 플레이어는 생명 1개를 잃습니다.
CALL을 선언한 플레이어가 최하위라면 생명 2개를 잃습니다.

## 승리 조건

반대편 플레이어가 같은 팀입니다. 팀원 중 한 명이라도 생명을 모두 잃으면
해당 팀 전체가 패배하고, 상대 팀이 승리합니다.
''';

class FinalCallTabletRoleBook extends StatelessWidget {
  const FinalCallTabletRoleBook({super.key, required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    return TabletGameRulebookDialog(
      title: provider.selectedGame?.name ?? 'Final Call',
      markdown: _finalCallRules,
      videoUrl: provider.selectedGame?.ruleVideoUrl,
      cardImages: [
        Assets.games.finalCall.images.cards.cardRed10,
        Assets.games.finalCall.images.cards.cardBlue10,
        Assets.games.finalCall.images.cards.cardYellow10,
        Assets.games.finalCall.images.cards.cardGreen10,
      ],
    );
  }
}
