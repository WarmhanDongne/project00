// [game_progress_command.dart] 연출 완료 후 서버 진행 명령을 재시도하며 전달합니다.
import 'dart:async';
import 'package:game_kit/recovery/services/game_command_batch.dart';

/// 사용자 행동이 아닌, 이미 끝난 연출의 완료 알림에 사용합니다.
///
/// [key]는 게임 시작 시각·라운드·세부 단계로 구성합니다. 같은 키의 요청은
/// 12초 예산에서 최대 네 번 시도합니다. 소진 뒤에는 수동 재시도합니다.
/// 새 게임/단계로 바뀌면 [isCurrent]가 false가 되어 옛 요청을 다시 보내지
/// 않습니다. 이미 서버로 전송된 요청은 취소할 수 없으므로 서버의 검증은
/// 여전히 필요합니다. 카드 제출처럼 새 행동을 만드는 명령에는 쓰지 마세요.
class GameProgressCommand {
  GameProgressCommand({
    this.retryDelay = const Duration(milliseconds: 250),
    this.elapsed,
  });

  final Duration retryDelay;
  final Duration Function()? elapsed;
  Object? _key;
  int _generation = 0;
  Timer? _timer;
  bool _disposed = false;
  bool _exhausted = false;
  void Function()? _retry;
  bool get needsRetry => _exhausted;
  void retry() {
    if (_exhausted) _retry?.call();
  }

  void run({
    required Object key,
    required bool Function() isCurrent,
    required Future<bool> Function() send,
    Map<String, Map<String, dynamic>>? capturedCommands,
  }) {
    if (_disposed || !isCurrent() || _key == key) return;
    cancel();
    _key = key;
    final generation = _generation;
    final baseline = elapsed?.call() ?? Duration.zero;
    final batch = GameCommandBatch(
      commands: capturedCommands,
      elapsed: elapsed == null ? null : () => elapsed!() - baseline,
    );
    var attempts = 0;
    _exhausted = false;
    _retry = () {
      if (_disposed) return;
      if (!isCurrent()) {
        cancel();
        return;
      }
      _key = null;
      run(
        key: key,
        isCurrent: isCurrent,
        send: send,
        capturedCommands: batch.commands,
      );
    };

    Future<void> attempt() async {
      if (_disposed || generation != _generation) return;
      if (!isCurrent()) {
        cancel();
        return;
      }
      // send는 게임 Controller의 오류 기록/사용자 안내를 거쳐 bool을 반환합니다.
      // 예외도 재시도 대상으로 받되 이전 요청의 완료가 새 타이머를 건드리지 않습니다.
      var success = false;
      try {
        attempts++;
        if (batch.remaining <= Duration.zero) {
          _exhausted = true;
          return;
        }
        success = await batch.run(send).timeout(batch.remaining);
      } catch (_) {
        success = false;
      }
      if (_disposed || generation != _generation) return;
      if (!isCurrent()) {
        cancel();
      } else if (!success) {
        final delay = retryDelay * (1 << (attempts - 1));
        if (attempts >= 4 || batch.remaining <= delay) {
          _exhausted = true;
          return;
        }
        _timer = Timer(delay, () => unawaited(attempt()));
      }
    }

    unawaited(attempt());
  }

  /// 새 판/화면 종료 시 호출합니다. 진행 중인 옛 Future의 후속 처리도 무효화합니다.
  void cancel() {
    _generation += 1;
    _timer?.cancel();
    _timer = null;
    _key = null;
    _retry = null;
    _exhausted = false;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
