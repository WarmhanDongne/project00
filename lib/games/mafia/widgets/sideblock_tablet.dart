import 'package:flutter/material.dart';
import 'package:project00/games/mafia/widgets/rolebook.dart';
import 'package:project00/games/mafia/widgets/setting.dart';
import 'package:project00/games/shared/widgets/tablet_game_side_bar.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

class SideBlock extends StatelessWidget {
  const SideBlock({super.key, required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    final icons = Assets.games.mafia.images.icons;
    return TabletGameSideBar(
      roleIcon: icons.roleIcon.image(fit: BoxFit.contain),
      settingIcon: icons.settingIcon.image(fit: BoxFit.contain),
      roleDialogBuilder: (_) => RoleBook(provider: provider),
      settingDialogBuilder: (_) => Setting(provider: provider),
    );
  }
}
