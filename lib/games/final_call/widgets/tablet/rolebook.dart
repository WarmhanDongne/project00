import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/tablet_game_rulebook_dialog.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

const _finalCallRules = '''
# 게임 목표

**4명이 2대2로** 겨루는 팀전입니다. 마주 보고 앉은 사람이 내 팀입니다.

팀원 중 **한 명이라도** 하트를 모두 잃으면 팀 전체가 패배합니다.
내 하트만 지키는 것으로는 이길 수 없습니다.

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
**상대 팀 두 명이 각각 하트 1개**를 잃고, 내 팀은 아무도 잃지 않습니다.

포카드는 CALL한 본인에게만 효력이 있습니다.
남이 CALL한 라운드에 포카드를 들고 있어도 평소처럼 점수로만 겨룹니다.
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
