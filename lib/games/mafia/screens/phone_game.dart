import 'package:flutter/material.dart';
import 'package:project00/games/mafia/animations/role_card_reveal_animation.dart';
import 'package:project00/games/mafia/widgets/phone_top_bar.dart';
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
          Positioned.fill(child: DeadScreen()),
          // Positioned.fill(child: FreeTalk()),
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
    return MafiaPhoneTopBar(isMorning: isMorning);
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

class DeadScreen extends StatelessWidget {
  const DeadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        // 플레이어 3명이 딱 들어가는 너비
        width: 250,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "관전자 정보",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              "이제 모든 플레이어의 신분을 확인할 수 있습니다.\n확인한 정보는 게임이 끝날 때까지 비밀로 유지하세요.",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),

            Row(
              children: const [
                Player(),
                SizedBox(width: 5),
                Player(),
                SizedBox(width: 5),
                Player(),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: const [
                Player(),
                SizedBox(width: 5),
                Player(),
                SizedBox(width: 5),
                Player(),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: const [
                Player(),
                SizedBox(width: 5),
                Player(),
                SizedBox(width: 5),
                Player(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Player extends StatelessWidget {
  const Player({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: Assets.games.mafia.images.cards.roleCitizen.image(
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        const SizedBox(height: 6),
        const Text("맥도날드", style: TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
