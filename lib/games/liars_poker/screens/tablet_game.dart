import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/games/liars_poker/loading/liars_poker_loading.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_tablet_session_provider.dart';
import 'package:project00/games/liars_poker/screens/tablet/game_status.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_animation.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_controller.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_helper.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_layer.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_overlay.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_penalty.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/shared/animations/mat_unroll_animation.dart';
import 'package:project00/games/shared/widgets/game_loading_screen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// Liar's Poker 태블릿 진행 화면의 진입점입니다.
///
/// 상태 처리는 [TabletGameController], 화면 구성은 각 layer 파일이 담당합니다.
class LiarsPokerTabletGame extends ConsumerStatefulWidget {
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
  ConsumerState<LiarsPokerTabletGame> createState() => TabletGameState();
}

class TabletGameState extends ConsumerState<LiarsPokerTabletGame>
    with SingleTickerProviderStateMixin {
  late final TabletGameController _controller;
  late final LiarsPokerTabletSessionArgs _sessionArgs;
  late final AnimationController _exitMatController;
  bool _hasScheduledInsufficientPlayersExit = false;
  bool _isExitingToLobby = false;

  GameStatus get gameStatus => _controller.status;

  @override
  void initState() {
    super.initState();
    //=======================라이어스 포커 세로·가로 허용==============================
    unawaited(AppOrientation.allowLiarsPokerRotation());
    _exitMatController = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 900),
      reverseDuration: const Duration(milliseconds: 820),
    );
    _sessionArgs = LiarsPokerTabletSessionArgs(
      playerLayout: widget.playerLayout,
      roomCode: widget.roomCode,
      service: widget.gameService,
      onError: _showGameError,
    );
    final provider = liarsPokerTabletSessionProvider(_sessionArgs);
    _controller = ref.read(provider.notifier);
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
    if (_isExitingToLobby) return;
    _isExitingToLobby = true;

    final ended = await _controller.endGame();
    if (!mounted) return;
    if (!ended) {
      _isExitingToLobby = false;
      return;
    }

    //=======================게임 화면 매트 퇴장==============================
    // 서버의 게임 종료 처리가 완료된 뒤 현재 게임 화면 전체를 위쪽으로 말아
    // 없애고, 애니메이션이 끝난 시점에 기존 태블릿 방 화면으로 복귀합니다.
    await _exitMatController.reverse();
    if (!mounted) return;
    _returnToLobby();
  }

  void _returnToLobby() {
    // 현재 게임 화면만 닫아 기존 태블릿 방 화면과 RoomProvider를 유지합니다.
    Navigator.of(context).maybePop();
  }

  void _scheduleInsufficientPlayersExit() {
    if (_hasScheduledInsufficientPlayersExit) return;
    _hasScheduledInsufficientPlayersExit = true;

    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _returnToLobby();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(liarsPokerTabletSessionProvider(_sessionArgs));
    //=======================게임 진입 로딩 화면==============================
    // 태블릿 공개 상태와 플레이어 프로필·게임 이미지를 먼저 준비합니다.
    return AnimatedBuilder(
      animation: _exitMatController,
      child: GameLoadingScreen(
        background: Assets
            .games
            .liarsPoker
            .images
            .background
            .backgroundLoadingTablet
            .provider(),
        tips: liarsPokerLoadingTips,
        prepare: (loadingContext) async {
          await _controller.waitForInitialData();
          if (!loadingContext.mounted) return;
          await preloadLiarsPokerAssets(
            loadingContext,
            isPhone: false,
            profileImageUrls: _controller.profileImageUrls,
          );
        },
        gameBuilder: (_) => _buildGameContent(),
      ),
      builder: (context, child) {
        return AbsorbPointer(
          absorbing: _isExitingToLobby,
          child: MatUnrollAnimation(
            progress: _exitMatController.value,
            child: child!,
          ),
        );
      },
    );
  }

  Widget _buildGameContent() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Builder(
        builder: (context) {
          if (_controller.isInsufficientPlayersEnding) {
            _scheduleInsufficientPlayersExit();
          }
          return Stack(
            children: [
              const Positioned.fill(child: _GameBackground()),
              //=======================기본 게임 레이어==============================
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
                  onExitToLobby: _endGame,
                ),
              ),
              //=======================제출 카드 애니메이션==============================
              if (_controller.shouldShowSubmittedPlay)
                Positioned.fill(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      _controller.isInsufficientPlayersEnding
                          ? const Color(0xA6000000)
                          : const Color(0x00000000),
                      BlendMode.srcATop,
                    ),
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
                ),

              if (_controller.isInsufficientPlayersEnding)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          '인원 부족으로 게임을 종료합니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              //=======================벌칙 룰렛 퇴장==============================
              // 이 슬롯은 항상 유지합니다. 상태가 dealing으로 바뀌면 아래 기본
              // 레이어에 다음 카드팩이 먼저 생성되고, 이전 룰렛만 축소·페이드됩니다.
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 720),
                  reverseDuration: const Duration(milliseconds: 720),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    fit: StackFit.expand,
                    children: [...previousChildren, ?currentChild],
                  ),
                  transitionBuilder: (child, animation) {
                    final scale = Tween<double>(begin: 0.72, end: 1).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: scale, child: child),
                    );
                  },
                  child:
                      _controller.status == GameStatus.penalty &&
                          !_controller.isInsufficientPlayersEnding
                      ? TabletGamePenalty(
                          key: ValueKey(
                            '${_controller.penaltyTargetUid}_'
                            '${_controller.penaltyAttemptCount}_'
                            '${_controller.rouletteRetry}',
                          ),
                          attemptCount: _controller.penaltyAttemptCount,
                          profileImageUrl:
                              _controller.penaltyPlayer?.profileImageUrl ?? '',
                          isResolving: _controller.isResolvingPenalty,
                          onResult: _controller.resolveRoulette,
                        )
                      : null,
                ),
              ),
              Positioned.fill(
                child: TabletGameOverlay(
                  provider: widget.provider,
                  status: _controller.status,
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
    _exitMatController.dispose();
    //=======================플랫폼 세로 화면 복원==============================
    unawaited(AppOrientation.lockPlatformPortrait());
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
