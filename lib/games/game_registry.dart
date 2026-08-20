import 'package:project00/games/template_game.dart';
import 'package:project00/games/final_call/final_call_game.dart';
import 'package:project00/games/liars_poker/liars_poker_game.dart';
import 'package:project00/games/mafia/mafia_game.dart';

abstract final class GameRegistry {
  static const games = [LiarsPokerGame(), FinalCallGame(), MafiaGame()];

  static TemplateGame? find(String id) {
    for (final game in games) {
      if (game.id == id) return game;
    }
    return null;
  }
}
