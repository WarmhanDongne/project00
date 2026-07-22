import 'package:flutter/material.dart';
import 'package:project00/platform/router/route_names.dart';

class GameDetailScreen extends StatelessWidget {
  const GameDetailScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Liar's Bar")),
    body: Center(
      child: FilledButton(
        onPressed: () => Navigator.pushNamed(context, RouteNames.liarsBarRoom),
        child: const Text('게임 시작'),
      ),
    ),
  );
}
