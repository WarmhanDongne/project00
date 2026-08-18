import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/widgets/tablet/rolebook.dart';
import 'package:project00/games/liars_poker/widgets/tablet/settings.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/shared/widgets/tablet_game_menu_overlay.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 게임 중 사용할 규칙/설정 메뉴를 화면 위에 배치합니다.
class LiarsPokerTabletGameOverlay extends StatelessWidget {
  const LiarsPokerTabletGameOverlay({
    super.key,
    required this.provider,
    required this.stage,
    required this.onRestartGame,
    required this.onEndGame,
  });

  final RoomProvider provider;
  final LiarsPokerTabletStage stage;
  final VoidCallback onRestartGame;
  final VoidCallback onEndGame;

  @override
  Widget build(BuildContext context) {
    //=======================사이드바 표시 조건==============================
    // 카드 배분 전과 배분 중에는 숨기고, RoundStartReveal이 테이블과 잔여
    // 카드를 띄우기 시작하는 roundStarting부터 함께 등장시킵니다.
    if (stage == LiarsPokerTabletStage.waiting ||
        stage == LiarsPokerTabletStage.dealing ||
        stage == LiarsPokerTabletStage.result ||
        stage == LiarsPokerTabletStage.finished) {
      return const SizedBox.expand();
    }

    final icons = Assets.games.liarsPoker.images.icons;
    return TabletGameMenuOverlay(
      visible: true,
      roleIcon: icons.iconRole.image(fit: BoxFit.contain),
      settingIcon: icons.iconSetting.image(fit: BoxFit.contain),
      roleDialogBuilder: (_) => RoleBook(provider: provider),
      settingDialogBuilder: (_) => Setting(
        provider: provider,
        onRestartGame: onRestartGame,
        onEndGame: onEndGame,
      ),
    );
  }
}
