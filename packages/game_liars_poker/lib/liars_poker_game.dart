import 'package:flutter/widgets.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_kit/template_game.dart';
import 'package:game_liars_poker/screens/phone_game.dart';
import 'package:game_liars_poker/screens/tablet_game.dart';
import 'package:game_liars_poker/services/liars_poker_service.dart';
import 'package:game_kit/player_layouts/player_layout_model.dart';
import 'package:game_kit/tablet_preview_artworks.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_kit/widgets/critical_network_guard.dart';

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
      Assets.games.liarsPoker.images.background.background.game.provider();
  @override
  ImageProvider get layoutTableImage =>
      Assets.games.liarsPoker.images.layout.layoutTable.game.provider();
  @override
  ImageProvider get layoutChairImage =>
      Assets.games.liarsPoker.images.layout.layoutChair.game.provider();

  @override
  Widget buildTabletPreviewArtwork() => LiarsPokerPreviewArtwork(
    cards: [
      Assets.games.liarsPoker.images.cards.whiteQ.game,
      Assets.games.liarsPoker.images.cards.whiteK.game,
      Assets.games.liarsPoker.images.cards.whiteA.game,
      Assets.games.liarsPoker.images.cards.whiteJoker.game,
      Assets.games.liarsPoker.images.cards.whiteBack.game,
    ],
  );

  @override
  Future<void> startGame(String roomCode, {Map<String, Object?>? options}) =>
      LiarsPokerService().command.startGame(roomCode: roomCode);

  @override
  Stream<String?> watchStatus(String roomCode) => LiarsPokerService().query
      .watchStatus(roomCode)
      .map((event) => event.snapshot.value as String?);

  @override
  Widget buildPhoneScreen({
    required String roomCode,
    required GameRoomContext provider,
    required Future<bool> Function() onExitRoom,
  }) {
    return Builder(
      builder: (context) => CriticalNetworkGuard(
        provider: provider,
        onExit: () => Navigator.of(context).popUntil((route) => route.isFirst),
        child: LiarsPokerPhoneGame(
          roomCode: roomCode,
          provider: provider,
          gameService: LiarsPokerService(),
          onExitRoom: onExitRoom,
        ),
      ),
    );
  }

  @override
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required GameRoomContext provider,
    required String roomCode,
  }) {
    return Builder(
      builder: (context) => CriticalNetworkGuard(
        provider: provider,
        exitLabel: '대기실로',
        onExit: () => Navigator.of(context).maybePop(),
        child: LiarsPokerTabletGame(
          playerLayout: playerLayout,
          provider: provider,
          roomCode: roomCode,
          gameService: LiarsPokerService(),
        ),
      ),
    );
  }
}
