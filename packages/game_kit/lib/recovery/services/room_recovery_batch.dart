import 'dart:async';

/// One room operation owner: immediate, then 1/2/4/8/8 seconds, within 30 seconds.
class RoomRecoveryBatch {
  RoomRecoveryBatch({Duration Function()? elapsed, this.wait})
    : _elapsed = elapsed ?? (Stopwatch()..start()).elapsedGetter;
  static final Object _key = Object();
  static RoomRecoveryBatch? get current {
    final batch = Zone.current[_key] as RoomRecoveryBatch?;
    return batch != null && batch._running > 0 ? batch : null;
  }

  /// Retains the original deadline for late continuations of an operation.
  static RoomRecoveryBatch? get inherited =>
      Zone.current[_key] as RoomRecoveryBatch?;

  int _running = 0;
  final Duration Function() _elapsed;
  final Future<void> Function(Duration)? wait;
  Duration get remaining => const Duration(seconds: 30) - _elapsed();
  Future<T> run<T>(
    Future<T> Function() attempt, {
    required bool Function() isCurrent,
    required bool Function(Object) retryable,
  }) async {
    _running++;
    try {
      return await _run(attempt, isCurrent: isCurrent, retryable: retryable);
    } finally {
      _running--;
    }
  }

  Future<T> _run<T>(
    Future<T> Function() attempt, {
    required bool Function() isCurrent,
    required bool Function(Object) retryable,
  }) async {
    const delays = [1, 2, 4, 8, 8];
    Object? last;
    for (var index = 0; index <= delays.length; index++) {
      if (!isCurrent() || remaining <= Duration.zero) break;
      try {
        return await runZoned(
          () => attempt().timeout(
            remaining < const Duration(seconds: 8)
                ? remaining
                : const Duration(seconds: 8),
          ),
          zoneValues: {_key: this},
        );
      } catch (error) {
        if (!retryable(error)) rethrow;
        last = error;
      }
      if (index == delays.length ||
          remaining <= Duration(seconds: delays[index])) {
        break;
      }
      await (wait ?? Future<void>.delayed)(Duration(seconds: delays[index]));
    }
    throw last ?? TimeoutException('복구 결과를 확인하지 못했습니다.');
  }

  Future<T> request<T>(Future<T> Function() action) {
    final budget = remaining;
    if (budget <= Duration.zero) {
      return Future.error(TimeoutException('복구 예산이 소진되었습니다.'));
    }
    return action().timeout(
      budget < const Duration(seconds: 8) ? budget : const Duration(seconds: 8),
    );
  }
}

extension on Stopwatch {
  Duration Function() get elapsedGetter =>
      () => elapsed;
}
