// [game_service.dart] 는 파이널콜에서 사용하는 게임의 읽기·쓰기 서비스를 묶어 제공하는 파일이다.
//
// - [Package] : 파이널콜
// - [Service] : 게임의 읽기·쓰기 서비스를 묶어 제공함
//
// 즉, 화면과 컨트롤러가 통신 구현을 쉽게 주입하고 교체하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'command_service.dart';
import 'query_service.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';

// ============================================================

/// Final Call의 읽기 구독과 서버 명령을 분리해 제공하는 진입 서비스입니다.
class FinalCallService {
  FinalCallService({
    FinalCallCommandService? command,
    FinalCallQueryService? query,
    GameInterruptionCommandService? interruption,
  }) : command = command ?? FinalCallCommandService(),
       query = query ?? FinalCallQueryService(),
       interruption = interruption ?? GameInterruptionCommandService();

  final FinalCallCommandService command;
  final FinalCallQueryService query;
  final GameInterruptionCommandService interruption;
}
