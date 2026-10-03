// [game_interruption_command_service.dart] 는 여러 게임이 함께 사용하는 서버의 게임 상태를 변경하는 명령을 모아둔 파일이다.
//
// - [Package] : 게임 공통 기반
// - [RecoveryService] : 중단 투표·제외·종료 명령을 서버에 전달함
//
// 즉, 화면에서 발생한 행동을 정해진 서버 쓰기 경계로 전달하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:game_kit/services/game_command_service.dart';

// ============================================================

/// 게임 종류와 무관한 연결 중단 투표 명령입니다.
///
/// 네 명령 모두 payload가 `roomCode` + `interruptionId`로 같고, 서버가
/// `interruptionId` 소진으로 멱등하게 처리하므로 전부 재전송을 켭니다.
/// 재전송해도 두 번 처리되지 않고, 서로 경합해도 먼저 도착한 쪽만 반영됩니다.
class GameInterruptionCommandService extends GameCommandService {
  GameInterruptionCommandService({super.functions, super.retryPolicy});

  /// 중단된 플레이어를 기다리며 게임을 계속하는 쪽에 투표합니다.
  Future<void> voteToContinue({
    required String roomCode,
    required String interruptionId,
  }) => _send(
    'game_common_interruption_vote_to_continue',
    roomCode,
    interruptionId,
  );

  /// 마감이 지난 중단을 정리합니다.
  Future<void> expire({
    required String roomCode,
    required String interruptionId,
  }) => _send('game_common_interruption_expire', roomCode, interruptionId);

  /// 남은 인원이 부족해 계속할 수 없을 때 60초 마감을 기다리지 않고 게임을
  /// 정상 종료합니다.
  ///
  /// [expire]와 같은 최종 상태를 만들되 마감 전에도 성공합니다. 0초 자동
  /// 만료와 경합해도 먼저 도착한 쪽만 처리됩니다.
  Future<void> finishNow({
    required String roomCode,
    required String interruptionId,
  }) => _send('game_common_interruption_finish_now', roomCode, interruptionId);

  /// 방을 만든 태블릿 진행자가 중단된 플레이어를 제외하고 즉시 계속합니다.
  Future<void> excludeAndContinue({
    required String roomCode,
    required String interruptionId,
  }) => _send(
    'game_common_interruption_exclude_player',
    roomCode,
    interruptionId,
  );

  Future<void> _send(
    String functionName,
    String roomCode,
    String interruptionId,
  ) => invoke(functionName, {
    'roomCode': roomCode,
    'interruptionId': interruptionId,
  }, retryTransientFailure: true);
}
