import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/time/server_clock.dart';

//=======================남은 시간 세기==============================
/// 남은 시간을 **1초마다 다시 계산해** 넘겨 주는 위젯입니다.
///
/// 서버 상태(`turnDeadlineAt`)만 보고 화면을 그리면, 상태가 바뀌지 않는 동안
/// 화면이 다시 그려지지 않아 **타이머가 멈춘 것처럼 보입니다.** 실제로 마피아
/// 토론·투표 타이머가 그렇게 굳어 있었습니다(2026-08 수정).
///
/// 라이어스 포커의 `PhoneTimer`가 쓰던 방식을 그대로 가져왔습니다. 생김새는
/// 게임마다 달라 [builder]에 맡기고, 이 위젯은 **시간 계산만** 합니다.
///
/// 두 가지를 지킵니다.
///
/// 1. 기기 시계가 아니라 [ServerClock] 보정 시각으로 계산합니다.
/// 2. 남은 시간이 0이어도 **타이머를 멈추지 않습니다.** 붙는 순간 보정이 아직
///    도착하지 않아 0으로 계산될 수 있는데, 그때 타이머를 세우면 화면이 0에
///    굳고 [onTimeout]도 영원히 오지 않습니다.
class GameTurnCountdown extends StatefulWidget {
  const GameTurnCountdown({
    super.key,
    required this.expiresAt,
    required this.builder,
    this.onTimeout,
    this.nowMillis,
  });

  /// 마감 시각(서버 기준 밀리초)입니다. null이면 남은 시간도 null입니다.
  final int? expiresAt;

  /// 남은 시간을 받아 화면을 그립니다. 마감이 없으면 null이 옵니다.
  final Widget Function(BuildContext context, Duration? remaining) builder;

  /// 남은 시간이 0이 된 순간 한 번 호출됩니다.
  ///
  /// 서버 시계 보정이 도착한 뒤에만 호출합니다(기기 시계 오차로 일찍
  /// 넘어가지 않게).
  final VoidCallback? onTimeout;

  /// 지금 시각을 돌려줍니다. 기본값은 [ServerClock]입니다.
  ///
  /// **시험용 주입 지점입니다.** 위젯 테스트의 `pump`는 가짜 시계만 돌리고
  /// 실제 시계는 거의 흐르지 않아, 이 값을 바꿔 주지 않으면 시간이 가는
  /// 모습을 확인할 수 없습니다.
  final int Function()? nowMillis;

  @override
  State<GameTurnCountdown> createState() => _GameTurnCountdownState();
}

class _GameTurnCountdownState extends State<GameTurnCountdown> {
  static const Duration _refreshInterval = Duration(seconds: 1);

  Timer? _timer;
  bool _hasFiredTimeout = false;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _calculateRemaining();
    _startTimer();
  }

  @override
  void didUpdateWidget(GameTurnCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expiresAt != oldWidget.expiresAt) {
      _hasFiredTimeout = false;
      _remaining = _calculateRemaining();
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_refreshInterval, (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final next = _calculateRemaining();

    if (next != null && next <= Duration.zero) {
      // 보정 전의 0은 기기 시계 오차일 수 있어 확정하지 않습니다.
      if (!_hasFiredTimeout && ServerClock.hasSynced) {
        _hasFiredTimeout = true;
        final onTimeout = widget.onTimeout;
        if (onTimeout != null) {
          // 빌드 도중 부모 상태가 바뀌지 않도록 이 프레임 뒤로 미룹니다.
          Future<void>.microtask(() {
            if (mounted) onTimeout();
          });
        }
      }
    } else {
      // 뒤늦게 도착한 보정으로 만료가 취소되면 다시 무장합니다.
      _hasFiredTimeout = false;
    }

    // 초 단위가 그대로면 다시 그리지 않습니다.
    if (next?.inSeconds == _remaining?.inSeconds) return;
    setState(() => _remaining = next);
  }

  Duration? _calculateRemaining() {
    final expiresAt = widget.expiresAt;
    if (expiresAt == null) return null;
    final now = (widget.nowMillis ?? ServerClock.nowMillis)();
    final remaining = expiresAt - now;
    return Duration(milliseconds: remaining.clamp(0, 1 << 31));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}
