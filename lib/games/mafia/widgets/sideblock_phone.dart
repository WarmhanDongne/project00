import 'package:flutter/material.dart';
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
                icon: Image.asset(
                  'assets/games/mafia/images/icons/tip.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
              IconButton(
                onPressed: () {
                  null;
                },
                icon: Image.asset(
                  isMorning
                      ? 'assets/games/mafia/images/icons/setting_black.png'
                      : 'assets/games/mafia/images/icons/setting_white.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
