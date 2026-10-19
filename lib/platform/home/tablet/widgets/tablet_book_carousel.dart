import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/localization/platform_localizations.dart';

/// 방 상태와 무관하게 실제 책을 탐색합니다. 위치와 회전을 하나의 진행 값으로
/// 그려, 책이 이동하며 펼쳐질 때 간격과 속도가 어긋나지 않게 합니다.
class TabletBookCarousel extends StatefulWidget {
  const TabletBookCarousel({
    super.key,
    required this.games,
    required this.selected,
    required this.coverWidth,
    required this.deep,
    this.emptyColor = const Color(0x660E0A3D),
    required this.onSelect,
    required this.onOpenDetail,
    this.preparing = false,
    this.selectedCoverKey,
  });

  /// 고른 게임을 준비(다운로드·선택) 중인지입니다. 책 위에 준비 표시가 뜹니다.
  final bool preparing;

  /// 고른 책에 붙는 키입니다. 책이 열리는 화면 전환의 출발 자리를 잽니다.
  final GlobalKey? selectedCoverKey;

  final List<GameInfo> games;
  final GameInfo selected;
  final double coverWidth;
  final Color deep;
  final Color emptyColor;
  final ValueChanged<GameInfo> onSelect;
  final ValueChanged<GameInfo> onOpenDetail;

  @override
  State<TabletBookCarousel> createState() => _TabletBookCarouselState();
}

class _TabletBookCarouselState extends State<TabletBookCarousel>
    with SingleTickerProviderStateMixin {
  double _dragDistance = 0;
  late double _position = _selectedIndex(widget).toDouble();
  double? _pendingPosition;

  // ---------------------------------------------------------------------------
  // 목록 변화(필터) 연출 — 로비 연출 12번
  // ---------------------------------------------------------------------------
  // 남는 책은 이전 자리에서 새 자리로 미끄러지고, 빠지는 책만 짧게 흐려지며
  // 작아집니다. 새로 들어오는 책은 제자리에서 나타납니다.
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
    value: 1,
  );

  /// 마지막으로 그린 선반 위치입니다. 목록이 바뀔 때 책의 이전 자리를 잽니다.
  double _drawnPosition = 0;
  Map<String, double> _fromOffsets = const {};
  int _fromCount = 0;
  Set<String> _appearing = const {};
  List<({GameInfo game, double offset})> _leaving = const [];

  List<GameInfo> _uniqueGames(TabletBookCarousel widget) {
    final seen = <String>{};
    return widget.games.where((game) => seen.add(game.id)).toList();
  }

  int _selectedIndex(TabletBookCarousel widget) => math.max(
    0,
    _uniqueGames(widget).indexWhere((game) => game.id == widget.selected.id),
  );

  int _nearestVirtualPosition(int index, double reference, int count) {
    if (count < 1) return 0;
    final lower = index + ((reference - index) / count).floor() * count;
    final upper = lower + count;
    return (reference - lower).abs() <= (upper - reference).abs()
        ? lower
        : upper;
  }

  double _wrappedOffset(double offset, int count) {
    if (count < 1) return offset;
    return (offset + count / 2) % count - count / 2;
  }

  String _catalogKey(TabletBookCarousel widget) =>
      _uniqueGames(widget).map((game) => game.id).join('/');

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TabletBookCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_catalogKey(oldWidget) != _catalogKey(widget)) {
      final oldGames = _uniqueGames(oldWidget);
      final games = _uniqueGames(widget);
      final nextIds = {for (final game in games) game.id};
      final oldIds = {for (final game in oldGames) game.id};
      _fromOffsets = {
        for (var i = 0; i < oldGames.length; i++)
          oldGames[i].id: i - _drawnPosition,
      };
      _fromCount = oldGames.length;
      _leaving = [
        for (var i = 0; i < oldGames.length; i++)
          if (!nextIds.contains(oldGames[i].id))
            (
              game: oldGames[i],
              offset: _wrappedOffset(i - _drawnPosition, oldGames.length),
            ),
      ];
      _appearing = {
        for (final game in games)
          if (!oldIds.contains(game.id)) game.id,
      };
      _position = _nearestVirtualPosition(
        _selectedIndex(widget),
        _drawnPosition,
        games.length,
      ).toDouble();
      if (MediaQuery.disableAnimationsOf(context)) {
        _morph.value = 1;
      } else {
        _morph.forward(from: 0);
      }
    } else if (oldWidget.selected.id != widget.selected.id) {
      _position =
          (_pendingPosition ??
                  _nearestVirtualPosition(
                    _selectedIndex(widget),
                    _drawnPosition,
                    widget.games.length,
                  ))
              .toDouble();
      _pendingPosition = null;
    }
  }

  void _selectAt(GameInfo game, int virtualIndex) {
    if (game.id == widget.selected.id) {
      widget.onOpenDetail(game);
      return;
    }
    _pendingPosition = virtualIndex.toDouble();
    widget.onSelect(game);
  }

  void _finishDrag(DragEndDetails details) {
    final games = _uniqueGames(widget);
    final velocity = details.primaryVelocity ?? 0;
    final direction = _dragDistance.abs() >= 32
        ? _dragDistance
        : velocity.abs() >= 180
        ? velocity
        : 0.0;
    _dragDistance = 0;
    if (direction == 0 || games.length < 2) return;
    final directionStep = direction < 0 ? 1 : -1;
    final currentVirtual = _nearestVirtualPosition(
      _selectedIndex(widget),
      _position,
      games.length,
    );
    final nextVirtual = currentVirtual + directionStep;
    final next = nextVirtual % games.length;
    _pendingPosition = nextVirtual.toDouble();
    widget.onSelect(games[next]);
  }

  @override
  Widget build(BuildContext context) {
    final games = _uniqueGames(widget);
    if (games.isEmpty) return const SizedBox.shrink();
    final count = games.length;
    const sideCount = 3;
    final stageWidth = widget.coverWidth + 396;
    final stageHeight = widget.coverWidth * 4 / 3 + 24;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 360);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 폭이나 (부모가 정해 준) 높이가 모자라면 선반 그림 전체를 줄입니다.
        final scale = math.min(
          1.0,
          math.min(
            constraints.maxWidth / stageWidth,
            constraints.hasBoundedHeight
                ? constraints.maxHeight / stageHeight
                : double.infinity,
          ),
        );
        return GestureDetector(
          key: const Key('book-carousel'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _dragDistance = 0,
          onHorizontalDragUpdate: (details) =>
              _dragDistance += details.delta.dx,
          onHorizontalDragCancel: () => _dragDistance = 0,
          onHorizontalDragEnd: _finishDrag,
          child: SizedBox(
            width: double.infinity,
            height: stageHeight * scale,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: stageWidth,
                height: stageHeight,
                child: AnimatedBuilder(
                  animation: _morph,
                  builder: (context, _) => TweenAnimationBuilder<double>(
                    key: ValueKey(_catalogKey(widget)),
                    tween: Tween(begin: _position, end: _position),
                    duration: duration,
                    curve: Curves.easeInOutCubic,
                    builder: (context, position, _) {
                      _drawnPosition = position;
                      final morph = Curves.easeInOutCubic.transform(
                        _morph.value,
                      );
                      final morphing = _morph.value < 1;
                      final entries =
                          [
                            for (
                              var gameIndex = 0;
                              gameIndex < count;
                              gameIndex++
                            )
                              () {
                                final game = games[gameIndex];
                                final virtualIndex = count == 1
                                    ? position.round()
                                    : _nearestVirtualPosition(
                                        gameIndex,
                                        position,
                                        count,
                                      );
                                final offset = virtualIndex - position;
                                final fromOffset = _fromOffsets[game.id];
                                final startOffset =
                                    fromOffset == null || _fromCount < 1
                                    ? offset
                                    : fromOffset +
                                          ((offset - fromOffset) / _fromCount)
                                                  .round() *
                                              _fromCount;
                                return (
                                  game: game,
                                  virtualIndex: virtualIndex,
                                  offset: morphing
                                      ? startOffset +
                                            (offset - startOffset) * morph
                                      : offset,
                                );
                              }(),
                          ]..sort(
                            (a, b) => b.offset.abs().compareTo(a.offset.abs()),
                          );
                      // 빠지는 책은 앞 0.18초 동안 흐려지며 작아집니다.
                      final leaveT = (_morph.value / 0.45).clamp(0.0, 1.0);
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          if (morphing)
                            for (final ghost in _leaving)
                              _buildBook(
                                ghost.game,
                                ghost.offset,
                                stageWidth,
                                sideCount,
                                virtualIndex:
                                    -100000 -
                                    games.indexWhere(
                                      (game) => game.id == ghost.game.id,
                                    ),
                                selected: false,
                                onTap: () {},
                                fade: 1 - leaveT,
                                shrink: 1 - 0.2 * leaveT,
                                interactive: false,
                              ),
                          for (final entry in entries)
                            _buildBook(
                              entry.game,
                              entry.offset,
                              stageWidth,
                              sideCount,
                              virtualIndex: entry.virtualIndex,
                              selected: entry.virtualIndex == position.round(),
                              onTap: () =>
                                  entry.virtualIndex == position.round()
                                  ? widget.onOpenDetail(entry.game)
                                  : _selectAt(entry.game, entry.virtualIndex),
                              canonicalOccurrence: true,
                              fade:
                                  morphing && _appearing.contains(entry.game.id)
                                  ? Curves.easeOut.transform(
                                      ((_morph.value - 0.4) / 0.6).clamp(0, 1),
                                    )
                                  : 1,
                              shrink:
                                  morphing && _appearing.contains(entry.game.id)
                                  ? 0.8 +
                                        0.2 *
                                            Curves.easeOutBack.transform(
                                              ((_morph.value - 0.4) / 0.6)
                                                  .clamp(0, 1),
                                            )
                                  : 1,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBook(
    GameInfo game,
    double offset,
    double stageWidth,
    int sideCount, {
    required int virtualIndex,
    required bool selected,
    required VoidCallback onTap,
    bool canonicalOccurrence = false,
    double fade = 1,
    double shrink = 1,
    bool interactive = true,
  }) {
    final distance = offset.abs();
    final face = (1 - distance).clamp(0.0, 1.0);
    final width = 46 + (widget.coverWidth - 46) * face;
    final firstGap = widget.coverWidth / 2 + 24 + 23;
    final displacement = distance <= 1
        ? firstGap * offset
        : offset.sign * (firstGap + (distance - 1) * 58);
    final opacity = (sideCount + 1 - distance).clamp(0.0, 1.0) * fade;
    final bookScale = game.id == 'holdem' ? 0.88 : 1.0;
    return Positioned(
      key: ValueKey(
        'book-${game.id}-$virtualIndex${interactive ? '' : '-leaving'}',
      ),
      left: 192 + widget.coverWidth / 2 + displacement - width / 2,
      bottom: 0,
      child: ExcludeSemantics(
        excluding: opacity < 0.5,
        child: IgnorePointer(
          ignoring: opacity < 0.5,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: bookScale * shrink,
              alignment: Alignment.bottomCenter,
              child: _PreparingBadge(
                // LP continues into its game background without a ready badge.
                visible:
                    selected && widget.preparing && game.id != 'liars_poker',
                child: KeyedSubtree(
                  key: selected && interactive ? widget.selectedCoverKey : null,
                  child: _TurningBook(
                    game: game,
                    selected: selected,
                    face: face,
                    width: width,
                    coverWidth: widget.coverWidth,
                    deep: widget.deep,
                    onTap: onTap,
                    spineKey: canonicalOccurrence
                        ? ValueKey('shelf-spine-${game.id}')
                        : ValueKey('shelf-spine-${game.id}-$virtualIndex'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TurningBook extends StatelessWidget {
  const _TurningBook({
    required this.game,
    required this.selected,
    required this.face,
    required this.width,
    required this.coverWidth,
    required this.deep,
    required this.onTap,
    required this.spineKey,
  });
  final GameInfo game;
  final bool selected;
  final double face;
  final double width;
  final double coverWidth;
  final Color deep;
  final VoidCallback onTap;
  final Key spineKey;

  @override
  Widget build(BuildContext context) {
    final displayName = game.localizedName(Localizations.localeOf(context));
    final angle = (1 - face) * math.pi / 2;
    final spineProjection = 46 * math.sin(angle);
    final projectedWidth = spineProjection + coverWidth * math.cos(angle);
    final coverHeight = coverWidth * 4 / 3;
    final height = math.max(288.0, coverHeight);
    return Semantics(
      button: true,
      selected: selected,
      label: GameLocale.select(
        ko: '$displayName ${selected ? '자세히 보기' : '선택'}',
        en: '$displayName ${selected ? 'View details' : 'Select'}',
        zhHans: '$displayName ${selected ? '查看详情' : '选择'}',
        zhHant: '$displayName ${selected ? '查看詳情' : '選擇'}',
      ),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: selected ? const Key('shelf-selected-cover') : spineKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: height,
          child: IgnorePointer(
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: projectedWidth,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (face < 1)
                      Positioned(
                        left: 0,
                        bottom: 0,
                        child: Transform(
                          key: ValueKey('book-spine-turn-${game.id}'),
                          alignment: Alignment.centerLeft,
                          transform: Matrix4.identity()
                            ..rotateY(angle - math.pi / 2),
                          child: MosiGameSpine(
                            gameId: game.id,
                            fallbackName: game.name,
                            displayName: displayName,
                            englishName: game.englishName,
                            deep: deep,
                            height: height,
                            onTap: onTap,
                          ),
                        ),
                      ),
                    if (face > 0)
                      Positioned(
                        left: spineProjection,
                        bottom: 0,
                        child: Transform(
                          key: ValueKey('book-front-turn-${game.id}'),
                          alignment: Alignment.centerLeft,
                          transform: Matrix4.identity()..rotateY(angle),
                          child: SizedBox(
                            width: coverWidth,
                            height: height,
                            child: FittedBox(
                              fit: BoxFit.fill,
                              child: MosiGameCover(
                                gameId: game.id,
                                fallbackName: game.name,
                                displayName: displayName,
                                englishName: game.englishName,
                                fallbackImageUrl: game.imageUrl,
                                width: coverWidth,
                                shadowColor: deep,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 고른 책 위에 뜨는 '준비 중' 표시입니다(로비 연출 5번).
///
/// 실제 다운로드 진행률은 에셋 저장소가 알려 주지 않아 점 세 개로만 진행
/// 중임을 알립니다. 준비가 끝나면 책이 열리며 다음 화면으로 넘어갑니다.
class _PreparingBadge extends StatelessWidget {
  const _PreparingBadge({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        AnimatedSlide(
          offset: Offset(0, visible ? -0.04 : 0),
          duration: MosiMotion.of(context, const Duration(milliseconds: 320)),
          curve: Curves.easeOutBack,
          child: child,
        ),
        // 선반 그림 위 여백(24px) 안에 들어오도록 표지 윗변에 걸쳐 띄웁니다.
        Positioned(
          top: -14,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: MosiMotion.of(
                context,
                const Duration(milliseconds: 220),
              ),
              child: AnimatedSlide(
                offset: Offset(0, visible ? 0 : 0.4),
                duration: MosiMotion.of(
                  context,
                  const Duration(milliseconds: 220),
                ),
                child: Container(
                  key: visible ? const Key('shelf-preparing-badge') : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: MosiColors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: MosiColors.ink, width: 2.5),
                    boxShadow: const [
                      BoxShadow(color: MosiColors.navy, offset: Offset(3, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.gamePreparing,
                        style: MosiFonts.sans(
                          locale: Localizations.maybeLocaleOf(context),
                          size: 14,
                          weight: FontWeight.w700,
                          color: MosiColors.navy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (visible)
                        const MosiLoadingDots(color: MosiColors.navy, size: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
