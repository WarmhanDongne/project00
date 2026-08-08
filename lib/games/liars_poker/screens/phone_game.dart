import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';
import 'package:project00/games/liars_poker/screens/phone_game_landscape.dart';
import 'package:project00/games/liars_poker/screens/phone_game_portrait.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';

/// 기기 방향과 관계없이 하나의 Firebase 구독 컨트롤러를 유지합니다.
class PhoneGame extends StatefulWidget {
  const PhoneGame({
    super.key,
    required this.roomCode,
    required this.gameService,
  });

  final String roomCode;
  final LiarsPokerService gameService;

  @override
  State<PhoneGame> createState() => _PhoneGameState();
}

class _PhoneGameState extends State<PhoneGame> {
  PhoneGameController? _controller;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _initializationError = '게임에 참여하려면 사용자 인증이 필요합니다.';
      return;
    }

    _controller = PhoneGameController(
      roomCode: widget.roomCode,
      uid: uid,
      gameService: widget.gameService,
    )..initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _initializationError ?? '게임을 초기화하지 못했습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 17),
            ),
          ),
        ),
      );
    }

    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return PhoneGamePortrait(controller: controller);
        }
        return PhoneGameLandscape(controller: controller);
      },
    );
  }
}
