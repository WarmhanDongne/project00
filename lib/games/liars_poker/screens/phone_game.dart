import 'package:flutter/material.dart';
// import 'package:project00/games/liars_poker/models/player_layout_model.dart';
import 'package:project00/games/liars_poker/widgets/phone/hand_card_stack.dart';

class PhoneGame extends StatefulWidget {
  const PhoneGame({
    super.key,
    //required this.playerLayout
  });

  //final PlayerLayoutModel playerLayout;

  @override
  State<PhoneGame> createState() => _PhoneGameState();
}

class _PhoneGameState extends State<PhoneGame> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/games/liars_poker/images/background/phone_background.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),

          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(child: HandCardStack()),
          ),
        ],
      ),
    );
  }
}
