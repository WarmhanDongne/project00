import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';
import 'package:project00/games/liars_poker/screens/phone_game_portrait.dart';

/// 가로 전용 배치가 완성되기 전에도 실제 게임 연결이 끊기지 않도록
/// 동일한 컨트롤러를 세로 게임 구성에 전달합니다.
class PhoneGameLandscape extends StatelessWidget {
  const PhoneGameLandscape({super.key, required this.controller});

  final PhoneGameController controller;

  @override
  Widget build(BuildContext context) {
    return PhoneGamePortrait(controller: controller);
  }
}
