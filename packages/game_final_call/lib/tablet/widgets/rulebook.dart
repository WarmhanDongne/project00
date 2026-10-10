// [rulebook.dart] 는 파이널콜의 태블릿 게임 규칙 화면을 구성하는 파일이다.
//
// - [Package] : 파이널콜
// - [TabletWidget] : 태블릿 게임 화면에서 재사용하는 UI를 구성함
//
// 즉, 공용 화면의 단계·결과·설정 표시를 작은 책임으로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/tablet/widgets/game_rulebook_dialog.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/widgets/card_view.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_final_call/game_copy.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 태블릿 규칙 설명 화면
// ---------------------------------------------------------------------------
class FinalCallTabletRoleBook extends StatelessWidget {
  const FinalCallTabletRoleBook({super.key, required this.provider});

  final GameRoomContext provider;

  @override
  Widget build(BuildContext context) {
    //[게임정보] 플랫폼에서 받은 이름·규칙 영상과 대표 카드 이미지를 함께 표시
    return TabletGameRulebookDialog(
      title: provider.selectedGame?.name ?? 'Final Call',
      markdown: FinalCallCopy.tabletRules,
      videoUrl: provider.selectedGame?.ruleVideoUrl,
      // 게임 화면과 같은 Party Pop 카드를 보여 줍니다.
      cards: [
        for (final color in const ['red', 'blue', 'yellow', 'green'])
          FinalCallCardFace(
            card: FinalCallCard(id: 'rule-$color-10', color: color, value: 10),
            width: 60,
          ),
      ],
    );
  }
}
