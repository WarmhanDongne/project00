import 'liars_poker_query_service.dart';
import 'liars_poker_command_service.dart';
import 'package:project00/games/shared/services/game_interruption_command_service.dart';

class LiarsPokerService {
  LiarsPokerService({
    LiarsPokerCommandService? command,
    LiarsPokerQueryService? query,
    GameInterruptionCommandService? interruption,
  }) : command = command ?? LiarsPokerCommandService(),
       query = query ?? LiarsPokerQueryService(),
       interruption = interruption ?? GameInterruptionCommandService();

  final LiarsPokerCommandService command;
  final LiarsPokerQueryService query;
  final GameInterruptionCommandService interruption;
}
