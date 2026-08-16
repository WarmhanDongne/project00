import 'dart:async';
import 'package:project00/games/shared/widgets/connection_banner.dart';
import 'package:project00/core/time/server_clock.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/final_call/providers/final_call_game_state.dart';
import 'package:project00/games/final_call/providers/final_call_session_provider.dart';
import 'package:project00/games/final_call/controllers/final_call_controller.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_animation.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_layer.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_overlay.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/final_call/widgets/tablet/result_overlay.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/widgets/game_announcement_layer.dart';
import 'package:project00/games/shared/widgets/game_interruption_layer.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// Final Call 태블릿 진행 화면의 진입점입니다.
class FinalCallTabletGame extends ConsumerStatefulWidget {
  const FinalCallTabletGame({
    super.key,
    required this.roomCode,
    required this.gameService,
    required this.provider,
  });

  final String roomCode;
  final FinalCallService gameService;
  final RoomProvider provider;

  @override
  ConsumerState<FinalCallTabletGame> createState() =>
      _FinalCallTabletGameState();
}

class _FinalCallTabletGameState extends ConsumerState<FinalCallTabletGame> {
  FinalCallController? controller;
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

  /// 설정에서 게임 종료를 누른 뒤 홈으로 나가는 중인지 여부입니다.
  bool isEndingGame = false;

  @override
  void initState() {
    super.initState();
    //=======================태블릿 게임 방향 불변 조건==============================
    // 게임 종류와 관계없이 모든 태블릿 게임은 항상 가로 고정입니다.
    // 휴대폰 게임별 방향 정책을 이 화면에 적용하지 마세요.
    unawaited(AppOrientation.lockTabletGameLandscape());
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      initializationError = '게임 진행 기기 인증을 확인할 수 없습니다.';
      return;
    }
    final args = FinalCallSessionArgs(
      roomCode: widget.roomCode,
      uid: uid,
      service: widget.gameService,
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

    if (game.isFinished &&
        (game.finishReason == 'insufficientPlayers' ||
            game.finishReason == 'interruptionVoteExpired')) {
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
        milliseconds: (deadline - ServerClock.nowMillis()).clamp(0, 30000),
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
    if (isEndingGame) return;
    //=======================설정에서 게임 종료==============================
    // endGame이 서버 상태를 finished로 바꾸는 사이 결과 화면이 잠깐 떴다가
    // 사라졌습니다. Liar's Poker처럼 결과를 거치지 않고 바로 홈으로 나가도록
    // 종료 처리 중에는 결과 화면을 그리지 않습니다.
    setState(() => isEndingGame = true);
    final ended = await controller?.endGame() ?? false;
    if (!mounted) return;
    if (!ended) {
      setState(() => isEndingGame = false);
      return;
    }
    //=======================게임 노드 정리는 선택 사항==============================
    // clearGame은 방을 남긴 채 game 노드만 지우는 뒷정리입니다. 서버가
    // `status == finished`를 아직 못 읽는 등으로 실패할 수 있는데, 그때
    // 화면 전환까지 막으면 결과 화면에 갇힙니다. Liar's Poker는 endGame만
    // 하고 바로 복귀하므로, 정리 실패는 무시하고 동일하게 홈으로 나갑니다.
    await controller?.clearGame();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _returnHomeAfterResult() async {
    // 결과 화면의 홈 버튼도 정리 실패로 막히지 않아야 합니다.
    await controller?.clearGame();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  FinalCallTabletStage _resolveStage(FinalCallController game) {
    if (game.loading) return FinalCallTabletStage.connecting;
    if (game.isFinished &&
        (game.finishReason == 'insufficientPlayers' ||
            game.finishReason == 'interruptionVoteExpired')) {
      return FinalCallTabletStage.closing;
    }
    if (game.roundResult != null && completedRevealRound != game.round) {
      return FinalCallTabletStage.roundResult;
    }
    if (game.isFinished) return FinalCallTabletStage.result;
    if (game.phase == 'dealing') return FinalCallTabletStage.dealing;
    // 공개 연출이 끝난 뒤 nextRound 명령이 반영되기 전까지 roundResult 화면을
    // 그대로 유지합니다. 이 구간을 playing으로 되돌리면 중앙 카드 공개
    // 애니메이션이 다시 마운트되어 카드 한 장을 더 뒤집는 것처럼 보입니다.
    if (game.phase == 'roundResult') return FinalCallTabletStage.roundResult;
    return FinalCallTabletStage.playing;
  }

  @override
  void dispose() {
    phaseTimer?.cancel();
    turnTimer?.cancel();
    insufficientPlayersExitTimer?.cancel();
    sessionSubscription?.close();
    //=======================플랫폼 가로 화면 복원==============================
    unawaited(AppOrientation.lockPlatformLandscape());
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
    final stage = _resolveStage(game);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          //============================================배경============================================
          Assets.games.finalCall.images.background.background.image(
            fit: BoxFit.cover,
          ),
          //============================================게임 카드============================================
          if (stage != FinalCallTabletStage.connecting)
            FinalCallTabletGameLayer(
              controller: game,
              stage: stage,
              onRoundRevealCompleted: _handleRoundRevealCompleted,
            ),
          if (stage == FinalCallTabletStage.playing)
            FinalCallTabletCallAnimation(
              controller: game,
              playerCount: game.players.length,
            ),
          if (stage == FinalCallTabletStage.playing &&
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
            visible:
                stage != FinalCallTabletStage.connecting &&
                stage != FinalCallTabletStage.result &&
                stage != FinalCallTabletStage.closing,
            onRestartGame: _restartGame,
            onEndGame: _endGame,
          ),
          if (!isEndingGame && stage == FinalCallTabletStage.result)
            FinalCallResultOverlay(
              winner: game.players[game.winnerUid],
              onRestart: () => game.restartGame(),
              onHome: () => unawaited(_returnHomeAfterResult()),
            ),
          Positioned.fill(
            child: GameAnnouncementLayer(
              announcement: switch (stage) {
                FinalCallTabletStage.connecting => GameAnnouncement.persistent(
                  id: 'final-call-preparing',
                  text: GameFlowCopy.preparingGame,
                ),
                FinalCallTabletStage.closing => GameAnnouncement.persistent(
                  id: 'insufficient-players',
                  text: game.finishReason == 'interruptionVoteExpired'
                      ? GameFlowCopy.interruptionVoteExpired
                      : GameFlowCopy.insufficientPlayers,
                  blocksInteraction: true,
                  showScrim: true,
                ),
                _ => null,
              },
              style: const GameAnnouncementStyle(
                fontFamily: null,
                fontSize: 28,
                gameStartFontSize: 58,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                shadows: [Shadow(color: Colors.black, blurRadius: 12)],
              ),
            ),
          ),
          const ConnectionBanner(),
          GameInterruptionLayer(
            interruption: game.interruption,
            currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
            isSubmitting: game.commandInFlight,
            onExpired: () async {
              await game.expireInterruption();
            },
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
