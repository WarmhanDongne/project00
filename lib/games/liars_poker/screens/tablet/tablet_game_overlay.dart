import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/liars_poker/widgets/tablet/rolebook.dart';
import 'package:project00/games/liars_poker/widgets/tablet/settings.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/shared/widgets/tablet_game_menu_overlay.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 게임 중 사용할 규칙/설정 메뉴와 현재 테이블 라벨을 화면 위에 배치합니다.
class LiarsPokerTabletGameOverlay extends StatelessWidget {
  const LiarsPokerTabletGameOverlay({
    super.key,
    required this.provider,
    required this.stage,
    required this.tableRank,
    required this.onRestartGame,
    required this.onEndGame,
  });

  final RoomProvider provider;
  final LiarsPokerTabletStage stage;

  /// 현재 라운드의 기준 카드(K/Q/A)입니다. 휴대폰 상단바처럼 좌상단에
  /// `KING's TABLE` 형태의 라벨로 표시합니다.
  final String tableRank;
  final VoidCallback onRestartGame;
  final VoidCallback onEndGame;

  @override
  Widget build(BuildContext context) {
    // 분배·결과처럼 전체 화면 연출이 필요한 단계에서는 사이드바를 숨깁니다.
    // 카드 배분 전과 배분 중에는 숨기고, RoundStartReveal이 테이블과 잔여
    // 카드를 띄우기 시작하는 roundStarting부터 함께 등장시킵니다.
    if (stage == LiarsPokerTabletStage.waiting ||
        stage == LiarsPokerTabletStage.dealing ||
        stage == LiarsPokerTabletStage.result ||
        stage == LiarsPokerTabletStage.finished) {
      return const SizedBox.expand();
    }

    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    // 사이드바(TabletGameMenuOverlay)와 같은 여백 규칙을 사용해 양쪽 상단이
    // 나란히 정렬되게 합니다.
    final inset = (shortestSide * 0.025).clamp(16.0, 24.0);
    final labelHeight = (shortestSide * 0.06).clamp(40.0, 64.0);

    final icons = Assets.games.liarsPoker.images.icons;
    return Stack(
      fit: StackFit.expand,
      children: [
        //=======================좌상단 테이블 라벨==============================
        // 휴대폰 상단바와 같은 자산을 사용해 현재 테이블(KING/QUEEN/ACE)을
        // 태블릿에서도 항상 확인할 수 있게 합니다.
        SizedBox.expand(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.all(inset),
                child: IgnorePointer(
                  child: _tableAsset(tableRank).image(
                    height: labelHeight,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ),
        TabletGameMenuOverlay(
          visible: true,
          roleIcon: icons.iconRole.image(fit: BoxFit.contain),
          settingIcon: icons.iconSetting.image(fit: BoxFit.contain),
          roleDialogBuilder: (_) => RoleBook(provider: provider),
          settingDialogBuilder: (_) => Setting(
            provider: provider,
            onRestartGame: onRestartGame,
            onEndGame: onEndGame,
          ),
        ),
      ],
    );
  }

  GameImage _tableAsset(String rank) {
    return switch (rank.toUpperCase()) {
      'A' => Assets.games.liarsPoker.images.table.tableAceWhite.game,
      'Q' => Assets.games.liarsPoker.images.table.tableQueenWhite.game,
      _ => Assets.games.liarsPoker.images.table.tableKingWhite.game,
    };
  }
}
