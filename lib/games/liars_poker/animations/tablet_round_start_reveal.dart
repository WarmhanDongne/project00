import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/shared/animations/board_element_entrance.dart';
import 'package:project00/games/shared/player_layouts/player_slot_positions.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/core/assets/game_image.dart';

/// 라운드 시작 시 중앙 테이블과 플레이어별 잔여 카드 수를 동시에 띄웁니다.
class RoundStartReveal extends StatefulWidget {
  const RoundStartReveal({
    super.key,
    required this.tableAsset,
    required this.playerCount,
    required this.remainingCardCounts,
    this.activePlayerIndex,
    this.playerSeatIndexes,
    this.playerPositions,
    this.tableWidth = 200,
    this.cardCountAsset,
    this.duration = const Duration(milliseconds: 980),
    this.orbitScale = 1,
    this.onCompleted,
  }) : assert(playerCount > 0),
       assert(remainingCardCounts.length == playerCount),
       assert(
         activePlayerIndex == null ||
             (activePlayerIndex >= 0 && activePlayerIndex < playerCount),
         'activePlayerIndex는 플레이어 범위 안이어야 합니다.',
       ),
       assert(
         playerSeatIndexes == null || playerSeatIndexes.length == playerCount,
         'playerSeatIndexes의 개수는 playerCount와 같아야 합니다.',
       ),
       assert(orbitScale > 0),
       assert(
         playerPositions == null || playerPositions.length == playerCount,
         'playerPositions의 개수는 playerCount와 같아야 합니다.',
       );

  final GameImage tableAsset;
  final int playerCount;
  final List<int> remainingCardCounts;
  final int? activePlayerIndex;
  final List<int>? playerSeatIndexes;

  /// `player_layouts`에서 저장한 플레이어 영역의 좌측 상단 정규화 좌표입니다.
  final List<Offset>? playerPositions;

  final double tableWidth;
  final GameImage? cardCountAsset;
  final Duration duration;

  /// 기본 플레이어 위치를 중앙 원 바깥 방향으로 확장하는 비율입니다.
  final double orbitScale;

  final VoidCallback? onCompleted;

  @override
  State<RoundStartReveal> createState() => _RoundStartRevealState();
}

class _RoundStartRevealState extends State<RoundStartReveal>
    with SingleTickerProviderStateMixin {
  // 등장 곡선은 다른 게임 보드와 공유합니다. (BoardEntranceCurves)
  static final Animatable<double> _depthScale = BoardEntranceCurves.depthScale;
  static final Animatable<double> _elevation = BoardEntranceCurves.elevation;

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
              final progress = _controller.value;
              final opacity = BoardEntranceCurves.opacityFor(progress);
              final scale = _depthScale.transform(progress);
              final elevation = _elevation.transform(progress);
              final shadowBlur = 7 + (22 * elevation);
              final shadowSpread = 1 + (5 * elevation);
              final shadowOpacity = 0.34 + (0.16 * elevation);
              final activePlayerIndex = widget.activePlayerIndex;
              final turnLightCenter = activePlayerIndex == null
                  ? null
                  : _playerCenter(size, activePlayerIndex);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: widget.tableAsset.image(
                          width: widget.tableWidth,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                  if (turnLightCenter != null)
                    AnimatedPositioned(
                      key: const ValueKey('moving-turn-light'),
                      duration: const Duration(milliseconds: 620),
                      curve: Curves.easeInOutCubic,
                      left: turnLightCenter.dx - 128,
                      top: turnLightCenter.dy - 128,
                      width: 256,
                      height: 256,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          child: const _TurnCircleLight(),
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
                      scale: scale,
                      shadowBlur: shadowBlur,
                      shadowSpread: shadowSpread,
                      shadowOpacity: shadowOpacity,
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
    required double scale,
    required double shadowBlur,
    required double shadowSpread,
    required double shadowOpacity,
  }) {
    const cardWidth = 82.0;
    const cardHeight = 104.0;
    final center = Offset(size.width / 2, size.height / 2);
    final playerCenter = _playerCenter(size, playerIndex);
    final direction = playerCenter - center;
    final isCurrentTurn = widget.activePlayerIndex == playerIndex;
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
        child: Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: angle,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: _FloorShadow(
                    width: cardWidth * 0.48,
                    height: cardHeight * 0.52,
                    blurRadius: shadowBlur,
                    spreadRadius: shadowSpread * 0.55,
                    opacity: shadowOpacity,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                _RemainingCardCounter(
                  key: ValueKey(playerIndex),
                  asset:
                      widget.cardCountAsset ??
                      Assets.games.liarsPoker.images.cards.cardCount.game,
                  count: widget.remainingCardCounts[playerIndex],
                  isCurrentTurn: isCurrentTurn,
                ),
              ],
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

/// 현재 턴 플레이어 사이를 이동하는 펠트 텍스처 원형 조명입니다.
class _TurnCircleLight extends StatelessWidget {
  const _TurnCircleLight();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x665A2F55),
              blurRadius: 34,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipOval(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const RadialGradient(
              colors: [Color(0xFFFFFFFF), Color(0xE8FFFFFF), Color(0x00FFFFFF)],
              stops: [0, 0.58, 1],
            ).createShader(bounds),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: 0.82,
                  child: Assets
                      .games
                      .liarsPoker
                      .images
                      .background
                      .background
                      .game
                      .image(
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.high,
                      ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Color(0x7088467C),
                        Color(0x405F3259),
                        Color(0x00281927),
                      ],
                      stops: [0, 0.56, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 탑뷰에서 높이를 느낄 수 있도록 물체 아래에 퍼지는 바닥 그림자입니다.
class _FloorShadow extends StatelessWidget {
  const _FloorShadow({
    required this.width,
    required this.height,
    required this.blurRadius,
    required this.spreadRadius,
    required this.opacity,
    this.borderRadius,
  });

  final double width;
  final double height;
  final double blurRadius;
  final double spreadRadius;
  final double opacity;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x01000000),
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, opacity),
              blurRadius: blurRadius,
              spreadRadius: spreadRadius,
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 수 이미지 위에서 이전 숫자와 새 숫자를 교차 이동시킵니다.
///
/// 부모 [RoundStartReveal]의 상태가 유지되는 동안 서버에서 잔여 카드 수가
/// 갱신되면, 감소한 숫자는 위로 사라지고 새 숫자는 아래에서 올라옵니다.
class _RemainingCardCounter extends StatefulWidget {
  const _RemainingCardCounter({
    super.key,
    required this.asset,
    required this.count,
    required this.isCurrentTurn,
  });

  final GameImage asset;
  final int count;
  final bool isCurrentTurn;

  @override
  State<_RemainingCardCounter> createState() => _RemainingCardCounterState();
}

class _RemainingCardCounterState extends State<_RemainingCardCounter>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 420);
  static const _numberOffsetX = 5.0;
  static const _numberStyle = TextStyle(
    color: Colors.black,
    fontSize: 36,
    height: 1,
    fontWeight: FontWeight.w800,
  );

  late final AnimationController _numberController;
  late int _previousCount;
  late int _currentCount;

  @override
  void initState() {
    super.initState();
    _previousCount = widget.count;
    _currentCount = widget.count;
    _numberController = AnimationController(
      vsync: this,
      duration: _animationDuration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(_RemainingCardCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count == widget.count) return;

    // 빠르게 연속 제출해도 화면에 마지막으로 보인 수에서 새 값으로 이어집니다.
    _previousCount = _currentCount;
    _currentCount = widget.count;
    _numberController.forward(from: 0);
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.isCurrentTurn ? 1 : 0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          widget.asset.image(
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          AnimatedBuilder(
            animation: _numberController,
            builder: (context, _) {
              final progress = Curves.easeOutCubic.transform(
                _numberController.value,
              );
              final isDecreasing = _currentCount < _previousCount;
              final direction = isDecreasing ? -1.0 : 1.0;

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (_numberController.isAnimating)
                    _buildNumber(
                      _previousCount,
                      opacity: 1 - progress,
                      offsetY: direction * 14 * progress,
                    ),
                  _buildNumber(
                    _currentCount,
                    opacity: progress,
                    offsetY: -direction * 14 * (1 - progress),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      builder: (context, progress, child) {
        final brightness = 0.42 + (0.58 * progress);
        final channel = (255 * brightness).round();
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            Color.fromARGB(255, channel, channel, channel),
            BlendMode.modulate,
          ),
          child: child,
        );
      },
    );
  }

  Widget _buildNumber(
    int count, {
    required double opacity,
    required double offsetY,
  }) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(_numberOffsetX, offsetY),
        child: Text('$count', style: _numberStyle),
      ),
    );
  }
}
