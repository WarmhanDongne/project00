import 'package:project00/games/liars_poker/models/liars_poker_state.dart';

abstract interface class LiarsPokerRepository {
  Stream<LiarsPokerState> watchGame(String roomId);
  Future<void> callLiar(String roomId, String playerId);
}
