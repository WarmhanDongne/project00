// liars_poker/screens/phone_game.dart

import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/screens/phone_game_portrait.dart';
import 'package:project00/games/liars_poker/screens/phone_game_landscape.dart';

class PhoneGame extends StatelessWidget {
  const PhoneGame({super.key});

  @override
  Widget build(BuildContext context) {
    // 기기의 현재 방향을 감지하여 렌더링 트리를 분기합니다.
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return const PhoneGamePortrait(); // 세로 모드
        } else {
          return const PhoneGameLandscape(); // 가로 모드
        }
      },
    );
  }
}
