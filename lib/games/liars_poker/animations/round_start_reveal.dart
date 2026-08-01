import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/widgets/player_layouts/player_slot_positions.dart';

/// 라운드 시작 시 중앙 테이블과 플레이어별 잔여 카드 수를 동시에 띄웁니다.
class RoundStartReveal extends StatefulWidget {
  const RoundStartReveal({
    super.key,
    required this.tableAsset,
    required this.playerCount,
    required this.remainingCardCounts,
    this.playerSeatIndexes,
    this.playerPositions,
    this.tableWidth = 200,
    this.duration = const Duration(milliseconds: 1300),
    this.riseDistance = 72,
    this.orbitScale = 1,
    this.onCompleted,
  }) : assert(playerCount > 0),
       assert(remainingCardCounts.length == playerCount),
       assert(
         playerSeatIndexes == null || playerSeatIndexes.length == playerCount,
         'playerSeatIndexes의 개수는 playerCount와 같아야 합니다.',
       ),
       assert(orbitScale > 0),
       assert(
         playerPositions == null || playerPositions.length == playerCount,
         'playerPositions의 개수는 playerCount와 같아야 합니다.',
       );

  final String tableAsset;
  final int playerCount;
  final List<int> remainingCardCounts;
  final List<int>? playerSeatIndexes;

  /// `player_layouts`에서 저장한 플레이어 영역의 좌측 상단 정규화 좌표입니다.
  final List<Offset>? playerPositions;

  final double tableWidth;
  final Duration duration;

  /// 아래에서 올라오기 시작하는 거리입니다.
  final double riseDistance;

  /// 기본 플레이어 위치를 중앙 원 바깥 방향으로 확장하는 비율입니다.
  final double orbitScale;

  final VoidCallback? onCompleted;

  @override
  State<RoundStartReveal> createState() => _RoundStartRevealState();
}

class _RoundStartRevealState extends State<RoundStartReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onStatusChanged)
      ..forward();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCompleted?.call();
    }
  }

  @override
  void didUpdateWidget(RoundStartReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final riseProgress = Curves.easeOutBack.transform(
                _controller.value,
              );
              final opacity = Curves.easeOut.transform(
                (_controller.value / 0.58).clamp(0.0, 1.0),
              );
              final verticalOffset = widget.riseDistance * (1 - riseProgress);
              final scale = 0.86 + (0.14 * riseProgress);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(0, verticalOffset),
                        child: Transform.scale(
                          scale: scale,
                          child: Image.asset(
                            widget.tableAsset,
                            width: widget.tableWidth,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (
                    var playerIndex = 0;
                    playerIndex < widget.playerCount;
                    playerIndex++
                  )
                    _buildRemainingCard(
                      size: size,
                      playerIndex: playerIndex,
                      opacity: opacity,
                      verticalOffset: verticalOffset,
                      scale: scale,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRemainingCard({
    required Size size,
    required int playerIndex,
    required double opacity,
    required double verticalOffset,
    required double scale,
  }) {
    const cardWidth = 58.0;
    const cardHeight = 72.0;
    final center = Offset(size.width / 2, size.height / 2);
    final playerCenter = _playerCenter(size, playerIndex);
    final direction = playerCenter - center;
    final angle = direction.distanceSquared == 0
        ? math.pi
        : math.atan2(direction.dy, direction.dx) + math.pi / 2 + math.pi;

    return Positioned(
      left: playerCenter.dx - cardWidth / 2,
      top: playerCenter.dy - cardHeight / 2,
      width: cardWidth,
      height: cardHeight,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, verticalOffset),
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: angle,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0x22000000)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 8,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${widget.remainingCardCounts[playerIndex]}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _playerCenter(Size size, int playerIndex) {
    final positions = widget.playerPositions;
    if (positions != null && playerIndex < positions.length) {
      const playerSlotSize = 160.0;
      final position = positions[playerIndex];
      return Offset(
        position.dx * size.width + playerSlotSize / 2,
        position.dy * size.height + playerSlotSize / 2,
      );
    }

    final centers = playerCentersForBoard(
      playerCount: widget.playerCount,
      boardSize: size,
      radiusFactor: defaultPlayerOrbitRadiusFactor * widget.orbitScale,
    );
    final seatIndex = widget.playerSeatIndexes?[playerIndex] ?? playerIndex;
    return centers[seatIndex];
  }
}
