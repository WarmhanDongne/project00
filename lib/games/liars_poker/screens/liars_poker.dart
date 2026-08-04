import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';
import 'package:project00/games/liars_poker/screens/phone_game.dart';
import 'package:project00/games/liars_poker/screens/tablet_game.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

class LiarsPoker extends StatelessWidget {
  const LiarsPoker({
    super.key,
    required this.playerLayout,
    required this.provider,
  });

  final PlayerLayoutModel playerLayout;
  final RoomProvider provider;
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 모바일 브레이크포인트 설정 (일반적으로 600px 기준)
        if (constraints.maxWidth < 600) {
          return PhoneGame(playerLayout: playerLayout);
        } else {
          return TabletGame(playerLayout: playerLayout, provider: provider);
        }
      },
    );
  }
}
