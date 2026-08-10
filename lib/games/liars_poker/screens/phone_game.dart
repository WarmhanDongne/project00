import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_landscape.dart';
import 'package:project00/games/liars_poker/widgets/phone/spectator_portrait.dart';
import 'package:project00/games/liars_poker/widgets/phone/spectator_landscape.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_portrait.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';

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

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // 가장 권장되는 방식: 기기 화면의 방향을 직접 구독
        // 화면이 회전될 때마다 플러터가 알아서 이 빌더를 다시 호출합니다.
        final orientation = MediaQuery.of(context).orientation;
        final isAlive = !controller.isEliminated;

        // 가드 클로즈: 살아있을 때 (게임 진행 중) 화면 우선 반환
        if (isAlive) {
          final gameScreen = orientation == Orientation.landscape
              ? PhoneGameLandscape(controller: controller)
              : PhoneGamePortrait(controller: controller);

          return Stack(
            fit: StackFit.expand,
            children: [
              gameScreen,
              if (controller.isCommandInFlight)
                const _CommandLoadingIndicator(),
            ],
          );
        }

        // 관전 모드: 죽은 상태 (isAlive == false)
        final survivors = controller.players.values
            .where((p) => p.status != 'eliminated')
            .toList();

        final survivorPlayers = survivors
            .map(
              (p) => PlayerLayoutPlayer(
                uid: p.uid,
                nickname: p.nickname,
                profileImageUrl: p.profileImageUrl, // 실제 프로필 이미지 연결
                seatIndex: 0,
              ),
            )
            .toList();

        if (orientation == Orientation.landscape) {
          return SpectatorLandscape(players: survivorPlayers);
        }

        return SpectatorPortrait(players: survivorPlayers);
      },
    );
  }
}

/// 서버 재요청 중 게임 화면을 가리지 않고 연결 상태만 작게 표시합니다.
class _CommandLoadingIndicator extends StatelessWidget {
  const _CommandLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: IgnorePointer(
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xB818211C),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x338CA695)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: Color(0xFFD8E2DB),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '연결 확인 중',
                      style: TextStyle(
                        color: Color(0xFFD8E2DB),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
