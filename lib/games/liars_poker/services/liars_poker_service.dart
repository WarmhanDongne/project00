import 'liars_poker_query_service.dart';
import 'liars_poker_command_service.dart';

class LiarsPokerService {
  LiarsPokerService({
    LiarsPokerCommandService? command,
    LiarsPokerQueryService? query,
  }) : command = command ?? LiarsPokerCommandService(),
       query = query ?? LiarsPokerQueryService();

  final LiarsPokerCommandService command;
  final LiarsPokerQueryService query;
}
