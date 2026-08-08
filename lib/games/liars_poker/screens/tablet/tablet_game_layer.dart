import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/animations/card_deal.dart';
import 'package:project00/games/liars_poker/animations/round_start_reveal.dart';
import 'package:project00/games/liars_poker/screens/tablet/game_status.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_helper.dart';
import 'package:project00/games/liars_poker/widgets/result_tablet.dart';

/// 대기, 카드 배분, 라운드, 결과 등 상태별 기본 화면을 그립니다.
class TabletGameLayer extends StatelessWidget {
  const TabletGameLayer({
    super.key,
    required this.status,
    required this.playerCount,
    required this.playerSeatIndexes,
    required this.cardsPerPlayer,
    required this.roundNumber,
    required this.table,
    required this.remainingCardCounts,
    required this.onDealCompleted,
    required this.onRoundRevealCompleted,
  });

  final GameStatus status;
  final int playerCount;
  final List<int> playerSeatIndexes;
  final int cardsPerPlayer;
  final int roundNumber;
  final String table;
  final List<int> remainingCardCounts;
  final VoidCallback onDealCompleted;
  final VoidCallback onRoundRevealCompleted;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      GameStatus.waiting => const _StatusMessage('게임 시작 대기 중'),
      GameStatus.dealing => CardDealAnimation(
        key: ValueKey('deal-$roundNumber'),
        playerCount: playerCount,
        playerSeatIndexes: playerSeatIndexes,
        cardsPerPlayer: cardsPerPlayer,
        duration: const Duration(milliseconds: 2800),
        onCompleted: onDealCompleted,
      ),
      GameStatus.roundStarting ||
      GameStatus.playing ||
      GameStatus.cardsPlaying ||
      GameStatus.cardsRevealing ||
      GameStatus.penalty => RoundStartReveal(
        key: ValueKey('round-$roundNumber'),
        tableAsset: tableAssetForRank(table),
        playerCount: playerCount,
        playerSeatIndexes: playerSeatIndexes,
        remainingCardCounts: remainingCardCounts,
        tableWidth: 300,
        onCompleted: onRoundRevealCompleted,
      ),
      GameStatus.result => const Center(child: Result()),
      GameStatus.finished => const _StatusMessage('게임이 종료되었습니다.'),
    };
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
