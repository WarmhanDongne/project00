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
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(PhoneTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expiresAt != oldWidget.expiresAt) {
      _hasFiredTimeout = false;
      _updateRemaining();
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (_remaining <= Duration.zero) return;

    _timer = Timer.periodic(_refreshInterval, (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final nextRemaining = _calculateRemaining();

    if (nextRemaining <= Duration.zero) {
      _timer?.cancel();
      _timer = null;
      if (!_hasFiredTimeout) {
        _hasFiredTimeout = true;
        widget.onTimeout?.call();
      }
      if (_remaining != Duration.zero) {
        setState(() {
          _remaining = Duration.zero;
        });
      }
    } else {
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
