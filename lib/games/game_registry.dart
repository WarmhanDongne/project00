import 'package:game_kit/template_game.dart';
import 'package:game_final_call/game_final_call.dart';
import 'package:game_liars_poker/game_liars_poker.dart';
import 'package:game_mafia/game_mafia.dart';
import 'package:game_holdem/game_holdem.dart';
import 'package:game_yut/game_yut.dart';

final class GameRegistry implements GameCatalog {
  const GameRegistry();

  @override
  List<TemplateGame> get games => const [
    LiarsPokerGame(),
    FinalCallGame(),
    MafiaGame(),
    HoldemGame(),
    YutGame(),
    StrategyYutGame(),
    StrategyYutEditionGame(),
  ];

  @override
  TemplateGame? find(String id) {
    for (final game in games) {
      if (game.id == id) return game;
    }
    return null;
  }
}
