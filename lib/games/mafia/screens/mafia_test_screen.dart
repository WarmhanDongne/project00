import 'package:flutter/material.dart';
import 'package:project00/games/mafia/screens/phone_game.dart';
import 'package:project00/games/mafia/screens/tablet_game.dart';

/// 방 생성과 플레이어 자리 배치 없이 Mafia UI를 바로 확인하는 개발 화면입니다.
///
/// 실제 게임 연동 전까지 Mafia 화면 작업은 이 위젯의 본문에서 진행합니다.
class MafiaTestScreen extends StatelessWidget {
  const MafiaTestScreen({super.key, this.testPlayerCount = 6});

  final int testPlayerCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 모바일 브레이크포인트 설정 (일반적으로 600px 기준)
        if (constraints.maxWidth < 600) {
          return MafiaPhoneGame();
        } else {
          return MafiaTabletGame();
        }
      },
    );
  }
}
