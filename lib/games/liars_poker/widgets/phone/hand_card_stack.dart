import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:project00/games/liars_poker/liars_poker_copy.dart';
import 'package:project00/games/liars_poker/liars_poker_flow_config.dart';
import 'package:project00/games/shared/animations/phone_card_receive_animation.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';
import 'package:project00/games/shared/widgets/game_announcement_layer.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/core/assets/game_image.dart';

/// 손패 선택 상태를 버튼에 전달하고 외부 SUBMIT 버튼으로 제출을 시작합니다.
class PhoneHandCardStackController extends ChangeNotifier {
  Object? _owner;
  Future<void> Function()? _submitSelection;
  List<int> _selectedIndexes = const [];
  bool _disposed = false;

  List<int> get selectedIndexes => _selectedIndexes;
  bool get hasSelection => _selectedIndexes.isNotEmpty;

  Future<void> submitSelectedCards() async {
    await _submitSelection?.call();
  }

  void _attach(Object owner, Future<void> Function() submitSelection) {
    _owner = owner;
    _submitSelection = submitSelection;
  }

  void _detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _submitSelection = null;
    _setSelection(owner, const [], allowDetachedOwner: true);
  }

  void _setSelection(
    Object owner,
    List<int> indexes, {
    bool allowDetachedOwner = false,
  }) {
    if (!allowDetachedOwner && !identical(_owner, owner)) return;
    if (_sameIndexes(_selectedIndexes, indexes)) return;
    _selectedIndexes = List<int>.unmodifiable(indexes);
    _notifySelectionListeners();
  }

  /// 선택 변경을 알립니다. 빌드 단계에서는 프레임이 끝난 뒤로 미룹니다.
  ///
  /// 손패 위젯의 `initState`·`dispose`·`didUpdateWidget`은 모두 빌드 단계에서
  /// 실행됩니다. 새 라운드가 시작되면 손패 위젯의 key가 바뀌어 이전 State가
  /// `dispose`(→ `_detach` → 선택 초기화)되고 새 State가 `initState`(→ `_attach`)
  /// 되는 일이 한 번의 빌드 안에서 일어납니다.
  ///
  /// 이때 곧바로 알리면, 이 컨트롤러를 듣고 있는 SUBMIT/LIAR 버튼의
  /// [AnimatedBuilder]가 빌드 도중 다시 빌드할 대상으로 표시되어
  /// `setState() or markNeedsBuild() called during build` 오류가 납니다.
  ///
  /// 카드를 눌러 선택하는 평소 경로는 빌드 단계가 아니므로 그대로 즉시
  /// 알립니다. 버튼 반응이 한 프레임 늦어지지 않습니다.
  void _notifySelectionListeners() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    // 미뤄 둔 알림이 dispose 이후에 실행되면 ChangeNotifier가 예외를 냅니다.
    _disposed = true;
    super.dispose();
  }

  bool _sameIndexes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

/// 화면 방향에 맞게 휴대폰 손패를 표시하고 위로 끌어 제출하는 위젯입니다.
///
/// 최대 3장까지 선택할 수 있으며, 선택된 카드 중 하나를 위로 끌면
/// 선택 카드가 함께 움직입니다. 제출 높이를 넘는 순간 [onCardsSubmitted]를
/// 호출하고 남은 카드를 새 개수 기준으로 중앙에 다시 정렬합니다.
class PhoneHandCardStack extends StatefulWidget {
  const PhoneHandCardStack({
    super.key,
    required this.isLandscape,
    this.cards,
    this.controller,
    this.enabled = true,
    this.submissionEnabled = true,
    this.maxSelection = 3,
    this.onSelectionChanged,
    this.onCardsSubmitRequested,
    this.onCardsSubmitted,
    this.onRevealStarted,
    this.onRevealCompleted,
    this.initiallyRevealed = false,
    this.entryCenterOffsetX = 0,
    this.entryCenterOffsetY = 0,
    this.announcementCenterOffset = Offset.zero,
    this.roundNumber = 1,
    this.tableRank = 'K',
  }) : assert(maxSelection > 0);

  final bool isLandscape;
  final List<GameImage>? cards;
  final PhoneHandCardStackController? controller;
  final bool enabled;
  final bool submissionEnabled;
  final int maxSelection;
  final ValueChanged<List<int>>? onSelectionChanged;
  final Future<bool> Function(List<int> indexes)? onCardsSubmitRequested;
  final ValueChanged<List<int>>? onCardsSubmitted;
  final VoidCallback? onRevealStarted;
  final VoidCallback? onRevealCompleted;
  final bool initiallyRevealed;
  final double entryCenterOffsetX;
  final double entryCenterOffsetY;

  /// ROUND·기준 카드(KING/QUEEN/ACE) 문구를 화면 정중앙에 놓기 위한 보정값입니다.
  ///
  /// 이 위젯은 화면 전체가 아니라 손패 영역에만 놓입니다. 그래서 문구를 이
  /// 위젯 기준으로 가운데 두면 손패 영역의 중앙(화면 중앙보다 위)에 뜹니다.
  /// 화면 크기를 아는 상위 화면이 `화면 중앙 - 손패 영역 중앙`을 넘겨줍니다.
  ///
  /// 카드 진입 위치([entryCenterOffsetX], [entryCenterOffsetY])와 따로 두어,
  /// 문구 위치를 고쳐도 카드 연출이 움직이지 않습니다.
  final Offset announcementCenterOffset;
  final int roundNumber;
  final String tableRank;

  double get preferredCardWidth => isLandscape ? 140 : 169;
  double get preferredSpreadStepX => isLandscape ? 110 : 35;
  double get preferredSpreadStepY => isLandscape ? 0 : 35;
  bool get rightCardOnTop => true;
  bool get spreadToLeft => isLandscape;

  @override
  State<PhoneHandCardStack> createState() => _PhoneHandCardStackState();
}

class _PhoneHandCardStackState extends State<PhoneHandCardStack> {
  static const double _selectedElevation = 20.0;
  static const double _submitThreshold = 82.0;
  static const double _submitExitOffset = 330.0;
  static const Duration _submitExitDuration = Duration(milliseconds: 420);
  static const Duration _submitReturnDuration = Duration(milliseconds: 380);

  final Set<int> _selectedCardIds = <int>{};
  late List<_HandCardEntry> _renderCards;

  int _nextCardId = 0;
  late bool _isDealing;
  late bool _showRoundIntro;
  late bool _showTableIntro;
  bool _isDragging = false;
  bool _isSubmitting = false;
  bool _isReturningSubmittedCards = false;
  bool _showMaxSelectionMessage = false;
  int? _draggingCardId;
  double _dragOffsetY = 0;
  List<GameImage>? _pendingCards;
  Timer? _maxSelectionMessageTimer;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this, _submitSelectedCards);
    _isDealing = !widget.initiallyRevealed;
    _showRoundIntro = _isDealing && widget.roundNumber > 1;
    // 첫 라운드는 상위 화면의 GAME START가 먼저 끝난 뒤 이 위젯이 생성됩니다.
    // 따라서 ROUND 문구 없이 바로 테이블을 안내하고 카드팩을 전달합니다.
    _showTableIntro = _isDealing && widget.roundNumber == 1;
    _replaceCards(widget.cards ?? _defaultCards);
    _notifySelectionChanged();
  }

  @override
  void didUpdateWidget(PhoneHandCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this, _submitSelectedCards);
      _notifySelectionChanged();
    }

    if (widget.cards != null &&
        !_sameCardAssets(oldWidget.cards, widget.cards!)) {
      // 제출 중 서버 손패가 먼저 갱신되어도 화면을 즉시 바꾸지 않습니다.
      // 카드가 화면 밖으로 이동한 다음 새 손패를 반영해야 중간 끊김이 없습니다.
      if (_isSubmitting) {
        _pendingCards = List<GameImage>.of(widget.cards!);
      } else if (_sameCardAssets(_renderCardAssets, widget.cards!)) {
        // 낙관적으로 먼저 제거한 손패와 서버 손패가 같으면 카드 State와
        // 재배치 애니메이션을 유지합니다.
      } else {
        _replaceCards(widget.cards!);
        _notifySelectionChanged();
      }
    }

    // initiallyRevealed는 새 위젯이 만들어질 때 방향 전환·재접속 상태를
    // 복원하는 값입니다. 공개 도중 이 값이 true로 바뀌었다고 즉시
    // _isDealing을 끝내면 PhoneCardReceiveAnimation이 먼저 dispose되어
    // onRevealCompleted와 헤더 진입 애니메이션이 실행되지 않습니다.

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
    widget.controller?._detach(this);
    _maxSelectionMessageTimer?.cancel();
    super.dispose();
  }

  List<GameImage> get _defaultCards => [
    Assets.games.liarsPoker.images.cards.whiteK.game,
    Assets.games.liarsPoker.images.cards.whiteQ.game,
    Assets.games.liarsPoker.images.cards.whiteA.game,
    Assets.games.liarsPoker.images.cards.whiteA.game,
    Assets.games.liarsPoker.images.cards.whiteJoker.game,
  ];

  void _replaceCards(List<GameImage> cards) {
    _renderCards = [
      for (final card in cards) _HandCardEntry(id: _nextCardId++, asset: card),
    ];
    _selectedCardIds.clear();
    _isDragging = false;
    _draggingCardId = null;
    _dragOffsetY = 0;
  }

  bool _sameCardAssets(List<GameImage>? left, List<GameImage> right) {
    if (identical(left, right)) return true;
    if (left == null || left.length != right.length) return false;

    for (var index = 0; index < left.length; index++) {
      if (left[index].path != right[index].path) return false;
    }
    return true;
  }

  List<GameImage> get _renderCardAssets =>
      _renderCards.map((card) => card.asset).toList(growable: false);

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
    final cardsBeforeSubmission = List<_HandCardEntry>.of(_renderCards);
    setState(() {
      _isSubmitting = true;
      _isReturningSubmittedCards = false;
      _isDragging = false;
      _draggingCardId = null;
      _dragOffsetY = -_submitExitOffset;
    });

    final submitRequested = widget.onCardsSubmitRequested;
    final submitFuture = Future<bool>(() async {
      try {
        return submitRequested == null
            ? true
            : await submitRequested(submittedIndexes);
      } catch (_) {
        return false;
      }
    });

    // 서버 응답을 기다리지 않고 카드가 화면 밖으로 이동한 즉시 남은 손패를
    // 중앙으로 재배치합니다. 네트워크 재시도는 이와 별개로 계속 진행됩니다.
    await Future<void>.delayed(_submitExitDuration);
    if (!mounted) return;

    setState(() {
      _renderCards.removeWhere((card) => submittedIds.contains(card.id));
      _selectedCardIds.clear();
      _isDragging = false;
      _draggingCardId = null;
      _dragOffsetY = 0;
    });
    _notifySelectionChanged();

    final accepted = await submitFuture;
    if (!mounted) return;

    // 함수 응답을 잃었더라도 RTDB 손패가 먼저 바뀌었다면 제출 성공으로
    // 간주합니다. 실제 서버 반영이 없는 최종 실패만 카드를 되돌립니다.
    if (!accepted && _pendingCards == null) {
      await _restoreFailedSubmission(cardsBeforeSubmission, submittedIds);
      return;
    }

    setState(() {
      final pendingCards = _pendingCards;
      if (pendingCards != null &&
          !_sameCardAssets(_renderCardAssets, pendingCards)) {
        _replaceCards(pendingCards);
      }
      _pendingCards = null;
      _isSubmitting = false;
      _isReturningSubmittedCards = false;
    });

    widget.onCardsSubmitted?.call(submittedIndexes);
  }

  /// 모든 서버 재시도가 실패하면 제출 전 손패를 위에서 다시 내려보냅니다.
  Future<void> _restoreFailedSubmission(
    List<_HandCardEntry> cardsBeforeSubmission,
    Set<int> submittedIds,
  ) async {
    setState(() {
      _renderCards = List<_HandCardEntry>.of(cardsBeforeSubmission);
      _selectedCardIds
        ..clear()
        ..addAll(submittedIds);
      _isReturningSubmittedCards = true;
      _dragOffsetY = -_submitExitOffset;
    });

    // 복원 카드가 첫 프레임에 화면 밖 위치로 그려진 다음 손패로 이동합니다.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _dragOffsetY = 0);

    await Future<void>.delayed(_submitReturnDuration);
    if (!mounted) return;
    setState(() {
      final pendingCards = _pendingCards;
      if (pendingCards != null &&
          !_sameCardAssets(_renderCardAssets, pendingCards)) {
        _replaceCards(pendingCards);
      }
      _pendingCards = null;
      _selectedCardIds.clear();
      _isSubmitting = false;
      _isReturningSubmittedCards = false;
      _isDragging = false;
      _draggingCardId = null;
      _dragOffsetY = 0;
    });
    _notifySelectionChanged();
  }

  void _notifySelectionChanged() {
    final indexes = List<int>.unmodifiable(_selectedIndexes);
    widget.controller?._setSelection(this, indexes);
    widget.onSelectionChanged?.call(indexes);
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
      return LayoutBuilder(
        builder: (context, constraints) {
          final layout = _resolveLayout(constraints);
          final announcement = _showRoundIntro
              ? GameAnnouncement.round(
                  widget.roundNumber,
                  id: 'phone-round-${widget.roundNumber}',
                  duration: LiarsPokerFlowTiming.roundAnnouncement,
                )
              : _showTableIntro
              ? GameAnnouncement.transient(
                  id: 'phone-table-${widget.roundNumber}-${widget.tableRank}',
                  text: LiarsPokerCopy.table(widget.tableRank),
                  blocksInteraction: true,
                )
              : null;

          return Stack(
            fit: StackFit.expand,
            children: [
              if (announcement == null)
                PhoneCardReceiveAnimation(
                  frontCardAssets: _renderCards
                      .map((card) => card.asset)
                      .toList(growable: false),
                  cardWidth: layout.cardWidth,
                  spreadStepX: layout.spreadStepX,
                  spreadStepY: layout.spreadStepY,
                  spreadToLeft: widget.spreadToLeft,
                  entryCenterOffsetX: widget.entryCenterOffsetX,
                  entryCenterOffsetY: widget.entryCenterOffsetY,
                  onRevealStarted: widget.onRevealStarted,
                  onCompleted: () {
                    if (!mounted) return;

                    setState(() => _isDealing = false);
                    widget.onRevealCompleted?.call();
                  },
                ),
              Positioned.fill(
                child: GameAnnouncementLayer(
                  announcement: announcement,
                  offset: widget.announcementCenterOffset,
                  style: GameAnnouncementStyle(
                    fontSize: widget.isLandscape ? 38 : 42,
                    gameStartFontSize: widget.isLandscape ? 38 : 42,
                    letterSpacing: 2.2,
                  ),
                  onCompleted: (_) {
                    if (!mounted) return;
                    setState(() {
                      if (_showRoundIntro) {
                        _showRoundIntro = false;
                        _showTableIntro = true;
                      } else {
                        _showTableIntro = false;
                      }
                    });
                  },
                ),
              ),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 400,
          constraints.hasBoundedHeight ? constraints.maxHeight : 600,
        );
        final layout = _resolveLayout(constraints);
        final centerX = size.width / 2;
        final centerY = size.height / 2;
        const cardAspectRatio = 512 / 350;
        final cardHeight = layout.cardWidth * cardAspectRatio;
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
                  cardWidth: layout.cardWidth,
                  cardHeight: cardHeight,
                  spreadStepX: layout.spreadStepX,
                  spreadStepY: layout.spreadStepY,
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
    required double cardWidth,
    required double cardHeight,
    required double spreadStepX,
    required double spreadStepY,
  }) {
    final centeredIndex = cardIndex - (cardCount - 1) / 2;
    final isSelected = _selectedCardIds.contains(card.id);
    final baseCenterX = widget.spreadToLeft
        ? _leftSpreadCardCenter(
            centerX: centerX,
            containerWidth: containerWidth,
            cardIndex: cardIndex,
            cardCount: cardCount,
            cardWidth: cardWidth,
            spreadStepX: spreadStepX,
          )
        : centerX + centeredIndex * spreadStepX;
    final baseLeft = baseCenterX - cardWidth / 2;
    final baseTop = centerY + centeredIndex * spreadStepY - cardHeight / 2;
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
            : _isReturningSubmittedCards
            ? _submitReturnDuration
            : _isSubmitting
            ? _submitExitDuration
            : const Duration(milliseconds: 260),
        curve: _isReturningSubmittedCards
            ? Curves.easeOutCubic
            : _isSubmitting
            ? Curves.easeInCubic
            : Curves.easeOutCubic,
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
              cardWidth: cardWidth,
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
    required double cardWidth,
    required double spreadStepX,
  }) {
    final availableSpread = math.max(0.0, containerWidth - cardWidth - 16);
    final spreadStep = cardCount <= 1
        ? 0.0
        : math.min(spreadStepX.abs(), availableSpread / (cardCount - 1));
    final totalSpread = spreadStep * math.max(0, cardCount - 1);
    final maxAnchorX = math.max(
      cardWidth / 2,
      containerWidth - cardWidth / 2 - 8,
    );
    final rightAnchorX = math.min(centerX + totalSpread / 2, maxAnchorX);
    return rightAnchorX - (cardCount - 1 - cardIndex) * spreadStep;
  }

  /// 실제 손패 영역에 맞춰 카드가 잘리거나 다른 조작부를 침범하지 않게 합니다.
  _HandLayout _resolveLayout(BoxConstraints constraints) {
    const cardAspectRatio = 512 / 350;
    final boundedWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : 400.0;
    final boundedHeight = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : 600.0;
    final availableWidth = math.max(120.0, boundedWidth - 16);
    final availableHeight = math.max(150.0, boundedHeight - 16);
    final cardCount = math.max(1, _renderCards.length);

    final maxByHeight = availableHeight / cardAspectRatio;
    final portraitStackHeight =
        cardAspectRatio * widget.preferredCardWidth +
        math.max(0, cardCount - 1) * widget.preferredSpreadStepY;
    final portraitScale = widget.isLandscape || portraitStackHeight <= 0
        ? 1.0
        : math.min(1.0, availableHeight / portraitStackHeight);
    final cardWidth = math.min(
      widget.preferredCardWidth * portraitScale,
      math.min(maxByHeight, availableWidth),
    );

    final horizontalCapacity = math.max(0.0, availableWidth - cardWidth);
    final spreadStepX = cardCount <= 1
        ? 0.0
        : math.min(
            widget.preferredSpreadStepX * portraitScale,
            horizontalCapacity / (cardCount - 1),
          );
    final verticalCapacity = math.max(
      0.0,
      availableHeight - cardWidth * cardAspectRatio,
    );
    final spreadStepY = widget.isLandscape || cardCount <= 1
        ? 0.0
        : math.min(
            widget.preferredSpreadStepY * portraitScale,
            verticalCapacity / (cardCount - 1),
          );

    return _HandLayout(
      cardWidth: cardWidth,
      spreadStepX: spreadStepX,
      spreadStepY: spreadStepY,
    );
  }
}

class _HandLayout {
  const _HandLayout({
    required this.cardWidth,
    required this.spreadStepX,
    required this.spreadStepY,
  });

  final double cardWidth;
  final double spreadStepX;
  final double spreadStepY;
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
          LiarsPokerCopy.selectionLimit(maxSelection),
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
  final GameImage asset;
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

  final GameImage asset;
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
