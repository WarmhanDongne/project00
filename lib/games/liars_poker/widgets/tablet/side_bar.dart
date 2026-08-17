import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/widgets/tablet/rolebook.dart';
import 'package:project00/games/liars_poker/widgets/tablet/settings.dart';
import 'package:project00/games/shared/widgets/tablet_game_side_bar.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 기존 호출부가 Liar's Poker 사이드바 설정을 계속 사용할 수 있는 어댑터입니다.
class SideBlock extends StatelessWidget {
  const SideBlock({
    super.key,
    required this.provider,
    this.onRestartGame,
    this.onEndGame,
  });

  final RoomProvider provider;
  final VoidCallback? onRestartGame;
  final VoidCallback? onEndGame;

  @override
  Widget build(BuildContext context) {
    final icons = Assets.games.liarsPoker.images.icons;
    return TabletGameSideBar(
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
