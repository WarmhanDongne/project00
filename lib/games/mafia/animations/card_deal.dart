import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/shared/player_layouts/player_slot_positions.dart';

typedef DealCardBuilder =
    Widget Function(BuildContext context, int playerIndex, int cardIndex);

/// 중앙 카드 더미에서 각 플레이어에게 카드를 빠르게 분배한 뒤,
/// 완성된 카드 묶음을 화면 바깥으로 내보내는 애니메이션입니다.
///
/// [playerCount]와 [cardsPerPlayer]만 바꾸면 전체 카드 수와 분배 속도가
/// 자동으로 다시 계산됩니다. 기본 도착 위치는 `player_layouts`의 2~6인
/// `slotPositions`와 동일합니다.
class CardDealAnimation extends StatefulWidget {
  const CardDealAnimation({
    super.key,
    this.playerCount = 4,
    this.playerSeatIndexes,
    this.playerPositions,
    this.cardsPerPlayer = 5,
    this.cardAsset = 'assets/games/liars_poker/images/cards/white back.png',
    this.cardBuilder,
    this.cardWidth = 168,
    this.duration = const Duration(milliseconds: 2800),
    this.autoplay = false,
    this.tapToStart = true,
    this.loop = false,
    this.backgroundColor,
    this.onCompleted,
  }) : assert(playerCount > 0),
       assert(
         playerSeatIndexes == null || playerSeatIndexes.length == playerCount,
         'playerSeatIndexes의 개수는 playerCount와 같아야 합니다.',
       ),
       assert(
         playerPositions == null || playerPositions.length == playerCount,
         'playerPositions의 개수는 playerCount와 같아야 합니다.',
       ),
       assert(cardsPerPlayer > 0),
       assert(cardWidth > 0);

  /// 카드를 받는 플레이어 수입니다.
  final int playerCount;

  /// 플레이어 인덱스별 실제 좌석 번호입니다.
  /// 예: `[2, 0, 1]`이면 첫 번째 플레이어는 2번 좌석으로 분배됩니다.
  final List<int>? playerSeatIndexes;

  /// 각 플레이어 영역의 좌측 상단 정규화 좌표입니다.
  ///
  /// `player_layouts`에서 저장한 실제 자리 좌표가 있다면 그대로 전달할 수
  /// 있습니다. 생략하면 인원 수에 맞는 기본 `slotPositions`를 사용합니다.
  final List<Offset>? playerPositions;

  /// 플레이어 한 명이 받는 카드 수입니다.
  final int cardsPerPlayer;

  /// [cardBuilder]를 지정하지 않았을 때 표시할 카드 뒷면 에셋입니다.
  final String cardAsset;

  /// 게임별 카드 UI를 직접 전달할 때 사용합니다.
  final DealCardBuilder? cardBuilder;

  /// 카드 너비입니다. 높이는 실제 카드 비율(350:512)에 맞춰 계산됩니다.
  final double cardWidth;

  /// 등장, 분배, 잠시 대기, 퇴장을 모두 포함한 전체 재생 시간입니다.
  final Duration duration;

  /// 위젯이 화면에 나타나면 바로 재생할지 여부입니다.
  final bool autoplay;

  /// 중앙 카드 더미를 눌렀을 때 분배를 시작할지 여부입니다.
  final bool tapToStart;

  /// 전체 동작을 계속 반복할지 여부입니다.
  final bool loop;

  /// 지정하지 않으면 아무 배경도 그리지 않아 뒤쪽 게임 화면이 그대로 보입니다.
  final Color? backgroundColor;
  final VoidCallback? onCompleted;

  @override
  CardDealAnimationState createState() => CardDealAnimationState();
}

class CardDealAnimationState extends State<CardDealAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onStatusChanged);

    if (widget.autoplay) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(CardDealAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    if (!oldWidget.autoplay && widget.autoplay && !_controller.isAnimating) {
      play();
    }
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }

    widget.onCompleted?.call();

    if (widget.loop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward(from: 0);
        }
      });
    }
  }

  /// 현재 위치부터 재생합니다. [restart]가 true면 처음부터 다시 시작합니다.
  void play({bool restart = false}) {
    if (restart || _controller.isCompleted) {
      _controller.forward(from: 0);
    } else {
      _controller.forward();
    }
  }

  void pause() => _controller.stop();

  void reset() => _controller.reset();

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.hasBoundedWidth ? constraints.maxWidth : 480,
            constraints.hasBoundedHeight ? constraints.maxHeight : 320,
          );

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _buildScene(context, size),
          );
        },
      ),
    );

    final backgroundColor = widget.backgroundColor;
    if (backgroundColor == null) {
      return animation;
    }

    return ColoredBox(color: backgroundColor, child: animation);
  }

  Widget _buildScene(BuildContext context, Size size) {
    final totalCards = widget.playerCount * widget.cardsPerPlayer;

    // 역순으로 그려서 현재 분배 중인 카드가 중앙 더미의 맨 위에 보입니다.
    final cards = List<Widget>.generate(totalCards, (reverseIndex) {
      final dealIndex = totalCards - reverseIndex - 1;
      return _buildAnimatedCard(context, size, dealIndex, totalCards);
    });

    if (widget.tapToStart && _controller.value == 0) {
      cards.add(_buildDeckTapTarget(size));
    }

    return SizedBox.fromSize(
      size: size,
      child: Stack(clipBehavior: Clip.none, children: cards),
    );
  }

  Widget _buildDeckTapTarget(Size size) {
    final cardWidth = _effectiveCardWidth(size);
    const cardAspectRatio = 512 / 350;
    final cardHeight = cardWidth * cardAspectRatio;

    return Positioned(
      left: (size.width - cardWidth) / 2,
      top: (size.height - cardHeight) / 2,
      width: cardWidth,
      height: cardHeight + 8,
      child: Semantics(
        button: true,
        label: '카드 분배 시작',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => play(restart: true),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCard(
    BuildContext context,
    Size size,
    int dealIndex,
    int totalCards,
  ) {
    const cardAspectRatio = 512 / 350;
    const dealEnd = 0.72;
    const exitStart = 0.84;

    final cardWidth = _effectiveCardWidth(size);
    final cardHeight = cardWidth * cardAspectRatio;
    final center = Offset(size.width / 2, size.height / 2);

    final playerIndex = dealIndex % widget.playerCount;
    final cardIndex = dealIndex ~/ widget.playerCount;
    final playerTarget = _playerTarget(size: size, playerIndex: playerIndex);
    final targetDelta = playerTarget - center;
    final direction = targetDelta.distanceSquared == 0
        ? const Offset(0, -1)
        : targetDelta / targetDelta.distance;
    final angle = math.atan2(direction.dy, direction.dx);
    final tangent = Offset(-direction.dy, direction.dx);

    final stackOffset = tangent * (cardIndex * 1.8);
    final target = playerTarget + stackOffset;

    // 카드 수가 많아져도 마지막 카드는 dealEnd 전에 도착하도록 간격을 압축합니다.
    final flightLength = math.min(0.15, dealEnd / totalCards * 3.2);
    final lastStart = math.max(0.0, dealEnd - flightLength);
    final dealStart = totalCards == 1
        ? 0.0
        : lastStart * dealIndex / (totalCards - 1);
    final dealProgress = _intervalProgress(
      _controller.value,
      dealStart,
      dealStart + flightLength,
      Curves.easeOutCubic,
    );
    final exitProgress = _intervalProgress(
      _controller.value,
      exitStart,
      1,
      Curves.easeInCubic,
    );

    // 시작 화면에서 여러 장의 아래쪽 테두리가 보여 카드 더미처럼 느껴집니다.
    final deckLayer = math.min(dealIndex, 7);
    final deckPosition = center + Offset(0, deckLayer * 1.15);
    var position = Offset.lerp(deckPosition, target, dealProgress)!;

    // 직선보다 생동감 있게 보이도록 이동 중 바깥 방향으로 살짝 휘게 합니다.
    final arc = math.sin(dealProgress * math.pi) * cardWidth * 0.16;
    position += direction * arc;

    final targetRotation = angle + math.pi / 2;
    final rotation =
        targetRotation * dealProgress +
        direction.dx * 0.025 * cardIndex * dealProgress;

    // 분배 구간에는 현재 회전된 카드의 외곽 크기를 기준으로 화면 안에 유지합니다.
    // 퇴장 구간에는 보정을 해제해야 카드 묶음이 정상적으로 밖으로 빠집니다.
    if (exitProgress == 0) {
      position = _keepCardInside(
        size: size,
        position: position,
        cardWidth: cardWidth,
        cardHeight: cardHeight,
        rotation: rotation,
      );
    }

    // 분배된 묶음 전체가 각 플레이어 방향의 화면 바깥으로 빠집니다.
    final exitDistance = math.max(size.width, size.height) * 0.82;
    position += direction * exitDistance * exitProgress;

    final opacity =
        1 -
        Curves.easeIn.transform(((exitProgress - 0.68) / 0.32).clamp(0.0, 1.0));

    return Positioned(
      left: position.dx - cardWidth / 2,
      top: position.dy - cardHeight / 2,
      width: cardWidth,
      height: cardHeight,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: rotation,
            child: _buildCard(context, playerIndex, cardIndex),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, int playerIndex, int cardIndex) {
    final customCard = widget.cardBuilder?.call(
      context,
      playerIndex,
      cardIndex,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child:
            customCard ??
            Image.asset(
              widget.cardAsset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
      ),
    );
  }

  double _effectiveCardWidth(Size size) {
    return math
        .min(widget.cardWidth, math.max(76, size.shortestSide * 0.58))
        .toDouble();
  }

  Offset _keepCardInside({
    required Size size,
    required Offset position,
    required double cardWidth,
    required double cardHeight,
    required double rotation,
  }) {
    const safePadding = 12.0;
    final cosine = math.cos(rotation).abs();
    final sine = math.sin(rotation).abs();

    // 회전된 사각형의 축 정렬 외곽 영역(AABB) 절반 크기입니다.
    final halfBoundsWidth = (cardWidth * cosine + cardHeight * sine) / 2;
    final halfBoundsHeight = (cardWidth * sine + cardHeight * cosine) / 2;

    return Offset(
      _safeCoordinate(
        value: position.dx,
        minimum: halfBoundsWidth + safePadding,
        maximum: size.width - halfBoundsWidth - safePadding,
        fallback: size.width / 2,
      ),
      _safeCoordinate(
        value: position.dy,
        minimum: halfBoundsHeight + safePadding,
        maximum: size.height - halfBoundsHeight - safePadding,
        fallback: size.height / 2,
      ),
    );
  }

  double _safeCoordinate({
    required double value,
    required double minimum,
    required double maximum,
    required double fallback,
  }) {
    if (minimum > maximum) {
      return fallback;
    }

    return value.clamp(minimum, maximum).toDouble();
  }

  Offset _playerTarget({required Size size, required int playerIndex}) {
    final positions = widget.playerPositions;
    if (positions != null && playerIndex < positions.length) {
      const playerSlotSize = 160.0;
      final position = positions[playerIndex];

      // player_layouts의 좌측 상단 좌표를 160x160 플레이어 영역의 중심으로 변환합니다.
      return Offset(
        position.dx * size.width + playerSlotSize / 2,
        position.dy * size.height + playerSlotSize / 2,
      );
    }

    final centers = playerCentersForBoard(
      playerCount: widget.playerCount,
      boardSize: size,
    );
    final seatIndex = widget.playerSeatIndexes?[playerIndex] ?? playerIndex;
    return centers[seatIndex];
  }

  double _intervalProgress(
    double value,
    double begin,
    double end,
    Curve curve,
  ) {
    final progress = ((value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(progress);
  }
}
