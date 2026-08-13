import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_controller.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_animation.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_layer.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_overlay.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/final_call/widgets/final_call_result.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// Final Call 아이패드 진행 화면의 진입점입니다.
class FinalCallTabletGame extends StatefulWidget {
  const FinalCallTabletGame({
    super.key,
    required this.roomCode,
    required this.service,
    required this.provider,
  });

  final String roomCode;
  final FinalCallService service;
  final RoomProvider provider;

  @override
  State<FinalCallTabletGame> createState() => _FinalCallTabletGameState();
}

class _FinalCallTabletGameState extends State<FinalCallTabletGame> {
  PhoneGameController? controller;
  String? initializationError;
  String? previousPhase;
  Timer? phaseTimer;
  Timer? turnTimer;
  int? scheduledDeadline;

  @override
  void initState() {
    super.initState();
    //=======================파이널 콜 가로 화면 고정==============================
    unawaited(AppOrientation.lockFinalCallLandscape());
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      initializationError = '게임 진행 기기 인증을 확인할 수 없습니다.';
      return;
    }
    controller =
        PhoneGameController(
            roomCode: widget.roomCode,
            uid: uid,
            gameService: widget.service,
            watchPrivateHand: false,
          )
          ..addListener(_handleState)
          ..initialize();
  }

  void _handleState() {
    final game = controller;
    if (game == null || !mounted) return;
    final enteredPhase = previousPhase != game.phase;
    previousPhase = game.phase;

    final deadline = game.turnDeadlineAt;
    if (deadline != null && deadline != scheduledDeadline) {
      scheduledDeadline = deadline;
      turnTimer?.cancel();
      final delay = Duration(
        milliseconds: (deadline - DateTime.now().millisecondsSinceEpoch).clamp(
          0,
          30000,
        ),
      );
      turnTimer = Timer(delay, () async {
        if (!mounted || controller?.turnDeadlineAt != deadline) return;
        await controller?.timeoutTurn();
      });
    }

    if (game.phase == 'roundResult' && enteredPhase) {
      phaseTimer?.cancel();
      phaseTimer = Timer(const Duration(seconds: 5), () async {
        if (!mounted || controller?.phase != 'roundResult') return;
        await controller?.nextRound();
      });
    }
  }

  //=======================설정 명령==============================
  void _restartGame() {
    unawaited(controller?.restartGame());
  }

  void _endGame() {
    unawaited(_endGameAndReturnToLobby());
  }

  Future<void> _endGameAndReturnToLobby() async {
    final ended = await controller?.endGame() ?? false;
    if (!mounted || !ended) return;
    final cleared = await controller?.clearGame() ?? false;
    if (!mounted || !cleared) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _returnHomeAfterResult() async {
    final cleared = await controller?.clearGame() ?? false;
    if (!mounted || !cleared) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    phaseTimer?.cancel();
    turnTimer?.cancel();
    controller
      ?..removeListener(_handleState)
      ..dispose();
    //=======================플랫폼 세로 화면 복원==============================
    unawaited(AppOrientation.lockPlatformPortrait());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = controller;
    if (game == null) {
      return Scaffold(
        body: Center(child: Text(initializationError ?? '게임을 열 수 없습니다.')),
      );
    }
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              //============================================배경============================================
              Assets.games.finalCall.images.background.background.image(
                fit: BoxFit.cover,
              ),
              //============================================게임 카드============================================
              if (!game.loading) FinalCallTabletGameLayer(controller: game),
              if (!game.loading)
                FinalCallTabletCallAnimation(
                  controller: game,
                  playerCount: game.players.length,
                ),
              //=======================우측 상단 사이드바==============================
              FinalCallTabletGameOverlay(
                provider: widget.provider,
                visible: !game.isFinished,
                onRestartGame: _restartGame,
                onEndGame: _endGame,
              ),
              if (game.isFinished)
                FinalCallResultOverlay(
                  winner: game.players[game.winnerUid],
                  onRestart: () => game.restartGame(),
                  onHome: () => unawaited(_returnHomeAfterResult()),
                ),
              if (game.commandInFlight)
                const Positioned(
                  right: 22,
                  bottom: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        );
      },
    );
  }
}
