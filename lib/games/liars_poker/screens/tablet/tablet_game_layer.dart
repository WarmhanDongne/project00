import 'package:flutter/material.dart';
import 'package:project00/games/shared/animations/card_deal.dart';
import 'package:project00/games/liars_poker/animations/tablet_round_start_reveal.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/shared/widgets/game_announcement_layer.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_helper.dart';
import 'package:project00/games/liars_poker/widgets/tablet/result.dart';

/// 대기, 카드 배분, 라운드, 결과 등 상태별 기본 화면을 그립니다.
class LiarsPokerTabletGameLayer extends StatelessWidget {
  const LiarsPokerTabletGameLayer({
    super.key,
    required this.stage,
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

  final LiarsPokerTabletStage stage;
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
    return switch (stage) {
      // 첫 RTDB 상태가 늦어져도 검은 화면으로 오해하지 않도록 배경 위에 준비
      // 상태를 명확히 표시합니다. 공개 상태가 도착하면 dealing으로 교체됩니다.
      LiarsPokerTabletStage.waiting => GameAnnouncementLayer(
        announcement: GameAnnouncement.persistent(
          id: 'liars-poker-preparing',
          text: GameFlowCopy.preparingGame,
        ),
        style: const GameAnnouncementStyle.tablet(),
      ),
      LiarsPokerTabletStage.dealing => _RoundDealLayer(
        key: ValueKey('deal-$roundNumber-$cardPileVersion'),
        roundNumber: roundNumber,
        playerCount: playerCount,
        playerSeatIndexes: playerSeatIndexes,
        cardsPerPlayer: cardsPerPlayer,
        onCompleted: onDealCompleted,
      ),
      LiarsPokerTabletStage.roundStarting ||
      LiarsPokerTabletStage.playing ||
      LiarsPokerTabletStage.cardsPlaying ||
      LiarsPokerTabletStage.cardsRevealing => RoundStartReveal(
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
      // 그리지 않습니다. 룰렛은 상위 LiarsPokerTabletGamePenalty 레이어가 담당합니다.
      LiarsPokerTabletStage.penalty => const SizedBox.shrink(),
      LiarsPokerTabletStage.result => Result(
        winnerPlayer: winnerPlayer,
        onRestartGame: onRestartGame,
        onExitToLobby: onExitToLobby,
      ),
      LiarsPokerTabletStage.finished => GameAnnouncementLayer(
        announcement: GameAnnouncement.persistent(
          id: 'game-finished',
          text: GameFlowCopy.gameFinished,
        ),
        style: const GameAnnouncementStyle.tablet(),
      ),
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
            // 첫 라운드만 중앙 덱을 직접 눌러 시작합니다. 2라운드부터는
            // ROUND 안내가 끝나는 순간 자동 재생해 게임 흐름을 끊지 않습니다.
            autoplay: widget.roundNumber > 1 && _introCompleted,
            tapToStart: widget.roundNumber == 1,
            onCompleted: widget.onCompleted,
          ),
        ),
        Positioned.fill(
          child: GameAnnouncementLayer(
            announcement: _showRoundIntro
                ? GameAnnouncement.round(
                    widget.roundNumber,
                    id: 'tablet-round-${widget.roundNumber}',
                  )
                : null,
            style: const GameAnnouncementStyle.tablet(),
            onCompleted: (_) {
              if (!mounted) return;
              setState(() => _introCompleted = true);
            },
          ),
        ),
      ],
    );
  }
}
