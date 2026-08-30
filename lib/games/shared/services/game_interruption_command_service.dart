import 'package:cloud_functions/cloud_functions.dart';
import 'package:project00/games/shared/services/callable_retry_policy.dart';
import 'package:project00/platform/home/room/services/controller_room_session_store.dart';

/// 게임 종류와 무관한 연결 중단 투표 명령입니다.
class GameInterruptionCommandService {
  GameInterruptionCommandService({
    FirebaseFunctions? functions,
    this.retryPolicy = const CallableRetryPolicy(),
  }) : _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;
  final CallableRetryPolicy retryPolicy;

  Future<void> voteToContinue({
    required String roomCode,
    required String interruptionId,
  }) async {
    final data = controllerCommandData(roomCode, {
      'interruptionId': interruptionId,
    });
    await retryPolicy.run(
      () => _functions
          .httpsCallable('game_common_interruption_vote_to_continue')
          .call(data),
      enabled: true,
    );
  }

  Future<void> expire({
    required String roomCode,
    required String interruptionId,
  }) async {
    final data = controllerCommandData(roomCode, {
      'interruptionId': interruptionId,
    });
    await retryPolicy.run(
      () => _functions
          .httpsCallable('game_common_interruption_expire')
          .call(data),
      enabled: true,
    );
  }

  /// 남은 인원이 부족해 계속할 수 없을 때 60초 마감을 기다리지 않고 게임을
  /// 정상 종료합니다.
  ///
  /// [expire]와 같은 최종 상태를 만들되 마감 전에도 성공합니다. 서버가
  /// `interruptionId` 소진으로 멱등하므로 재전송해도 두 번 종료되지 않고,
  /// 0초 자동 만료와 경합해도 먼저 도착한 쪽만 처리됩니다.
  Future<void> finishNow({
    required String roomCode,
    required String interruptionId,
  }) async {
    final data = controllerCommandData(roomCode, {
      'interruptionId': interruptionId,
    });
    await retryPolicy.run(
      () => _functions
          .httpsCallable('game_common_interruption_finish_now')
          .call(data),
      enabled: true,
    );
  }

  /// 방을 만든 태블릿 진행자가 중단된 플레이어를 제외하고 즉시 계속합니다.
  Future<void> excludeAndContinue({
    required String roomCode,
    required String interruptionId,
  }) async {
    final data = controllerCommandData(roomCode, {
      'interruptionId': interruptionId,
    });
    await retryPolicy.run(
      () => _functions
          .httpsCallable('game_common_interruption_exclude_player')
          .call(data),
      enabled: true,
    );
  }
}
