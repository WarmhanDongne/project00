import 'package:flutter/material.dart';
import 'package:project00/games/final_call/widgets/tablet/rolebook_tablet.dart';
import 'package:project00/games/final_call/widgets/tablet/setting_tablet.dart';
import 'package:project00/games/shared/widgets/tablet_game_side_bar.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// Final Call 정보와 자산을 공통 태블릿 사이드바에 연결합니다.
class FinalCallTabletGameOverlay extends StatelessWidget {
  const FinalCallTabletGameOverlay({
    super.key,
    required this.provider,
    required this.onRestartGame,
    required this.onEndGame,
    required this.visible,
  });

  final RoomProvider provider;
  final VoidCallback onRestartGame;
  final VoidCallback onEndGame;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final icons = Assets.games.finalCall.images.icons;
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: TabletGameSideBar(
            iconSize: 90,
            spacing: 12,
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
      ),
    );
  }
}
