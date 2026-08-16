import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:project00/games/final_call/animations/phone_card_receive_animation.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';

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
  final VoidCallback onRevealStarted;
  final VoidCallback onRevealCompleted;
  final ValueChanged<String> onCardSelected;
  final void Function(String draggedCardId, String targetCardId)
  onCardsReordered;

  @override
  Widget build(BuildContext context) {
    if (!isRevealed) {
      return FinalCallPhoneCardReceiveAnimation(
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

        return SizedBox.expand(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
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

class _SelectableHandCard extends StatefulWidget {
  const _SelectableHandCard({
    super.key,
    required this.card,
    required this.width,
    required this.selected,
    required this.showNew,
    required this.replacing,
    required this.onTap,
    required this.onReorder,
  });

  final FinalCallCard card;
  final double width;
  final bool selected;
  final bool showNew;
  final bool replacing;
  final VoidCallback? onTap;
  final ValueChanged<String>? onReorder;

  @override
  State<_SelectableHandCard> createState() => _SelectableHandCardState();
}

class _SelectableHandCardState extends State<_SelectableHandCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bobController;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _syncBobAnimation();
  }

  @override
  void didUpdateWidget(_SelectableHandCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        oldWidget.replacing != widget.replacing) {
      _syncBobAnimation();
    }
  }

  void _syncBobAnimation() {
    if (widget.selected && !widget.replacing) {
      _bobController.repeat(reverse: true);
    } else {
      _bobController.stop();
      _bobController.value = 0;
    }
  }

  @override
  void dispose() {
    _bobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onTap: widget.onTap,
      child: AnimatedSlide(
        offset: widget.replacing ? const Offset(1.8, 0) : Offset.zero,
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeInOutCubic,
        child: AnimatedOpacity(
          opacity: widget.replacing ? 0 : 1,
          duration: const Duration(milliseconds: 460),
          child: AnimatedBuilder(
            animation: _bobController,
            builder: (context, child) {
              final bob = widget.selected
                  ? -8 - (5 * _bobController.value)
                  : 0.0;
              return Transform.translate(offset: Offset(0, bob), child: child);
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: widget.selected
                          ? const Color(0xFFE5DB00)
                          : Colors.transparent,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FinalCallCardView(
                    card: widget.card,
                    width: widget.width,
                  ),
                ),
                if (widget.selected)
                  const Positioned(
                    bottom: -13,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: Color(0xFFE5DB00), width: 2),
                        ),
                      ),
                      child: SizedBox.square(
                        dimension: 27,
                        child: Icon(
                          Icons.check_rounded,
                          color: Color(0xFFE5DB00),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                if (widget.showNew)
                  const Positioned(
                    top: -20,
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.white, blurRadius: 3)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final onReorder = widget.onReorder;
    if (onReorder == null) return card;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != widget.card.id,
      onAcceptWithDetails: (details) => onReorder(details.data),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<String>(
          data: widget.card.id,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: Material(
            color: Colors.transparent,
            child: Transform.translate(
              offset: Offset(-widget.width / 2, -widget.width * 0.72),
              child: Transform.scale(
                scale: 1.06,
                child: FinalCallCardView(
                  card: widget.card,
                  width: widget.width,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.24, child: card),
          child: AnimatedScale(
            scale: candidateData.isEmpty ? 1 : 1.04,
            duration: const Duration(milliseconds: 140),
            child: card,
          ),
        );
      },
    );
  }
}
