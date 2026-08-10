import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';
import 'package:project00/games/liars_poker/screens/phone_game.dart';
import 'package:project00/games/liars_poker/screens/tablet_game.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

class LiarsPoker extends StatelessWidget {
  const LiarsPoker({
    super.key,
    required this.playerLayout,
    required this.provider,
    required this.roomCode,
    required this.gameService,
  });

  final PlayerLayoutModel playerLayout;
  final RoomProvider provider;
  final String roomCode;
  final LiarsPokerService gameService;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 모바일 브레이크포인트 설정 (단변 기준 600px 미만이면 폰으로 간주)
        final shortestSide = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        
        if (shortestSide < 600) {
          return PhoneGame(roomCode: roomCode, gameService: gameService);
        } else {
          return LiarsPokerTabletGame(
            playerLayout: playerLayout,
            provider: provider,
            roomCode: roomCode,
            gameService: gameService,
          );
        }
      },
    );
  }
}
