import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';
import 'package:project00/games/liars_poker/screens/tablet/game_status.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_animation.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_controller.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_helper.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_layer.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_overlay.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_penalty.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// Liar's Poker 태블릿 진행 화면의 진입점입니다.
///
/// 상태 처리는 [TabletGameController], 화면 구성은 각 layer 파일이 담당합니다.
class LiarsPokerTabletGame extends StatefulWidget {
  const LiarsPokerTabletGame({
    super.key,
    required this.playerLayout,
    required this.provider,
    required this.roomCode,
    required this.gameService,
  });

  final PlayerLayoutModel playerLayout;
  final RoomProvider provider;
  final String roomCode;
  final LiarsPokerService gameService;

  @override
  State<LiarsPokerTabletGame> createState() => TabletGameState();
}

class TabletGameState extends State<LiarsPokerTabletGame> {
  late final TabletGameController _controller;

  GameStatus get gameStatus => _controller.status;

  @override
  void initState() {
    super.initState();
    _controller = TabletGameController(
      playerLayout: widget.playerLayout,
      roomCode: widget.roomCode,
      gameService: widget.gameService,
      onError: _showGameError,
    )..initialize();
  }

  void _showGameError(String message, Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$message\n$error')));
  }

  // 기존 외부 호출 코드를 깨지 않도록 공개 메서드를 유지합니다.
  void startDealing() => _controller.startDealing();

  void startNextRound({
    required String table,
    required List<int> remainingCardCounts,
  }) {
    _controller.startNextRound(
      table: table,
      remainingCardCounts: remainingCardCounts,
    );
  }

  void showSubmittedCards({
    required String eventId,
    required String playerId,
    required int cardCount,
  }) {
    _controller.showSubmittedCards(
      eventId: eventId,
      playerId: playerId,
      cardCount: cardCount,
    );
  }

  void revealSubmittedCards(List<String> actualRanks) {
    _controller.revealSubmittedCards(actualRanks);
  }

  void showPenalty() => _controller.changeStatus(GameStatus.penalty);

  void showResult() => _controller.changeStatus(GameStatus.result);

  void finishGame() => _controller.changeStatus(GameStatus.finished);

  void _restartGame() {
    unawaited(_controller.restartGame());
  }

  void _endGame() {
    unawaited(_endGameAndReturnToLobby());
  }

  Future<void> _endGameAndReturnToLobby() async {
    final ended = await _controller.endGame();
    if (!mounted || !ended) return;
    _returnToLobby();
  }

  void _returnToLobby() {
    // 현재 게임 화면만 닫아 기존 태블릿 방 화면과 RoomProvider를 유지합니다.
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              const Positioned.fill(child: _GameBackground()),
              //기본 세팅
              Positioned.fill(
                child: TabletGameLayer(
                  status: _controller.status,
                  playerCount: _controller.playerCount,
                  playerSeatIndexes: _controller.seatIndexes,
                  cardsPerPlayer: cardsPerPlayer,
                  roundNumber: _controller.roundNumber,
                  cardPileVersion: _controller.cardPileVersion,
                  table: _controller.table,
                  winnerPlayer: _controller.winnerPlayer,
                  remainingCardCounts: _controller.remainingCardCounts,
                  currentTurnPlayerIndex: _controller.currentTurnPlayerIndex,
                  onDealCompleted: _controller.onDealCompleted,
                  onRoundRevealCompleted: _controller.onRoundRevealCompleted,
                  onRestartGame: _restartGame,
                  onExitToLobby: _returnToLobby,
                ),
              ),
              //제출된 카드 애니메이션
              if (_controller.shouldShowSubmittedPlay)
                Positioned.fill(
                  child: TabletGameAnimation(
                    key: ValueKey(
                      'card-pile-${_controller.roundNumber}-'
                      '${_controller.cardPileVersion}',
                    ),
                    roundPlays: _controller.roundPlays,
                    activePlayId: _controller.activeAnimationPlayId,
                    playerCount: _controller.playerCount,
                    playerSeatIndexes: _controller.seatIndexes,
                    onCardsPlayed: _controller.onCardsPlayed,
                    onCardsRevealed: _controller.onCardsRevealed,
                  ),
                ),

              //패널티 부분
              if (_controller.status == GameStatus.penalty)
                Positioned.fill(
                  child: TabletGamePenalty(
                    key: ValueKey(
                      '${_controller.penaltyTargetUid}_'
                      '${_controller.penaltyAttemptCount}_'
                      '${_controller.rouletteRetry}',
                    ),
                    attemptCount: _controller.penaltyAttemptCount,
                    isResolving: _controller.isResolvingPenalty,
                    onResult: _controller.resolveRoulette,
                  ),
                ),
              Positioned.fill(
                child: TabletGameOverlay(
                  provider: widget.provider,
                  status: _controller.status,
                  onDebugStatusChanged: _controller.selectDebugStatus,
                  onRestartGame: _restartGame,
                  onEndGame: _endGame,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _GameBackground extends StatelessWidget {
  const _GameBackground();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Assets.games.liarsPoker.images.background.background.image(
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
    );
  }
}
