import 'package:project00/games/final_call/final_call_game.dart';
import 'package:project00/games/liars_poker/liars_poker_game.dart';

abstract final class GameRegistry {
  static const games = [LiarsPokerGame(), FinalCallGame()];
}
