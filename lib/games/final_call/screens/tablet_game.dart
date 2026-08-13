import 'package:flutter/material.dart';
import 'package:project00/games/final_call/screens/tablet/final_call_tablet_game.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// Liar's Poker와 동일한 위치에 둔 Final Call 태블릿 진입 화면입니다.
class FinalCallTabletGameEntry extends StatelessWidget {
  const FinalCallTabletGameEntry({
    super.key,
    required this.roomCode,
    required this.gameService,
    required this.provider,
  });

  final String roomCode;
  final FinalCallService gameService;
  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    return FinalCallTabletGame(
      roomCode: roomCode,
      service: gameService,
      provider: provider,
    );
  }
}
