import 'package:flutter/material.dart';
import 'package:game_final_call/games/final_call/widgets/tablet/rolebook.dart';
import 'package:game_final_call/games/final_call/widgets/tablet/settings.dart';
import 'package:game_kit/games/shared/widgets/tablet_game_menu_overlay.dart';
import 'package:game_final_call/gen/assets.gen.dart';
import 'package:game_contract/games/shared/models/game_room_context.dart';

/// Final Call 정보와 자산을 공통 태블릿 사이드바에 연결합니다.
class FinalCallTabletGameOverlay extends StatelessWidget {
  const FinalCallTabletGameOverlay({
    super.key,
    required this.provider,
    required this.onRestartGame,
    required this.onEndGame,
    required this.visible,
  });

  final GameRoomContext provider;
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
