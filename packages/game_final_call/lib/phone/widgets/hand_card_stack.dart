// [hand_card_stack.dart] 는 파이널콜에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
//
// - [Package] : 파이널콜
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI를 구성함
//
// 즉, 플레이어 입력과 상태 표시를 작은 책임으로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:game_final_call/phone/animations/card_receive_animation.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/widgets/card_view.dart';
import 'package:game_final_call/game_copy.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';

// ============================================================

/// 휴대폰 가로 화면의 손패·조작 패널 배치입니다(Party Pop 시안).
///
/// 손패 받기 연출과 펼친 손패가 같은 위치·크기를 쓰도록 한곳에서 계산합니다.
abstract final class FinalCallPhoneLayout {
  /// 상단바 높이(시안 58)입니다.
  static const topBarHeight = 58.0;

  /// 화면 가장자리 여백입니다.
  static const edge = 14.0;

  /// 손패와 조작 패널 사이 간격입니다.
  static const gap = 14.0;

  /// 오른쪽 조작 패널 폭(시안 222)입니다.
  static const panelWidth = 222.0;

  /// 시안 카드 폭(104)보다 조금 큰 상한입니다.
  static const maxCardWidth = 112.0;

  static Size handArea(Size screen) => Size(
    math.max(1.0, screen.width - edge * 2 - gap - panelWidth),
    math.max(1.0, screen.height - topBarHeight - edge),
  );

  static double cardWidth(Size screen) => math.min(
    maxCardWidth,
    FinalCallPhoneHandCardStack.cardWidthFor(
      BoxConstraints.loose(handArea(screen)),
      true,
    ),
  );

  /// 화면 중심에서 손패 영역 중심까지의 거리입니다.
  static Offset handCenterOffset(Size screen) =>
      Offset(-(gap + panelWidth) / 2, (topBarHeight - edge) / 2);
}

/// 라운드마다 처음에는 한 덱으로 들어오고, 탭한 뒤 펼쳐진 손패를 유지합니다.
class FinalCallPhoneHandCardStack extends StatelessWidget {
  const FinalCallPhoneHandCardStack({
    super.key,
    required this.cards,
    required this.isLandscape,
    required this.isRevealed,
    required this.selectedCardId,
    this.selectedCardIds = const {},
    required this.onRevealStarted,
    required this.onRevealCompleted,
    required this.onCardSelected,
    required this.onCardsReordered,
    this.newCardId,
    this.selectionEnabled = false,
    this.replacingCardId,
    this.replacementInProgress = false,
    this.cardWidth,
    this.selectionMode = FinalCallHandSelectionMode.replace,
    this.combinationCardIds = const {},
    this.combinationLabel,
  });

  final List<FinalCallCard> cards;
  final bool isLandscape;
  final bool isRevealed;
  final String? selectedCardId;
  final Set<String> selectedCardIds;
  final String? newCardId;
  final bool selectionEnabled;
  final String? replacingCardId;
  final bool replacementInProgress;
  final double? cardWidth;

  /// 교체할 한 장을 고르는지, 최종 조합 여러 장을 고르는지입니다.
  final FinalCallHandSelectionMode selectionMode;

  /// 지금 점수를 만든 카드입니다. 비어 있으면 묶음 표시를 그리지 않습니다.
  final Set<String> combinationCardIds;

  /// 묶음 아래 꼬리표 문구입니다(예: 7 + 7 = 14점).
  final String? combinationLabel;
  final VoidCallback onRevealStarted;
  final VoidCallback onRevealCompleted;
  final ValueChanged<String> onCardSelected;
  final void Function(String draggedCardId, String targetCardId)
  onCardsReordered;

  @override
  Widget build(BuildContext context) {
    if (!isRevealed) {
      return FinalCallCardReceiveAnimation(
        key: ValueKey(
          'final-call-deal-${cards.map((card) => card.id).join('-')}',
        ),
        cards: cards,
        isLandscape: isLandscape,
        onRevealStarted: onRevealStarted,
        onCompleted: onRevealCompleted,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final safeWidth = cardWidthFor(constraints, isLandscape);
        final width = cardWidth == null
            ? safeWidth
            : math.min(cardWidth!, safeWidth);
        const cardGap = 8.0;
        // 카드 그림은 선택 테두리(3)와 안쪽 여백(3)만큼 상자 안에서 밀려 있어,
        // 상자를 기준으로 가운데 정렬하면 카드 자체는 그만큼 오른쪽·아래로
        // 치우칩니다. 펼침 애니메이션은 카드 자체를 가운데 두므로 그 차이가
        // 전환 순간 튀어 보입니다. 여기서 같은 값을 보정해 위치를 맞춥니다.
        const cardInset = 3.0;
        final cardBoxWidth = width + 6;
        final cardBoxHeight = width * finalCallCardHeightRatio + 6;
        final totalWidth =
            cardBoxWidth * cards.length +
            cardGap * math.max(0, cards.length - 1);
        // 손패가 영역을 꽉 채우는 화면에서도 가운데 정렬을 유지합니다.
        // 0으로 자르면 줄 전체가 왼쪽으로 붙어 펼침 위치와 어긋납니다.
        final firstLeft = (constraints.maxWidth - totalWidth) / 2 - cardInset;
        final cardTop = (constraints.maxHeight - cardBoxHeight) / 2 - cardInset;

        final comboIndexes = [
          for (var index = 0; index < cards.length; index++)
            if (combinationCardIds.contains(cards[index].id)) index,
        ];
        final label = combinationLabel;
        return SizedBox.expand(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 점수를 만든 카드를 아래에서 노란 괄호로 묶고 계산식을 답니다.
              if (comboIndexes.isNotEmpty && label != null)
                Positioned(
                  key: const ValueKey('final-call-combination-bracket'),
                  left:
                      firstLeft +
                      cardInset +
                      comboIndexes.first * (cardBoxWidth + cardGap),
                  width:
                      (comboIndexes.last - comboIndexes.first) *
                          (cardBoxWidth + cardGap) +
                      width,
                  top:
                      cardTop +
                      cardInset +
                      width * finalCallCardHeightRatio +
                      12,
                  child: _CombinationBracket(label: label),
                ),
              for (var index = 0; index < cards.length; index++)
                AnimatedPositioned(
                  key: ValueKey('final-call-hand-position-${cards[index].id}'),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  left: firstLeft + index * (cardBoxWidth + cardGap),
                  top: cardTop,
                  child: _SelectableHandCard(
                    key: ValueKey(cards[index].id),
                    card: cards[index],
                    width: width,
                    selected:
                        selectedCardIds.contains(cards[index].id) ||
                        selectedCardId == cards[index].id,
                    mode: selectionMode,
                    dimmed:
                        selectionMode == FinalCallHandSelectionMode.submit &&
                        selectedCardIds.isNotEmpty &&
                        !selectedCardIds.contains(cards[index].id),
                    showNew: cards[index].id == newCardId,
                    replacing:
                        replacementInProgress &&
                        replacingCardId == cards[index].id,
                    onTap: selectionEnabled
                        ? () => onCardSelected(cards[index].id)
                        : null,
                    onReorder: replacementInProgress
                        ? null
                        : (draggedCardId) =>
                              onCardsReordered(draggedCardId, cards[index].id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 카드 4장, 선택 이동, 체크 표식을 모두 포함해 주어진 영역을 넘지 않는
  /// 카드 너비를 계산합니다.
  static double cardWidthFor(BoxConstraints constraints, bool isLandscape) {
    // 카드마다 선택 테두리 패딩 6px, 카드 사이에는 8px가 추가됩니다.
    const horizontalPadding = 48.0;
    final maxByWidth = math.max(
      1.0,
      (constraints.maxWidth - horizontalPadding) / 4,
    );
    final maxByHeight = math.max(
      1.0,
      (constraints.maxHeight - 78) / finalCallCardHeightRatio,
    );
    return math.min(
      isLandscape ? 138.0 : 92.0,
      math.min(maxByWidth, maxByHeight),
    );
  }
}

/// 손패에서 카드를 고르는 방식입니다.
enum FinalCallHandSelectionMode {
  /// 새 카드와 바꿀 한 장을 고릅니다(기울어진 노란 테두리 + '바꿀 카드').
  replace,

  /// 최종 점수에 쓸 여러 장을 고릅니다(초록 체크, 고르지 않은 카드는 흐리게).
  submit,
}

class _CombinationBracket extends StatelessWidget {
  const _CombinationBracket({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Positioned.fill(
          bottom: 26,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: const Border(
                left: BorderSide(color: FinalCallColors.yellow, width: 3),
                right: BorderSide(color: FinalCallColors.yellow, width: 3),
                bottom: BorderSide(color: FinalCallColors.yellow, width: 3),
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
          ),
        ),
        Positioned(top: 8, child: FinalCallPopTag(label: label)),
      ],
    ),
  );
}

class _SelectableHandCard extends StatelessWidget {
  const _SelectableHandCard({
    super.key,
    required this.card,
    required this.width,
    required this.selected,
    required this.mode,
    required this.dimmed,
    required this.showNew,
    required this.replacing,
    required this.onTap,
    required this.onReorder,
  });

  final FinalCallCard card;
  final double width;
  final bool selected;
  final FinalCallHandSelectionMode mode;
  final bool dimmed;
  final bool showNew;
  final bool replacing;
  final VoidCallback? onTap;
  final ValueChanged<String>? onReorder;

  @override
  Widget build(BuildContext context) {
    final replaceSelected =
        selected && mode == FinalCallHandSelectionMode.replace;
    final submitSelected =
        selected && mode == FinalCallHandSelectionMode.submit;
    final unit = width / 104;
    final face = GestureDetector(
      onTap: onTap,
      child: AnimatedSlide(
        offset: replacing ? const Offset(1.8, 0) : Offset.zero,
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeInOutCubic,
        child: AnimatedOpacity(
          opacity: replacing
              ? 0
              : dimmed
              ? 0.55
              : 1,
          duration: const Duration(milliseconds: 220),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: selected ? 1 : 0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            builder: (context, lift, child) => Transform.translate(
              offset: Offset(0, -16 * unit * lift),
              child: Transform.rotate(
                angle: replaceSelected ? 0.052 * lift : 0,
                child: child,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: replaceSelected
                          ? FinalCallColors.highlight
                          : Colors.transparent,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(20 * unit),
                  ),
                  child: FinalCallCardView(card: card, width: width),
                ),
                if (replaceSelected)
                  Positioned(
                    bottom: -30,
                    child: FinalCallPopTag(label: FinalCallCopy.replaceTarget),
                  ),
                if (submitSelected)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      key: ValueKey('final-call-submit-check-${card.id}'),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: FinalCallColors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: FinalCallColors.ink,
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                if (showNew)
                  const Positioned(
                    top: -14,
                    right: -10,
                    child: FinalCallPopTag(
                      label: 'NEW',
                      color: FinalCallColors.red,
                      textColor: Colors.white,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final reorder = onReorder;
    if (reorder == null) return face;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != card.id,
      onAcceptWithDetails: (details) => reorder(details.data),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<String>(
          data: card.id,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: Material(
            color: Colors.transparent,
            child: Transform.translate(
              offset: Offset(-width / 2, -width * 0.72),
              child: Transform.scale(
                scale: 1.06,
                child: FinalCallCardView(card: card, width: width),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.24, child: face),
          child: AnimatedScale(
            scale: candidateData.isEmpty ? 1 : 1.04,
            duration: const Duration(milliseconds: 140),
            child: face,
          ),
        );
      },
    );
  }
}
