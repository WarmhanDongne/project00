import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';
import 'package:project00/games/liars_poker/screens/phone_game_landscape.dart';
import 'package:project00/games/liars_poker/widgets/phone/spectator_portrait.dart';
import 'package:project00/games/liars_poker/widgets/phone/spectator_landscape.dart';
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
    // 💡 가장 권장되는 방식: 기기 화면의 방향을 직접 구독(Subscribe)
    // 화면이 회전될 때마다 플러터가 알아서 이 build 함수를 다시 호출합니다.
    final orientation = MediaQuery.of(context).orientation;

    final isAlive = true;

    final List<String> dummySurvivors = [
      '맥도날드 감자튀김 도둑',
      '김하준',
      '윤유원',
      '배워서 남주자',
    ];

    if (isAlive == false && orientation == Orientation.portrait) {
      return SpectatorPortrait(survivors: dummySurvivors);
    } else if (isAlive == false && orientation == Orientation.landscape) {
      return SpectatorLandscape(survivors: dummySurvivors);
    }

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
