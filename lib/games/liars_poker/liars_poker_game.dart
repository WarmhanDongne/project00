import 'package:flutter/widgets.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/games/template_game.dart';
import 'package:project00/games/liars_poker/screens/phone_game.dart';
import 'package:project00/games/liars_poker/screens/tablet_game.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

class LiarsPokerGame extends TemplateGame {
  const LiarsPokerGame();

  @override
  String get id => 'liars_poker';
  @override
  String get title => "Liar's Poker";
  @override
  String get leaveFunctionName => 'game_liars_poker_leave_game';
  @override
  PhoneGameOrientation get phoneOrientation =>
      PhoneGameOrientation.portraitAndLandscape;
  @override
  Color get tableColor => const Color(0xFF6E2A82);
  @override
  ImageProvider get tableBackgroundImage =>
      Assets.games.liarsPoker.images.background.background.provider();
  @override
  ImageProvider get layoutTableImage =>
      Assets.games.liarsPoker.images.layout.layoutTable.provider();
  @override
  ImageProvider get layoutChairImage =>
      Assets.games.liarsPoker.images.layout.layoutChair.provider();

  @override
  Future<void> startGame(String roomCode) =>
      LiarsPokerService().command.startGame(roomCode: roomCode);

  @override
  Stream<String?> watchStatus(String roomCode) => LiarsPokerService().query
      .watchStatus(roomCode)
      .map((event) => event.snapshot.value as String?);

  @override
  Widget buildPhoneScreen({
    required String roomCode,
    required Future<bool> Function() onExitRoom,
  }) {
    return LiarsPokerPhoneGame(
      roomCode: roomCode,
      gameService: LiarsPokerService(),
      onExitRoom: onExitRoom,
    );
  }

  @override
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required RoomProvider provider,
    required String roomCode,
  }) {
    return LiarsPokerTabletGame(
      playerLayout: playerLayout,
      provider: provider,
      roomCode: roomCode,
      gameService: LiarsPokerService(),
    );
  }
}
