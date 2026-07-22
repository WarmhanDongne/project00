import 'package:flutter/material.dart';

class GameCategoryChip extends StatelessWidget {
  const GameCategoryChip({
    required this.label,
    this.selected = false,
    super.key,
  });
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) =>
      FilterChip(label: Text(label), selected: selected, onSelected: (_) {});
}
