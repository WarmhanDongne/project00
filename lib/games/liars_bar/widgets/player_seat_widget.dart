import 'package:flutter/material.dart';

class PlayerSeatWidget extends StatelessWidget {
  const PlayerSeatWidget({
    required this.name,
    this.isCurrentTurn = false,
    super.key,
  });
  final String name;
  final bool isCurrentTurn;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(isCurrentTurn ? Icons.play_arrow : Icons.person),
    label: Text(name),
  );
}
