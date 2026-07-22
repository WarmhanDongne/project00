import 'package:project00/games/liars_bar/models/liars_bar_state.dart';

abstract interface class LiarsBarRepository {
  Stream<LiarsBarState> watchGame(String roomId);
  Future<void> callLiar(String roomId, String playerId);
}
