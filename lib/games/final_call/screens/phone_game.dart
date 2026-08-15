import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/final_call/providers/final_call_game_state.dart';
import 'package:project00/games/final_call/providers/final_call_session_provider.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_controller.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_screen.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/final_call/widgets/phone/phone_card_change_dialog.dart';
import 'package:project00/games/shared/animations/fade_hold_fade.dart';
import 'package:project00/games/shared/animations/phone_game_start_animation.dart';
import 'package:project00/games/shared/widgets/phone_result_dialog.dart';
import 'package:project00/games/shared/widgets/phone_exit_modal.dart';
import 'package:project00/gen/assets.gen.dart';

/// Final Call 휴대폰 화면의 진입점입니다.
class PhoneGame extends ConsumerStatefulWidget {
  const PhoneGame({
    super.key,
    required this.roomCode,
    required this.gameService,
    required this.onExitRoom,
  });

  final String roomCode;
  final FinalCallService gameService;
  final Future<bool> Function() onExitRoom;

  @override
  ConsumerState<PhoneGame> createState() => _PhoneGameState();
}

class _PhoneGameState extends ConsumerState<PhoneGame> {
  PhoneGameController? controller;
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
    //=======================가로 화면 고정==============================
    unawaited(AppOrientation.lockFinalCallLandscape());
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      initializationError = '게임에 참여하려면 사용자 인증이 필요합니다.';
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
    final shouldCloseGame =
        game.isFinished &&
        (game.finishReason == 'manual' ||
            game.finishReason == 'insufficientPlayers');
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
  void _scheduleAutomaticFinalTurnCardChange(PhoneGameController game) {
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
      surfaceColor: const Color(0xFFF2F0EB),
      primaryColor: const Color(0xFF171717),
      titleColor: const Color(0xFF171717),
      descriptionColor: const Color(0xFF5E5E5E),
      showSurface: false,
      showText: true,
    );
    if (leave != true || !mounted) return;
    if (_isLeavingRoom) return;
    _isLeavingRoom = true;
    final left = await widget.onExitRoom();
    if (!mounted) return;
    if (left) {
      Navigator.of(context).pop(true);
      return;
    }
    _isLeavingRoom = false;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('게임에서 퇴장하지 못했습니다.')));
  }

  bool _turnHasEnded(PhoneGameController game) {
    final deadline = game.turnDeadlineAt;
    return !game.isMyTurn ||
        !game.canDraw ||
        (deadline != null && DateTime.now().millisecondsSinceEpoch >= deadline);
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
        (expectedDeadline != null &&
            DateTime.now().millisecondsSinceEpoch >= expectedDeadline) ||
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
              DateTime.now().millisecondsSinceEpoch >= expectedDeadline) ||
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
    if (game.loading || game.hand.isEmpty) {
      return Scaffold(
        body: Assets.games.finalCall.images.background.phoneBackground.image(
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    //=======================태블릿 최종 공개 완료 대기==============================
    // 승자가 확정되어도 태블릿의 카드 공개·생명 소멸 연출이 모두 끝나기
    // 전에는 휴대폰 결과 화면을 먼저 열지 않습니다.
    if (game.isFinished &&
        game.finishReason != 'manual' &&
        game.finishReason != 'insufficientPlayers' &&
        game.resultRevealCompletedAt == null) {
      return Scaffold(
        body: Assets.games.finalCall.images.background.phoneBackground.image(
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    if (game.isFinished) {
      final winner = game.players[game.winnerUid];
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Assets.games.finalCall.images.background.phoneBackground.image(
              fit: BoxFit.cover,
              color: const Color(0xB8000000),
              colorBlendMode: BlendMode.darken,
            ),
            PhoneResultDialog(
              nickname: winner?.nickname ?? 'WINNER',
              profileImageUrl: winner?.profileImageUrl ?? '',
            ),
          ],
        ),
      );
    }

    //=======================GAME START와 라운드 안내==============================
    if (!gameStartCompleted) {
      return _buildIntro(
        PhoneGameStartAnimation(
          textColor: Colors.black,
          onCompleted: () {
            if (mounted) setState(() => gameStartCompleted = true);
          },
        ),
      );
    }
    if (announcedRound != game.round) {
      return _buildIntro(
        FadeHoldFade(
          key: ValueKey('final-call-round-${game.round}'),
          onCompleted: () {
            if (mounted) setState(() => announcedRound = game.round);
          },
          child: Center(
            child: Text(
              'ROUND ${game.round}',
              style: const TextStyle(
                fontFamily: 'BebasNeue',
                color: Colors.black,
                fontSize: 48,
                letterSpacing: 3,
                shadows: [Shadow(color: Colors.black87, blurRadius: 14)],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: PhoneGameScreen(
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
              onExitRoom: _leaveRoom,
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
    );
  }

  Widget _buildIntro(Widget child) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Assets.games.finalCall.images.background.phoneBackground.image(
            fit: BoxFit.cover,
          ),
          child,
        ],
      ),
    );
  }
}
