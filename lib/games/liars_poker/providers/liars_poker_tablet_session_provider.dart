import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_tablet_state.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_controller.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';

//=======================Liar's Poker 태블릿 세션 식별자==============================
@immutable
class LiarsPokerTabletSessionArgs {
  const LiarsPokerTabletSessionArgs({
    required this.playerLayout,
    required this.roomCode,
    required this.service,
    required this.onError,
  });

  final PlayerLayoutModel playerLayout;
  final String roomCode;
  final LiarsPokerService service;
  final TabletGameErrorHandler onError;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiarsPokerTabletSessionArgs &&
          identical(playerLayout, other.playerLayout) &&
          roomCode == other.roomCode &&
          identical(service, other.service) &&
          identical(onError, other.onError);

  @override
  int get hashCode => Object.hash(
    identityHashCode(playerLayout),
    roomCode,
    identityHashCode(service),
    identityHashCode(onError),
  );
}

//=======================Liar's Poker 태블릿 세션 Provider==============================
final liarsPokerTabletSessionProvider = NotifierProvider.autoDispose
    .family<
      TabletGameController,
      LiarsPokerTabletState,
      LiarsPokerTabletSessionArgs
    >((args) {
      return TabletGameController(
        playerLayout: args.playerLayout,
        roomCode: args.roomCode,
        gameService: args.service,
        onError: args.onError,
      );
    });
