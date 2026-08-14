import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/final_call/providers/final_call_game_state.dart';
import 'package:project00/games/final_call/providers/final_call_session_provider.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_controller.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_animation.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_layer.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_overlay.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/final_call/widgets/tablet/tablet_result_overlay.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// Final Call 태블릿 진행 화면의 진입점입니다.
class FinalCallTabletGame extends ConsumerStatefulWidget {
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
  ConsumerState<FinalCallTabletGame> createState() =>
      _FinalCallTabletGameState();
}

class _FinalCallTabletGameState extends ConsumerState<FinalCallTabletGame> {
  PhoneGameController? controller;
  FinalCallSessionArgs? sessionArgs;
  ProviderSubscription<FinalCallGameState>? sessionSubscription;
  String? initializationError;
  String? previousPhase;
  Timer? phaseTimer;
  Timer? turnTimer;
  int? scheduledDeadline;
  int? completedRevealRound;
  bool resultRevealSignalInFlight = false;
  Timer? insufficientPlayersExitTimer;

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
    final args = FinalCallSessionArgs(
      roomCode: widget.roomCode,
      uid: uid,
      service: widget.service,
      watchPrivateHand: false,
    );
    sessionArgs = args;
    final provider = finalCallSessionProvider(args);
    sessionSubscription = ref.listenManual(provider, (_, _) {
      _handleState();
    });
    controller = ref.read(provider.notifier);
  }

  void _handleState() {
    final game = controller;
    if (game == null || !mounted) return;
    final enteredPhase = previousPhase != game.phase;
    previousPhase = game.phase;

    if (game.isFinished && game.finishReason == 'insufficientPlayers') {
      turnTimer?.cancel();
      phaseTimer?.cancel();
      insufficientPlayersExitTimer ??= Timer(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).maybePop();
      });
      setState(() {});
      return;
    }

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

    if (enteredPhase && game.phase != 'roundResult') phaseTimer?.cancel();

    // 라운드 공개 없이 승자가 결정된 경우에는 태블릿 결과 화면이 즉시
    // 준비되므로 같은 시점에 휴대폰 결과 화면도 해제합니다.
    if (game.isFinished &&
        game.roundResult == null &&
        game.resultRevealCompletedAt == null &&
        !resultRevealSignalInFlight) {
      resultRevealSignalInFlight = true;
      unawaited(
        game.completeResultReveal().whenComplete(() {
          resultRevealSignalInFlight = false;
        }),
      );
    }
  }

  //=======================공개 연출 완료 후 다음 라운드==============================
  // 카드 순차 공개와 최하위 생명 소멸이 모두 끝난 뒤에만 다음 라운드를
  // 시작합니다. 고정 타이머로 연출 중 화면이 바뀌는 문제를 막습니다.
  void _handleRoundRevealCompleted() {
    final game = controller;
    if (game == null ||
        game.roundResult == null ||
        completedRevealRound == game.round) {
      return;
    }
    completedRevealRound = game.round;
    setState(() {});
    if (game.isFinished) {
      unawaited(game.completeResultReveal());
      return;
    }
    if (game.phase != 'roundResult') return;
    phaseTimer?.cancel();
    phaseTimer = Timer(const Duration(milliseconds: 900), () async {
      if (!mounted || controller?.phase != 'roundResult') return;
      await controller?.nextRound();
    });
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
    insufficientPlayersExitTimer?.cancel();
    sessionSubscription?.close();
    //=======================플랫폼 세로 화면 복원==============================
    unawaited(AppOrientation.lockPlatformPortrait());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = sessionArgs;
    if (args != null) ref.watch(finalCallSessionProvider(args));
    final game = args == null
        ? null
        : ref.read(finalCallSessionProvider(args).notifier);
    controller = game;
    if (game == null) {
      return Scaffold(
        body: Center(child: Text(initializationError ?? '게임을 열 수 없습니다.')),
      );
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          //============================================배경============================================
          Assets.games.finalCall.images.background.background.image(
            fit: BoxFit.cover,
          ),
          //============================================게임 카드============================================
          if (!game.loading)
            FinalCallTabletGameLayer(
              controller: game,
              onRoundRevealCompleted: _handleRoundRevealCompleted,
            ),
          if (!game.loading)
            FinalCallTabletCallAnimation(
              controller: game,
              playerCount: game.players.length,
            ),
          if (!game.loading &&
              game.roundResult == null &&
              game.discardEvent != null)
            FinalCallTabletDiscardAnimation(
              key: ValueKey('discard-${game.discardEvent!.version}'),
              controller: game,
              event: game.discardEvent!,
              playerCount: game.players.length,
            ),
          //=======================우측 상단 사이드바==============================
          FinalCallTabletGameOverlay(
            provider: widget.provider,
            visible: !game.loading && !game.isFinished,
            onRestartGame: _restartGame,
            onEndGame: _endGame,
          ),
          if (game.isFinished &&
              game.finishReason != 'insufficientPlayers' &&
              (game.roundResult == null || completedRevealRound == game.round))
            FinalCallResultOverlay(
              winner: game.players[game.winnerUid],
              onRestart: () => game.restartGame(),
              onHome: () => unawaited(_returnHomeAfterResult()),
            ),
          if (game.isFinished && game.finishReason == 'insufficientPlayers')
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        '인원 부족으로 게임을 종료합니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
  }
}
