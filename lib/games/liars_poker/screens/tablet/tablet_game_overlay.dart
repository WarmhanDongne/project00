import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/widgets/tablet/rolebook_tablet.dart';
import 'package:project00/games/liars_poker/widgets/tablet/setting_tablet.dart';
import 'package:project00/games/liars_poker/screens/tablet/game_status.dart';
import 'package:project00/games/shared/widgets/tablet_game_side_bar.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 게임 중 사용할 규칙/설정 메뉴를 화면 위에 배치합니다.
class TabletGameOverlay extends StatelessWidget {
  const TabletGameOverlay({
    super.key,
    required this.provider,
    required this.status,
    required this.onRestartGame,
    required this.onEndGame,
  });

  final RoomProvider provider;
  final GameStatus status;
  final VoidCallback onRestartGame;
  final VoidCallback onEndGame;

  @override
  Widget build(BuildContext context) {
    //=======================사이드바 표시 조건==============================
    if (status == GameStatus.result || status == GameStatus.finished) {
      return const SizedBox.shrink();
    }

    final icons = Assets.games.liarsPoker.images.icons;
    return Stack(
      children: [
        Positioned(
          top: 20,
          right: 20,
          child: TabletGameSideBar(
            roleIcon: icons.iconRole.image(fit: BoxFit.contain),
            settingIcon: icons.iconSetting.image(fit: BoxFit.contain),
            roleDialogBuilder: (_) => RoleBook(provider: provider),
            settingDialogBuilder: (_) => Setting(
              provider: provider,
              onRestartGame: onRestartGame,
              onEndGame: onEndGame,
            ),
          ),
        ),
      ],
    );
  }
}
