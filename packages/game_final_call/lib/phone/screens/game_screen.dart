// [game_screen.dart] 는 파이널콜에서 사용하는 휴대폰 게임의 세부 진행 화면을 구성하는 파일이다.
//
// - [Package] : 파이널콜
// - [PhoneScreen] : 휴대폰 게임의 세부 진행 화면을 구성함
//
// 즉, 플레이어가 현재 단계와 가능한 행동을 확인하고 입력하기 위해 필요한 파일이다.

import 'package:game_final_call/phone/phone_board.dart';
import 'dart:async';
import 'package:game_kit/game_feedback.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:flutter/material.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/game_copy.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';
import 'package:game_final_call/phone/widgets/game_actions.dart';
import 'package:game_final_call/phone/widgets/hand_card_stack.dart';
import 'package:game_kit/phone/animations/control_entry_animation.dart';

// ============================================================

/// 휴대폰의 손패(왼쪽)와 조작 패널(오른쪽)을 표시합니다(Party Pop 시안).
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
    required this.regions,
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
  final PhoneGameRegions regions;

  @override
  State<FinalCallPhoneGameScreen> createState() =>
      _FinalCallPhoneGameScreenState();
}

class _FinalCallPhoneGameScreenState extends State<FinalCallPhoneGameScreen>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // 손패 공개 후 조작부 등장
  // ---------------------------------------------------------------------------
  // Liar's Poker와 동일한 컨트롤러·연출(ControlEntryAnimation)을 그대로
  // 사용합니다. 손패 펼치기가 끝나는 순간 상단바·타이머·조작부가 같은
  // 컨트롤러로 함께 등장합니다.
  late final AnimationController _controlsEntryController;
  int? _revealedRoundForEntry;
  String? _pendingActionLabel;
  int? _pendingActionRevision;

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
  PhoneGameRegions get regions => widget.regions;

  @override
  void initState() {
    super.initState();
    _controlsEntryController = AnimationController(
      vsync: this,
      duration: FinalCallPhoneTiming.controlsEntry,
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

  @override
  void didUpdateWidget(covariant FinalCallPhoneGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pendingActionRevision != null &&
        (controller.revision != _pendingActionRevision ||
            !controller.isMyTurn)) {
      _pendingActionLabel = null;
      _pendingActionRevision = null;
    }
  }

  void _showActionFeedback(String label) {
    setState(() {
      _pendingActionLabel = label;
      _pendingActionRevision = controller.revision;
    });
  }

  void _clearActionFeedback() {
    if (!mounted) return;
    setState(() {
      _pendingActionLabel = null;
      _pendingActionRevision = null;
    });
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

  /// 덱 또는 공개 카드에서 새 카드를 가져옵니다.
  Future<void> _draw(BuildContext context, String source) async {
    final expectedTurnUid = controller.turnUid;
    final expectedDeadline = controller.turnDeadlineAt;
    if (!controller.canDraw || _deadlinePassed(expectedDeadline)) return;
    if (source == 'discard' && controller.discardCard == null) return;
    _showActionFeedback(FinalCallCopy.newCard);
    final completed = await controller.draw(source);
    if (!completed && context.mounted) {
      _clearActionFeedback();
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
    _showActionFeedback('CALL');
    // 판을 뒤집는 선언이므로 강한 진동으로 확정감을 줍니다.
    GameFeedback.declare();
    onSelectedCardChanged(null);
    final completed = await controller.call();
    if (!completed && context.mounted) {
      _clearActionFeedback();
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
        final waitingForReveal = !handRevealed;
        return Stack(
          fit: StackFit.expand,
          children: [
            const FinalCallPopBackground(),
            SafeArea(
              child: waitingForReveal && regions.showHand
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
                  : regions.showHand
                  ? _buildBoard(context)
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  /// 왼쪽 손패와 오른쪽 조작 패널입니다(Party Pop 시안).
  Widget _buildBoard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = FinalCallPhoneLayout.cardWidth(constraints.biggest);
        return Padding(
          // 상단바 자체는 공용 셸(PhoneGameShell)이 이 자리 위에 겹쳐
          // 그립니다. 카드 위치가 달라지지 않도록 같은 높이만 비워 둡니다.
          padding: const EdgeInsets.fromLTRB(
            FinalCallPhoneLayout.edge,
            FinalCallPhoneLayout.topBarHeight,
            FinalCallPhoneLayout.edge,
            FinalCallPhoneLayout.edge,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildLandscapeHand(cardWidth)),
              const SizedBox(width: FinalCallPhoneLayout.gap),
              SizedBox(
                width: FinalCallPhoneLayout.panelWidth,
                // 상단바보다 살짝 늦게, 큰 버튼답게 떨어지는 heavyDrop
                // 연출로 조작 패널을 등장시킵니다.
                child: regions.showActions
                    ? ControlEntryAnimation(
                        animation: _controlsEntryController,
                        style: ControlEntryStyle.heavyDrop,
                        begin: 0.12,
                        end: 1,
                        child: FinalCallPhonePanel(
                          child: _buildControl(context),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLandscapeHand(double cardWidth) {
    final submitMode = controller.isFinalSubmitPhase;
    // 점수를 만든 카드 묶음은 고를 일이 없을 때만 손패 아래에 표시합니다.
    final showCombination =
        handRevealed &&
        !submitMode &&
        controller.pendingDraw == null &&
        controller.hand.isNotEmpty;
    final combination = showCombination
        ? finalCallBestCombination(controller.hand)
        : null;
    return FinalCallPhoneHandCardStack(
      cards: controller.hand,
      isLandscape: true,
      isRevealed: handRevealed,
      selectedCardId: selectedCardId,
      selectedCardIds: selectedFinalCardIds,
      newCardId: controller.pendingDraw?.id,
      replacingCardId: replacingCardId,
      replacementInProgress: replacementInProgress,
      cardWidth: cardWidth,
      selectionMode: submitMode
          ? FinalCallHandSelectionMode.submit
          : FinalCallHandSelectionMode.replace,
      combinationCardIds: combination?.cardIds ?? const {},
      combinationLabel: combination == null
          ? null
          : FinalCallCopy.combinationEquation(combination),
      selectionEnabled: controller.canCompleteTurn || submitMode,
      onRevealStarted: onRevealStarted,
      onRevealCompleted: _handleRevealCompleted,
      onCardSelected: submitMode
          ? onFinalCardSelected
          : (id) {
              onSelectedCardChanged(selectedCardId == id ? null : id);
            },
      onCardsReordered: controller.reorderHand,
    );
  }

  Widget _buildControl(BuildContext context) {
    final Widget child;
    final String key;
    if (controller.isFinalSubmitPhase) {
      key = 'submit';
      child = _FinalSubmitAction(
        controller: controller,
        selectedCardIds: selectedFinalCardIds,
      );
    } else if (_pendingActionLabel != null &&
        _pendingActionRevision == controller.revision &&
        controller.isMyTurn) {
      key = 'seal';
      child = Center(child: _FinalCallActionSeal(label: _pendingActionLabel!));
    } else if (controller.isMyTurn) {
      key = controller.pendingDraw == null ? 'turn-start' : 'pending-draw';
      child = FinalCallPhoneActions(
        controller: controller,
        selectedCardId: selectedCardId,
        onDraw: (source) => _draw(context, source),
        onCall: () => _call(context),
        onCompleteTurn: onCompleteTurn,
        replacementInProgress: replacementInProgress,
      );
    } else {
      key = 'waiting';
      child = FinalCallWaitingPanel(controller: controller);
    }
    // 패널 안 내용만 살짝 떠오르며 바뀌고, 흰 패널 틀은 제자리에 둡니다.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(key), child: child),
    );
  }
}

/// 명령을 보낸 직후 서버 스피너 대신 누른 행동을 짧게 각인합니다.
class _FinalCallActionSeal extends StatelessWidget {
  const _FinalCallActionSeal({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(label),
    tween: Tween(begin: .72, end: 1),
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeOutBack,
    builder: (context, scale, child) =>
        Transform.scale(scale: scale, child: child),
    child: Semantics(
      liveRegion: true,
      label: '$label 선택됨',
      excludeSemantics: true,
      child: FinalCallPopBox(
        color: FinalCallColors.violet,
        radius: 20,
        width: 150,
        height: 86,
        child: Center(
          child: Text(
            label,
            style: finalCallPopText(
              24,
              color: Colors.white,
              shadows: finalCallPopOutline(),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FinalSubmitAction extends StatefulWidget {
  const _FinalSubmitAction({
    required this.controller,
    required this.selectedCardIds,
  });
  final FinalCallController controller;
  final Set<String> selectedCardIds;

  @override
  State<_FinalSubmitAction> createState() => _FinalSubmitActionState();
}

class _FinalSubmitActionState extends State<_FinalSubmitAction> {
  int? _submittedRevision;

  @override
  void didUpdateWidget(covariant _FinalSubmitAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_submittedRevision != null &&
        (widget.controller.revision != _submittedRevision ||
            !widget.controller.isFinalSubmitPhase)) {
      _submittedRevision = null;
    }
  }

  Future<void> _submit() async {
    if (_submittedRevision != null || !widget.controller.canSubmitFinalHand) {
      return;
    }
    final cards = widget.selectedCardIds.toList(growable: false);
    if (cards.isEmpty) return;
    setState(() => _submittedRevision = widget.controller.revision);
    final completed = await widget.controller.submitFinalHand(cards);
    if (!mounted || completed) return;
    setState(() => _submittedRevision = null);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(widget.controller.actionErrorMessage)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final selectedCards = controller.hand
        .where((card) => widget.selectedCardIds.contains(card.id))
        .toList(growable: false);
    final combination = finalCallBestCombination(selectedCards);
    final score = combination.score;
    final best = finalCallBestCombination(controller.hand);
    final isPreset =
        widget.selectedCardIds.isNotEmpty &&
        widget.selectedCardIds.length == best.cardIds.length &&
        widget.selectedCardIds.containsAll(best.cardIds);
    final submitted = _submittedRevision == controller.revision;
    final hasSelection = widget.selectedCardIds.isNotEmpty;
    final canSubmit =
        !submitted && hasSelection && controller.canSubmitFinalHand;
    final label = submitted
        ? FinalCallCopy.submitted
        : hasSelection
        ? FinalCallCopy.submit
        : FinalCallCopy.selectCards;
    return Column(
      children: [
        Text(
          FinalCallCopy.myScore,
          style: finalCallPopText(16, color: FinalCallColors.muted),
        ),
        // 선택한 최종 조합의 현재 점수를 즉시 다시 계산해 표시합니다.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: Tween<double>(begin: 1.4, end: 1).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Text(
            '$score',
            key: ValueKey(score),
            style: finalCallPopText(
              72,
              color: FinalCallColors.violet,
              height: 1,
              shadows: finalCallPopOutline(3),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hasSelection
              ? FinalCallCopy.combinationName(
                  combination,
                  finalCallCardColorLabel,
                )
              : FinalCallCopy.selectFinalCombination,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: finalCallPopText(16),
        ),
        if (isPreset && !submitted) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: FinalCallColors.lilac,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              FinalCallCopy.presetBest,
              style: finalCallPopText(12, color: FinalCallColors.muted),
            ),
          ),
        ],
        const Spacer(),
        FinalCallPopButton(
          semanticLabel: submitted ? '최종 조합 선택됨' : label,
          onPressed: canSubmit ? () => unawaited(_submit()) : null,
          color: FinalCallColors.green,
          height: 52,
          borderWidth: 4,
          shadowDepth: 5,
          child: Text(
            label,
            style: finalCallPopText(
              22,
              color: Colors.white,
              shadows: finalCallPopOutline(),
            ),
          ),
        ),
      ],
    );
  }
}
