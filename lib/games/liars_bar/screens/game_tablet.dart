import 'package:flutter/material.dart';
import 'package:project00/games/liars_bar/widgets/result.dart';
import 'package:project00/games/liars_bar/widgets/sideblock.dart';

class GameTablet extends StatefulWidget {
  const GameTablet({super.key});

  @override
  State<GameTablet> createState() => _GameTabletState();
}

class _GameTabletState extends State<GameTablet> {
  final String table = 'q';

  final bool book = true;

  final bool setting = true;

  GameStatus gameStatus = GameStatus.result;

  // void updateGameStatus(GameStatus status) {
  //   setState(() {
  //     gameStatus = status;
  //   });
  //   if (status == GameStatus.result) {
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (_) => Result(),
  //     );
  //   }
  // }
  bool showResultDialog = true;

  @override
  Widget build(BuildContext context) {
    if (showResultDialog) {
      showResultDialog = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return const Align(
              alignment: Alignment.center,
              child: Material(color: Colors.transparent, child: Result()),
            );
          },
        );
      });
    }
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              'assets/games/liars_bar/images/background/background.png',
            ),
            fit: BoxFit.fill,
          ),
        ),
        child: Stack(
          children: [Positioned(top: 20, right: 20, child: SideBlock())],
        ),
      ),
    );
  }
}

enum GameStatus {
  waiting, // 대기
  starting, // 시작 연출
  playing, // 진행 중
  result, // 결과 화면
  finished, // 종료
}
