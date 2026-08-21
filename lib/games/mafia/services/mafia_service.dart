import 'package:project00/games/mafia/services/mafia_command_service.dart';
import 'package:project00/games/mafia/services/mafia_query_service.dart';
import 'package:project00/games/shared/services/game_interruption_command_service.dart';

/// 마피아의 읽기 구독과 서버 명령을 분리해 제공하는 진입 서비스입니다.
class MafiaService {
  MafiaService({
    MafiaCommandService? command,
    MafiaQueryService? query,
    GameInterruptionCommandService? interruption,
  }) : command = command ?? MafiaCommandService(),
       query = query ?? MafiaQueryService(),
       interruption = interruption ?? GameInterruptionCommandService();

  final MafiaCommandService command;
  final MafiaQueryService query;
  final GameInterruptionCommandService interruption;
}
