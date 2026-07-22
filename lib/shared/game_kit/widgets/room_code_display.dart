import 'package:flutter/material.dart';

class RoomCodeDisplay extends StatelessWidget {
  const RoomCodeDisplay({required this.code, super.key});
  final String code;
  @override
  Widget build(BuildContext context) =>
      SelectableText(code, style: Theme.of(context).textTheme.headlineMedium);
}
