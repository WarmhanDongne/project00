import 'dart:async';
import 'package:project00/core/time/server_clock.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/final_call/providers/final_call_game_state.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/final_call/providers/final_call_session_provider.dart';
import 'package:project00/games/final_call/controllers/final_call_controller.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_screen.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/final_call/widgets/phone/card_change_dialog.dart';
import 'package:project00/games/final_call/widgets/phone/top_bar.dart';
import 'package:project00/games/shared/game_flow/game_screen_phase.dart';
import 'package:project00/games/shared/game_flow/phone_game_shell.dart';
import 'package:project00/games/shared/widgets/phone_result_dialog.dart';
import 'package:project00/games/shared/widgets/phone_exit_modal.dart';
import 'package:project00/games/shared/widgets/game_interruption_layer.dart';
import 'package:project00/gen/assets.gen.dart';

/// Final Call 휴대폰 화면의 진입점입니다.
class FinalCallPhoneGame extends ConsumerStatefulWidget {
  const FinalCallPhoneGame({
    super.key,
    required this.roomCode,
    required this.gameService,
    required this.onExitRoom,
  });

  final String roomCode;
  final FinalCallService gameService;
  final Future<bool> Function() onExitRoom;

  @override
  ConsumerState<FinalCallPhoneGame> createState() => _FinalCallPhoneGameState();
}

class _FinalCallPhoneGameState extends ConsumerState<FinalCallPhoneGame> {
  FinalCallController? controller;
  FinalCallSessionArgs? sessionArgs;
  ProviderSubscription<FinalCallGameState>? sessionSubscription;
  String? initializationError;
  String? selectedCardId;
  final Set<String> selectedFinalCardIds = <String>{};
  String? visibleCallerUid;
  String? observedCallerUid;
  int revealedRound = 0;
  Timer? callNoticeTimer;
  bool hasScheduledManualExit = false;
  bool gameStartCompleted = false;
  int? announcedRound;
  String? previousStatus;
  bool replacementInProgress = false;
  String? replacingCardId;
  String? _automaticCardChangeKey;
  bool _isLeavingRoom = false;

  @override
  void initState() {
    super.initState();
    //=======================휴대폰 게임 방향 정책==============================
    // Final Call 휴대폰 UI는 가로만 지원합니다. 태블릿은 별도 공용 불변
    // 조건에 따라 게임 종류와 관계없이 항상 가로 고정됩니다.
    unawaited(
      AppOrientation.applyPhoneGame(PhoneGameOrientation.landscapeOnly),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      initializationError = GameFlowCopy.authenticationRequired;
      return;
    }
    final args = FinalCallSessionArgs(
      roomCode: widget.roomCode,
      uid: uid,
      service: widget.gameService,
      watchPrivateHand: true,
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
    if (previousStatus == 'finished' && !game.isFinished) {
      gameStartCompleted = false;
      announcedRound = null;
      revealedRound = 0;
    }
    previousStatus = game.status;
    //=======================승부가 나지 않은 종료는 모두 퇴장==============================
    // 나가야 할 종료 사유를 나열하지 않고, '정상 결과가 아니면 나간다'로 뒤집어
    // 판단합니다. 사유 목록 방식은 서버에 종료 사유가 하나만 늘어도 휴대폰이
    // 결과 화면에 갇힙니다. 라이어스포커와 같은 규칙입니다.
    final shouldCloseGame = game.isFinished && !game.isNaturalResult;
    if (shouldCloseGame) {
      if (_isLeavingRoom) return;
      if (hasScheduledManualExit) return;
      hasScheduledManualExit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return;
    }
    hasScheduledManualExit = false;
    if (selectedCardId != null &&
        !game.hand.any((card) => card.id == selectedCardId)) {
      selectedCardId = null;
    }
    if (game.isFinalSubmitPhase) selectedCardId = null;
    if (!game.isFinalSubmitPhase && selectedFinalCardIds.isNotEmpty) {
      selectedFinalCardIds.clear();
    }
    _scheduleAutomaticFinalTurnCardChange(game);
    if (game.callerUid == null) {
      observedCallerUid = null;
      visibleCallerUid = null;
      callNoticeTimer?.cancel();
    } else if (game.callerUid != observedCallerUid) {
      observedCallerUid = game.callerUid;
      visibleCallerUid = game.callerUid;
      callNoticeTimer?.cancel();
      callNoticeTimer = Timer(const Duration(milliseconds: 4200), () {
        if (!mounted) return;
        setState(() => visibleCallerUid = null);
      });
    }
    setState(() {});
  }

  //=======================CALL 이후 자동 카드 교체 진입==============================
  // CALL하지 않은 플레이어의 마지막 턴에는 별도의 카드 교체 버튼을 누르지
  // 않아도 공개 카드·덱 선택창을 즉시 엽니다.
  void _scheduleAutomaticFinalTurnCardChange(FinalCallController game) {
    if (game.phase != 'finalTurns' ||
        !game.isMyTurn ||
        game.pendingDrawUid != null ||
        game.commandInFlight) {
      return;
    }
    final promptKey = '${game.round}:${game.turnUid}:${game.turnDeadlineAt}';
    if (_automaticCardChangeKey == promptKey) return;
    _automaticCardChangeKey = promptKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || controller?.phase != 'finalTurns') return;
      final discard = game.discardCard;
      if (discard == null) {
        _automaticCardChangeKey = null;
        return;
      }
      final source = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => FinalCallCardChangeDialog(
          discardCard: discard,
          canSelectDeck: game.deckRemainingCount > 0,
          deadlineAt: game.turnDeadlineAt,
        ),
      );
      if (!mounted) return;
      if (source == null) {
        _automaticCardChangeKey = null;
        _scheduleAutomaticFinalTurnCardChange(game);
        return;
      }
      if (!game.canDraw) return;
      final completed = await game.draw(source);
      if (!mounted || completed) return;
      if (_turnHasEnded(game)) {
        game.clearError();
        return;
      }
      _automaticCardChangeKey = null;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(game.actionErrorMessage)));
      _scheduleAutomaticFinalTurnCardChange(game);
    });
  }

  Future<void> _leaveRoom() async {
    final leave = await SharedPhoneExitModal.show(
      context,
      doorImage: Assets.games.finalCall.images.modal.modalImageDoor.image(
        fit: BoxFit.contain,
      ),
      surfaceColor: Colors.white,
      titleColor: Colors.white,
      descriptionColor: Colors.white,
      primaryColor: const Color(0xFF171717),
      showSurface: false,
      showText: true,
    );
    if (leave != true || !mounted) return;
    if (_isLeavingRoom) return;
    _isLeavingRoom = true;
    final left = await widget.onExitRoom();
    if (!mounted) return;
    if (left) {
      // 서버 퇴장 성공 뒤에는 게임 라우트를 먼저 닫습니다. 세로 복원 Future를
      // 먼저 기다리면 iOS 회전 응답이 지연될 때 게임 화면에 갇힐 수 있습니다.
      // 방향 복원은 dispose와 상위 대기 화면이 비동기로 처리합니다.
      Navigator.of(context).pop(true);
      return;
    }
    _isLeavingRoom = false;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(GameFlowCopy.leaveFailed)));
  }

  bool _turnHasEnded(FinalCallController game) {
    final deadline = game.turnDeadlineAt;
    return !game.isMyTurn ||
        !game.canDraw ||
        (deadline != null && ServerClock.hasPassed(deadline));
  }

  Future<void> _completeTurn(String? replaceCardId) async {
    final game = controller;
    if (game == null || replacementInProgress) return;
    final expectedTurnUid = game.turnUid;
    final expectedDeadline = game.turnDeadlineAt;

    if (replaceCardId != null) {
      setState(() {
        replacementInProgress = true;
        replacingCardId = replaceCardId;
      });
      await Future<void>.delayed(const Duration(milliseconds: 460));
      if (!mounted) return;
    }

    if (game.turnUid != expectedTurnUid ||
        (expectedDeadline != null && ServerClock.hasPassed(expectedDeadline)) ||
        !game.canCompleteTurn) {
      game.clearError();
      setState(() {
        replacementInProgress = false;
        replacingCardId = null;
      });
      return;
    }

    final completed = await game.completeTurn(replaceCardId);
    if (!mounted) return;
    setState(() {
      replacementInProgress = false;
      replacingCardId = null;
      if (completed) selectedCardId = null;
    });
    if (!completed) {
      if (game.turnUid != expectedTurnUid ||
          (expectedDeadline != null &&
              ServerClock.hasPassed(expectedDeadline)) ||
          !game.canCompleteTurn) {
        game.clearError();
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(game.actionErrorMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  void dispose() {
    callNoticeTimer?.cancel();
    sessionSubscription?.close();
    //=======================다른 화면 방향 복원==============================
    unawaited(AppOrientation.lockPlatformPortrait());
    super.dispose();
  }

  //=======================게임 진입==============================
  // 태블릿에서 테이블이 확대되는 순간과 맞춰 매트가 풀리며 게임 배경이
  // 드러납니다. 서버 데이터는 그 뒤에서 채워집니다.
  @override
  Widget build(BuildContext context) => _buildGameScreen(context);

  //=======================서버 상태 → 공용 화면 단계==============================
  // 화면 분기를 직접 짜지 않고, 공용 셸이 이해하는 단계로 번역만 합니다.
  GameScreenPhase _resolvePhase(FinalCallController game) {
    // 아직 서버 첫 상태나 내 손패가 오지 않았습니다.
    if (game.loading) return GameScreenPhase.connecting;
    if (game.phase == 'dealing' && game.hand.isEmpty) {
      return GameScreenPhase.connecting;
    }
    if (game.isFinished &&
        (game.finishReason == 'insufficientPlayers' ||
            game.finishReason == 'interruptionVoteExpired')) {
      return GameScreenPhase.closing;
    }
    if (!gameStartCompleted) return GameScreenPhase.intro;
    if (announcedRound != game.round) return GameScreenPhase.roundIntro;
    // 태블릿의 카드 공개·생명 소멸 연출이 끝나기 전에는 결과를 열지 않고
    // 진행 화면을 유지합니다. 이 동안에도 퇴장할 수 있어야 합니다.
    if (game.isFinished &&
        game.finishReason != 'manual' &&
        game.resultRevealCompletedAt == null) {
      return GameScreenPhase.playing;
    }
    if (game.isFinished) return GameScreenPhase.result;
    return GameScreenPhase.playing;
  }

  Widget _buildGameScreen(BuildContext context) {
    final args = sessionArgs;
    if (args != null) ref.watch(finalCallSessionProvider(args));
    final game = args == null
        ? null
        : ref.read(finalCallSessionProvider(args).notifier);
    controller = game;
    if (game == null) {
      return Scaffold(
        body: Center(
          child: Text(initializationError ?? GameFlowCopy.gameOpenFailed),
        ),
      );
    }

    final phase = _resolvePhase(game);
    final winner = game.players[game.winnerUid];

    return Stack(
      fit: StackFit.expand,
      children: [
        PhoneGameShell(
          phase: phase,
          roundNumber: game.round,
          introTextColor: Colors.black,
          background: Assets.games.finalCall.images.background.phoneBackground
              .image(fit: BoxFit.cover),
          // 손패가 준비되고 펼치기가 끝나야 상단바가 등장합니다.
          contentReady: game.hand.isNotEmpty,
          contentRevealed: revealedRound == game.round,
          onIntroCompleted: () {
            if (mounted) setState(() => gameStartCompleted = true);
          },
          onRoundIntroCompleted: () {
            if (mounted) setState(() => announcedRound = game.round);
          },
          topBar: FinalCallPhoneTopBar(
            controller: game,
            onExitRoom: () => unawaited(_leaveRoom()),
            onRulesPressed: (origin) => showFinalCallRules(context, origin),
          ),
          result: PhoneResultDialog(
            nickname: winner?.nickname ?? 'WINNER',
            profileImageUrl: winner?.profileImageUrl ?? '',
          ),
          content: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: FinalCallPhoneGameScreen(
                  controller: game,
                  handRevealed: revealedRound == game.round,
                  selectedCardId: selectedCardId,
                  selectedFinalCardIds: selectedFinalCardIds,
                  visibleCallerUid: visibleCallerUid,
                  onRevealStarted: () {},
                  onRevealCompleted: () =>
                      setState(() => revealedRound = game.round),
                  onSelectedCardChanged: (id) =>
                      setState(() => selectedCardId = id),
                  onFinalCardSelected: (id) => setState(() {
                    if (!selectedFinalCardIds.remove(id)) {
                      selectedFinalCardIds.add(id);
                    }
                  }),
                  onCompleteTurn: _completeTurn,
                  replacingCardId: replacingCardId,
                  replacementInProgress: replacementInProgress,
                  onExitRoom: () => unawaited(_leaveRoom()),
                ),
              ),
              if (game.commandInFlight)
                const Positioned(
                  right: 14,
                  bottom: 14,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
        GameInterruptionLayer(
          interruption: game.interruption,
          currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
          isSubmitting: game.commandInFlight,
          onVote: () async {
            await game.voteToContinueInterruption();
          },
          onExpired: game.expireInterruption,
        ),
      ],
    );
  }
}
