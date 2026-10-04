// [game_service.dart] 는 마피아에서 사용하는 게임의 조회·명령 서비스를 묶어 제공하는 파일이다.
//
// - [Package] : 마피아
// - [Service] : 게임의 조회·명령 서비스를 묶어 제공함
//
// 즉, 게임 로직이 서버 접근 방식을 한곳에서 사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:game_mafia/shared/services/command_service.dart';
import 'package:game_mafia/shared/services/query_service.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';

// ============================================================

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
