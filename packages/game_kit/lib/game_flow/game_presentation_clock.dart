import 'dart:async';

import 'package:flutter/material.dart';

/// 화면 연출 전용 시계입니다. 서버 deadline/게임 규칙의 시간은 바꾸지 않습니다.
/// 여러 중단 원인 중 마지막 원인까지 해소되어야 남은 연출을 이어갑니다.
class GamePresentationClock extends ChangeNotifier {
  GamePresentationClock({DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final _reasons = <Object>{};
  final _timers = <PresentationTimer>{};
  bool get paused => _reasons.isNotEmpty;

  void setPaused(Object reason, bool value) {
    final wasPaused = paused;
    value ? _reasons.add(reason) : _reasons.remove(reason);
    if (paused == wasPaused) return;
    for (final timer in _timers.toList()) {
      paused ? timer._pause() : timer._resume();
    }
    notifyListeners();
  }

  PresentationTimer schedule(Duration delay, VoidCallback callback) {
    final timer = PresentationTimer._(this, delay, callback);
    _timers.add(timer);
    if (!paused) timer._resume();
    return timer;
  }

  @override
  void dispose() {
    for (final timer in _timers.toList()) {
      timer.cancel();
    }
    super.dispose();
  }
}

/// 중단 시간은 차감하지 않는 취소 가능한 단발성 타이머입니다.
class PresentationTimer {
  PresentationTimer._(this._clock, this._remaining, this._callback);
  final GamePresentationClock _clock;
  final VoidCallback _callback;
  Duration _remaining;
  DateTime? _started;
  Timer? _timer;
  bool _active = true;

  void _resume() {
    if (!_active) return;
    _started = _clock._now();
    _timer = Timer(_remaining.isNegative ? Duration.zero : _remaining, () {
      cancel();
      _callback();
    });
  }

  void _pause() {
    _timer?.cancel();
    final started = _started;
    if (started != null) _remaining -= _clock._now().difference(started);
    _started = null;
  }

  void cancel() {
    _active = false;
    _timer?.cancel();
    _clock._timers.remove(this);
  }
}

/// 게임 화면의 공용 중단 경계. 네트워크 단절·백그라운드·게임 중단을 합칩니다.
/// 연결 복구는 transport 기준이며 참가 자격/스냅샷 복원은 플랫폼 책임입니다.
class GamePresentationBoundary extends StatefulWidget {
  const GamePresentationBoundary({
    super.key,
    required this.clock,
    required this.connectionChanges,
    required this.interrupted,
    required this.child,
  });
  final GamePresentationClock clock;
  final Stream<bool> connectionChanges;
  final bool interrupted;
  final Widget child;

  static GamePresentationClock? clockOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_PresentationScope>()?.clock;

  @override
  State<GamePresentationBoundary> createState() =>
      _GamePresentationBoundaryState();
}

class _GamePresentationBoundaryState extends State<GamePresentationBoundary>
    with WidgetsBindingObserver {
  final _network = Object(), _lifecycle = Object(), _interruption = Object();
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.clock.setPaused(_interruption, widget.interrupted);
    final state = WidgetsBinding.instance.lifecycleState;
    widget.clock.setPaused(
      _lifecycle,
      state != null && state != AppLifecycleState.resumed,
    );
    _listen();
  }

  void _listen() {
    _subscription = widget.connectionChanges.listen(
      (connected) => widget.clock.setPaused(_network, !connected),
      onError: (Object _) => widget.clock.setPaused(_network, true),
    );
  }

  @override
  void didUpdateWidget(GamePresentationBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      identical(oldWidget.clock, widget.clock),
      'Clock belongs to the board lifetime.',
    );
    widget.clock.setPaused(_interruption, widget.interrupted);
    if (!identical(oldWidget.connectionChanges, widget.connectionChanges)) {
      _subscription?.cancel();
      _listen();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      widget.clock.setPaused(_lifecycle, state != AppLifecycleState.resumed);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _PresentationScope(clock: widget.clock, child: widget.child);
}

class _PresentationScope extends InheritedWidget {
  const _PresentationScope({required this.clock, required super.child});
  final GamePresentationClock clock;
  @override
  bool updateShouldNotify(_PresentationScope oldWidget) =>
      oldWidget.clock != clock;
}

/// 연출 위젯에서 Timer 대신 presentationTimer를 사용합니다.
/// TickerMode만 끄면 복귀 시 애니메이션 시간이 건너뛰므로 실제 재생도 멈춥니다.
mixin GamePresentationState<T extends StatefulWidget> on State<T> {
  final _localClock = GamePresentationClock();
  final _scheduled = <PresentationTimer>[];
  final _stopped = <AnimationController, AnimationStatus>{};
  GamePresentationClock? _clock;
  Iterable<AnimationController> get presentationAnimations => const [];
  Iterable<AnimationController> get repeatingPresentationAnimations => const [];

  PresentationTimer presentationTimer(
    Duration duration,
    VoidCallback callback,
  ) {
    final clock = GamePresentationBoundary.clockOf(context) ?? _localClock;
    late final PresentationTimer timer;
    timer = clock.schedule(duration, () {
      _scheduled.remove(timer);
      if (mounted) callback();
    });
    _scheduled.add(timer);
    return timer;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final clock = GamePresentationBoundary.clockOf(context) ?? _localClock;
    if (identical(clock, _clock)) return;
    _clock?.removeListener(_syncPlayback);
    _clock = clock..addListener(_syncPlayback);
    for (final animation in presentationAnimations) {
      animation.addStatusListener(_onAnimationStatus);
    }
    _syncPlayback();
  }

  void _onAnimationStatus(AnimationStatus _) {
    if (_clock?.paused ?? false) _syncPlayback();
  }

  void _syncPlayback() {
    if (_clock?.paused ?? false) {
      for (final animation in presentationAnimations) {
        if (animation.isAnimating) {
          _stopped[animation] = animation.status;
          animation.stop(canceled: false);
        }
      }
    } else {
      final stopped = Map.of(_stopped);
      _stopped.clear();
      for (final entry in stopped.entries) {
        if (repeatingPresentationAnimations.contains(entry.key)) {
          entry.key.repeat();
        } else if (entry.value == AnimationStatus.reverse) {
          entry.key.reverse();
        } else {
          entry.key.forward();
        }
      }
    }
  }

  @override
  void dispose() {
    _clock?.removeListener(_syncPlayback);
    for (final timer in _scheduled) {
      timer.cancel();
    }
    _localClock.dispose();
    // AnimationController는 소유 State에서 dispose하므로 여기서 재접근하지 않습니다.
    super.dispose();
  }
}
