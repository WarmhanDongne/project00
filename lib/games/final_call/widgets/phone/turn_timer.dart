import 'dart:async';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/games/shared/sound/countdown_tick_cue.dart';

import 'package:flutter/material.dart';

class FinalCallTimer extends StatefulWidget {
  const FinalCallTimer({super.key, required this.deadline, this.onTimeout});
  final int deadline;
  final VoidCallback? onTimeout;

  @override
  State<FinalCallTimer> createState() => _FinalCallTimerState();
}

class _FinalCallTimerState extends State<FinalCallTimer> {
  Timer? _timer;
  bool _didNotifyTimeout = false;

  /// 마지막 5초 초읽기 소리입니다. 이 위젯은 내 턴에만 그려지므로, 소리도
  /// 지금 행동해야 하는 사람의 기기에서만 납니다.
  final CountdownTickCue _tickCue = CountdownTickCue();

  int get seconds =>
      (ServerClock.remainingUntil(widget.deadline).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 30);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _notifyTimeoutIfNeeded();
    });
    _tickCue.schedule(widget.deadline);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickCue.attach(context);
  }

  @override
  void didUpdateWidget(covariant FinalCallTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      _didNotifyTimeout = false;
      _tickCue.schedule(widget.deadline);
    }
  }

  void _notifyTimeoutIfNeeded() {
    if (seconds > 0) {
      // 뒤늦게 도착한 시계 보정으로 만료가 취소되면 타임아웃도 다시 무장합니다.
      _didNotifyTimeout = false;
      return;
    }
    // 서버 시각 보정 전의 0은 기기 시계 오차일 수 있으므로 자동 행동을
    // 확정하지 않습니다. 보정이 도착하면 다음 tick에서 판정합니다.
    // (라이어스 포커 PhoneTimer와 같은 규칙입니다.)
    if (_didNotifyTimeout || !ServerClock.hasSynced) return;
    _didNotifyTimeout = true;
    widget.onTimeout?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // 제한시간 전에 행동을 마치면 이 위젯이 사라집니다. 초읽기도 그때 멈춰야
    // 다음 사람 차례까지 소리가 이어지지 않습니다.
    _tickCue.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    '00:${seconds.toString().padLeft(2, '0')}',
    style: TextStyle(
      fontFamily: 'DigitalTimer',
      color: seconds <= 10 ? Colors.red : Colors.black87,
      fontSize: 28,
      fontWeight: FontWeight.w700,
    ),
  );
}
