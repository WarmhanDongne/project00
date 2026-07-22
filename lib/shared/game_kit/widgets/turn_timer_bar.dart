import 'package:flutter/material.dart';

class TurnTimerBar extends StatelessWidget {
  const TurnTimerBar({required this.progress, super.key});
  final double progress;
  @override
  Widget build(BuildContext context) =>
      LinearProgressIndicator(value: progress.clamp(0, 1));
}
