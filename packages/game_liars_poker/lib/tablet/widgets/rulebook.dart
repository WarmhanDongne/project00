// [rulebook.dart] 라이어스 포커 규칙 문구와 테이블 이미지를
// 공용 태블릿 규칙 다이얼로그에 연결하는 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/tablet/widgets/game_rulebook_dialog.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_liars_poker/game_copy.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 태블릿 규칙 설명 화면
// ---------------------------------------------------------------------------
class LiarsPokerTabletRulebook extends StatelessWidget {
  const LiarsPokerTabletRulebook({super.key, required this.provider});

  final GameRoomContext provider;

  @override
  Widget build(BuildContext context) {
    // 플랫폼 공용 역할북 레이아웃에 라이어스 포커 규칙을 전달합니다.
    return TabletGameRulebookDialog(
      title: provider.selectedGame?.name ?? "Liar's Poker",
      markdown: LiarsPokerCopy.tabletRules,
      videoUrl: provider.selectedGame?.ruleVideoUrl,
      cardImages: [
        Assets.games.liarsPoker.images.cards.whiteA.game,
        Assets.games.liarsPoker.images.cards.whiteK.game,
        Assets.games.liarsPoker.images.cards.whiteQ.game,
        Assets.games.liarsPoker.images.cards.whiteJoker.game,
      ],
    );
  }
}

/// 이전 클래스 이름을 사용하는 코드와 팀원 브랜치를 위한 호환 별칭입니다.
@Deprecated('LiarsPokerTabletRulebook을 사용하세요.')
typedef RoleBook = LiarsPokerTabletRulebook;
