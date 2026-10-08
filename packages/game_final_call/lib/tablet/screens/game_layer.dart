// 단계별 화면의 내부 렌더링입니다. 화면 선택/시간 설정은 tablet_board.dart를 수정합니다.
part of '../tablet_board.dart';

class _RevealedTable extends StatefulWidget {
  const _RevealedTable({
    super.key,
    required this.controller,
    required this.result,
    required this.onCompleted,
  });

  final FinalCallController controller;
  final FinalCallRoundResult result;
  final VoidCallback onCompleted;

  @override
  State<_RevealedTable> createState() => _RevealedTableState();
}

// 라운드 결과 연출의 구간 시간입니다. 부모(_RevealedTable)의 전체 타임라인
// 계산과 자식(_SequencedRevealedHand)의 카드별 진행도 계산이 같은 값을
// 쓰므로 파일 상단에 한 번만 둡니다.
final int _initialHoldMs =
    FinalCallTabletTiming.roundResultInitialHold.inMilliseconds;
final int _focusMs = FinalCallTabletTiming.roundResultFocus.inMilliseconds;
final int _cardStepMs =
    FinalCallTabletTiming.roundResultCardStep.inMilliseconds;
final int _cardFlipMs =
    FinalCallTabletTiming.roundResultCardFlip.inMilliseconds;
final int _settleMs = FinalCallTabletTiming.roundResultSettle.inMilliseconds;
final int _heartMs = FinalCallTabletTiming.roundResultHeartLoss.inMilliseconds;

class _RevealedTableState extends State<_RevealedTable> {
  /// [_BreakingHeart]가 하트를 실제로 가르기 시작하는 진행도입니다.
  /// 그쪽 임계값(0.22)을 바꾸면 여기도 같이 바꿔야 소리와 화면이 맞습니다.
  static const double _heartShatterProgress = 0.22;

  late final List<FinalCallPlayer> _players;
  late final List<int> _playerStarts;
  late final int _heartStart;
  late final int _totalDurationMs;
  late final bool _hasLifeLoss;
  final _heartbreakCue = ProgressSoundCue();

  @override
  void initState() {
    super.initState();
    _hasLifeLoss = widget.result.lifeLosses.values.any((loss) => loss > 0);
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
        return OneShotTimeline(
          duration: Duration(milliseconds: _totalDurationMs),
          onCompleted: widget.onCompleted,
          builder: (context, progress) {
            final elapsed = progress * _totalDurationMs;
            final heartProgress = ((elapsed - _heartStart) / _heartMs).clamp(
              0.0,
              1.0,
            );
            _playHeartbreakSound(context, elapsed);
            return Stack(
              fit: StackFit.expand,
              children: [
                for (var index = 0; index < _players.length; index++)
                  _buildPositionedHand(
                    player: _players[index],
                    desiredCenter: centers[_players[index].seatIndex],
                    boardSize: boardSize,
                    cardWidth: cardWidth,
                    elapsedMs: elapsed - _playerStarts[index],
                    // 뒷면 카드가 좌석 쪽에서 밀려 나오는 최초 배치 연출은
                    // 모든 자리가 같은 시점(전체 경과 시간)을 기준으로 합니다.
                    entryElapsedMs: elapsed,
                    heartProgress: heartProgress,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// 하트가 갈라지기 시작하는 순간에 맞춰 파열음을 한 번 재생합니다.
  ///
  /// 라운드 결과에서 실제로 하트를 잃은 플레이어가 있을 때만 냅니다.
  void _playHeartbreakSound(BuildContext context, double elapsedMs) {
    if (!_hasLifeLoss) return;
    _heartbreakCue.maybePlay(
      context,
      FinalCallSounds.heartbreak,
      value: elapsedMs,
      threshold:
          _heartStart +
          _heartMs * _heartShatterProgress -
          ProgressSoundCue.lead.inMilliseconds,
    );
  }

  Widget _buildPositionedHand({
    required FinalCallPlayer player,
    required Offset desiredCenter,
    required Size boardSize,
    required double cardWidth,
    required double elapsedMs,
    required double entryElapsedMs,
    required double heartProgress,
  }) {
    final cards = widget.result.revealedHands[player.uid] ?? const [];
    final handScale = _revealedHandScale(
      elapsedMs: elapsedMs,
      cardCount: cards.length,
    );
    final rotation = finalCallSeatRotationForCenter(
      center: desiredCenter,
      boardSize: boardSize,
    );
    // 카드 위의 점수 표시(약 58px + 여백)까지 포함해 화면 밖으로 나가지
    // 않도록 세로 크기를 잡습니다. 카드가 한 장뿐이면 점수 상자가 더 넓습니다.
    final rowWidth = math.max(86.0, cards.length * (cardWidth + 8));
    final contentHeight = cardWidth * finalCallCardHeightRatio + 66 + 80;
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
            entryElapsedMs: entryElapsedMs,
            scale: handScale,
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
    required this.entryElapsedMs,
    required this.scale,
    required this.player,
    required this.lifeLoss,
    required this.heartProgress,
  });

  final List<FinalCallCard> cards;
  final int finalScore;
  final double cardWidth;
  final double elapsedMs;

  /// 공개 시작부터의 전체 경과 시간입니다. 뒷면 카드가 좌석 쪽에서 밀려
  /// 나오는 최초 등장에만 씁니다.
  final double entryElapsedMs;

  /// 부모가 화면 밖 보정에 쓰려고 이미 계산한 [_revealedHandScale] 값입니다.
  final double scale;
  final FinalCallPlayer player;
  final int lifeLoss;
  final double heartProgress;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final revealEnd = _focusMs + cards.length * _cardStepMs;
    final segmentEnd = revealEnd + _settleMs;

    final progresses = <double>[];
    final revealedCards = <FinalCallCard>[];
    for (var index = 0; index < cards.length; index++) {
      final cardStart = _focusMs + index * _cardStepMs;
      final progress = ((elapsedMs - cardStart) / _cardFlipMs).clamp(0.0, 1.0);
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
          // 제출 카드를 한 장씩 공개하면서 점수를 다시 계산해 표시합니다.
          // 변화하는 합계는 제출 카드 위에 둡니다.
          _AnimatedScoreCounter(score: score),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var index = 0; index < cards.length; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildRevealingCard(
                    cards[index],
                    progresses[index],
                    index,
                  ),
                ),
            ],
          ),
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

  Widget _buildRevealingCard(FinalCallCard card, double progress, int index) {
    final showFront = progress >= 0.5;
    final rotationY = showFront ? (progress - 1) * math.pi : progress * math.pi;

    // 좌석에서 제출 카드가 밀려 나오는 최초 등장 연출입니다.
    // 이 손패는 좌석이 테이블을 바라보도록 회전된 좌표계 안에 있으므로,
    // 로컬 +Y는 항상 테이블 반대쪽(플레이어 자리 쪽)입니다. 뒷면 카드를 그
    // 방향에서 한 장씩 밀어 넣어 좌석에서 제출한 느낌을 줍니다.
    const entryDurationMs = 420.0;
    const entryStaggerMs = 90.0;
    final entryProgress = Curves.easeOutCubic.transform(
      ((entryElapsedMs - index * entryStaggerMs) / entryDurationMs).clamp(
        0.0,
        1.0,
      ),
    );
    final entryOffsetY = (1 - entryProgress) * cardWidth * 1.7;

    return Opacity(
      opacity: entryProgress,
      child: Transform.translate(
        offset: Offset(0, entryOffsetY),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(rotationY),
          child: FinalCallCardView(
            card: card,
            faceDown: !showFront,
            width: cardWidth,
          ),
        ),
      ),
    );
  }
}

double _revealedHandScale({required double elapsedMs, required int cardCount}) {
  final revealEnd = _focusMs + cardCount * _cardStepMs;
  final segmentEnd = revealEnd + _settleMs;
  if (elapsedMs > 0 && elapsedMs < _focusMs) {
    return 1 + 0.22 * Curves.easeOutCubic.transform(elapsedMs / _focusMs);
  }
  if (elapsedMs >= _focusMs && elapsedMs < revealEnd) return 1.22;
  if (elapsedMs >= revealEnd && elapsedMs < segmentEnd) {
    return 1.22 -
        0.22 *
            Curves.easeInOutCubic.transform(
              (elapsedMs - revealEnd) / _settleMs,
            );
  }
  return 1;
}

class _AnimatedScoreCounter extends StatelessWidget {
  const _AnimatedScoreCounter({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    // 멀리서도 읽히도록 숫자와 상자를 크게 잡습니다.
    return FinalCallPopBox(
      radius: 18,
      borderWidth: 4,
      shadowDepth: 5,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 46, minHeight: 46),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: Tween<double>(begin: 1.5, end: 1).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              '$score',
              key: ValueKey(score),
              style: finalCallPopText(
                40,
                color: score <= 10
                    ? FinalCallColors.red
                    : FinalCallColors.violet,
                height: 1,
                shadows: finalCallPopOutline(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 테이블 가운데 위의 '○○ 차례예요' 알약입니다(팀 색).
class _FinalCallTurnPill extends StatelessWidget {
  const _FinalCallTurnPill({required this.player, required this.deadline});

  final FinalCallPlayer player;
  final int? deadline;

  @override
  Widget build(BuildContext context) {
    final deadline = this.deadline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: finalCallTeamColor(player.team),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FinalCallColors.ink, width: 4),
        boxShadow: const [
          BoxShadow(color: FinalCallColors.ink, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              FinalCallCopy.turnOf(player.nickname),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: finalCallPopText(
                20,
                color: Colors.white,
                shadows: finalCallPopOutline(),
              ),
            ),
          ),
          if (deadline != null) ...[
            const SizedBox(width: 8),
            // 태블릿은 소리 없이 남은 시간만 보여 줍니다.
            GameTurnCountdown(
              key: ValueKey(deadline),
              expiresAt: deadline,
              builder: (context, remaining) {
                final seconds =
                    ((remaining ?? Duration.zero).inMilliseconds / 1000)
                        .ceil()
                        .clamp(0, 99);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: FinalCallColors.ink,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '0:${seconds.toString().padLeft(2, '0')}',
                    style: finalCallPopText(
                      18,
                      color: FinalCallColors.yellow,
                      height: 1.3,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// 테이블 둘레의 좌석 이름표입니다. 각 이름표는 앉은 사람 쪽을 향합니다.
///
/// 얼굴·이름·하트를 보여 주고, 차례인 사람은 팀 색 테두리, CALL한 사람은
/// 노란 이름표로 강조합니다.
class _FinalCallSeatPlates extends StatelessWidget {
  const _FinalCallSeatPlates({
    required this.players,
    required this.turnUid,
    required this.callerUid,
    required this.pendingDrawUid,
  });

  final List<FinalCallPlayer> players;
  final String? turnUid;
  final String? callerUid;
  final String? pendingDrawUid;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.biggest;
        final scale = finalCallTabletScale(boardSize);
        final centers = playerCentersForBoard(
          playerCount: players.length,
          boardSize: boardSize,
        );
        final sixSeats = players.length > 4;
        final plateSize = sixSeats ? const Size(240, 80) : const Size(320, 88);
        return Stack(
          children: [
            for (final player in players)
              Positioned(
                left: centers[player.seatIndex].dx - plateSize.width / 2,
                top: centers[player.seatIndex].dy - plateSize.height / 2,
                width: plateSize.width,
                height: plateSize.height,
                child: Transform.rotate(
                  angle: finalCallSeatRotationForCenter(
                    center: centers[player.seatIndex],
                    boardSize: boardSize,
                  ),
                  child: Transform.scale(
                    scale: scale,
                    child: _SeatPlate(
                      player: player,
                      partner: sixSeats
                          ? null
                          : players
                                .where(
                                  (other) =>
                                      other.team == player.team &&
                                      other.uid != player.uid,
                                )
                                .firstOrNull,
                      isTurn: player.uid == turnUid,
                      isCaller: player.uid == callerUid,
                      isSwapping:
                          player.uid == turnUid && player.uid == pendingDrawUid,
                      compact: sixSeats,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SeatPlate extends StatelessWidget {
  const _SeatPlate({
    required this.player,
    required this.partner,
    required this.isTurn,
    required this.isCaller,
    required this.isSwapping,
    required this.compact,
  });

  final FinalCallPlayer player;
  final FinalCallPlayer? partner;
  final bool isTurn;
  final bool isCaller;
  final bool isSwapping;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final teamColor = finalCallTeamColor(player.team);
    final eliminated = player.status == 'eliminated';
    final tag = isCaller
        ? const FinalCallPopTag(
            label: 'CALL',
            color: FinalCallColors.ink,
            textColor: FinalCallColors.yellow,
            fontSize: 14,
            borderWidth: 0,
          )
        : isTurn
        ? FinalCallPopTag(
            label: isSwapping
                ? FinalCallCopy.swapping
                : FinalCallCopy.turnBadge,
            color: teamColor,
            textColor: Colors.white,
            fontSize: 13,
            borderWidth: 0,
          )
        : null;
    final partner = this.partner;
    return Opacity(
      opacity: eliminated ? 0.6 : 1,
      child: FinalCallPopBox(
        color: isCaller ? FinalCallColors.yellow : Colors.white,
        radius: compact ? 20 : 22,
        borderWidth: isTurn && !isCaller ? 5 : 4,
        shadowDepth: isTurn && !isCaller ? 9 : 5,
        ringColor: isTurn && !isCaller ? teamColor : null,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            FinalCallPopAvatar(
              characterId: player.characterId,
              color: teamColor,
              size: compact ? 46 : 56,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          player.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: finalCallPopText(compact ? 20 : 22),
                        ),
                      ),
                      if (tag != null) ...[const SizedBox(width: 6), tag],
                    ],
                  ),
                  if (partner != null)
                    Text(
                      FinalCallCopy.teamWithPartner(
                        player.team.label,
                        partner.nickname,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: finalCallPopText(13, color: FinalCallColors.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _FinalCallLifeRow(
              player: player,
              loss: 0,
              lossProgress: 0,
              onPlate: true,
            ),
          ],
        ),
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
    this.onPlate = false,
  });

  final FinalCallPlayer player;
  final int loss;
  final double lossProgress;

  /// 좌석 이름표 안의 작은 하트 줄입니다. 잃은 하트 자리를 점선으로 남깁니다.
  final bool onPlate;

  @override
  Widget build(BuildContext context) {
    final rowWidth = onPlate ? 72.0 : 124.0;
    final rowHeight = onPlate ? 24.0 : 48.0;
    final heartSize = onPlate ? 20.0 : 22.0;
    if (player.status == 'eliminated' && (loss == 0 || lossProgress >= 1)) {
      return SizedBox(
        width: rowWidth,
        height: rowHeight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${player.team.label} 탈락',
            key: ValueKey('final-call-eliminated-${player.uid}'),
            style: finalCallPopText(16, color: FinalCallColors.muted),
          ),
        ),
      );
    }
    final previousLives = (player.lives + loss).clamp(0, 3);
    final teamColor = finalCallTeamColor(player.team);
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
      width: rowWidth,
      height: rowHeight,
      child: Center(
        child: Transform.scale(
          scale: rowScale,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < previousLives; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: index < player.lives
                      ? FinalCallPopHeart(
                          key: ValueKey(
                            'final-call-${player.team.name}-heart-$index',
                          ),
                          color: teamColor,
                          size: heartSize,
                        )
                      : _BreakingHeart(
                          progress: lossProgress,
                          team: player.team,
                        ),
                ),
              if (onPlate)
                for (var index = previousLives; index < 3; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: FinalCallPopHeart(
                      color: teamColor,
                      filled: false,
                      size: heartSize,
                    ),
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
  const _BreakingHeart({required this.progress, required this.team});

  final double progress;
  final FinalCallTeam team;

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
    return SizedBox(
      width: 22,
      height: 20,
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
                    child: FinalCallPopHeart(
                      color: finalCallTeamColor(team),
                      size: 22,
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

/// 태블릿 공통 배경입니다. 점무늬 바탕 가운데에 둥근 테이블을 놓습니다.
class FinalCallTableBackdrop extends StatelessWidget {
  const FinalCallTableBackdrop({super.key});

  @override
  Widget build(BuildContext context) => FinalCallPopBackground(
    spacing: 28,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.biggest;
        final radius = finalCallTableRadius(boardSize);
        final scale = finalCallTabletScale(boardSize);
        return Stack(
          children: [
            Positioned(
              left: boardSize.width / 2 - radius,
              top: boardSize.height / 2 - radius,
              width: radius * 2,
              height: radius * 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: FinalCallColors.lilac,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FinalCallColors.ink,
                    width: 6 * scale,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: FinalCallColors.ink,
                      offset: Offset(0, 12 * scale),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
