import 'package:flutter/material.dart';

class GameCard extends StatelessWidget {
  const GameCard({required this.title, required this.onTap, super.key});
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.casino_outlined),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
