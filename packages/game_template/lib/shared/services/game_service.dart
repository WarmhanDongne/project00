// [game_service.dart] 는 새 게임을 같은 구조로 시작할 때 사용하는 게임의 조회·명령 서비스를 묶어 제공하는 파일이다.
//
// - [Package] : 새 게임 템플릿
// - [Service] : 게임의 조회·명령 서비스를 묶어 제공함
//
// 즉, 게임 로직이 서버 접근 방식을 한곳에서 사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';

import 'command_service.dart';
import 'query_service.dart';

// ============================================================

/// Command/Query 서비스를 묶는 파사드입니다. 모든 게임이 이 모양을 따릅니다.
class TemplateService {
  TemplateService({
    TemplateCommandService? command,
    TemplateQueryService? query,
    GameInterruptionCommandService? interruption,
  }) : command = command ?? TemplateCommandService(),
       query = query ?? TemplateQueryService(),
       interruption = interruption ?? GameInterruptionCommandService();

  //[쓰기] 서버 상태를 바꾸는 명령
  final TemplateCommandService command;

  //[읽기] 공개·개인 상태 구독
  final TemplateQueryService query;

  //[중단] 참가자 끊김 투표·종료 (공용 뼈대가 씀)
  final GameInterruptionCommandService interruption;
}
