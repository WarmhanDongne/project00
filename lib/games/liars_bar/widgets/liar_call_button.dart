import 'package:flutter/material.dart';

class LiarCallButton extends StatelessWidget {
  const LiarCallButton({this.onPressed, super.key});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) =>
      FilledButton.tonal(onPressed: onPressed, child: const Text('거짓말이야!'));
}
