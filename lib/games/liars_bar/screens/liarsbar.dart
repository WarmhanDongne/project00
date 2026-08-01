import 'package:flutter/material.dart';
import 'package:project00/games/liars_bar/screens/phone_game.dart';
import 'package:project00/games/liars_bar/screens/tablet_game.dart';

class LiarsBar extends StatelessWidget {
  const LiarsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 모바일 브레이크포인트 설정 (일반적으로 600px 기준)
        if (constraints.maxWidth < 600) {
          return const PhoneGame();
        } else {
          return const TabletGame();
        }
      },
    );
  }
}
