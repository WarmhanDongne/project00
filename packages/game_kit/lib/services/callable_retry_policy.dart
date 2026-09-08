import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

/// 멱등성을 보장하는 게임 명령의 Cloud Functions 일시 오류 재전송 정책입니다.
///
/// [maxAttempts]는 최초 요청을 포함합니다. 기본값 4는 첫 실패 뒤 같은 요청을
/// 최대 3번 더 전송한다는 의미입니다. 호출자는 재전송 전체에서 같은
/// `commandId`와 payload를 유지해야 합니다.
///
/// 전체 대기 시간은 [totalBudget]을 넘지 않습니다. 예전에는 상한이 없어서
/// callable 기본 타임아웃(70초) × 4회 = 최악 281초 동안 응답을 기다렸습니다.
/// 그동안 휴대폰의 `isCommandInFlight`가 계속 true라 제출·라이어 버튼이 모두
/// 잠겨, 실제로 판이 멈춘 것처럼 보였습니다. 턴 제한이 30초이므로 그보다 오래
/// 기다리는 재전송은 어차피 의미가 없습니다.
class CallableRetryPolicy {
  const CallableRetryPolicy({
    this.baseDelay = const Duration(milliseconds: 250),
    this.attemptTimeout = const Duration(seconds: 8),
    this.totalBudget = const Duration(seconds: 12),
  });

  static const int maxAttempts = 4;

  final Duration baseDelay;

  /// 한 번의 요청이 응답을 기다리는 최대 시간입니다.
  final Duration attemptTimeout;

  /// 재전송을 포함해 호출자가 기다리는 전체 최대 시간입니다.
  final Duration totalBudget;

  static const retryableCodes = <String>{
    'aborted',
    'cancelled',
    'deadline-exceeded',
    'internal',
    'unavailable',
    'unknown',
  };

  Future<T> run<T>(
    Future<T> Function() request, {
    required bool enabled,
  }) async {
    final elapsed = Stopwatch()..start();
    Object lastError = TimeoutException(
      '서버 응답이 오지 않아 요청을 취소했습니다.',
      totalBudget,
    );
    StackTrace lastStackTrace = StackTrace.current;

    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      final remaining = totalBudget - elapsed.elapsed;
      if (remaining <= Duration.zero) break;

      try {
        return await request().timeout(
          remaining < attemptTimeout ? remaining : attemptTimeout,
        );
      } on TimeoutException catch (error, stackTrace) {
        // 응답이 늦는 것도 일시 오류로 봅니다. 명령에는 commandId가 붙어 있어
        // 서버가 이미 처리했다면 재전송해도 두 번 진행되지 않습니다.
        lastError = error;
        lastStackTrace = stackTrace;
      } on FirebaseFunctionsException catch (error, stackTrace) {
        if (!enabled || !retryableCodes.contains(error.code)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        lastError = error;
        lastStackTrace = stackTrace;
      }

      if (!enabled) break;
      final delay = _delayForRetry(attempt);
      // 남은 예산으로 다음 시도를 의미 있게 할 수 없으면 여기서 멈춥니다.
      if (elapsed.elapsed + delay >= totalBudget) break;
      await Future<void>.delayed(delay);
    }

    Error.throwWithStackTrace(lastError, lastStackTrace);
  }

  Duration _delayForRetry(int failedAttempt) {
    final multiplier = 1 << failedAttempt.clamp(0, 4);
    return Duration(milliseconds: baseDelay.inMilliseconds * multiplier);
  }
}
