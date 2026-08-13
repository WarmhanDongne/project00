import 'dart:async';

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
  int get seconds =>
      ((widget.deadline - DateTime.now().millisecondsSinceEpoch) / 1000)
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
  }

  @override
  void didUpdateWidget(covariant FinalCallTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      _didNotifyTimeout = false;
    }
  }

  void _notifyTimeoutIfNeeded() {
    if (seconds > 0 || _didNotifyTimeout) return;
    _didNotifyTimeout = true;
    widget.onTimeout?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
