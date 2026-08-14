import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/animations/card_deal.dart';
import 'package:project00/games/final_call/animations/tablet_center_card_reveal.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_controller.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_helper.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';
import 'package:project00/games/shared/player_layouts/player_slot_positions.dart';
import 'package:project00/gen/assets.gen.dart';

/// 중앙 덱, 플레이어별 생명과 라운드 공개 손패를 그리는 아이패드 보드입니다.
class FinalCallTabletGameLayer extends StatelessWidget {
  const FinalCallTabletGameLayer({
    super.key,
    required this.controller,
    required this.onRoundRevealCompleted,
  });

  final PhoneGameController controller;
  final VoidCallback onRoundRevealCompleted;

  @override
  Widget build(BuildContext context) {
    if (controller.phase == 'dealing') {
      final players =
          controller.players.values
              .where((player) => player.status == 'alive')
              .toList()
            ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
      if (players.isEmpty) return const SizedBox.shrink();

      //=======================태블릿 카드 배분==============================
      return LayoutBuilder(
        builder: (context, constraints) {
          final allSeatPositions = normalizedPlayerSlotTopLeftPositions(
            playerCount: controller.players.length,
            boardSize: constraints.biggest,
          );
          return CardDealAnimation(
            key: ValueKey('final-call-deal-${controller.round}'),
            playerCount: players.length,
            playerPositions: players
                .map((player) => allSeatPositions[player.seatIndex])
                .toList(growable: false),
            cardsPerPlayer: 4,
            cardAsset: Assets.games.finalCall.images.cards.cardBack,
            cardWidth: 146,
            duration: const Duration(milliseconds: 2800),
            onCompleted: () => controller.completeDealing(),
          );
        },
      );
    }

    final players = controller.players.values.toList(growable: false)
      ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
    final result = controller.roundResult;
    if (result == null) {
      final visibleDiscard =
          controller.discardEvent?.previousCard ?? controller.discardCard;
      final hideDiscardWhileTaken =
          controller.pendingDrawUid != null &&
          controller.pendingDrawSource == 'discard';
      final hideDiscardDuringThrow =
          controller.discardEvent?.drawSource == 'discard';
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: FinalCallCenterCardReveal(
              key: ValueKey('center-card-${controller.round}'),
              card: visibleDiscard,
              cardWidth: 148,
              showRevealedCard:
                  !hideDiscardWhileTaken && !hideDiscardDuringThrow,
            ),
          ),
          _FinalCallLivesLayer(players: players),
        ],
      );
    }

    return _RevealedTable(
      key: ValueKey('round-result-${controller.round}'),
      controller: controller,
      result: result,
      onCompleted: onRoundRevealCompleted,
    );
  }
}

/// 제출 카드 전체를 뒷면으로 먼저 배치한 뒤 플레이어 한 명씩 공개합니다.
class _RevealedTable extends StatefulWidget {
  const _RevealedTable({
    super.key,
    required this.controller,
    required this.result,
    required this.onCompleted,
  });

  final PhoneGameController controller;
  final FinalCallRoundResult result;
  final VoidCallback onCompleted;

  @override
  State<_RevealedTable> createState() => _RevealedTableState();
}

class _RevealedTableState extends State<_RevealedTable>
    with SingleTickerProviderStateMixin {
  static const int _initialHoldMs = 900;
  static const int _focusMs = 520;
  static const int _cardStepMs = 900;
  static const int _cardFlipMs = 680;
  static const int _settleMs = 520;
  static const int _heartMs = 1500;

  late final List<FinalCallPlayer> _players;
  late final List<int> _playerStarts;
  late final int _heartStart;
  late final int _totalDurationMs;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _players =
        widget.controller.players.values
            .where(
              (player) => widget.result.revealedHands.containsKey(player.uid),
            )
            .toList()
          ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));

    var cursor = _initialHoldMs;
    _playerStarts = <int>[];
    for (final player in _players) {
      _playerStarts.add(cursor);
      final cardCount = widget.result.revealedHands[player.uid]?.length ?? 0;
      cursor += _focusMs + cardCount * _cardStepMs + _settleMs;
    }
    _heartStart = cursor;
    _totalDurationMs = _heartStart + _heartMs;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalDurationMs),
    )..addStatusListener(_handleStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onCompleted();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.biggest;
        final seatCount = widget.controller.players.length;
        final seatCardLimit = switch (seatCount) {
          >= 4 => 68.0,
          3 => 82.0,
          _ => 108.0,
        };
        final cardWidth = math.max(
          46.0,
          math.min(seatCardLimit, boardSize.shortestSide * 0.12),
        );
        final centers = playerCentersForBoard(
          playerCount: seatCount,
          boardSize: boardSize,
        );
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final elapsed = _controller.value * _totalDurationMs;
            final heartProgress = ((elapsed - _heartStart) / _heartMs).clamp(
              0.0,
              1.0,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: FinalCallCenterCardReveal(
                    key: ValueKey(
                      'result-center-card-${widget.controller.round}',
                    ),
                    card: widget.controller.discardCard,
                    cardWidth: 128,
                  ),
                ),
                for (var index = 0; index < _players.length; index++)
                  _buildPositionedHand(
                    player: _players[index],
                    desiredCenter: centers[_players[index].seatIndex],
                    boardSize: boardSize,
                    cardWidth: cardWidth,
                    elapsedMs: elapsed - _playerStarts[index],
                    heartProgress: heartProgress,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPositionedHand({
    required FinalCallPlayer player,
    required Offset desiredCenter,
    required Size boardSize,
    required double cardWidth,
    required double elapsedMs,
    required double heartProgress,
  }) {
    final cards = widget.result.revealedHands[player.uid] ?? const [];
    final handScale = _revealedHandScale(
      elapsedMs: elapsedMs,
      cardCount: cards.length,
      focusMs: _focusMs,
      cardStepMs: _cardStepMs,
      settleMs: _settleMs,
    );
    final rotation = finalCallSeatRotationForCenter(
      center: desiredCenter,
      boardSize: boardSize,
    );
    final rowWidth = cards.length * (cardWidth + 8);
    final contentHeight = cardWidth * finalCallCardHeightRatio + 110;
    final center = _keepRevealedHandInside(
      desiredCenter: desiredCenter,
      boardSize: boardSize,
      contentSize: Size(rowWidth, contentHeight),
      rotation: rotation,
      contentScale: handScale,
    );
    return Positioned(
      left: center.dx,
      top: center.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: rotation,
          child: _SequencedRevealedHand(
            cards: cards,
            finalScore: widget.result.scores[player.uid] ?? 0,
            cardWidth: cardWidth,
            elapsedMs: elapsedMs,
            focusMs: _focusMs,
            cardStepMs: _cardStepMs,
            cardFlipMs: _cardFlipMs,
            settleMs: _settleMs,
            player: player,
            lifeLoss: widget.result.lifeLosses[player.uid] ?? 0,
            heartProgress: heartProgress,
          ),
        ),
      ),
    );
  }

  Offset _keepRevealedHandInside({
    required Offset desiredCenter,
    required Size boardSize,
    required Size contentSize,
    required double rotation,
    required double contentScale,
  }) {
    const safePadding = 12.0;
    final cosine = math.cos(rotation).abs();
    final sine = math.sin(rotation).abs();
    final halfWidth =
        (contentSize.width * cosine + contentSize.height * sine) *
        contentScale /
        2;
    final halfHeight =
        (contentSize.width * sine + contentSize.height * cosine) *
        contentScale /
        2;
    double safeCoordinate(double value, double halfExtent, double total) {
      final minimum = halfExtent + safePadding;
      final maximum = total - halfExtent - safePadding;
      if (minimum > maximum) return total / 2;
      return value.clamp(minimum, maximum).toDouble();
    }

    return Offset(
      safeCoordinate(desiredCenter.dx, halfWidth, boardSize.width),
      safeCoordinate(desiredCenter.dy, halfHeight, boardSize.height),
    );
  }
}

class _SequencedRevealedHand extends StatelessWidget {
  const _SequencedRevealedHand({
    required this.cards,
    required this.finalScore,
    required this.cardWidth,
    required this.elapsedMs,
    required this.focusMs,
    required this.cardStepMs,
    required this.cardFlipMs,
    required this.settleMs,
    required this.player,
    required this.lifeLoss,
    required this.heartProgress,
  });

  final List<FinalCallCard> cards;
  final int finalScore;
  final double cardWidth;
  final double elapsedMs;
  final int focusMs;
  final int cardStepMs;
  final int cardFlipMs;
  final int settleMs;
  final FinalCallPlayer player;
  final int lifeLoss;
  final double heartProgress;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final revealEnd = focusMs + cards.length * cardStepMs;
    final segmentEnd = revealEnd + settleMs;
    final scale = _revealedHandScale(
      elapsedMs: elapsedMs,
      cardCount: cards.length,
      focusMs: focusMs,
      cardStepMs: cardStepMs,
      settleMs: settleMs,
    );

    final progresses = <double>[];
    final revealedCards = <FinalCallCard>[];
    for (var index = 0; index < cards.length; index++) {
      final cardStart = focusMs + index * cardStepMs;
      final progress = ((elapsedMs - cardStart) / cardFlipMs).clamp(0.0, 1.0);
      progresses.add(progress);
      if (progress >= 0.5) revealedCards.add(cards[index]);
    }
    final score = elapsedMs >= segmentEnd
        ? finalScore
        : calculateFinalCallScore(revealedCards);

    return Transform.scale(
      scale: scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < cards.length; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildRevealingCard(cards[index], progresses[index]),
                ),
            ],
          ),
          const SizedBox(height: 9),
          _AnimatedScoreCounter(score: score),
          const SizedBox(height: 12),
          _FinalCallLifeRow(
            player: player,
            loss: lifeLoss,
            lossProgress: heartProgress,
          ),
        ],
      ),
    );
  }

  Widget _buildRevealingCard(FinalCallCard card, double progress) {
    final showFront = progress >= 0.5;
    final rotationY = showFront ? (progress - 1) * math.pi : progress * math.pi;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateY(rotationY),
      child: FinalCallCardView(
        card: card,
        faceDown: !showFront,
        width: cardWidth,
      ),
    );
  }
}

double _revealedHandScale({
  required double elapsedMs,
  required int cardCount,
  required int focusMs,
  required int cardStepMs,
  required int settleMs,
}) {
  final revealEnd = focusMs + cardCount * cardStepMs;
  final segmentEnd = revealEnd + settleMs;
  if (elapsedMs > 0 && elapsedMs < focusMs) {
    return 1 + 0.22 * Curves.easeOutCubic.transform(elapsedMs / focusMs);
  }
  if (elapsedMs >= focusMs && elapsedMs < revealEnd) return 1.22;
  if (elapsedMs >= revealEnd && elapsedMs < segmentEnd) {
    return 1.22 -
        0.22 *
            Curves.easeInOutCubic.transform((elapsedMs - revealEnd) / settleMs);
  }
  return 1;
}

class _AnimatedScoreCounter extends StatelessWidget {
  const _AnimatedScoreCounter({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween<double>(begin: 1.5, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Text(
          '$score',
          key: ValueKey(score),
          style: TextStyle(
            color: score <= 10 ? Colors.red : const Color(0xFF244EB8),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Liar's Poker 잔여 카드와 같은 원형 궤도에 잔여 생명을 표시합니다.
class _FinalCallLivesLayer extends StatelessWidget {
  const _FinalCallLivesLayer({required this.players});

  final List<FinalCallPlayer> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.biggest;
        final centers = playerCentersForBoard(
          playerCount: players.length,
          boardSize: boardSize,
        );
        return Stack(
          children: [
            for (final player in players)
              _buildPlayerLives(
                player: player,
                center: centers[player.seatIndex],
                boardCenter: boardSize.center(Offset.zero),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPlayerLives({
    required FinalCallPlayer player,
    required Offset center,
    required Offset boardCenter,
  }) {
    final direction = center - boardCenter;
    final angle = direction.distanceSquared == 0
        ? 0.0
        : math.atan2(direction.dy, direction.dx) + math.pi / 2 + math.pi;

    return Positioned(
      left: center.dx - 62,
      top: center.dy - 30,
      width: 124,
      height: 60,
      child: Transform.rotate(
        angle: angle,
        child: _FinalCallLifeRow(player: player, loss: 0, lossProgress: 0),
      ),
    );
  }
}

/// 카드 공개 결과와 평상시 보드가 같은 생명 행을 사용합니다.
class _FinalCallLifeRow extends StatelessWidget {
  const _FinalCallLifeRow({
    required this.player,
    required this.loss,
    required this.lossProgress,
  });

  final FinalCallPlayer player;
  final int loss;
  final double lossProgress;

  @override
  Widget build(BuildContext context) {
    final previousLives = (player.lives + loss).clamp(0, 3);
    var rowScale = 1.0;
    if (loss > 0 && lossProgress < 0.45) {
      rowScale = 1 + 0.42 * Curves.easeOutBack.transform(lossProgress / 0.45);
    } else if (loss > 0) {
      rowScale =
          1.42 -
          0.42 *
              Curves.easeInOutCubic.transform(
                ((lossProgress - 0.45) / 0.55).clamp(0.0, 1.0),
              );
    }

    return SizedBox(
      width: 124,
      height: 48,
      child: Center(
        child: Transform.scale(
          scale: rowScale,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < previousLives; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: index < player.lives
                      ? Assets.games.finalCall.images.icons.iconHeart.image(
                          width: 31,
                          height: 31,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        )
                      : _BreakingHeart(progress: lossProgress),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 잃은 하트를 네 조각으로 갈라 바깥으로 흩어지게 합니다.
class _BreakingHeart extends StatelessWidget {
  const _BreakingHeart({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final breakProgress = Curves.easeInCubic.transform(
      ((progress - 0.22) / 0.78).clamp(0.0, 1.0),
    );
    final opacity = (1 - breakProgress).clamp(0.0, 1.0);
    const directions = <Offset>[
      Offset(-1.0, -0.75),
      Offset(1.0, -0.65),
      Offset(-0.8, 1.0),
      Offset(0.85, 1.1),
    ];
    const rotations = <double>[-0.48, 0.42, -0.7, 0.62];
    return SizedBox.square(
      dimension: 31,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var index = 0; index < directions.length; index++)
            Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset:
                    directions[index] * 15 * breakProgress +
                    Offset(0, 8 * breakProgress * breakProgress),
                child: Transform.rotate(
                  angle: rotations[index] * breakProgress,
                  child: ClipPath(
                    clipper: _HeartShardClipper(index),
                    child: Assets.games.finalCall.images.icons.iconHeart.image(
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeartShardClipper extends CustomClipper<Path> {
  const _HeartShardClipper(this.index);

  final int index;

  @override
  Path getClip(Size size) {
    final polygons = <List<Offset>>[
      [
        const Offset(0, 0),
        const Offset(.56, 0),
        const Offset(.47, .52),
        const Offset(0, .6),
      ],
      [
        const Offset(.56, 0),
        const Offset(1, 0),
        const Offset(1, .58),
        const Offset(.47, .52),
      ],
      [
        const Offset(0, .6),
        const Offset(.47, .52),
        const Offset(.54, 1),
        const Offset(0, 1),
      ],
      [
        const Offset(.47, .52),
        const Offset(1, .58),
        const Offset(1, 1),
        const Offset(.54, 1),
      ],
    ];
    final points = polygons[index];
    final path = Path()
      ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_HeartShardClipper oldClipper) => oldClipper.index != index;
}
