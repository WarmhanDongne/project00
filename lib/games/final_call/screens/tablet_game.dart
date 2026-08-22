import 'dart:async';
import 'package:project00/games/final_call/loading/final_call_loading.dart';
import 'package:project00/core/time/server_clock.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_asset_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/games/final_call/final_call_flow_config.dart';
import 'package:project00/games/final_call/providers/final_call_game_state.dart';
import 'package:project00/games/final_call/providers/final_call_session_provider.dart';
import 'package:project00/games/final_call/controllers/final_call_controller.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_animation.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_layer.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_overlay.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/final_call/sound/final_call_sounds.dart';
import 'package:project00/games/final_call/widgets/tablet/result_overlay.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/sound/game_background_music.dart';
import 'package:project00/games/shared/widgets/game_announcement_layer.dart';
import 'package:project00/games/shared/widgets/game_interruption_layer.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/core/assets/game_image.dart';

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

  /// 카드 분배가 시작되면 켜고, 화면을 떠날 때 끄는 배경음악입니다.
  final GameBackgroundMusic backgroundMusic = GameBackgroundMusic();

  /// 우승 발표마다 승리음을 한 번만 재생하기 위한 플래그입니다.
  bool hasPlayedWinSound = false;

  /// CALL 나레이션을 이미 낸 선언자입니다. 같은 CALL로 두 번 내지 않습니다.
  String? _announcedCallerUid;

  /// 설정에서 게임 종료를 누른 뒤 홈으로 나가는 중인지 여부입니다.
  bool isEndingGame = false;

  /// 종료를 누른 순간 화면에 있던 단계입니다.
  ///
  /// 종료 명령이 서버에 반영되면 stage가 closing으로 바뀌고, closing은 판을
  /// 아예 그리지 않습니다(`SizedBox.shrink`). 그래서 닫히기 직전에 좌석과
  /// 프로필이 사라진 빈 화면이 한 번 보였습니다. 나가는 동안에는 이 단계를
  /// 그대로 유지해 정리되는 장면을 보여주지 않습니다.
  FinalCallTabletStage? stageBeforeExit;

  /// 에셋 사전 준비는 첫 상태 수신 때 한 번만 합니다(캐릭터 목록이 필요).
  bool _hasPreloadedAssets = false;

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
    // 서버 에셋 도입 대비 훅입니다. 실패해도 번들 폴백으로 진행합니다.
    unawaited(
      GameAssetStore.instance.prepareGame('final_call').catchError((_) {}),
    );
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
    // 첫 스냅샷이 오면 이미지·캐릭터를 미리 디코딩합니다(LP와 같은 규약).
    if (!_hasPreloadedAssets && game.players.isNotEmpty) {
      _hasPreloadedAssets = true;
      unawaited(
        preloadFinalCallAssets(
          context,
          characterIds: game.players.values.map((player) => player.characterId),
        ),
      );
    }
    final enteredPhase = previousPhase != game.phase;
    previousPhase = game.phase;

    // CALL이 선언되는 순간 나레이션을 한 번 냅니다(태블릿만 — 여러 기기가
    // 울리면 말이 겹칩니다). 선언자는 라운드가 끝나면 지워지므로, 없다가
    // 생긴 순간만 잡습니다.
    final caller = game.callerUid;
    if (caller != null && caller != _announcedCallerUid) {
      _announcedCallerUid = caller;
      SoundEffects.play(context, FinalCallSounds.voiceCall);
    } else if (caller == null) {
      _announcedCallerUid = null;
    }

    // 카드 분배가 시작되면 배경음악을 켭니다. 라운드마다 분배가 반복되지만
    // start가 한 번만 실행되므로 곡이 처음으로 되감기지 않습니다.
    if (game.phase == 'dealing') {
      backgroundMusic.start(FinalCallSounds.background);
    }

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

    _celebrateWinIfNeeded(game);
  }

  /// 우승 발표 오버레이가 화면에 뜨는 순간 승리음을 한 번 재생합니다.
  ///
  /// 결과 화면은 두 경로로 열립니다 — 마지막 라운드 공개 연출이 끝난 뒤
  /// ([_handleRoundRevealCompleted]), 또는 공개 없이 승자가 확정된 스냅샷
  /// 직후([_handleState]). 두 곳 모두 이 함수를 지나며, 오버레이가 실제로
  /// 보이는 조건과 같은 시점에만 냅니다. 배경음악은 발표와 함께 멈춥니다.
  void _celebrateWinIfNeeded(FinalCallController game) {
    if (!game.isFinished || !game.isNaturalResult) {
      // 다시하기로 새 판이 시작되면 다음 우승 발표에서 다시 재생합니다.
      hasPlayedWinSound = false;
      return;
    }
    // 마지막 라운드의 카드 공개·하트 소멸 연출이 끝나기 전에는 결과
    // 오버레이가 뜨지 않으므로 소리도 내지 않습니다.
    if (game.roundResult != null && completedRevealRound != game.round) return;
    if (hasPlayedWinSound) return;
    hasPlayedWinSound = true;
    backgroundMusic.stop();
    SoundEffects.play(context, FinalCallSounds.win);
    // 승리음(음악) 위에 결과 나레이션을 얹습니다.
    SoundEffects.play(
      context,
      FinalCallSounds.resultVoiceFor(
        isDraw: game.finishReason == 'draw',
        winningTeam: game.winningTeam,
      ),
    );
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
      _celebrateWinIfNeeded(game);
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
    setState(() {
      isEndingGame = true;
      stageBeforeExit = _currentStage();
    });
    final ended = await controller?.endGame() ?? false;
    if (!mounted) return;
    if (!ended) {
      setState(() {
        isEndingGame = false;
        stageBeforeExit = null;
      });
      return;
    }
    // Liar's Poker와 같은 흐름입니다: endGame 성공 = 즉시 복귀.
    //
    // 예전에는 여기서 clearGame까지 기다렸습니다. game 노드를 지우는 건 선택적
    // 뒷정리인데, callable 왕복이 하나 더 붙어 종료가 그만큼 늦어지고 실패하면
    // 결과 화면이 잠깐 비칩니다. 새 게임 시작(game_final_call_start_game)이
    // finished 상태의 기존 게임을 그대로 교체하므로 미리 지울 필요가 없습니다.
    Navigator.of(context).maybePop();
  }

  Future<void> _returnHomeAfterResult() async {
    if (isEndingGame) return;
    setState(() {
      isEndingGame = true;
      stageBeforeExit = _currentStage();
    });

    // 결과 화면 HOME은 휴대폰에도 종료 상태가 전달된 뒤 태블릿을 닫습니다.
    // game 노드를 바로 지우고 태블릿만 나가면, clearGame이 실패했을 때
    // 휴대폰에는 종료 신호가 전파되지 않아 결과 화면에 남게 됩니다.
    // 설정 종료와 같게 먼저 manual finished를 서버에 확정하고,
    // 이 명령이 성공한 경우에만 태블릿 화면을 닫습니다. 새 게임 시작은
    // 기존 finished game을 교체하므로 여기서 즉시 삭제하지 않습니다.
    final ended = await controller?.endGame() ?? false;
    if (!mounted) return;
    if (!ended) {
      setState(() {
        isEndingGame = false;
        stageBeforeExit = null;
      });
      final message = controller?.actionErrorMessage;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message ?? '게임을 종료하지 못했습니다.')));
      return;
    }
    Navigator.of(context).maybePop();
  }

  /// 현재 서버 상태로 계산한 단계입니다.
  FinalCallTabletStage? _currentStage() {
    final game = controller;
    return game == null ? null : _resolveStage(game);
  }

  FinalCallTabletStage _resolveStage(FinalCallController game) {
    // 나가는 중에는 종료가 반영되기 전 화면을 그대로 유지합니다.
    final held = stageBeforeExit;
    if (isEndingGame && held != null) return held;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // dispose에서는 context를 읽을 수 없으므로 미리 붙잡아 둡니다.
    backgroundMusic.attach(context);
  }

  @override
  void dispose() {
    // 배경음악은 반복 재생이라 화면을 떠날 때 반드시 멈춥니다.
    backgroundMusic.stop();
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
          Assets.games.finalCall.images.background.background.game.image(
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
