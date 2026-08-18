import 'package:flutter/material.dart';
import 'package:project00/games/final_call/widgets/tablet/rolebook.dart';
import 'package:project00/games/final_call/widgets/tablet/settings.dart';
import 'package:project00/games/shared/widgets/tablet_game_menu_overlay.dart';
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
    final icons = Assets.games.finalCall.images.icons;
    return TabletGameMenuOverlay(
      visible: visible,
      roleIcon: icons.iconRole.image(fit: BoxFit.contain),
      settingIcon: icons.iconSetting.image(fit: BoxFit.contain),
      roleDialogBuilder: (_) => FinalCallTabletRoleBook(provider: provider),
      settingDialogBuilder: (_) => FinalCallTabletSetting(
        provider: provider,
        onRestartGame: onRestartGame,
        onEndGame: onEndGame,
      ),
    );
  }
}
