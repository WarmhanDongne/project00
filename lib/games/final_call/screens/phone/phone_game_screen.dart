import 'dart:math' as math;
import 'package:project00/games/shared/game_feedback.dart';
import 'package:project00/core/time/server_clock.dart';

import 'package:flutter/material.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/final_call_copy.dart';
import 'package:project00/games/final_call/controllers/final_call_controller.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';
import 'package:project00/games/final_call/widgets/phone/card_change_dialog.dart';
import 'package:project00/games/final_call/widgets/phone/game_actions.dart';
import 'package:project00/games/final_call/widgets/phone/hand_card_stack.dart';
import 'package:project00/games/final_call/widgets/phone/top_bar.dart';
import 'package:project00/games/final_call/widgets/phone/turn_action_switcher.dart';
import 'package:project00/games/final_call/widgets/phone/turn_timer.dart';
import 'package:project00/games/shared/animations/phone_control_entry_animation.dart';
import 'package:project00/gen/assets.gen.dart';

/// 휴대폰의 손패와 조작부를 분리된 두 영역으로 표시합니다.
class FinalCallPhoneGameScreen extends StatefulWidget {
  const FinalCallPhoneGameScreen({
    super.key,
    required this.controller,
    required this.handRevealed,
    required this.selectedCardId,
    required this.selectedFinalCardIds,
    required this.visibleCallerUid,
    required this.onRevealStarted,
    required this.onRevealCompleted,
    required this.onSelectedCardChanged,
    required this.onFinalCardSelected,
    required this.onCompleteTurn,
    required this.replacingCardId,
    required this.replacementInProgress,
    required this.onExitRoom,
  });

  final FinalCallController controller;
  final bool handRevealed;
  final String? selectedCardId;
  final Set<String> selectedFinalCardIds;
  final String? visibleCallerUid;
  final VoidCallback onRevealStarted;
  final VoidCallback onRevealCompleted;
  final ValueChanged<String?> onSelectedCardChanged;
  final ValueChanged<String> onFinalCardSelected;
  final Future<void> Function(String? replaceCardId) onCompleteTurn;
  final String? replacingCardId;
  final bool replacementInProgress;
  final VoidCallback onExitRoom;

  @override
  State<FinalCallPhoneGameScreen> createState() =>
      _FinalCallPhoneGameScreenState();
}

class _FinalCallPhoneGameScreenState extends State<FinalCallPhoneGameScreen>
    with SingleTickerProviderStateMixin {
  //=======================조작부 등장==============================
  // Liar's Poker와 동일한 컨트롤러·연출(PhoneControlEntryAnimation)을 그대로
  // 사용합니다. 손패 펼치기가 끝나는 순간 상단바·타이머·조작부가 같은
  // 컨트롤러로 함께 등장합니다.
  late final AnimationController _controlsEntryController;
  int? _revealedRoundForEntry;

  FinalCallController get controller => widget.controller;
  bool get handRevealed => widget.handRevealed;
  String? get selectedCardId => widget.selectedCardId;
  Set<String> get selectedFinalCardIds => widget.selectedFinalCardIds;
  String? get visibleCallerUid => widget.visibleCallerUid;
  VoidCallback get onRevealStarted => widget.onRevealStarted;
  ValueChanged<String?> get onSelectedCardChanged =>
      widget.onSelectedCardChanged;
  ValueChanged<String> get onFinalCardSelected => widget.onFinalCardSelected;
  Future<void> Function(String?) get onCompleteTurn => widget.onCompleteTurn;
  String? get replacingCardId => widget.replacingCardId;
  bool get replacementInProgress => widget.replacementInProgress;
  VoidCallback get onExitRoom => widget.onExitRoom;

  @override
  void initState() {
    super.initState();
    _controlsEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    if (widget.handRevealed) {
      _controlsEntryController.value = 1;
      _revealedRoundForEntry = widget.controller.round;
    }
  }

  @override
  void dispose() {
    _controlsEntryController.dispose();
    super.dispose();
  }

  /// 손패 펼치기가 끝나면 상단바를 포함한 UI가 한 번에 등장합니다.
  void _handleRevealCompleted() {
    widget.onRevealCompleted();
    _revealedRoundForEntry = widget.controller.round;
    if (!_controlsEntryController.isAnimating &&
        !_controlsEntryController.isCompleted) {
      _controlsEntryController.forward();
    }
  }

  /// 새 라운드 카드가 다시 배분되면 다음 공개까지 UI를 감춥니다.
  ///
  /// build 도중에 컨트롤러를 되돌리면 리스너가 즉시 setState를 호출해 오류가
  /// 나므로, Liar's Poker와 같이 프레임이 끝난 뒤에 되돌립니다.
  void _resetEntryForNewRound() {
    if (_revealedRoundForEntry == null) return;
    _revealedRoundForEntry = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.controller.phase != 'dealing') return;
      _controlsEntryController.reset();
    });
  }

  Future<void> _openCardChange(BuildContext context) async {
    final discard = controller.discardCard;
    final expectedTurnUid = controller.turnUid;
    final expectedDeadline = controller.turnDeadlineAt;
    if (discard == null ||
        !controller.canDraw ||
        _deadlinePassed(expectedDeadline)) {
      return;
    }
    final source = await FinalCallCardChangeDialog.show(
      context,
      discardCard: discard,
      canSelectDeck: controller.deckRemainingCount > 0,
      deadlineAt: expectedDeadline,
    );
    if (source == null || !context.mounted) return;

    // 모달을 보고 있는 동안 턴이 끝났다면 오래된 명령을 보내지 않습니다.
    if (!controller.canDraw ||
        controller.turnUid != expectedTurnUid ||
        controller.turnDeadlineAt != expectedDeadline ||
        _deadlinePassed(expectedDeadline)) {
      controller.clearError();
      return;
    }
    final completed = await controller.draw(source);
    if (!completed && context.mounted) {
      if (!controller.canDraw ||
          controller.turnUid != expectedTurnUid ||
          _deadlinePassed(expectedDeadline)) {
        controller.clearError();
        return;
      }
      _showActionError(context, controller.actionErrorMessage);
    }
  }

  bool _deadlinePassed(int? deadline) =>
      deadline != null && ServerClock.hasPassed(deadline);

  Future<void> _call(BuildContext context) async {
    if (!controller.canCall) return;
    // 판을 뒤집는 선언이므로 강한 진동으로 확정감을 줍니다.
    GameFeedback.declare();
    onSelectedCardChanged(null);
    final completed = await controller.call();
    if (!completed && context.mounted) {
      _showActionError(context, controller.actionErrorMessage);
    }
  }

  void _showActionError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // 새 라운드 배분이 시작되면 다음 공개까지 상단바·조작부를 다시 감춥니다.
    if (controller.phase == 'dealing') _resetEntryForNewRound();

    return LayoutBuilder(
      builder: (context, constraints) {
        final timerVisible =
            controller.turnDeadlineAt != null &&
            controller.isMyTurn &&
            controller.status == 'playing' &&
            controller.phase != 'roundResult' &&
            controller.phase != 'dealing';
        final controlAreaWidth = constraints.maxWidth * 3 / 11;
        final board = Stack(
          children: [
            Column(
              children: [
                //=======================상단바 자리==============================
                // 상단바 자체는 공용 셸(PhoneGameShell)이 이 자리 위에 겹쳐
                // 그립니다. 셸이 표시 시점과 퇴장 접근을 보장하며, 여기서는
                // 카드 위치가 달라지지 않도록 같은 높이만 비워 둡니다.
                const SizedBox(height: finalCallPhoneTopBarHeight),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, contentConstraints) {
                      final handAreaWidth =
                          (contentConstraints.maxWidth - 1) * 8 / 11 - 28;
                      final naturalCardWidth =
                          FinalCallPhoneHandCardStack.cardWidthFor(
                            BoxConstraints(
                              maxWidth: handAreaWidth,
                              maxHeight: contentConstraints.maxHeight,
                            ),
                            true,
                          );
                      final controlSafeCardWidth = math.max(
                        1.0,
                        (contentConstraints.maxHeight - 112) /
                            finalCallCardHeightRatio,
                      );
                      final cardWidth = math.min(
                        naturalCardWidth,
                        controlSafeCardWidth,
                      );
                      final cardHeight = cardWidth * finalCallCardHeightRatio;
                      final dividerHeight = math.min(
                        contentConstraints.maxHeight * 0.68,
                        math.max(72.0, cardHeight * 0.86),
                      );
                      final cardTop = math.max(
                        0.0,
                        (contentConstraints.maxHeight - cardHeight) / 2,
                      );
                      final timerTop = math.max(0.0, (cardTop - 34) / 2);

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 8,
                                child: _buildLandscapeHand(cardWidth),
                              ),
                              SizedBox(
                                width: 1,
                                child: Center(
                                  child: SizedBox(
                                    width: 1,
                                    height: dividerHeight,
                                    child: const ColoredBox(
                                      color: Color(0x26000000),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                //=======================조작부·턴 정보 등장==============================
                                // 상단바보다 살짝 늦게, 큰 버튼답게 떨어지는
                                // Liar's Poker의 heavyDrop 연출을 씁니다.
                                child: PhoneControlEntryAnimation(
                                  animation: _controlsEntryController,
                                  style: PhoneControlEntryStyle.heavyDrop,
                                  begin: 0.12,
                                  end: 1,
                                  child: _buildControl(context, cardHeight),
                                ),
                              ),
                            ],
                          ),
                          //=======================상단 UI와 카드 사이 타이머==============================
                          if (timerVisible)
                            Positioned(
                              top: timerTop,
                              left: 18,
                              right: controlAreaWidth + 12,
                              child: Center(
                                child: PhoneControlEntryAnimation(
                                  animation: _controlsEntryController,
                                  style: PhoneControlEntryStyle.header,
                                  begin: 0,
                                  end: 0.76,
                                  child: FinalCallTimer(
                                    key: ValueKey(controller.turnDeadlineAt),
                                    deadline: controller.turnDeadlineAt!,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );

        final waitingForReveal = !handRevealed;
        return Stack(
          fit: StackFit.expand,
          children: [
            Assets.games.finalCall.images.background.phoneBackground.image(
              fit: BoxFit.cover,
            ),
            SafeArea(
              child: waitingForReveal
                  ? FinalCallPhoneHandCardStack(
                      cards: controller.hand,
                      isLandscape: true,
                      isRevealed: false,
                      selectedCardId: null,
                      selectedCardIds: const {},
                      onRevealStarted: onRevealStarted,
                      onRevealCompleted: _handleRevealCompleted,
                      onCardSelected: (_) {},
                      onCardsReordered: controller.reorderHand,
                    )
                  : board,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLandscapeHand(double cardWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: FinalCallPhoneHandCardStack(
        cards: controller.hand,
        isLandscape: true,
        isRevealed: handRevealed,
        selectedCardId: selectedCardId,
        selectedCardIds: selectedFinalCardIds,
        newCardId: controller.pendingDraw?.id,
        replacingCardId: replacingCardId,
        replacementInProgress: replacementInProgress,
        cardWidth: cardWidth,
        selectionEnabled:
            controller.canCompleteTurn || controller.isFinalSubmitPhase,
        onRevealStarted: onRevealStarted,
        onRevealCompleted: _handleRevealCompleted,
        onCardSelected: controller.isFinalSubmitPhase
            ? onFinalCardSelected
            : (id) {
                onSelectedCardChanged(selectedCardId == id ? null : id);
              },
        onCardsReordered: controller.reorderHand,
      ),
    );
  }

  Widget _buildControl(BuildContext context, double cardHeight) {
    final callNoticeReplacesTurnProfile =
        visibleCallerUid != null && visibleCallerUid != controller.uid;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: FinalCallTurnActionSwitcher(
            isMyTurn: controller.isMyTurn,
            turnPlayer: controller.turnPlayer,
            callMessage: callNoticeReplacesTurnProfile
                ? Assets.games.finalCall.images.modal.modalMessageCall.image(
                    fit: BoxFit.contain,
                  )
                : null,
            action: controller.isFinalSubmitPhase
                ? _FinalSubmitAction(
                    controller: controller,
                    selectedCardIds: selectedFinalCardIds,
                    scoreBlockHeight: cardHeight,
                  )
                : FinalCallPhoneActions(
                    controller: controller,
                    selectedCardId: selectedCardId,
                    onOpenCardChange: () => _openCardChange(context),
                    onCall: () => _call(context),
                    onCompleteTurn: onCompleteTurn,
                    replacementInProgress: replacementInProgress,
                  ),
          ),
        ),
      ),
    );
  }
}

class _FinalSubmitAction extends StatelessWidget {
  const _FinalSubmitAction({
    required this.controller,
    required this.selectedCardIds,
    required this.scoreBlockHeight,
  });
  final FinalCallController controller;
  final Set<String> selectedCardIds;
  final double scoreBlockHeight;

  @override
  Widget build(BuildContext context) {
    final selectedCards = controller.hand
        .where((card) => selectedCardIds.contains(card.id))
        .toList(growable: false);
    final scoreResult = calculateFinalCallScoreResult(selectedCards);
    final score = scoreResult.value;
    final scoreColor = switch (scoreResult.type) {
      FinalCallCombinationType.sameNumber => Colors.black,
      FinalCallCombinationType.color => switch (scoreResult.color) {
        'red' => const Color(0xFFD11928),
        'blue' => const Color(0xFF173BA7),
        'yellow' => const Color(0xFFB88A00),
        'green' => const Color(0xFF157A3A),
        _ => Colors.black,
      },
    };
    final canSubmit =
        selectedCardIds.isNotEmpty && controller.canSubmitFinalHand;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          FinalCallCopy.selectFinalCombination,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        //=======================최종 조합 점수 카드==============================
        SizedBox(
          width: scoreBlockHeight * 381 / 512,
          height: scoreBlockHeight,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Assets.games.finalCall.images.other.blockNumberHolder.image(
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: Tween<double>(begin: 1.5, end: 1).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Text(
                    '$score',
                    key: ValueKey(score),
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: (scoreBlockHeight * 0.34).clamp(34.0, 56.0),
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: canSubmit
              ? () => controller.submitFinalHand(selectedCardIds.toList())
              : null,
          child: Container(
            width: 112,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: canSubmit ? Colors.white : const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 8,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              canSubmit ? FinalCallCopy.submit : FinalCallCopy.selectCards,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}
