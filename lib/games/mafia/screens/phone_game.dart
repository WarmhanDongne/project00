import 'package:flutter/material.dart';
import 'package:project00/games/mafia/animations/role_card_reveal_animation.dart';
import 'package:project00/games/mafia/widgets/sideblock_phone.dart';
import 'package:project00/gen/assets.gen.dart';

final bool isMorning = true;

class MafiaPhoneGame extends StatelessWidget {
  const MafiaPhoneGame({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: _GameBackground()),
          Positioned.fill(child: Header()),

          Positioned.fill(child: FreeTalk()),
          Positioned.fill(
            child: RoleCardRevealAnimation(
              backCardAsset: Assets.games.mafia.images.cards.roleBack,
              frontCardAsset: Assets.games.mafia.images.cards.roleCitizen,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameBackground extends StatelessWidget {
  const _GameBackground();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: isMorning
          ? Assets.games.mafia.images.background.backgroundMorningPhone.image(
              fit: BoxFit.cover,
              alignment: Alignment.center,
            )
          : Assets.games.mafia.images.background.backgroundNightPhone.image(
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
    );
  }
}

class Header extends StatefulWidget {
  const Header({super.key});

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  @override
  Widget build(BuildContext context) {
    return SideBlock(isMorning: isMorning);
  }
}

class Body extends StatefulWidget {
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class FreeTalk extends StatelessWidget {
  const FreeTalk({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "자유토론",
            style: TextStyle(fontSize: 50, fontWeight: FontWeight.w900),
          ),
          Text(
            "2m 30s",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          Assets.games.mafia.images.other.talkPhone.image(
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),

          FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: const Size(240, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text("토론 종료하기"),
          ),
        ],
      ),
    );
  }
}
