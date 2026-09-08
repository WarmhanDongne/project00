import 'package:game_kit/template_game.dart';
import 'package:game_final_call/final_call_game.dart';
import 'package:game_liars_poker/liars_poker_game.dart';
import 'package:game_mafia/mafia_game.dart';

final class GameRegistry implements GameCatalog {
  const GameRegistry();

  @override
  List<TemplateGame> get games => const [
    LiarsPokerGame(),
    FinalCallGame(),
    MafiaGame(),
  ];

  @override
  TemplateGame? find(String id) {
    for (final game in games) {
      if (game.id == id) return game;
    }
    return null;
  }
}
