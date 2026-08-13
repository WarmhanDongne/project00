import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_controller.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_screen.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/final_call/widgets/final_call_result.dart';
import 'package:project00/games/shared/widgets/phone_exit_modal.dart';
import 'package:project00/gen/assets.gen.dart';

/// Final Call 휴대폰 화면의 진입점입니다.
class PhoneGame extends StatefulWidget {
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
  State<PhoneGame> createState() => _PhoneGameState();
}

class _PhoneGameState extends State<PhoneGame> {
  PhoneGameController? controller;
  String? initializationError;
  String? selectedCardId;
  final Set<String> selectedFinalCardIds = <String>{};
  String? visibleCallerUid;
  String? observedCallerUid;
  int revealedRound = 0;
  Timer? callNoticeTimer;
  bool hasScheduledManualExit = false;

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
    controller =
        PhoneGameController(
            roomCode: widget.roomCode,
            uid: uid,
            gameService: widget.gameService,
          )
          ..addListener(_handleState)
          ..initialize();
  }

  void _handleState() {
    final game = controller;
    if (game == null || !mounted) return;
    if (game.isFinished && game.finishReason == 'manual') {
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
    if (!game.canSubmitCallerHand && selectedFinalCardIds.isNotEmpty) {
      selectedFinalCardIds.clear();
    }
    if (game.callerUid != null && game.callerUid != observedCallerUid) {
      observedCallerUid = game.callerUid;
      visibleCallerUid = game.callerUid;
      callNoticeTimer?.cancel();
      callNoticeTimer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        setState(() => visibleCallerUid = null);
      });
    }
    setState(() {});
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
    );
    if (leave != true || !mounted) return;
    final left = await widget.onExitRoom();
    if (left && mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    callNoticeTimer?.cancel();
    controller
      ?..removeListener(_handleState)
      ..dispose();
    //=======================다른 화면 방향 복원==============================
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
    if (game.loading || game.hand.isEmpty) {
      return Scaffold(
        body: Assets.games.finalCall.images.background.phoneBackground.image(
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
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
          if (game.isFinished)
            FinalCallResultOverlay(
              winner: game.players[game.winnerUid],
              showActions: false,
            ),
        ],
      ),
    );
  }
}
