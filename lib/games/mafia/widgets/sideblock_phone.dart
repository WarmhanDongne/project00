import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/games/mafia/screens/phone_game.dart';

class SideBlock extends StatefulWidget {
  const SideBlock({super.key, required this.isMorning});

  final bool isMorning;
  @override
  State<SideBlock> createState() => _SideBlockState();
}

class _SideBlockState extends State<SideBlock> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 50),
          child: Row(
            children: [
              const Spacer(),
              IconButton(
                onPressed: () {
                  null;
                },
                icon: Assets.games.mafia.images.icons.tip.image(
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
              IconButton(
                onPressed: () {
                  null;
                },
                icon:
                    (isMorning
                            ? Assets.games.mafia.images.icons.settingBlack
                            : Assets.games.mafia.images.icons.settingWhite)
                        .image(width: 50, height: 50, fit: BoxFit.contain),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
