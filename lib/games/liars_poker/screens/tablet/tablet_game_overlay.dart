import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/screens/tablet/game_status.dart';
import 'package:project00/games/liars_poker/widgets/sideblock_tablet.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 게임 중 사용할 규칙/설정 메뉴를 화면 위에 배치합니다.
class TabletGameOverlay extends StatelessWidget {
  const TabletGameOverlay({
    super.key,
    required this.provider,
    required this.status,
    required this.onRestartGame,
    required this.onEndGame,
  });

  final RoomProvider provider;
  final GameStatus status;
  final VoidCallback onRestartGame;
  final VoidCallback onEndGame;

  @override
  Widget build(BuildContext context) {
    // 결과·종료 화면에서는 우승 화면만 보이도록 SideBlock도 숨깁니다.
    if (status == GameStatus.result || status == GameStatus.finished) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        Positioned(
          top: 20,
          right: 20,
          child: SideBlock(
            provider: provider,
            onRestartGame: onRestartGame,
            onEndGame: onEndGame,
          ),
        ),
      ],
    );
  }
}
