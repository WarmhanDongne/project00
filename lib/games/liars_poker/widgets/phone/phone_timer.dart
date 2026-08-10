import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class PhoneTimer extends StatefulWidget {
  const PhoneTimer({
    super.key,
    required this.expiresAt,
    this.onTimeout,
  });

  final int expiresAt;
  final VoidCallback? onTimeout;

  @override
  State<PhoneTimer> createState() => _PhoneTimerState();
}

class _PhoneTimerState extends State<PhoneTimer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  bool _hasFiredTimeout = false;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _updateRemaining();
    if (_remaining > Duration.zero) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(PhoneTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expiresAt != oldWidget.expiresAt) {
      _hasFiredTimeout = false;
      _updateRemaining();
      if (_remaining > Duration.zero && !_ticker.isTicking) {
        _ticker.start();
      }
    }
  }

  void _onTick(Duration elapsed) {
    _updateRemaining();
  }

  void _updateRemaining() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMillis = widget.expiresAt - now;

    if (remainingMillis <= 0) {
      if (_ticker.isTicking) _ticker.stop();
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
      setState(() {
        _remaining = Duration(milliseconds: remainingMillis);
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    final milliseconds = (_remaining.inMilliseconds % 1000) ~/ 10;

    final formattedMinutes = minutes.toString().padLeft(2, '0');
    final formattedSeconds = seconds.toString().padLeft(2, '0');
    final formattedMillis = milliseconds.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B14), // Dark greenish black
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        '$formattedMinutes.$formattedSeconds.$formattedMillis',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'DigitalTimer',
          color: Color(0xFF5CE3A6),
          fontSize: 28,
          height: 1.1,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}
