import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';

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
  });

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

class _TabletBookCarouselState extends State<TabletBookCarousel> {
  double _dragDistance = 0;
  late double _position = _selectedIndex(widget).toDouble();

  int _selectedIndex(TabletBookCarousel widget) => math.max(
    0,
    widget.games.indexWhere((game) => game.id == widget.selected.id),
  );

  String _catalogKey(TabletBookCarousel widget) =>
      widget.games.map((game) => game.id).join('/');

  @override
  void didUpdateWidget(covariant TabletBookCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_catalogKey(oldWidget) != _catalogKey(widget)) {
      _position = _selectedIndex(widget).toDouble();
    } else if (oldWidget.selected.id != widget.selected.id) {
      _position = _selectedIndex(widget).toDouble();
    }
  }

  void _finishDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final direction = _dragDistance.abs() >= 32
        ? _dragDistance
        : velocity.abs() >= 180
        ? velocity
        : 0.0;
    _dragDistance = 0;
    if (direction == 0 || widget.games.length < 2) return;
    final next = _selectedIndex(widget) + (direction < 0 ? 1 : -1);
    if (next < 0 || next >= widget.games.length) return;
    widget.onSelect(widget.games[next]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.games.isEmpty) return const SizedBox.shrink();
    final count = widget.games.length;
    const sideCount = 3;
    final stageWidth = widget.coverWidth + 396;
    final stageHeight = widget.coverWidth * 4 / 3 + 24;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 360);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(1.0, constraints.maxWidth / stageWidth);
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
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_catalogKey(widget)),
                  tween: Tween(begin: _position, end: _position),
                  duration: duration,
                  curve: Curves.easeInOutCubic,
                  builder: (context, position, _) {
                    final entries = [
                      for (var i = 0; i < count; i++)
                        (game: widget.games[i], offset: i - position),
                    ]..sort((a, b) => b.offset.abs().compareTo(a.offset.abs()));
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // 원래 책장의 빈 칸과 고정 순서를 유지합니다.
                        for (var slot = 0; slot < 2; slot++)
                          Positioned(
                            left: 64 + slot * 58,
                            bottom: 0,
                            child: Opacity(
                              opacity: (2 - slot - position).clamp(0.0, 1.0),
                              child: MosiEmptySpine(color: widget.emptyColor),
                            ),
                          ),
                        for (var slot = 0; slot < 3; slot++)
                          Positioned(
                            left: 216 + widget.coverWidth + slot * 58,
                            bottom: 0,
                            child: Opacity(
                              opacity: (position - (count - 2 - slot)).clamp(
                                0.0,
                                1.0,
                              ),
                              child: MosiEmptySpine(color: widget.emptyColor),
                            ),
                          ),
                        for (final entry in entries)
                          _buildBook(
                            entry.game,
                            entry.offset,
                            stageWidth,
                            sideCount,
                          ),
                      ],
                    );
                  },
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
    int sideCount,
  ) {
    final distance = offset.abs();
    final face = (1 - distance).clamp(0.0, 1.0);
    final width = 46 + (widget.coverWidth - 46) * face;
    final firstGap = widget.coverWidth / 2 + 24 + 23;
    final displacement = distance <= 1
        ? firstGap * offset
        : offset.sign * (firstGap + (distance - 1) * 58);
    final opacity = (sideCount + 1 - distance).clamp(0.0, 1.0);
    final selected = game.id == widget.selected.id;
    final bookScale = game.id == 'holdem' ? 0.88 : 1.0;
    return Positioned(
      key: ValueKey('book-${game.id}'),
      left: 192 + widget.coverWidth / 2 + displacement - width / 2,
      bottom: 0,
      child: ExcludeSemantics(
        excluding: opacity < 0.5,
        child: IgnorePointer(
          ignoring: opacity < 0.5,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: bookScale,
              alignment: Alignment.bottomCenter,
              child: _TurningBook(
                game: game,
                selected: selected,
                face: face,
                width: width,
                coverWidth: widget.coverWidth,
                deep: widget.deep,
                onTap: () => selected
                    ? widget.onOpenDetail(game)
                    : widget.onSelect(game),
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
  });
  final GameInfo game;
  final bool selected;
  final double face;
  final double width;
  final double coverWidth;
  final Color deep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final angle = (1 - face) * math.pi / 2;
    final spineProjection = 46 * math.sin(angle);
    final projectedWidth = spineProjection + coverWidth * math.cos(angle);
    final coverHeight = coverWidth * 4 / 3;
    final height = math.max(288.0, coverHeight);
    return Semantics(
      button: true,
      selected: selected,
      label: '${game.name} ${selected ? '자세히 보기' : '선택'}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: selected
            ? const Key('shelf-selected-cover')
            : ValueKey('shelf-spine-${game.id}'),
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
