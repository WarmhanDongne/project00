// [connection_notice_host.dart] 는 서버 연결 알림 띠의 단계(끊김 → 다시 연결 중 → 복구)를 정하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 연결 상태 스트림을 듣고 띠 단계를 계산해 화면 아래에 띠를 얹음
//
// 즉, 로비 띠와 게임 LED 띠가 같은 시간표로 움직이게 하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:flutter/material.dart';

// ============================================================

/// 연결 알림 띠의 단계입니다.
enum ConnectionNoticePhase {
  /// 연결이 정상이라 띠가 없습니다.
  hidden,

  /// 연결이 끊긴 직후입니다.
  lost,

  /// 자동으로 다시 잇는 중입니다.
  reconnecting,

  /// 다시 연결됐습니다. 잠깐 보인 뒤 사라집니다.
  restored,
}

/// 띠를 그리는 함수입니다. [step]은 다시 연결 중일 때의 단계(1부터)입니다.
typedef ConnectionNoticeBuilder =
    Widget Function(
      BuildContext context,
      ConnectionNoticePhase phase,
      int step,
    );

/// 서버 연결 상태를 듣고 화면 맨 아래에 알림 띠를 얹습니다.
///
/// 1. 연결이 끊기고 [graceDelay] 동안 돌아오지 않으면 '끊김' 띠가 올라옵니다.
///    잠깐 흔들렸다 바로 돌아오면 띠를 띄우지 않습니다.
/// 2. [lostHold] 뒤에도 끊겨 있으면 '다시 연결 중' 띠로 바뀝니다.
/// 3. 연결이 돌아오면 '복구' 띠를 [restoredHold] 동안 보여 준 뒤 내려갑니다.
///
/// 다시 연결 중의 단계([ConnectionNoticeBuilder]의 `step`)는 앱의 재시도 간격
/// (1·2·4·8초)을 기준으로 **경과 시간에서 계산한 값**입니다. Firebase SDK가 내부에서
/// 실제로 몇 번 재시도했는지는 알 수 없습니다. 최대 [maxSteps]에서 멈춥니다.
class ConnectionNoticeHost extends StatefulWidget {
  const ConnectionNoticeHost({
    super.key,
    required this.child,
    required this.connectionChanges,
    required this.builder,
    this.graceDelay = const Duration(milliseconds: 1500),
    this.lostHold = const Duration(seconds: 3),
    this.restoredHold = const Duration(seconds: 1),
    this.maxSteps = 5,
  });

  final Widget child;

  /// 서버 연결 여부입니다(`.info/connected`). null이면 띠를 그리지 않습니다.
  final Stream<bool>? connectionChanges;
  final ConnectionNoticeBuilder builder;
  final Duration graceDelay;
  final Duration lostHold;
  final Duration restoredHold;
  final int maxSteps;

  /// 다시 연결 중 단계가 올라가는 시점입니다(다시 연결 중이 시작된 뒤 초).
  static const List<int> stepSeconds = [0, 1, 3, 7, 15];

  /// 다시 연결 중으로 바뀐 뒤 [elapsed]가 지났을 때의 단계입니다.
  static int stepFor(Duration elapsed, int maxSteps) {
    var step = 0;
    for (final seconds in stepSeconds) {
      if (elapsed.inMilliseconds >= seconds * 1000) step++;
    }
    return step.clamp(1, maxSteps);
  }

  @override
  State<ConnectionNoticeHost> createState() => _ConnectionNoticeHostState();
}

class _ConnectionNoticeHostState extends State<ConnectionNoticeHost> {
  StreamSubscription<bool>? _subscription;
  Timer? _timer;
  Timer? _stepTimer;
  ConnectionNoticePhase _phase = ConnectionNoticePhase.hidden;

  /// 내려가는 동안 마지막 띠 모양을 유지하려고 기억합니다.
  ConnectionNoticePhase _lastVisible = ConnectionNoticePhase.lost;

  /// 다시 연결 중이 된 뒤 지난 시간입니다. 0.5초마다 더합니다.
  Duration _reconnectingFor = Duration.zero;
  int _step = 1;

  /// 이번 끊김에서 띠를 실제로 보여 줬는지입니다. 안 보여 줬으면 복구 띠도 없습니다.
  bool _shownThisOutage = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(ConnectionNoticeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectionChanges != widget.connectionChanges) _subscribe();
  }

  void _subscribe() {
    unawaited(_subscription?.cancel());
    _timer?.cancel();
    _stopSteps();
    _shownThisOutage = false;
    _phase = ConnectionNoticePhase.hidden;
    final source = widget.connectionChanges;
    _subscription = source?.listen(
      (connected) {
        if (identical(widget.connectionChanges, source)) _handle(connected);
      },
      onError: (_) {
        if (identical(widget.connectionChanges, source)) _handle(false);
      },
    );
  }

  void _handle(bool connected) {
    if (!mounted) return;
    _timer?.cancel();
    if (connected) {
      _stopSteps();
      if (!_shownThisOutage) {
        _setPhase(ConnectionNoticePhase.hidden);
        return;
      }
      _shownThisOutage = false;
      _setPhase(ConnectionNoticePhase.restored);
      _timer = Timer(widget.restoredHold, () {
        if (mounted) _setPhase(ConnectionNoticePhase.hidden);
      });
      return;
    }
    // 이미 띠가 떠 있으면 단계를 처음으로 되돌리지 않습니다.
    if (_phase == ConnectionNoticePhase.lost ||
        _phase == ConnectionNoticePhase.reconnecting) {
      _scheduleReconnecting();
      return;
    }
    _timer = Timer(widget.graceDelay, () {
      if (!mounted) return;
      _shownThisOutage = true;
      _setPhase(ConnectionNoticePhase.lost);
      _scheduleReconnecting();
    });
  }

  void _scheduleReconnecting() {
    _timer?.cancel();
    if (_phase == ConnectionNoticePhase.reconnecting) return;
    _timer = Timer(widget.lostHold, () {
      if (!mounted) return;
      _reconnectingFor = Duration.zero;
      _step = 1;
      _setPhase(ConnectionNoticePhase.reconnecting);
      _stepTimer?.cancel();
      const tick = Duration(milliseconds: 500);
      _stepTimer = Timer.periodic(tick, (_) {
        if (!mounted) return;
        _reconnectingFor += tick;
        final step = ConnectionNoticeHost.stepFor(
          _reconnectingFor,
          widget.maxSteps,
        );
        if (step != _step) setState(() => _step = step);
      });
    });
  }

  void _stopSteps() {
    _stepTimer?.cancel();
    _stepTimer = null;
    _reconnectingFor = Duration.zero;
  }

  void _setPhase(ConnectionNoticePhase phase) {
    if (_phase == phase) return;
    setState(() {
      _phase = phase;
      if (phase != ConnectionNoticePhase.hidden) _lastVisible = phase;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stepTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _phase != ConnectionNoticePhase.hidden;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, 1.1),
              duration: const Duration(milliseconds: 280),
              curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                // 띠는 Scaffold 바깥에 얹힐 수 있어 Material을 깔아 글자 기본
                // 스타일(밑줄 없음)을 받게 합니다.
                child: Material(
                  type: MaterialType.transparency,
                  child: widget.builder(
                    context,
                    visible ? _phase : _lastVisible,
                    _step,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
