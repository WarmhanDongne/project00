import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/animations/phone_card_receive_animation.dart';
import 'package:project00/gen/assets.gen.dart';

/// 휴대폰 손패를 선택하고 위로 끌어 제출하는 위젯입니다.
///
/// 최대 3장까지 선택할 수 있으며, 선택된 카드 중 하나를 위로 끌면
/// 선택 카드가 함께 움직입니다. 제출 높이를 넘는 순간 [onCardsSubmitted]를
/// 호출하고 남은 카드를 새 개수 기준으로 중앙에 다시 정렬합니다.
class HandCardStackPortrait extends StatefulWidget {
  const HandCardStackPortrait({
    super.key,
    this.cards,
    this.enabled = true,
    this.submissionEnabled = true,
    this.maxSelection = 3,
    this.onSelectionChanged,
    this.onCardsSubmitRequested,
    this.onCardsSubmitted,
    this.onRevealStarted,
    this.onRevealCompleted,
    this.initiallyRevealed = false,
    this.cardWidth = 169.0,
    this.spreadStepX = 35.0,
    this.spreadStepY = 35.0,
    this.rightCardOnTop = true,
    this.spreadToLeft = false,
    this.entryCenterOffsetX = 0,
    this.entryCenterOffsetY = 0,
  }) : assert(maxSelection > 0);

  final List<AssetGenImage>? cards;
  final bool enabled;
  final bool submissionEnabled;
  final int maxSelection;
  final ValueChanged<List<int>>? onSelectionChanged;
  final Future<bool> Function(List<int> indexes)? onCardsSubmitRequested;
  final ValueChanged<List<int>>? onCardsSubmitted;
  final VoidCallback? onRevealStarted;
  final VoidCallback? onRevealCompleted;
  final bool initiallyRevealed;
  final double cardWidth;
  final double spreadStepX;
  final double spreadStepY;
  final bool rightCardOnTop;
  final bool spreadToLeft;
  final double entryCenterOffsetX;
  final double entryCenterOffsetY;

  @override
  State<HandCardStackPortrait> createState() => _HandCardStackPortrait();
}

class _HandCardStackPortrait extends State<HandCardStackPortrait> {
  static const double _selectedElevation = 20.0;
  static const double _submitThreshold = 82.0;
  static const double _submitExitOffset = 330.0;
  static const Duration _submitExitDuration = Duration(milliseconds: 420);

  final Set<int> _selectedCardIds = <int>{};
  late List<_HandCardEntry> _renderCards;

  int _nextCardId = 0;
  late bool _isDealing;
  bool _isDragging = false;
  bool _isSubmitting = false;
  bool _showMaxSelectionMessage = false;
  int? _draggingCardId;
  double _dragOffsetY = 0;
  List<AssetGenImage>? _pendingCards;
  Timer? _maxSelectionMessageTimer;

  @override
  void initState() {
    super.initState();
    _isDealing = !widget.initiallyRevealed;
    _replaceCards(widget.cards ?? _defaultCards);
  }

  @override
  void didUpdateWidget(HandCardStackPortrait oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.cards != null && oldWidget.cards != widget.cards) {
      // 제출 중 서버 손패가 먼저 갱신되어도 화면을 즉시 바꾸지 않습니다.
      // 카드가 화면 밖으로 이동한 다음 새 손패를 반영해야 중간 끊김이 없습니다.
      if (_isSubmitting) {
        _pendingCards = List<AssetGenImage>.of(widget.cards!);
      } else {
        _replaceCards(widget.cards!);
        _notifySelectionChanged();
      }
    }

    if (!oldWidget.initiallyRevealed && widget.initiallyRevealed) {
      _isDealing = false;
    }

    if (oldWidget.enabled &&
        !widget.enabled &&
        _selectedCardIds.isNotEmpty &&
        !_isSubmitting) {
      _selectedCardIds.clear();
      _isDragging = false;
      _draggingCardId = null;
      _dragOffsetY = 0;
      _notifySelectionChanged();
    }

    // 차례가 넘어가 제출만 비활성화되면 선택은 유지하고 드래그만 취소합니다.
    if (oldWidget.submissionEnabled &&
        !widget.submissionEnabled &&
        _isDragging &&
        !_isSubmitting) {
      _isDragging = false;
      _draggingCardId = null;
      _dragOffsetY = 0;
    }
  }

  @override
  void dispose() {
    _maxSelectionMessageTimer?.cancel();
    super.dispose();
  }

  List<AssetGenImage> get _defaultCards => [
    Assets.games.liarsPoker.images.cards.whiteK,
    Assets.games.liarsPoker.images.cards.whiteQ,
    Assets.games.liarsPoker.images.cards.whiteA,
    Assets.games.liarsPoker.images.cards.whiteA,
    Assets.games.liarsPoker.images.cards.whiteJoker,
  ];

  void _replaceCards(List<AssetGenImage> cards) {
    _renderCards = [
      for (final card in cards) _HandCardEntry(id: _nextCardId++, asset: card),
    ];
    _selectedCardIds.clear();
    _isDragging = false;
    _draggingCardId = null;
    _dragOffsetY = 0;
  }

  List<int> get _selectedIndexes => [
    for (var index = 0; index < _renderCards.length; index++)
      if (_selectedCardIds.contains(_renderCards[index].id)) index,
  ];

  void _toggleSelection(int cardId) {
    if (!widget.enabled || _isSubmitting) return;

    if (!_selectedCardIds.contains(cardId) &&
        _selectedCardIds.length >= widget.maxSelection) {
      _showSelectionLimitMessage();
      return;
    }

    setState(() {
      if (!_selectedCardIds.remove(cardId)) {
        _selectedCardIds.add(cardId);
      }
    });
    _notifySelectionChanged();
  }

  void _startDragging(int cardId) {
    if (!widget.enabled || !widget.submissionEnabled || _isSubmitting) return;

    var selectionChanged = false;

    if (!_selectedCardIds.contains(cardId)) {
      if (_selectedCardIds.length >= widget.maxSelection) {
        _showSelectionLimitMessage();
        return;
      }
      selectionChanged = true;
    }

    setState(() {
      if (selectionChanged) {
        _selectedCardIds.add(cardId);
      }
      _isDragging = true;
      _draggingCardId = cardId;
      _dragOffsetY = 0;
    });

    if (selectionChanged) {
      _notifySelectionChanged();
    }
  }

  void _updateDrag(DragUpdateDetails details) {
    if (!widget.enabled ||
        !widget.submissionEnabled ||
        !_isDragging ||
        _draggingCardId == null ||
        _isSubmitting) {
      return;
    }

    final nextOffset = (_dragOffsetY + details.delta.dy).clamp(
      -_submitThreshold - 24,
      0.0,
    );

    if (nextOffset <= -_submitThreshold) {
      _dragOffsetY = -_submitThreshold;
      unawaited(_submitSelectedCards());
      return;
    }

    setState(() {
      _dragOffsetY = nextOffset;
    });
  }

  void _finishDrag() {
    if (!_isDragging || _isSubmitting) return;

    setState(() {
      _isDragging = false;
      _draggingCardId = null;
      _dragOffsetY = 0;
    });
  }

  Future<void> _submitSelectedCards() async {
    if (_selectedCardIds.isEmpty ||
        !widget.submissionEnabled ||
        _isSubmitting) {
      return;
    }

    final submittedIndexes = List<int>.unmodifiable(_selectedIndexes);
    final submittedIds = Set<int>.of(_selectedCardIds);
    setState(() {
      _isSubmitting = true;
      _isDragging = false;
      _draggingCardId = null;
      _dragOffsetY = -_submitExitOffset;
    });

    final submitRequested = widget.onCardsSubmitRequested;
    var accepted = true;

    // 서버 응답과 카드 이동을 동시에 시작합니다. 서버가 빨라도 애니메이션은
    // 끝까지 보여주고, 느려도 별도의 로딩 정지 없이 카드가 먼저 움직입니다.
    await Future.wait<void>([
      Future<void>(() async {
        accepted = submitRequested == null
            ? true
            : await submitRequested(submittedIndexes);
      }),
      Future<void>.delayed(_submitExitDuration),
    ]);
    if (!mounted) return;

    if (!accepted) {
      final pendingCards = _pendingCards;
      setState(() {
        // 함수 응답만 실패하고 RTDB에는 제출 결과가 반영된 경우가 있습니다.
        // 이때는 서버에서 먼저 도착한 손패를 신뢰해 제출 카드가 되살아나지
        // 않도록 합니다.
        if (pendingCards != null) {
          _replaceCards(pendingCards);
        }
        _pendingCards = null;
        _isSubmitting = false;
        if (pendingCards == null) {
          _isDragging = false;
          _draggingCardId = null;
          _dragOffsetY = 0;
        }
      });
      if (pendingCards != null) {
        _notifySelectionChanged();
      }
      return;
    }

    setState(() {
      // 기존 카드 ID를 유지해야 남은 카드가 순간 교체되지 않고 중앙으로
      // 자연스럽게 재배치됩니다. 대기 중인 서버 값은 이미 같은 제출 결과이므로
      // 여기서는 선택 카드만 로컬 목록에서 제거합니다.
      _renderCards.removeWhere((card) => submittedIds.contains(card.id));
      _selectedCardIds.clear();
      _isDragging = false;
      _draggingCardId = null;
      _dragOffsetY = 0;
      _pendingCards = null;
      _isSubmitting = false;
    });

    widget.onSelectionChanged?.call(const []);
    widget.onCardsSubmitted?.call(submittedIndexes);
  }

  void _notifySelectionChanged() {
    widget.onSelectionChanged?.call(List<int>.unmodifiable(_selectedIndexes));
  }

  void _showSelectionLimitMessage() {
    _maxSelectionMessageTimer?.cancel();

    if (!_showMaxSelectionMessage) {
      setState(() {
        _showMaxSelectionMessage = true;
      });
    }

    _maxSelectionMessageTimer = Timer(const Duration(milliseconds: 1250), () {
      if (!mounted) return;
      setState(() {
        _showMaxSelectionMessage = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isDealing) {
      return PhoneCardReceiveAnimation(
        frontCardAssets: _renderCards
            .map((card) => card.asset)
            .toList(growable: false),
        cardWidth: widget.cardWidth,
        spreadStepX: widget.spreadStepX,
        spreadStepY: widget.spreadStepY,
        spreadToLeft: widget.spreadToLeft,
        entryCenterOffsetX: widget.entryCenterOffsetX,
        entryCenterOffsetY: widget.entryCenterOffsetY,
        onRevealStarted: widget.onRevealStarted,
        onCompleted: () {
          if (!mounted) return;

          setState(() {
            _isDealing = false;
          });
          widget.onRevealCompleted?.call();
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 400,
          constraints.hasBoundedHeight ? constraints.maxHeight : 600,
        );
        final centerX = size.width / 2;
        final centerY = size.height / 2;
        const cardAspectRatio = 512 / 350;
        final cardHeight = widget.cardWidth * cardAspectRatio;
        final cardCount = _renderCards.length;

        // 선택 여부와 관계없이 원래 손패 순서대로 겹쳐서 그립니다.
        final indexedCards = _renderCards.asMap().entries.toList();
        final paintOrder = widget.rightCardOnTop
            ? indexedCards
            : indexedCards.reversed;

        return SizedBox.fromSize(
          size: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final indexedCard in paintOrder)
                _buildCard(
                  card: indexedCard.value,
                  cardIndex: indexedCard.key,
                  cardCount: cardCount,
                  centerX: centerX,
                  centerY: centerY,
                  containerWidth: size.width,
                  cardHeight: cardHeight,
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _showMaxSelectionMessage ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: AnimatedScale(
                        scale: _showMaxSelectionMessage ? 1 : 0.96,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: _SelectionLimitMessage(
                          maxSelection: widget.maxSelection,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required _HandCardEntry card,
    required int cardIndex,
    required int cardCount,
    required double centerX,
    required double centerY,
    required double containerWidth,
    required double cardHeight,
  }) {
    final centeredIndex = cardIndex - (cardCount - 1) / 2;
    final isSelected = _selectedCardIds.contains(card.id);
    final baseCenterX = widget.spreadToLeft
        ? _leftSpreadCardCenter(
            centerX: centerX,
            containerWidth: containerWidth,
            cardIndex: cardIndex,
            cardCount: cardCount,
          )
        : centerX + centeredIndex * widget.spreadStepX;
    final baseLeft = baseCenterX - widget.cardWidth / 2;
    final baseTop =
        centerY + centeredIndex * widget.spreadStepY - cardHeight / 2;
    final dragOffset = isSelected ? _dragOffsetY : 0.0;

    return AnimatedPositioned(
      key: ValueKey(card.id),
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      left: baseLeft,
      top: isSelected ? baseTop - _selectedElevation : baseTop,
      child: AnimatedContainer(
        duration: _isDragging
            ? Duration.zero
            : _isSubmitting
            ? _submitExitDuration
            : const Duration(milliseconds: 260),
        curve: _isSubmitting ? Curves.easeInCubic : Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, dragOffset, 0),
        transformAlignment: Alignment.center,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? () => _toggleSelection(card.id) : null,
          onVerticalDragStart: widget.enabled && widget.submissionEnabled
              ? (_) => _startDragging(card.id)
              : null,
          onVerticalDragUpdate: widget.enabled && widget.submissionEnabled
              ? _updateDrag
              : null,
          onVerticalDragEnd: widget.enabled && widget.submissionEnabled
              ? (_) => _finishDrag()
              : null,
          onVerticalDragCancel: widget.enabled && widget.submissionEnabled
              ? _finishDrag
              : null,
          child: Semantics(
            selected: isSelected,
            label: isSelected ? '선택된 카드' : '선택하지 않은 카드',
            child: _StaticCardFace(
              asset: card.asset,
              cardWidth: widget.cardWidth,
              cardHeight: cardHeight,
              isSelected: isSelected,
            ),
          ),
        ),
      ),
    );
  }

  double _leftSpreadCardCenter({
    required double centerX,
    required double containerWidth,
    required int cardIndex,
    required int cardCount,
  }) {
    final availableSpread = math.max(
      0.0,
      containerWidth - widget.cardWidth - 16,
    );
    final spreadStep = cardCount <= 1
        ? 0.0
        : math.min(widget.spreadStepX.abs(), availableSpread / (cardCount - 1));
    final totalSpread = spreadStep * math.max(0, cardCount - 1);
    final maxAnchorX = math.max(
      widget.cardWidth / 2,
      containerWidth - widget.cardWidth / 2 - 8,
    );
    final rightAnchorX = math.min(centerX + totalSpread / 2, maxAnchorX);
    return rightAnchorX - (cardCount - 1 - cardIndex) * spreadStep;
  }
}

class _SelectionLimitMessage extends StatelessWidget {
  const _SelectionLimitMessage({required this.maxSelection});

  final int maxSelection;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEB1D2922),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x668CA695)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Text(
          '최대 $maxSelection장만 선택할 수 있습니다',
          style: const TextStyle(
            color: Color(0xFFD8E2DB),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _HandCardEntry {
  const _HandCardEntry({required this.id, required this.asset});

  final int id;
  final AssetGenImage asset;
}

class _StaticCardFace extends StatelessWidget {
  const _StaticCardFace({
    required this.asset,
    required this.cardWidth,
    required this.cardHeight,
    required this.isSelected,
  });

  static const Color _selectedBorderColor = Color(0xFF8CA695);
  static const Color _selectedShadowColor = Color(0x66394F42);

  final AssetGenImage asset;
  final double cardWidth;
  final double cardHeight;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: isSelected ? _selectedShadowColor : const Color(0x66000000),
            blurRadius: isSelected ? 14 : 7,
            spreadRadius: isSelected ? 1 : 0,
            offset: isSelected ? const Offset(0, 8) : const Offset(0, 5),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: _selectedBorderColor, width: 2.4)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: asset.image(
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
