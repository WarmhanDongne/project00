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
