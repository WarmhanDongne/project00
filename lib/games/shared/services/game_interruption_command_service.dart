import 'package:cloud_functions/cloud_functions.dart';
import 'package:project00/games/shared/services/callable_retry_policy.dart';

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
    final data = {'roomCode': roomCode, 'interruptionId': interruptionId};
    await retryPolicy.run(
      () =>
          _functions.httpsCallable('voteToContinueInterruptedGame').call(data),
      enabled: true,
    );
  }

  Future<void> expire({
    required String roomCode,
    required String interruptionId,
  }) async {
    final data = {'roomCode': roomCode, 'interruptionId': interruptionId};
    await retryPolicy.run(
      () => _functions.httpsCallable('expireInterruptedGame').call(data),
      enabled: true,
    );
  }
}
