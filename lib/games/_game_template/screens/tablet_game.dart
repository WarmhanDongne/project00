import 'package:flutter/material.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';

/// 태블릿 진행 화면 뼈대입니다.
///
/// 화면이 여러 형제 위젯 파일로 쪼개질 만큼 복잡해지면(라이어스포커 사례),
/// [template_game.dart]의 문서 주석에 적힌 기준에 따라 이 화면 전용
/// 오케스트레이션 Provider를 별도로 추가하세요. 그 전까지는 파이널콜처럼
/// 이 위젯의 로컬 상태(`StatefulWidget`)만으로 충분합니다.
class TemplateTabletGame extends StatelessWidget {
  const TemplateTabletGame({
    super.key,
    required this.playerLayout,
    required this.roomCode,
  });

  final PlayerLayoutModel playerLayout;
  final String roomCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'TODO: 태블릿 진행 화면 ($roomCode, ${playerLayout.playerCount}명)',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
