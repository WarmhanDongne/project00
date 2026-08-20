import 'dart:async';
import 'package:project00/core/time/server_clock.dart';

import 'package:flutter/material.dart';

class PhoneTimer extends StatefulWidget {
  const PhoneTimer({super.key, required this.expiresAt, this.onTimeout});

  final int expiresAt;
  final VoidCallback? onTimeout;

  @override
  State<PhoneTimer> createState() => _PhoneTimerState();
}

class _PhoneTimerState extends State<PhoneTimer> {
  static const _refreshInterval = Duration(seconds: 1);

  Timer? _timer;
  bool _hasFiredTimeout = false;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = _calculateRemaining();
    _startTimer();
  }

  @override
  void didUpdateWidget(PhoneTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expiresAt != oldWidget.expiresAt) {
      _hasFiredTimeout = false;
      _updateRemaining();
      _startTimer();
    }
  }

  /// 남은 시간과 무관하게 항상 주기 타이머를 유지합니다.
  ///
  /// 마운트 시점에 ServerClock 보정이 아직 도착하지 않아 남은 시간이 0으로
  /// 계산되면, 예전에는 타이머가 생성되지 않아 화면이 00.00에 고착되고
  /// onTimeout도 영원히 발화하지 않았습니다. 타이머를 계속 돌리면 보정이
  /// 도착하는 즉시 실제 남은 시간으로 스스로 복구됩니다.
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_refreshInterval, (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final nextRemaining = _calculateRemaining();

    if (nextRemaining <= Duration.zero) {
      // 서버 시각 보정 전의 0은 기기 시계 오차일 수 있으므로 자동 행동을
      // 확정하지 않습니다. 보정이 도착하면 다음 tick에서 판정합니다.
      if (!_hasFiredTimeout && ServerClock.hasSynced) {
        _hasFiredTimeout = true;
        final onTimeout = widget.onTimeout;
        if (onTimeout != null) {
          // didUpdateWidget(빌드 도중) 경로에서 부모 상태 변경이 일어나지
          // 않도록 현재 빌드가 끝난 뒤 호출합니다.
          Future<void>.microtask(() {
            if (mounted) onTimeout();
          });
        }
      }
      if (_remaining != Duration.zero) {
        setState(() {
          _remaining = Duration.zero;
        });
      }
    } else {
      // 뒤늦게 도착한 시계 보정으로 만료가 취소되면 타임아웃도 다시 무장합니다.
      _hasFiredTimeout = false;
      if (nextRemaining.inSeconds == _remaining.inSeconds) {
        return;
      }
      setState(() {
        _remaining = nextRemaining;
      });
    }
  }

  Duration _calculateRemaining() {
    final now = ServerClock.nowMillis();
    final remainingMillis = widget.expiresAt - now;
    return Duration(milliseconds: remainingMillis.clamp(0, 1 << 31));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    final isUrgent = _remaining <= const Duration(seconds: 10);

    final formattedMinutes = minutes.toString().padLeft(2, '0');
    final formattedSeconds = seconds.toString().padLeft(2, '0');

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isUrgent ? const Color(0xFF2A1010) : const Color(0xFF0F1B14),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isUrgent ? const Color(0xFFB83434) : Colors.black,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isUrgent ? const Color(0x665E0D0D) : Colors.black54,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: TextStyle(
            fontFamily: 'DigitalTimer',
            color: isUrgent ? const Color(0xFFFF4B4B) : const Color(0xFF5CE3A6),
            fontSize: 28,
            height: 1.1,
            letterSpacing: 2.0,
          ),
          child: Text(
            '$formattedMinutes.$formattedSeconds',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
