import 'package:flutter/material.dart';
import 'package:project00/games/shared/animations/card_deal.dart';
import 'package:project00/games/shared/animations/fade_hold_fade.dart';
import 'package:project00/games/liars_poker/animations/round_start_reveal.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/liars_poker/screens/tablet/game_status.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_helper.dart';
import 'package:project00/games/liars_poker/widgets/tablet/result_tablet.dart';

/// 대기, 카드 배분, 라운드, 결과 등 상태별 기본 화면을 그립니다.
class TabletGameLayer extends StatelessWidget {
  const TabletGameLayer({
    super.key,
    required this.status,
    required this.playerCount,
    required this.playerSeatIndexes,
    required this.cardsPerPlayer,
    required this.roundNumber,
    required this.cardPileVersion,
    required this.table,
    required this.remainingCardCounts,
    required this.currentTurnPlayerIndex,
    required this.onDealCompleted,
    required this.onRoundRevealCompleted,
    required this.onRestartGame,
    required this.onExitToLobby,
    required this.winnerPlayer,
  });

  final GameStatus status;
  final int playerCount;
  final List<int> playerSeatIndexes;
  final int cardsPerPlayer;
  final int roundNumber;
  final int cardPileVersion;
  final String table;
  final List<int> remainingCardCounts;
  final int? currentTurnPlayerIndex;
  final VoidCallback onDealCompleted;
  final VoidCallback onRoundRevealCompleted;
  final VoidCallback onRestartGame;
  final VoidCallback onExitToLobby;
  final PlayerLayoutPlayer? winnerPlayer;
  @override
  Widget build(BuildContext context) {
    return switch (status) {
      GameStatus.waiting => const _StatusMessage('게임 시작 대기 중'),
      GameStatus.dealing => _RoundDealLayer(
        key: ValueKey('deal-$roundNumber-$cardPileVersion'),
        roundNumber: roundNumber,
        playerCount: playerCount,
        playerSeatIndexes: playerSeatIndexes,
        cardsPerPlayer: cardsPerPlayer,
        onCompleted: onDealCompleted,
      ),
      GameStatus.roundStarting ||
      GameStatus.playing ||
      GameStatus.cardsPlaying ||
      GameStatus.cardsRevealing => RoundStartReveal(
        key: ValueKey('round-$roundNumber'),
        tableAsset: tableAssetForRank(table),
        playerCount: playerCount,
        playerSeatIndexes: playerSeatIndexes,
        remainingCardCounts: remainingCardCounts,
        activePlayerIndex: currentTurnPlayerIndex,
        tableWidth: 300,
        onCompleted: onRoundRevealCompleted,
      ),
      //=======================벌칙 배경 정리==============================
      // 룰렛 진행 중에는 배경 위에 룰렛만 남기고 테이블과 잔여 카드는
      // 그리지 않습니다. 룰렛은 상위 TabletGamePenalty 레이어가 담당합니다.
      GameStatus.penalty => const SizedBox.shrink(),
      GameStatus.result => Result(
        winnerPlayer: winnerPlayer,
        onRestartGame: onRestartGame,
        onExitToLobby: onExitToLobby,
      ),
      GameStatus.finished => const _StatusMessage('게임이 종료되었습니다.'),
    };
  }
}

/// 두 번째 라운드부터 안내 문구를 보여주는 동안 다음 카드팩을 미리 렌더링합니다.
class _RoundDealLayer extends StatefulWidget {
  const _RoundDealLayer({
    super.key,
    required this.roundNumber,
    required this.playerCount,
    required this.playerSeatIndexes,
    required this.cardsPerPlayer,
    required this.onCompleted,
  });

  final int roundNumber;
  final int playerCount;
  final List<int> playerSeatIndexes;
  final int cardsPerPlayer;
  final VoidCallback onCompleted;

  @override
  State<_RoundDealLayer> createState() => _RoundDealLayerState();
}

class _RoundDealLayerState extends State<_RoundDealLayer> {
  bool get _showRoundIntro => widget.roundNumber > 1 && !_introCompleted;
  bool _introCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 룰렛이 퇴장하는 동안에도 중앙 카드팩은 이미 이 레이어에 있습니다.
        AbsorbPointer(
          absorbing: _showRoundIntro,
          child: CardDealAnimation(
            playerCount: widget.playerCount,
            playerSeatIndexes: widget.playerSeatIndexes,
            cardsPerPlayer: widget.cardsPerPlayer,
            duration: const Duration(milliseconds: 2800),
            onCompleted: widget.onCompleted,
          ),
        ),
        if (_showRoundIntro)
          Positioned.fill(
            child: IgnorePointer(
              child: FadeHoldFade(
                key: ValueKey('tablet-round-${widget.roundNumber}'),
                onCompleted: () {
                  if (!mounted) return;
                  setState(() => _introCompleted = true);
                },
                child: Center(
                  child: Text(
                    'ROUND ${widget.roundNumber}',
                    style: const TextStyle(
                      fontFamily: 'BebasNeue',
                      color: Colors.white,
                      fontSize: 58,
                      letterSpacing: 3.2,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 18)],
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
