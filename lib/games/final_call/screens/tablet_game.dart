import 'dart:async';
import 'package:project00/core/time/server_clock.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/games/final_call/final_call_flow_config.dart';
import 'package:project00/games/final_call/providers/final_call_game_state.dart';
import 'package:project00/games/final_call/providers/final_call_session_provider.dart';
import 'package:project00/games/final_call/controllers/final_call_controller.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_animation.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_layer.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_overlay.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/final_call/widgets/tablet/result_overlay.dart';
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
  Timer? closingExitTimer;

  /// 설정에서 게임 종료를 누른 뒤 홈으로 나가는 중인지 여부입니다.
  bool isEndingGame = false;

  @override
  void initState() {
    super.initState();
    // ========================================================================
    // 게임 진입 환경
    // ========================================================================
    // 태블릿은 게임 종류와 관계없이 가로·전체화면을 유지합니다. 이 설정을
    // 제거하면 저장된 좌석 좌표와 카드 이동 방향이 달라질 수 있습니다.
    unawaited(AppSystemUi.enterGameFullscreen());
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

    if (game.isFinished && !game.isNaturalResult) {
      turnTimer?.cancel();
      phaseTimer?.cancel();
      closingExitTimer ??= Timer(FinalCallFlowTiming.closingRouteDelay, () {
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

  // ============================================================================
  // 라운드 결과 공개 완료
  // ============================================================================
  //
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
    phaseTimer = Timer(FinalCallFlowTiming.roundResultAfterDelay, () async {
      if (!mounted || controller?.phase != 'roundResult') return;
      await controller?.nextRound();
    });
  }

  // ---------------------------------------------------------------------------
  // 설정 및 결과 화면 명령
  // ---------------------------------------------------------------------------
  void _restartGame() {
    unawaited(controller?.restartGame());
  }

  void _endGame() {
    unawaited(_endGameAndReturnToLobby());
  }

  Future<void> _endGameAndReturnToLobby() async {
    if (isEndingGame) return;
    // 설정에서 게임을 종료할 때 결과 화면을 잠깐 노출하지 않습니다.
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
    // game 노드 정리는 화면 복귀를 막지 않는 선택적 뒷정리입니다.
    // clearGame은 방을 남긴 채 game 노드만 지우는 뒷정리입니다. 서버가
    // `status == finished`를 아직 못 읽는 등으로 실패할 수 있는데, 그때
    // 화면 전환까지 막으면 결과 화면에 갇힙니다. Liar's Poker는 endGame만
    // 하고 바로 복귀하므로, 정리 실패는 무시하고 동일하게 홈으로 나갑니다.
    await controller?.clearGame();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _returnHomeAfterResult() async {
    if (isEndingGame) return;
    setState(() => isEndingGame = true);

    // 결과 화면 HOME은 휴대폰에도 종료 상태가 전달된 뒤 태블릿을 닫습니다.
    // game 노드를 바로 지우고 태블릿만 나가면, clearGame이 실패했을 때
    // 휴대폰에는 종료 신호가 전파되지 않아 결과 화면에 남게 됩니다.
    // 설정 종료와 같게 먼저 manual finished를 서버에 확정하고,
    // 이 명령이 성공한 경우에만 태블릿 화면을 닫습니다. 새 게임 시작은
    // 기존 finished game을 교체하므로 여기서 즉시 삭제하지 않습니다.
    final ended = await controller?.endGame() ?? false;
    if (!mounted) return;
    if (!ended) {
      setState(() => isEndingGame = false);
      final message = controller?.actionErrorMessage;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message ?? '게임을 종료하지 못했습니다.')));
      return;
    }
    Navigator.of(context).maybePop();
  }

  FinalCallTabletStage _resolveStage(FinalCallController game) {
    // ========================================================================
    // 서버 상태 → 태블릿 화면 단계
    // ========================================================================
    //
    // 이 함수만 서버 phase 문자열을 해석합니다. 하위 Widget은 typed stage와
    // GameFlowConfig만 받아 화면을 그리며 서버 상태를 다시 추측하지 않습니다.
    if (game.loading) return FinalCallTabletStage.connecting;
    // 수동 종료·인원 부족처럼 정상 승자가 없는 finished는 stale roundResult가
    // 남아 있어도 결과 화면보다 먼저 차단합니다.
    if (game.isFinished && !game.isNaturalResult) {
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
    closingExitTimer?.cancel();
    sessionSubscription?.close();
    // ---------------------------------------------------------------------------
    // 게임 종료 후 플랫폼 화면 정책 복원
    // ---------------------------------------------------------------------------
    unawaited(AppOrientation.lockPlatformLandscape());
    unawaited(AppSystemUi.showPlatformSystemBars());
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
    final closingMessage = switch (game.finishReason) {
      'interruptionVoteExpired' => GameFlowCopy.interruptionVoteExpired,
      'insufficientPlayers' => GameFlowCopy.insufficientPlayers,
      _ => GameFlowCopy.gameFinished,
    };
    final flowConfig = buildFinalCallTabletFlowConfig(
      closingMessage: closingMessage,
    );
    final flowStep = flowConfig.stepFor(stage);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ---------------------------------------------------------------------------
          // 공통 배경
          // ---------------------------------------------------------------------------
          Assets.games.finalCall.images.background.background.image(
            fit: BoxFit.cover,
          ),
          // 단계별 카드·하트·판정 화면입니다. 화면 표시 여부는 Flow Config에서
          // 확인하고, 실제 Widget 선택은 exhaustive stage switch가 담당합니다.
          if (flowStep.showScreen)
            FinalCallTabletGameLayer(
              controller: game,
              stage: stage,
              flowConfig: flowConfig,
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
          // ---------------------------------------------------------------------------
          // 공용 태블릿 사이드바
          // ---------------------------------------------------------------------------
          FinalCallTabletGameOverlay(
            provider: widget.provider,
            visible:
                stage != FinalCallTabletStage.connecting &&
                stage != FinalCallTabletStage.result &&
                stage != FinalCallTabletStage.closing,
            onRestartGame: _restartGame,
            onEndGame: _endGame,
          ),
          // 설정 종료·인원 부족 등 승자가 없는 종료에는 결과 화면을 절대
          // 만들지 않습니다. stage 검사와 자연 종료 검사로 이중 차단합니다.
          if (!isEndingGame &&
              game.isNaturalResult &&
              stage == FinalCallTabletStage.result)
            FinalCallResultOverlay(
              winners: game.winners,
              winningTeam: game.winningTeam,
              isDraw: game.finishReason == 'draw',
              onRestart: () => game.restartGame(),
              onHome: () => unawaited(_returnHomeAfterResult()),
            ),
          Positioned.fill(
            child: GameAnnouncementLayer(
              announcement: flowStep.buildAnnouncement(),
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
          GameInterruptionLayer(
            interruption: game.interruption,
            currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
            presentation: GameInterruptionPresentation.tabletController,
            isSubmitting: game.commandInFlight,
            onContinue: () async {
              await game.excludeInterruptedPlayerAndContinue();
            },
            onExpired: game.expireInterruption,
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
