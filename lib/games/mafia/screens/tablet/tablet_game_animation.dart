import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/animations/card_play_animation.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_helper.dart';

/// 현재 라운드에 제출된 모든 카드 묶음을 중앙 더미에 쌓습니다.
///
/// 새 제출만 플레이어 자리에서 중앙으로 이동하고, 라이어 선언으로
/// `isRevealed`가 바뀐 마지막 묶음만 앞면 공개 애니메이션을 실행합니다.
class TabletGameAnimation extends StatelessWidget {
  const TabletGameAnimation({
    super.key,
    required this.roundPlays,
    required this.activePlayId,
    required this.playerCount,
    required this.playerSeatIndexes,
    required this.onCardsPlayed,
    required this.onCardsRevealed,
  });

  final List<SubmittedPlay> roundPlays;
  final String? activePlayId;
  final int playerCount;
  final List<int> playerSeatIndexes;
  final VoidCallback onCardsPlayed;
  final VoidCallback onCardsRevealed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            for (var index = 0; index < roundPlays.length; index++)
              _buildCardGroup(
                play: roundPlays[index],
                pileIndex: index,
                boardSize: size,
              ),
          ],
        );
      },
    );
  }

  Widget _buildCardGroup({
    required SubmittedPlay play,
    required int pileIndex,
    required Size boardSize,
  }) {
    final isActivePlay = play.eventId == activePlayId;

    return CardPlayAnimation(
      key: ValueKey(play.eventId),
      playerCount: playerCount,
      playerSeatIndexes: playerSeatIndexes,
      fromPlayerIndex: play.playerIndex,
      frontCardAssets: play.frontCardAssets,
      tableAlignment: _pileAlignment(pileIndex, boardSize),
      initiallyPlayed: !play.animateEntry,
      revealCards: play.isRevealed,
      revealOnTap: false,
      onCardsPlayed: isActivePlay ? onCardsPlayed : null,
      onRevealed: isActivePlay && play.isRevealed ? onCardsRevealed : null,
    );
  }

  /// 카드 묶음이 완전히 겹치지 않도록 작은 나선 형태로 쌓습니다.
  Alignment _pileAlignment(int index, Size boardSize) {
    if (index == 0 || boardSize.isEmpty) return Alignment.center;

    const goldenAngle = 2.399963229728653;
    final radius = math.min(10 + math.sqrt(index) * 9, 48).toDouble();
    final angle = index * goldenAngle;
    final offset = Offset(
      math.cos(angle) * radius,
      math.sin(angle) * radius * 0.55,
    );

    return Alignment(
      offset.dx * 2 / boardSize.width,
      offset.dy * 2 / boardSize.height,
    );
  }
}
