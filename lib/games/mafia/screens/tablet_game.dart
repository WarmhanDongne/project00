import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_controller.dart';
import 'package:project00/gen/assets.gen.dart';

/// Liar's Poker 태블릿 진행 화면의 진입점입니다.
///
/// 상태 처리는 [TabletGameController], 화면 구성은 각 layer 파일이 담당합니다.
class MafiaTabletGame extends StatefulWidget {
  const MafiaTabletGame({super.key});

  @override
  State<MafiaTabletGame> createState() => TabletGameState();
}

class TabletGameState extends State<MafiaTabletGame> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [const Positioned.fill(child: _GameBackground())]),
    );
  }
}

class _GameBackground extends StatelessWidget {
  const _GameBackground();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Assets.games.mafia.images.background.backgroundMorning.image(
        fit: BoxFit.contain,
        alignment: Alignment.center,
      ),
    );
  }
}
