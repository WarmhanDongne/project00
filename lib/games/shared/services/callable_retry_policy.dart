import 'package:cloud_functions/cloud_functions.dart';

/// 멱등성을 보장하는 게임 명령의 Cloud Functions 일시 오류 재전송 정책입니다.
///
/// [maxAttempts]는 최초 요청을 포함합니다. 기본값 4는 첫 실패 뒤 같은 요청을
/// 최소 3번 더 전송한다는 의미입니다. 호출자는 재전송 전체에서 같은
/// `commandId`와 payload를 유지해야 합니다.
class CallableRetryPolicy {
  const CallableRetryPolicy({
    this.baseDelay = const Duration(milliseconds: 250),
  });

  static const int maxAttempts = 4;
  final Duration baseDelay;

  static const retryableCodes = <String>{
    'aborted',
    'cancelled',
    'deadline-exceeded',
    'internal',
    'not-found',
    'resource-exhausted',
    'unavailable',
    'unknown',
  };

  Future<T> run<T>(
    Future<T> Function() request, {
    required bool enabled,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      try {
        return await request();
      } on FirebaseFunctionsException catch (error) {
        final hasMoreAttempts = attempt < maxAttempts - 1;
        if (!enabled ||
            !hasMoreAttempts ||
            !retryableCodes.contains(error.code)) {
          rethrow;
        }
        await Future<void>.delayed(_delayForRetry(attempt));
      }
    }
    throw StateError('도달할 수 없는 재시도 상태입니다.');
  }

  Duration _delayForRetry(int failedAttempt) {
    final multiplier = 1 << failedAttempt.clamp(0, 4);
    return Duration(milliseconds: baseDelay.inMilliseconds * multiplier);
  }
}
