import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/games/liars_poker/sound/liars_poker_sounds.dart';
import 'package:project00/games/shared/player_layouts/player_slot_positions.dart';
import 'package:project00/gen/assets.gen.dart';

// final playKey = GlobalKey<CardPlayAnimationState>();

// CardPlayAnimation(
//   key: playKey,
//   playerCount: 5,
//   fromPlayerIndex: 2,
//   frontCardAssets: [
//     Assets.games.liarsPoker.images.cards.whiteQ,
//     Assets.games.liarsPoker.images.cards.whiteQ,
//     Assets.games.liarsPoker.images.cards.whiteJoker,
//   ],
//   onCardsPlayed: () {
//     // 다음 플레이어 차례
//   },
//   onRevealed: () {
//     // 라이어 판정
//   },
// )

// 라이어 외쳤을때
// playKey.currentState?.reveal();

//CardPlayAnimation(
//   revealCards: isLiarCalled,
// )

/// 플레이어 자리에서 패를 뒷면으로 중앙에 던지고, 라이어 선언 시 공개합니다.
class CardPlayAnimation extends StatefulWidget {
  const CardPlayAnimation({
    super.key,
    required this.frontCardAssets,
    this.backCardAsset,
    this.playerCount = 5,
    this.playerSeatIndexes,
    this.fromPlayerIndex = 0,
    this.fromPosition,
    this.tableAlignment = Alignment.center,
    this.cardWidth = 245,
    this.throwDuration = const Duration(milliseconds: 540),
    this.throwStagger = const Duration(milliseconds: 55),
    this.revealDuration = const Duration(milliseconds: 900),
    this.autoplay = true,
    this.initiallyPlayed = false,
    this.revealCards = false,
    this.revealOnTap = true,
    this.onCardsPlayed,
    this.onRevealed,
  }) : assert(frontCardAssets.length > 0),
       assert(playerCount > 0),
       assert(
         playerSeatIndexes == null || playerSeatIndexes.length == playerCount,
         'playerSeatIndexes의 개수는 playerCount와 같아야 합니다.',
       ),
       assert(fromPlayerIndex >= 0 && fromPlayerIndex < playerCount),
       assert(cardWidth > 0),
       assert(throwDuration > Duration.zero),
       assert(throwStagger >= Duration.zero),
       assert(revealDuration > Duration.zero);

  /// 실제로 낸 카드의 앞면입니다. 던질 때는 [backCardAsset]만 보입니다.
  final List<AssetGenImage> frontCardAssets;
  final AssetGenImage? backCardAsset;

  /// 공통 플레이어 배치에서 패를 던지는 플레이어입니다.
  final int playerCount;
  final List<int>? playerSeatIndexes;
  final int fromPlayerIndex;

  /// 직접 지정할 경우 사용하는 플레이어 중심 정규화 좌표입니다.
  final Offset? fromPosition;

  final Alignment tableAlignment;
  final double cardWidth;
  final Duration throwDuration;
  final Duration throwStagger;
  final Duration revealDuration;
  final bool autoplay;

  /// 이미 중앙 더미에 놓인 카드라면 이동 애니메이션을 완료 상태로 시작합니다.
  final bool initiallyPlayed;

  /// false에서 true로 변경하면 뒷면으로 놓인 카드가 공개됩니다.
  final bool revealCards;

  /// 중앙에 놓인 카드 더미를 직접 눌러 공개할지 여부입니다.
  final bool revealOnTap;

  final VoidCallback? onCardsPlayed;
  final VoidCallback? onRevealed;

  @override
  CardPlayAnimationState createState() => CardPlayAnimationState();
}

class CardPlayAnimationState extends State<CardPlayAnimation>
    with TickerProviderStateMixin {
  /// 카드가 살짝 들렸다가 테이블에 닿는 순간 짧게 눌리는 크기 변화입니다.
  static final Animatable<double> _throwScaleMotion = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.86,
        end: 1.035,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 68,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.035,
        end: 0.975,
      ).chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 16,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.975,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 16,
    ),
  ]);

  /// 던진 카드가 테이블에 닿는 시점입니다(카드 한 장의 비행 구간 기준).
  ///
  /// [_throwScaleMotion]의 첫 구간 weight(68)와 같은 값입니다. 카드가 가장 크게
  /// 보인 뒤 눌리기 시작하는 순간이 착지입니다.
  static const double _throwImpactProgress = 0.68;

  /// [cardIndex]번째 카드가 뒤집기를 시작·끝내는 진행도입니다.
  ///
  /// 화면과 효과음이 같은 값을 쓰도록 여기서만 정의합니다.
  static double _flipStartOf(int cardIndex) => 0.16 + cardIndex * 0.055;

  static double _flipEndOf(int cardIndex) =>
      math.min(0.92, _flipStartOf(cardIndex) + 0.56);

  late final AnimationController _throwController;
  late final AnimationController _revealController;

  bool _throwLandingSoundPlayed = false;
  bool _revealLandingSoundPlayed = false;

  Duration get _totalThrowDuration {
    final lastCardDelay =
        widget.throwStagger.inMilliseconds *
        (widget.frontCardAssets.length - 1);
    return Duration(
      milliseconds: lastCardDelay + widget.throwDuration.inMilliseconds,
    );
  }

  @override
  void initState() {
    super.initState();
    _throwController =
        AnimationController(
            vsync: this,
            duration: _totalThrowDuration,
            value: widget.initiallyPlayed ? 1 : 0,
          )
          ..addStatusListener(_onThrowStatusChanged)
          ..addListener(_playThrowLandingSound);
    _revealController =
        AnimationController(
            vsync: this,
            duration: widget.revealDuration,
            value: widget.initiallyPlayed && widget.revealCards ? 1 : 0,
          )
          ..addStatusListener(_onRevealStatusChanged)
          ..addListener(_playRevealLandingSound);

    // 재접속·화면 재구성으로 이미 놓인 패를 복원할 때는 소리를 내지 않습니다.
    if (widget.initiallyPlayed) {
      _throwLandingSoundPlayed = true;
      if (widget.revealCards) _revealLandingSoundPlayed = true;
    }

    if (widget.autoplay && !widget.initiallyPlayed) {
      playCards().then((_) {
        if (mounted && widget.revealCards) {
          reveal();
        }
      });
    }
  }

  @override
  void didUpdateWidget(CardPlayAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.throwDuration != widget.throwDuration ||
        oldWidget.throwStagger != widget.throwStagger ||
        oldWidget.frontCardAssets.length != widget.frontCardAssets.length) {
      _throwController.duration = _totalThrowDuration;
    }
    if (oldWidget.revealDuration != widget.revealDuration) {
      _revealController.duration = widget.revealDuration;
    }

    if (!oldWidget.autoplay &&
        widget.autoplay &&
        !_throwController.isAnimating) {
      playCards();
    }
    if (!oldWidget.revealCards && widget.revealCards) {
      reveal();
    }
  }

  void _onThrowStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCardsPlayed?.call();
    }
  }

  void _onRevealStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onRevealed?.call();
    }
  }

  /// 현재 플레이어 자리에서 중앙 테이블로 패를 던집니다.
  Future<void> playCards({bool restart = false}) async {
    if (restart) {
      _revealController.reset();
      _throwLandingSoundPlayed = false;
      _revealLandingSoundPlayed = false;
      await _throwController.forward(from: 0);
      return;
    }
    if (!_throwController.isCompleted) {
      await _throwController.forward();
    }
  }

  /// 던져진 패를 펼치면서 뒷면에서 앞면으로 공개합니다.
  Future<void> reveal({bool restart = false}) async {
    if (!_throwController.isCompleted) {
      await playCards();
    }
    if (!mounted ||
        (!restart &&
            (_revealController.isAnimating || _revealController.isCompleted))) {
      return;
    }
    if (restart) _revealLandingSoundPlayed = false;
    await _revealController.forward(from: restart ? 0 : null);
  }

  /// 던진 패가 테이블에 닿는 순간에 맞춰 효과음을 재생합니다.
  ///
  /// [_throwScaleMotion]에서 카드가 눌리기 시작하는 지점이 착지 순간입니다.
  void _playThrowLandingSound() {
    if (!mounted || _throwLandingSoundPlayed) return;

    final totalMilliseconds = _totalThrowDuration.inMilliseconds;
    if (totalMilliseconds <= 0) return;

    final elapsed = _throwController.value * totalMilliseconds;
    final impactAt = widget.throwDuration.inMilliseconds * _throwImpactProgress;
    if (elapsed < impactAt) return;

    _throwLandingSoundPlayed = true;
    SoundEffects.play(context, LiarsPokerSounds.submit);
  }

  /// 뒤집던 카드가 테이블에 다시 내려앉는 순간에 맞춰 효과음을 재생합니다.
  ///
  /// 카드는 뒤집히는 동안 살짝 떠 있다가([_flipLift]) 뒤집기가 끝나면서 다시
  /// 바닥에 놓입니다. 연출 시작에 재생하면 첫 장이 내려앉기까지 남은 시간만큼
  /// (기본 900ms 기준 약 650ms) 소리가 먼저 들립니다.
  void _playRevealLandingSound() {
    if (!mounted || _revealLandingSoundPlayed) return;
    if (_revealController.value < _flipEndOf(0)) return;

    _revealLandingSoundPlayed = true;
    SoundEffects.play(context, LiarsPokerSounds.submit);
  }

  /// 공개된 패를 다시 뒷면 상태로 되돌립니다.
  Future<void> conceal() => _revealController.reverse();

  void reset() {
    _throwController.reset();
    _revealController.reset();
    _throwLandingSoundPlayed = false;
    _revealLandingSoundPlayed = false;
  }

  @override
  void dispose() {
    _throwController
      ..removeStatusListener(_onThrowStatusChanged)
      ..removeListener(_playThrowLandingSound)
      ..dispose();
    _revealController
      ..removeStatusListener(_onRevealStatusChanged)
      ..removeListener(_playRevealLandingSound)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 600,
          constraints.hasBoundedHeight ? constraints.maxHeight : 420,
        );

        return ClipRect(
          child: AnimatedBuilder(
            animation: Listenable.merge([_throwController, _revealController]),
            builder: (context, _) {
              return SizedBox.fromSize(
                size: size,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (
                      var cardIndex = 0;
                      cardIndex < widget.frontCardAssets.length;
                      cardIndex++
                    )
                      _buildAnimatedCard(size: size, cardIndex: cardIndex),
                    if (widget.revealOnTap) _buildRevealTapTarget(size),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRevealTapTarget(Size size) {
    const cardAspectRatio = 512 / 350;
    final cardWidth = _effectiveCardWidth(size);
    final cardHeight = cardWidth * cardAspectRatio;
    final extraCards = math.max(0, widget.frontCardAssets.length - 1);
    final tapWidth = cardWidth + cardWidth * 0.18 * extraCards + 36;
    final tapHeight = cardHeight + cardHeight * 0.055 * extraCards + 36;
    final tableCenter = Offset(
      (widget.tableAlignment.x + 1) * size.width / 2,
      (widget.tableAlignment.y + 1) * size.height / 2,
    );
    final canReveal =
        !_revealController.isAnimating && !_revealController.isCompleted;

    return Positioned(
      left: tableCenter.dx - tapWidth / 2,
      top: tableCenter.dy - tapHeight / 2,
      width: tapWidth,
      height: tapHeight,
      child: Semantics(
        button: canReveal,
        label: '낸 카드 공개',
        child: MouseRegion(
          cursor: canReveal
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: canReveal ? () => reveal() : null,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCard({required Size size, required int cardIndex}) {
    const cardAspectRatio = 512 / 350;
    final cardCount = widget.frontCardAssets.length;
    final cardWidth = _effectiveCardWidth(size);
    final cardHeight = cardWidth * cardAspectRatio;
    final centeredIndex = cardIndex - (cardCount - 1) / 2;

    final customSource = widget.fromPosition;
    final seatIndex =
        widget.playerSeatIndexes?[widget.fromPlayerIndex] ??
        widget.fromPlayerIndex;
    final source = customSource == null
        ? playerCentersForBoard(
            playerCount: widget.playerCount,
            boardSize: size,
          )[seatIndex]
        : playerCenterFromNormalized(
            normalizedCenter: customSource,
            boardSize: size,
          );
    final tableCenter = Offset(
      (widget.tableAlignment.x + 1) * size.width / 2,
      (widget.tableAlignment.y + 1) * size.height / 2,
    );

    final sourceDirection = tableCenter - source;
    final inwardDirection = sourceDirection.distanceSquared == 0
        ? const Offset(0, -1)
        : sourceDirection / sourceDirection.distance;
    final tangentDirection = Offset(-inwardDirection.dy, inwardDirection.dx);

    // 제출 플레이어가 바라보는 원 중심 방향을 유지하며 옆으로 겹칩니다.
    final tightStep =
        tangentDirection * (cardWidth * 0.105) +
        inwardDirection * (cardHeight * 0.035);
    final revealedStep =
        tangentDirection * (cardWidth * 0.18) +
        inwardDirection * (cardHeight * 0.055);
    final faceDownTarget = tableCenter + tightStep * centeredIndex;
    final faceUpTarget = tableCenter + revealedStep * centeredIndex;

    final totalMilliseconds = _totalThrowDuration.inMilliseconds;
    final elapsedMilliseconds = _throwController.value * totalMilliseconds;
    final cardStartMilliseconds =
        cardIndex * widget.throwStagger.inMilliseconds;
    final throwProgress =
        ((elapsedMilliseconds - cardStartMilliseconds) /
                widget.throwDuration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble();
    // 전체 시간의 앞부분에 이동을 끝내고, 남은 시간은 짧은 착지에 사용합니다.
    final easedThrow = _interval(throwProgress, 0, 0.76, Curves.easeOutQuart);

    final curveSide = seatIndex.isEven ? 1.0 : -1.0;
    final controlPoint =
        Offset.lerp(source, faceDownTarget, 0.5)! +
        tangentDirection * math.min(18, size.shortestSide * 0.035) * curveSide;
    var position = _quadraticBezier(
      source,
      controlPoint,
      faceDownTarget,
      easedThrow,
    );

    final spreadProgress = _interval(
      _revealController.value,
      0,
      0.46,
      Curves.easeOutCubic,
    );
    position = Offset.lerp(position, faceUpTarget, spreadProgress)!;

    final flipStart = _flipStartOf(cardIndex);
    final flipEnd = _flipEndOf(cardIndex);
    final flipProgress = _interval(
      _revealController.value,
      flipStart,
      flipEnd,
      Curves.easeInOutCubic,
    );
    final flipLift = math.sin(flipProgress * math.pi);
    position += Offset(0, -cardHeight * 0.09 * flipLift);

    final sourceRotation =
        math.atan2(sourceDirection.dy, sourceDirection.dx) + math.pi / 2;
    final pileRotation = sourceRotation + centeredIndex * 0.055;
    final revealedRotation = sourceRotation + centeredIndex * 0.035;
    final flickRotation = math.sin(throwProgress * math.pi) * 0.13 * curveSide;
    final throwRotation =
        lerpDouble(sourceRotation, pileRotation, easedThrow)! + flickRotation;
    final zRotation = lerpDouble(
      throwRotation,
      revealedRotation,
      spreadProgress,
    )!;

    final isFrontVisible = flipProgress >= 0.5;
    final yRotation = isFrontVisible
        ? math.pi * (1 - flipProgress)
        : math.pi * flipProgress;
    final throwScale = _throwScaleMotion.transform(throwProgress);
    final scale = throwScale * (1 + flipLift * 0.07);
    final throwLift = math.sin(throwProgress * math.pi).clamp(0.0, 1.0);
    final visualLift = math.max(throwLift, flipLift);
    final throwOpacity = _interval(throwProgress, 0, 0.1, Curves.easeOut);

    return Positioned(
      left: position.dx - cardWidth / 2,
      top: position.dy - cardHeight / 2,
      width: cardWidth,
      height: cardHeight,
      child: Opacity(
        opacity: throwOpacity,
        child: Transform.rotate(
          angle: zRotation,
          child: Transform.scale(
            scale: scale,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(yRotation),
              child: _buildCard(
                isFrontVisible
                    ? widget.frontCardAssets[cardIndex]
                    : widget.backCardAsset ??
                          Assets.games.liarsPoker.images.cards.whiteBack,
                lift: visualLift,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(AssetGenImage asset, {required double lift}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: const Color(0x66000000),
            blurRadius: 7 + lift * 9,
            offset: Offset(0, 5 + lift * 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: asset.image(
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  double _effectiveCardWidth(Size size) {
    final minimumCardWidth = math.min(52.0, widget.cardWidth);
    return math
        .min(widget.cardWidth, math.min(size.width * 0.48, size.height * 0.64))
        .clamp(minimumCardWidth, widget.cardWidth)
        .toDouble();
  }

  Offset _quadraticBezier(
    Offset start,
    Offset control,
    Offset end,
    double progress,
  ) {
    final inverse = 1 - progress;
    return start * (inverse * inverse) +
        control * (2 * inverse * progress) +
        end * (progress * progress);
  }

  double _interval(double value, double begin, double end, Curve curve) {
    final progress = ((value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(progress);
  }
}
