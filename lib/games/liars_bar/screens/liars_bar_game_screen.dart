import 'package:flutter/material.dart';
import 'package:project00/games/liars_bar/widgets/card_hand_widget.dart';
import 'package:project00/games/liars_bar/widgets/liar_call_button.dart';

class LiarsBarGameScreen extends StatelessWidget {
  const LiarsBarGameScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Liar's Bar")),
    body: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CardHandWidget(cardCount: 5),
        SizedBox(height: 24),
        LiarCallButton(),
      ],
    ),
  );
}
