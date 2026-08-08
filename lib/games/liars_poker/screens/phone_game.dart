// liars_poker/screens/phone_game.dart
import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/screens/phone_game_portrait.dart';
import 'package:project00/games/liars_poker/screens/phone_game_landscape.dart';
import 'package:project00/games/liars_poker/widgets/phone/spectator_portrait.dart';
import 'package:project00/games/liars_poker/widgets/phone/spectator_landscape.dart';

class PhoneGame extends StatelessWidget {
  const PhoneGame({super.key});

  @override
  Widget build(BuildContext context) {
    // 💡 가장 권장되는 방식: 기기 화면의 방향을 직접 구독(Subscribe)
    // 화면이 회전될 때마다 플러터가 알아서 이 build 함수를 다시 호출합니다.
    final orientation = MediaQuery.of(context).orientation;

    final isAlive = true;

    final List<String> dummySurvivors = [
      '맥도날드 감자튀김 도둑',
      '김하준',
      '윤유원',
      '배워서 남주자',
    ];

    if (isAlive == false && orientation == Orientation.portrait) {
      return SpectatorPortrait(survivors: dummySurvivors);
    } else if (isAlive == false && orientation == Orientation.landscape) {
      return SpectatorLandscape(survivors: dummySurvivors);
    }

    if (orientation == Orientation.portrait) {
      return const PhoneGamePortrait(); // 세로 모드 반환
    } else {
      return const PhoneGameLandscape(); // 가로 모드 반환
    }
  }
}
