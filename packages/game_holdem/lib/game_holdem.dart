import 'package:flutter/widgets.dart';
import 'package:game_holdem/game_assets.dart';
import 'package:game_holdem/game_theme.dart';
import 'package:game_holdem/phone/phone_board.dart';
import 'package:game_holdem/shared/services/game_service.dart';
import 'package:game_holdem/tablet/tablet_board.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/recovery/widgets/critical_network_guard.dart';
import 'package:game_kit/template_game.dart';

class HoldemGame extends TemplateGame {
  const HoldemGame();

  @override
  String get id => 'holdem';
  @override
  String get title => "Texas Hold'em";
  @override
  List<int> get supportedPlayerCounts => const [2, 3, 4, 5, 6, 7, 8];
  @override
  String get leaveFunctionName => 'game_holdem_leave_game';
  @override
  PhoneGameOrientation get phoneOrientation =>
      PhoneGameOrientation.portraitOnly;
  @override
  Color get tableColor => HoldemColors.felt;
  @override
  ImageProvider get tableBackgroundImage =>
      HoldemAssets.tabletBackground.provider();
  @override
  ImageProvider get layoutTableImage => HoldemAssets.layoutTable.provider();
  @override
  ImageProvider get layoutChairImage => HoldemAssets.layoutChair.provider();

  @override
  int get requiredAssetVersion => HoldemAssets.assetVersion;

  @override
  Future<void> startGame(String roomCode, {Map<String, Object?>? options}) =>
      HoldemService().command.startGame(roomCode: roomCode);
  @override
  Stream<String?> watchStatus(String roomCode) => HoldemService().query
      .watchStatus(roomCode)
      .map((event) => event.snapshot.value as String?);

  @override
  Widget buildPhoneScreen({
    required String roomCode,
    required GameRoomContext provider,
    required Future<bool> Function() onExitRoom,
  }) => Builder(
    builder: (context) => CriticalNetworkGuard(
      provider: provider,
      onExit: () => Navigator.of(context).popUntil((route) => route.isFirst),
      child: HoldemPhoneGame(
        roomCode: roomCode,
        provider: provider,
        gameService: HoldemService(),
        onExitRoom: onExitRoom,
      ),
    ),
  );

  @override
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required GameRoomContext provider,
    required String roomCode,
  }) => Builder(
    builder: (context) => CriticalNetworkGuard(
      provider: provider,
      exitLabel: '대기실로',
      onExit: () => Navigator.of(context).maybePop(),
      child: HoldemTabletGame(
        playerLayout: playerLayout,
        provider: provider,
        roomCode: roomCode,
        gameService: HoldemService(),
      ),
    ),
  );
}
