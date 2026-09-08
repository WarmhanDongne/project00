import 'package:flutter/widgets.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_final_call/gen/assets.gen.dart';
import 'package:game_kit/template_game.dart';
import 'package:game_final_call/screens/phone_game.dart';
import 'package:game_final_call/screens/tablet_game.dart';
import 'package:game_final_call/services/final_call_service.dart';
import 'package:game_kit/player_layouts/player_layout_model.dart';
import 'package:game_kit/tablet_preview_artworks.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_final_call/game_assets.dart';
import 'package:game_kit/widgets/critical_network_guard.dart';

class FinalCallGame extends TemplateGame {
  const FinalCallGame();

  @override
  String get id => 'final_call';
  @override
  String get title => 'Final Call';
  @override
  int get fixedPlayerCount => 4;
  @override
  String get leaveFunctionName => 'game_final_call_leave_game';
  @override
  PhoneGameOrientation get phoneOrientation =>
      PhoneGameOrientation.landscapeOnly;
  @override
  Color get tableColor => const Color(0xFFF2F0EB);
  @override
  ImageProvider get tableBackgroundImage =>
      Assets.games.finalCall.images.background.background.game.provider();
  @override
  ImageProvider get layoutTableImage =>
      Assets.games.finalCall.images.layout.layoutTable.game.provider();
  @override
  ImageProvider get layoutChairImage =>
      Assets.games.finalCall.images.layout.layoutChair.game.provider();

  @override
  Widget buildTabletPreviewArtwork() => FinalCallPreviewArtwork(
    cards: [
      Assets.games.finalCall.images.cards.cardRed7.game,
      Assets.games.finalCall.images.cards.cardBlue7.game,
      Assets.games.finalCall.images.cards.cardGreen3.game,
      Assets.games.finalCall.images.cards.cardYellow10.game,
    ],
    redHeart: Assets.games.finalCall.images.icons.iconHeartRed.game,
    blueHeart: Assets.games.finalCall.images.icons.iconHeartBlue.game,
  );

  @override
  Future<void> startGame(String roomCode, {Map<String, Object?>? options}) =>
      FinalCallService().command.startGame(roomCode: roomCode);

  @override
  Stream<String?> watchStatus(String roomCode) => FinalCallService().query
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
        child: FinalCallPhoneGame(
          roomCode: roomCode,
          provider: provider,
          gameService: FinalCallService(),
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
    // Final Call 태블릿 화면은 좌석 배치를 쓰지 않아 playerLayout을 사용하지 않습니다.
    return Builder(
      builder: (context) => CriticalNetworkGuard(
        provider: provider,
        exitLabel: '대기실로',
        onExit: () => Navigator.of(context).maybePop(),
        child: FinalCallTabletGame(
          roomCode: roomCode,
          gameService: FinalCallService(),
          provider: provider,
        ),
      ),
    );
  }
}
