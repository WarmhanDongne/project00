import 'package:flutter/material.dart';
import 'package:project00/games/mafia/widgets/sideblock_phone.dart';

final bool isMorning = false;

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
          ? Image.asset(
              'assets/games/mafia/images/background/background_morning_phone.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            )
          : Image.asset(
              'assets/games/mafia/images/background/background_night_phone.png',
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
    return Container(child: SideBlock(isMorning:isMorning));
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

class RoleCard extends StatefulWidget {
  const RoleCard({super.key});

  @override
  State<RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<RoleCard> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
