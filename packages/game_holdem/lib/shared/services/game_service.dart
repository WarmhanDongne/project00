import 'package:game_holdem/shared/services/command_service.dart';
import 'package:game_holdem/shared/services/query_service.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';

class HoldemService {
  HoldemService({
    HoldemCommandService? command,
    HoldemQueryService? query,
    GameInterruptionCommandService? interruption,
  }) : command = command ?? HoldemCommandService(),
       query = query ?? HoldemQueryService(),
       interruption = interruption ?? GameInterruptionCommandService();

  final HoldemCommandService command;
  final HoldemQueryService query;
  final GameInterruptionCommandService interruption;
}
