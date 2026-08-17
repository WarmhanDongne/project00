import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';

/// Mafia 태블릿 UI를 확인하는 개발용 화면입니다.
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
