// [game_service.dart] 라이어스 포커의 명령·조회·게임 중단
// 서비스를 하나의 객체로 묶어 Controller에 제공하는 파일이다.

// ========================[ import ]==========================
import 'query_service.dart';
import 'command_service.dart';
import 'package:game_kit/services/game_interruption_command_service.dart';
// ============================================================

// ---------------------------------------------------------------------------
// 라이어스포커 서버 통신 묶음
// ---------------------------------------------------------------------------
class LiarsPokerService {
  LiarsPokerService({
    LiarsPokerCommandService? command,
    LiarsPokerQueryService? query,
    GameInterruptionCommandService? interruption,
  }) : command = command ?? LiarsPokerCommandService(),
       query = query ?? LiarsPokerQueryService(),
       interruption = interruption ?? GameInterruptionCommandService();

  /// 카드 제출·LIAR·룰렛처럼 서버 상태를 바꾸는 명령을 제공합니다.
  final LiarsPokerCommandService command;

  /// 공개 상태와 개인 상태를 읽고 구독하는 조회를 제공합니다.
  final LiarsPokerQueryService query;

  /// 공통 게임 중단 요청과 복구 흐름에 사용하는 명령을 제공합니다.
  final GameInterruptionCommandService interruption;
}
