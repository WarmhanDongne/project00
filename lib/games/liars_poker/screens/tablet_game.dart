import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/games/liars_poker/liars_poker_flow_config.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/games/liars_poker/loading/liars_poker_loading.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_tablet_session_provider.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_animation.dart';
import 'package:project00/games/liars_poker/controllers/liars_poker_tablet_controller.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_helper.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_layer.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_overlay.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_penalty.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/shared/animations/mat_unroll_animation.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';
import 'package:project00/games/shared/game_flow/game_flow_auto_complete.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/widgets/game_announcement_layer.dart';
import 'package:project00/games/shared/widgets/game_interruption_layer.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// Liar's Poker 태블릿 진행 화면의 진입점입니다.
///
/// 상태 처리는 [LiarsPokerTabletController], 화면 구성은 각 layer 파일이 담당합니다.
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
  ConsumerState<LiarsPokerTabletGame> createState() =>
      _LiarsPokerTabletGameState();
}

class _LiarsPokerTabletGameState extends ConsumerState<LiarsPokerTabletGame>
    with SingleTickerProviderStateMixin {
  late final LiarsPokerTabletController _controller;
  late final LiarsPokerTabletSessionArgs _sessionArgs;
  late final AnimationController _exitMatController;
  bool _hasScheduledInsufficientPlayersExit = false;
  bool _isExitingToLobby = false;

  LiarsPokerTabletStage get stage => _controller.stage;

  @override
  void initState() {
    super.initState();
    // ========================================================================
    // 게임 진입 환경
    // ========================================================================
    // 모든 태블릿 게임은 가로·전체화면입니다. 이 정책을 게임별 설정으로
    // 바꾸면 좌석 좌표와 카드 애니메이션 방향이 어긋날 수 있습니다.
    unawaited(AppSystemUi.enterGameFullscreen());
    // 게임 종류와 관계없이 모든 태블릿 게임은 항상 가로 고정입니다.
    // Liar's Poker 휴대폰의 세로·가로 허용 정책을 이 화면에 적용하지 마세요.
    unawaited(AppOrientation.lockTabletGameLandscape());
    _exitMatController = AnimationController(
      vsync: this,
      value: 1,
      duration: LiarsPokerFlowTiming.gameEntry,
      reverseDuration: LiarsPokerFlowTiming.gameExit,
    );
    _sessionArgs = LiarsPokerTabletSessionArgs(
      playerLayout: widget.playerLayout,
      roomCode: widget.roomCode,
      service: widget.gameService,
      onError: _showGameError,
    );
    final provider = liarsPokerTabletSessionProvider(_sessionArgs);
    _controller = ref.read(provider.notifier);
    unawaited(_warmUpAssets());
  }

  /// 자리 배치 연출에서 이어지는 배경 위에서 조용히 이미지를 준비합니다.
  /// 별도 로딩 화면을 보여주지 않으므로 실패해도 게임 진행을 막지 않습니다.
  Future<void> _warmUpAssets() async {
    await _controller.waitForInitialData();
    if (!mounted) return;
    await preloadLiarsPokerAssets(
      context,
      isPhone: false,
      profileImageUrls: _controller.profileImageUrls,
    );
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

  void showPenalty() => _controller.changeStage(LiarsPokerTabletStage.penalty);

  void showResult() => _controller.changeStage(LiarsPokerTabletStage.result);

  void finishGame() => _controller.changeStage(LiarsPokerTabletStage.finished);

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

    // ---------------------------------------------------------------------------
    // 게임 화면 매트 퇴장
    // ---------------------------------------------------------------------------
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

    Future<void>.delayed(LiarsPokerFlowTiming.closingRouteDelay, () {
      if (!mounted) return;
      _returnToLobby();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(liarsPokerTabletSessionProvider(_sessionArgs));
    // ============================================================================
    // 게임 화면 진입
    // ============================================================================
    // 자리 배치 연출의 테이블과 같은 배경 이미지를 곧바로 보여주고, 서버
    // 데이터는 그 위에서 조용히 채워집니다. 별도 로딩 화면 없이 자연스럽게
    // 이어지도록 합니다.
    return AnimatedBuilder(
      animation: _exitMatController,
      child: _buildGameContent(),
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
    final flowConfig = buildLiarsPokerTabletFlowConfig(
      roundNumber: _controller.roundNumber,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Builder(
        builder: (context) {
          if (_controller.isInsufficientPlayersEnding) {
            _scheduleInsufficientPlayersExit();
          }
          // 다른 게임 화면과 동일하게 expand로 둡니다. 느슨한 Stack은 크기가
          // 0인 non-positioned 자식 하나만 있어도 통째로 0×0이 됩니다.
          return Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: _GameBackground()),
              // ---------------------------------------------------------------------------
              // 단계별 기본 게임 레이어
              // ---------------------------------------------------------------------------
              Positioned.fill(
                child: LiarsPokerTabletGameLayer(
                  stage: _controller.stage,
                  flowConfig: flowConfig,
                  playerCount: _controller.playerCount,
                  playerSeatIndexes: _controller.seatIndexes,
                  dealPlayerSeatIndexes: _controller.activeSeatIndexes,
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
              // 제출/공개 이벤트는 서버 미러 상태와 분리된 태블릿 연출입니다.
              if (_controller.shouldShowSubmittedPlay)
                Positioned.fill(
                  child:
                      _controller.stage != LiarsPokerTabletStage.playing &&
                          !flowConfig
                              .stepFor(_controller.stage)
                              .animation
                              .enabled
                      ? GameFlowAutoComplete(
                          key: ValueKey(
                            'card-event-skipped-'
                            '${_controller.activeAnimationPlayId}',
                          ),
                          onCompleted:
                              _controller.stage ==
                                  LiarsPokerTabletStage.cardsRevealing
                              ? _controller.onCardsRevealed
                              : _controller.onCardsPlayed,
                        )
                      : ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            _controller.isInsufficientPlayersEnding
                                ? const Color(0xA6000000)
                                : const Color(0x00000000),
                            BlendMode.srcATop,
                          ),
                          child: LiarsPokerTabletGameAnimation(
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
                Positioned.fill(
                  child: GameAnnouncementLayer(
                    announcement: GameAnnouncement.persistent(
                      id: 'insufficient-players',
                      text:
                          _controller.endingMessage ??
                          GameFlowCopy.insufficientPlayers,
                      blocksInteraction: true,
                      showScrim: true,
                    ),
                    style: const GameAnnouncementStyle(
                      fontFamily: null,
                      fontSize: 28,
                      gameStartFontSize: 58,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      shadows: [Shadow(color: Colors.black, blurRadius: 12)],
                    ),
                  ),
                ),

              // ---------------------------------------------------------------------------
              // 벌칙 룰렛 진입·퇴장
              // ---------------------------------------------------------------------------
              // 이 슬롯은 항상 유지합니다. 상태가 dealing으로 바뀌면 아래 기본
              // 레이어에 다음 카드팩이 먼저 생성되고, 이전 룰렛만 축소·페이드됩니다.
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: LiarsPokerFlowTiming.penaltySwitch,
                  reverseDuration: LiarsPokerFlowTiming.penaltySwitch,
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
                      _controller.stage == LiarsPokerTabletStage.penalty &&
                          !_controller.isInsufficientPlayersEnding
                      ? LiarsPokerTabletGamePenalty(
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
                child: LiarsPokerTabletGameOverlay(
                  provider: widget.provider,
                  stage: _controller.stage,
                  onRestartGame: _restartGame,
                  onEndGame: _endGame,
                ),
              ),
              GameInterruptionLayer(
                interruption: _controller.interruption,
                currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                presentation: GameInterruptionPresentation.tabletController,
                isSubmitting: _controller.isProcessingMenuCommand,
                onContinue: () async {
                  await _controller.excludeInterruptedPlayerAndContinue();
                },
                onExpired: _controller.expireInterruption,
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
    // ---------------------------------------------------------------------------
    // 게임 종료 후 플랫폼 화면 정책 복원
    // ---------------------------------------------------------------------------
    unawaited(AppOrientation.lockPlatformLandscape());
    unawaited(AppSystemUi.showPlatformSystemBars());
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
