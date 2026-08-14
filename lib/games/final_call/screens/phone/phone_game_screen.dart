import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_controller.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';
import 'package:project00/games/final_call/widgets/phone/phone_card_change_dialog.dart';
import 'package:project00/games/final_call/widgets/phone/phone_game_actions.dart';
import 'package:project00/games/final_call/widgets/phone/phone_hand_card_stack.dart';
import 'package:project00/games/final_call/widgets/phone/phone_turn_action_switcher.dart';
import 'package:project00/games/final_call/widgets/phone/phone_turn_timer.dart';
import 'package:project00/games/shared/widgets/phone_game_top_bar.dart';
import 'package:project00/games/shared/widgets/phone_rule_dialog.dart';
import 'package:project00/games/shared/widgets/phone_ripple_dialog.dart';
import 'package:project00/gen/assets.gen.dart';

/// 휴대폰의 손패와 조작부를 분리된 두 영역으로 표시합니다.
class PhoneGameScreen extends StatelessWidget {
  const PhoneGameScreen({
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

  final PhoneGameController controller;
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

  Future<void> _openCardChange(BuildContext context) async {
    final discard = controller.discardCard;
    final expectedTurnUid = controller.turnUid;
    final expectedDeadline = controller.turnDeadlineAt;
    if (discard == null ||
        !controller.canDraw ||
        _deadlinePassed(expectedDeadline)) {
      return;
    }
    final source = await showDialog<String>(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => FinalCallCardChangeDialog(
        discardCard: discard,
        canSelectDeck: controller.deckRemainingCount > 0,
      ),
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
      deadline != null && DateTime.now().millisecondsSinceEpoch >= deadline;

  Future<void> _call(BuildContext context) async {
    if (!controller.canCall) return;
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 16, 0),
                  child: SharedPhoneGameTopBar(
                    isLandscape: true,
                    trailingLeading: _buildLives(),
                    bookIcon: Assets.games.finalCall.images.icons.iconTipBlack
                        .image(fit: BoxFit.contain),
                    outIcon: Assets.games.finalCall.images.icons.iconOut.image(
                      fit: BoxFit.contain,
                    ),
                    onOutPressed: onExitRoom,
                    onBookPressed: () => _showRules(context),
                    onBookPressedAt: (origin) => _showRules(context, origin),
                  ),
                ),
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
                                child: _buildControl(context, cardHeight),
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
                                child: FinalCallTimer(
                                  key: ValueKey(controller.turnDeadlineAt),
                                  deadline: controller.turnDeadlineAt!,
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
                      onRevealCompleted: onRevealCompleted,
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

  void _showRules(BuildContext context, [Offset? origin]) {
    final screenSize = MediaQuery.sizeOf(context);
    showPhoneRippleDialog<void>(
      context: context,
      origin: origin ?? Offset(screenSize.width - 82, 28),
      builder: (_) => const PhoneGameRuleDialog(
        title: 'FINAL CALL',
        rules:
            '같은 숫자 카드의 합과 같은 색 카드의 합 중 더 높은 값이 '
            '최종 점수입니다. 자신의 턴에는 공개 카드 또는 카드 더미에서 '
            '한 장을 가져와 손패와 교체하거나 버릴 수 있습니다.\n\n'
            'CALL을 선언하면 나머지 플레이어가 마지막 교체를 한 번 진행합니다. '
            '가장 낮은 점수의 플레이어는 생명 1개를 잃고, CALL을 선언한 '
            '플레이어가 최하위라면 생명 2개를 잃습니다. 마지막 생존자가 승리합니다.',
        surfaceColor: Color.fromARGB(255, 0, 0, 0),
        foregroundColor: Color.fromARGB(255, 255, 255, 255),
        showSurface: false,
        dismissOnAnyTap: true,
      ),
    );
  }

  Widget _buildLives() {
    final lives = controller.players[controller.uid]?.lives ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < lives; index++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Assets.games.finalCall.images.icons.iconHeart.image(
              width: 38,
              fit: BoxFit.contain,
            ),
          ),
      ],
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
        onRevealCompleted: onRevealCompleted,
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
  final PhoneGameController controller;
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
          '최종 조합을 선택하세요',
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
              canSubmit ? '제출' : '카드 선택',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}
