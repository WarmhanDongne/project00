import 'package:flutter/material.dart';
import 'package:project00/games/shared/animations/card_deal.dart';
import 'package:project00/games/liars_poker/animations/tablet_round_start_reveal.dart';
import 'package:project00/games/shared/game_flow/game_flow_config.dart';
import 'package:project00/games/shared/game_flow/game_flow_auto_complete.dart';
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
    required this.flowConfig,
    required this.playerCount,
    required this.playerSeatIndexes,
    required this.dealPlayerSeatIndexes,
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
  final GameFlowConfig<LiarsPokerTabletStage> flowConfig;
  final int playerCount;
  final List<int> playerSeatIndexes;
  final List<int> dealPlayerSeatIndexes;
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
      LiarsPokerTabletStage.waiting => GameAnnouncementLayer(
        announcement: flowConfig.stepFor(stage).buildAnnouncement(),
        style: const GameAnnouncementStyle.tablet(),
      ),
      // key에 좌석 목록을 넣지 않습니다. 분배 도중 플레이어 상태가 바뀌어
      // 좌석 집합이 변하면 애니메이션이 처음부터 재생성되고, 1라운드는 시작
      // 탭을 다시 기다리게 되어 분배가 영원히 끝나지 않을 수 있습니다.
      LiarsPokerTabletStage.dealing => _RoundDealLayer(
        key: ValueKey('deal-$roundNumber-$cardPileVersion'),
        roundNumber: roundNumber,
        boardSeatCount: playerCount,
        playerSeatIndexes: dealPlayerSeatIndexes,
        cardsPerPlayer: cardsPerPlayer,
        flowStep: flowConfig.stepFor(stage),
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
        // playing/cardsPlaying/cardsRevealing에서도 같은 보드를 유지하지만,
        // 등장 시간은 항상 roundStarting 단계 설정을 사용합니다. 현재 stage의
        // 카드 이동 시간으로 덮으면 재접속 시 보드 속도가 달라질 수 있습니다.
        duration:
            flowConfig
                .stepFor(LiarsPokerTabletStage.roundStarting)
                .animation
                .enabled
            ? flowConfig
                  .stepFor(LiarsPokerTabletStage.roundStarting)
                  .animation
                  .duration
            : Duration.zero,
        onCompleted: onRoundRevealCompleted,
      ),
      // 벌칙 중에는 테이블을 숨기고 상위 룰렛 레이어만 남깁니다.
      // 룰렛 진행 중에는 배경 위에 룰렛만 남기고 테이블과 잔여 카드는
      // 그리지 않습니다. 룰렛은 상위 LiarsPokerTabletGamePenalty 레이어가 담당합니다.
      LiarsPokerTabletStage.penalty => const SizedBox.shrink(),
      LiarsPokerTabletStage.result => Result(
        winnerPlayer: winnerPlayer,
        onRestartGame: onRestartGame,
        onExitToLobby: onExitToLobby,
      ),
      LiarsPokerTabletStage.finished => GameAnnouncementLayer(
        announcement: flowConfig.stepFor(stage).buildAnnouncement(),
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
    required this.boardSeatCount,
    required this.playerSeatIndexes,
    required this.cardsPerPlayer,
    required this.flowStep,
    required this.onCompleted,
  });

  final int roundNumber;
  final int boardSeatCount;
  final List<int> playerSeatIndexes;
  final int cardsPerPlayer;
  final GameFlowStep<LiarsPokerTabletStage> flowStep;
  final VoidCallback onCompleted;

  @override
  State<_RoundDealLayer> createState() => _RoundDealLayerState();
}

class _RoundDealLayerState extends State<_RoundDealLayer> {
  bool get _showRoundIntro => widget.roundNumber > 1 && !_introCompleted;
  bool _introCompleted = false;

  @override
  Widget build(BuildContext context) {
    if (widget.playerSeatIndexes.isEmpty) {
      // 공개 players와 좌석 배치가 아직 매칭되지 않으면 분배 애니메이션을
      // 만들 수 없습니다. 그렇다고 완료 신호 없이 대기만 하면 서버 phase가
      // dealing에 영구 고착되어 모든 기기가 멈추므로, 잠시 기다렸다가
      // 좌석 정보가 오지 않으면 완료 신호를 보내 게임을 진행시킵니다.
      // 그 사이 좌석 정보가 도착하면 아래 일반 분기로 전환됩니다.
      return GameFlowAutoComplete(
        key: ValueKey('deal-empty-${widget.roundNumber}'),
        delay: const Duration(seconds: 3),
        onCompleted: widget.onCompleted,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // 룰렛이 퇴장하는 동안에도 중앙 카드팩은 이미 이 레이어에 있습니다.
        AbsorbPointer(
          absorbing: _showRoundIntro,
          child: !widget.flowStep.animation.enabled && !_showRoundIntro
              ? GameFlowAutoComplete(
                  key: ValueKey('deal-skipped-${widget.roundNumber}'),
                  delay:
                      widget.flowStep.beforeDelay + widget.flowStep.afterDelay,
                  onCompleted: widget.onCompleted,
                )
              : CardDealAnimation(
                  playerCount: widget.playerSeatIndexes.length,
                  boardSeatCount: widget.boardSeatCount,
                  playerSeatIndexes: widget.playerSeatIndexes,
                  cardsPerPlayer: widget.cardsPerPlayer,
                  duration: widget.flowStep.animation.duration,
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
                ? widget.flowStep.buildAnnouncement()
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
