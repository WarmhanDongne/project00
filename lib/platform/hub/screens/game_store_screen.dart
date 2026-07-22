import 'package:flutter/material.dart';
import 'package:project00/platform/hub/widgets/game_card.dart';
import 'package:project00/platform/router/route_names.dart';

class GameStoreScreen extends StatelessWidget {
  const GameStoreScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('게임 스토어')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GameCard(
          title: "Liar's Bar",
          onTap: () => Navigator.pushNamed(context, RouteNames.gameDetail),
        ),
      ],
    ),
  );
}
