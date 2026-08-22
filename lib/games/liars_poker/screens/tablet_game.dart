import 'dart:async';

import 'package:project00/core/diagnostics/dev_error_log.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/games/liars_poker/liars_poker_flow_config.dart';
import 'package:project00/games/liars_poker/sound/liars_poker_sounds.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/games/liars_poker/loading/liars_poker_loading.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_game_state.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_session_provider.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_animation.dart';
import 'package:project00/games/liars_poker/controllers/liars_poker_controller.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_helper.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_layer.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_overlay.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_penalty.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/shared/animations/mat_unroll_animation.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';
import 'package:project00/games/shared/game_flow/game_flow_auto_complete.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/sound/game_background_music.dart';
import 'package:project00/games/shared/widgets/game_announcement_layer.dart';
import 'package:project00/games/shared/widgets/game_interruption_layer.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/core/assets/game_image.dart';

/// Liar's Poker 태블릿 진행 화면의 진입점입니다.
///
/// 서버 미러 상태는 공용 [LiarsPokerController]가 담당하고, 태블릿 전용 연출
/// 상태(stage, 카드 더미, 제출 연출)는 Final Call처럼 이 화면 State가
/// 소유합니다.
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
  LiarsPokerController? _controller;
  LiarsPokerSessionArgs? _sessionArgs;
  ProviderSubscription<LiarsPokerGameState>? _sessionSubscription;
  String? _initializationError;
  late final AnimationController _exitMatController;
  bool _hasScheduledInsufficientPlayersExit = false;
  bool _isExitingToLobby = false;

  //=======================태블릿 전용 연출 상태==============================
  // 서버 미러 상태와 분리해 이 화면이 소유합니다. 새 제출·공개를 감지하려면
  // 직전 서버 상태와의 비교가 필요하므로 마지막으로 처리한 값을 함께 둡니다.
  LiarsPokerTabletStage _stage = LiarsPokerTabletStage.waiting;
  int _cardPileVersion = 0;
  List<SubmittedPlay> _roundPlays = const <SubmittedPlay>[];
  String? _activeAnimationPlayId;
  bool _hasReceivedFirstState = false;
  String _previousServerPhase = 'playing';
  int _previousRound = 1;
  Timer? _penaltyTransitionTimer;

  //=======================턴 타임아웃 백스톱==============================
  // 타임아웃 처리는 원래 턴 플레이어 휴대폰의 타이머가 합니다. 그 기기가
  // 화면 잠금·백그라운드로 멈추면 아무도 턴을 넘기지 못하므로, 태블릿이
  // 마감 + 여유 시간 뒤에도 턴이 그대로면 서버에 강제 해결을 요청합니다.
  Timer? _turnTimeoutBackstop;
  int? _backstopDeadline;

  /// 휴대폰 타이머가 먼저 처리할 시간을 주는 여유입니다.
  static const Duration _backstopGrace = Duration(seconds: 2);

  /// 강제 해결이 실패했을 때 다시 시도하기까지의 간격입니다.
  static const Duration _backstopRetryDelay = Duration(seconds: 3);

  /// 서버 시각 보정을 아직 못 받았을 때 다시 확인하기까지의 간격입니다.
  static const Duration _clockSyncRecheck = Duration(milliseconds: 500);

  /// 카드 분배가 시작되면 켜고, 화면을 떠날 때 끄는 배경음악입니다.
  final GameBackgroundMusic _backgroundMusic = GameBackgroundMusic();

  /// 우승 발표마다 승리음을 한 번만 재생하기 위한 플래그입니다.
  bool _hasPlayedWinSound = false;

  LiarsPokerTabletStage get stage => _stage;

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _initializationError = GameFlowCopy.authenticationRequired;
      return;
    }
    final args = LiarsPokerSessionArgs(
      roomCode: widget.roomCode,
      uid: uid,
      service: widget.gameService,
      // 태블릿은 진행 기기라 개인 손패가 없습니다.
      watchPrivateHand: false,
      onError: _showGameError,
    );
    _sessionArgs = args;
    final provider = liarsPokerSessionProvider(args);
    _sessionSubscription = ref.listenManual(provider, (_, _) {
      _handleState();
    });
    _controller = ref.read(provider.notifier);
    unawaited(_warmUpAssets());
  }

  /// 자리 배치 연출에서 이어지는 배경 위에서 조용히 이미지를 준비합니다.
  /// 별도 로딩 화면을 보여주지 않으므로 실패해도 게임 진행을 막지 않습니다.
  Future<void> _warmUpAssets() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      // 첫 스냅샷이 오지 않거나 구독이 에러로 끝나도 사전 로딩 대기가
      // unhandled exception이나 영구 대기로 남지 않게 합니다.
      await controller.waitForInitialData().timeout(
        const Duration(seconds: 12),
      );
    } catch (_) {
      // 프로필 이미지 없이도 나머지 에셋은 준비할 수 있습니다.
    }
    if (!mounted) return;
    await preloadLiarsPokerAssets(
      context,
      isPhone: false,
      characterIds: _characterIds,
    );
  }

  /// 컨트롤러가 이미 사용자 문구로 변환한 안내만 표시합니다.
  /// [error]는 개발용 기록 전용이며 화면에 붙이지 않습니다.
  void _showGameError(String message, Object error) {
    if (!mounted || message.isEmpty) return;
    DevErrorLog.instance.add(
      error: error,
      context: 'liars_poker/tablet',
      time: DateTime.now(),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  //=======================서버 상태 → 태블릿 연출 상태==============================
  // 구 태블릿 컨트롤러의 공개 상태 처리와 같은 로직입니다. 새 제출·공개는
  // 직전 상태와의 비교로만 감지할 수 있어 서버 미러 상태와 분리해 둡니다.
  void _handleState() {
    final game = _controller;
    if (game == null || !mounted) return;
    // 첫 공개 상태가 오기 전의 명령 상태 변화(메뉴 잠금 등)에는 연출 상태를
    // 만들지 않습니다.
    if (game.isInitialLoading) return;

    if (game.phase != 'penalty') {
      _penaltyTransitionTimer?.cancel();
      _penaltyTransitionTimer = null;
    }

    _scheduleTurnTimeoutBackstop(game);

    final isFirstSnapshot = !_hasReceivedFirstState;
    final wasDealing = _previousServerPhase == 'dealing';
    final isRoundChanged = game.round != _previousRound;
    final shouldResetCardPile = isRoundChanged || game.phase == 'dealing';

    // 새 라운드 및 게임 재시작으로 배분 단계에 다시 들어오면 카드 더미
    // 위젯 자체를 새 인스턴스로 만들어 남아 있던 애니메이션까지 종료합니다.
    if (game.phase == 'dealing' &&
        (isFirstSnapshot || !wasDealing || isRoundChanged)) {
      _cardPileVersion += 1;
    }
    final previousPlays = <String, SubmittedPlay>{
      for (final play in _roundPlays) play.eventId: play,
    };
    final nextRoundPlays = <SubmittedPlay>[];
    var hasNewSubmission = false;
    var hasNewReveal = false;
    String? nextActiveAnimationPlayId;

    for (final publicPlay
        in shouldResetCardPile ? const <PublicLastPlay>[] : game.roundPlays) {
      final playerIndex = widget.playerLayout.players.indexWhere(
        (player) => player.uid == publicPlay.playerUid,
      );
      if (playerIndex < 0) continue;

      final previousPlay = previousPlays[publicPlay.playId];
      final isNewSubmission = previousPlay == null;
      final isNewReveal =
          publicPlay.revealed && previousPlay?.isRevealed != true;
      final ranks = publicPlay.revealed && publicPlay.actualRanks.isNotEmpty
          ? publicPlay.actualRanks
          : List<String>.filled(publicPlay.cardCount, publicPlay.declaredRank);

      nextRoundPlays.add(
        SubmittedPlay(
          eventId: publicPlay.playId,
          playerIndex: playerIndex,
          frontCardAssets: ranks.map(cardAssetForRank).toList(growable: false),
          submittedAt: publicPlay.submittedAt,
          isRevealed: publicPlay.revealed,
          // 첫 구독 때 복원한 카드는 중앙에 즉시 표시합니다.
          animateEntry: previousPlay?.animateEntry ?? !isFirstSnapshot,
        ),
      );

      if (!isFirstSnapshot && isNewSubmission) {
        hasNewSubmission = true;
        nextActiveAnimationPlayId = publicPlay.playId;
      }
      if (!isFirstSnapshot && isNewReveal) {
        hasNewReveal = true;
        nextActiveAnimationPlayId = publicPlay.playId;
      }
    }

    _roundPlays = shouldResetCardPile
        ? const []
        : List.unmodifiable(nextRoundPlays);
    _activeAnimationPlayId = shouldResetCardPile
        ? null
        : nextActiveAnimationPlayId ?? _activeAnimationPlayId;

    // 서버 상태보다 한 번만 실행해야 하는 애니메이션 상태를 우선합니다.
    if (game.isInsufficientPlayersEnding) {
      // 태블릿에서 1초간 인원 부족 안내와 카드 더미 암전 상태를 보여준 뒤
      // 게임 화면만 닫습니다. 현재 표시 상태는 유지해 테이블이 사라지지 않습니다.
    } else if (game.isFinished) {
      _stage = LiarsPokerTabletStage.result;
    } else if (game.phase == 'dealing') {
      // 더미 초기화를 먼저 반영하고 새 라운드 카드 배분만 표시합니다.
      _stage = LiarsPokerTabletStage.dealing;
    } else if (hasNewReveal) {
      _stage = LiarsPokerTabletStage.cardsRevealing;
      // 패가 공개되는 건 누군가 라이어를 선언했다는 뜻입니다. 그 순간에
      // 나레이션을 한 번 냅니다(태블릿만 — 여러 기기가 울리면 겹칩니다).
      SoundEffects.play(context, LiarsPokerSounds.voiceLiar);
    } else if (hasNewSubmission) {
      _stage = LiarsPokerTabletStage.cardsPlaying;
      unawaited(game.warmUpLiarCommand());
    } else if (game.phase == 'penalty' &&
        _stage != LiarsPokerTabletStage.cardsRevealing) {
      _stage = LiarsPokerTabletStage.penalty;
    } else if (isRoundChanged) {
      // 새 라운드에서도 태블릿 카드 배분 애니메이션을 다시 실행합니다.
      _stage = LiarsPokerTabletStage.roundStarting;
    } else if (isFirstSnapshot && _roundPlays.isEmpty) {
      // 게임 화면에 처음 들어왔을 때만 카드 배분 애니메이션을 실행합니다.
      _stage = LiarsPokerTabletStage.dealing;
    } else if (isFirstSnapshot) {
      // 진행 중 재접속이면 기존 더미를 복원하고 바로 현재 단계로 진입합니다.
      _stage = game.phase == 'penalty'
          ? LiarsPokerTabletStage.penalty
          : LiarsPokerTabletStage.playing;
    }

    // 정상 우승이 확정돼 결과 화면이 뜨는 순간, 배경음악을 멈추고 승리음을
    // 한 번 재생합니다. 수동 종료·인원 부족 종료에서는 재생하지 않습니다.
    if (game.isFinished && game.isNaturalResult) {
      if (!_hasPlayedWinSound) {
        _hasPlayedWinSound = true;
        _backgroundMusic.stop();
        SoundEffects.play(context, LiarsPokerSounds.win);
      }
    } else {
      // 다시하기로 새 판이 시작되면 다음 우승 발표에서 다시 재생합니다.
      _hasPlayedWinSound = false;
    }

    _hasReceivedFirstState = true;
    _previousServerPhase = game.phase;
    _previousRound = game.round;
    setState(() {});
  }

  //=======================자리 배치 파생 상태==============================
  int get _playerCount => widget.playerLayout.playerCount;

  List<int> get _seatIndexes => widget.playerLayout.seatIndexes;

  int? get _currentTurnPlayerIndex {
    final currentTurnUid = _controller?.turnUid;
    if (currentTurnUid == null) return null;

    final index = widget.playerLayout.players.indexWhere(
      (player) => player.uid == currentTurnUid,
    );
    return index < 0 ? null : index;
  }

  /// 공개 게임 데이터에서 플레이어를 찾고 자리 배치 데이터로 빈 값을 보완합니다.
  PlayerLayoutPlayer? _playerByUid(String? uid) {
    if (uid == null) return null;

    final layoutPlayer = widget.playerLayout.playerByUid(uid);
    final publicPlayer = _controller?.players[uid];
    if (publicPlayer == null) return layoutPlayer;

    return PlayerLayoutPlayer(
      uid: uid,
      nickname: publicPlayer.nickname.trim().isNotEmpty
          ? publicPlayer.nickname.trim()
          : layoutPlayer?.nickname ?? 'Player',
      characterId: publicPlayer.characterId.trim().isNotEmpty
          ? publicPlayer.characterId.trim()
          : layoutPlayer?.characterId ?? 'frog',
      seatIndex: publicPlayer.seatIndex,
    );
  }

  /// 화면에 배치된 플레이어 순서대로 남은 카드 수를 반환합니다.
  List<int> get _remainingCardCounts {
    if (!_hasReceivedFirstState) {
      return List<int>.filled(_playerCount, cardsPerPlayer);
    }
    final players = _controller?.players ?? const <String, PhoneGamePlayer>{};
    return widget.playerLayout.players
        .map(
          (layoutPlayer) => players[layoutPlayer.uid]?.remainingCardCount ?? 0,
        )
        .toList(growable: false);
  }

  /// 최초 자리 배치 순서를 유지한 채 현재 생존자의 실제 좌석 번호만 반환합니다.
  List<int> get _activeSeatIndexes {
    if (!_hasReceivedFirstState) {
      return List<int>.generate(_playerCount, (index) => index);
    }
    final players = _controller?.players ?? const <String, PhoneGamePlayer>{};
    final seats = <int>[];
    for (final layoutPlayer in widget.playerLayout.players) {
      final publicPlayer = players[layoutPlayer.uid];
      if (publicPlayer == null || publicPlayer.status != 'alive') continue;
      seats.add(publicPlayer.seatIndex);
    }
    seats.sort();
    return seats;
  }

  List<String> get _characterIds {
    final players = _controller?.players ?? const <String, PhoneGamePlayer>{};
    return widget.playerLayout.players
        .map((layoutPlayer) {
          final characterId = players[layoutPlayer.uid]?.characterId.trim();
          if (characterId != null && characterId.isNotEmpty) {
            return characterId;
          }
          return layoutPlayer.characterId.trim();
        })
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  bool get _shouldShowSubmittedPlay {
    if (_roundPlays.isEmpty) return false;
    return switch (_stage) {
      LiarsPokerTabletStage.playing ||
      LiarsPokerTabletStage.cardsPlaying ||
      LiarsPokerTabletStage.cardsRevealing => true,
      _ => false,
    };
  }

  //=======================화면 애니메이션 완료 이벤트==============================
  Future<void> _onDealCompleted() async {
    _changeStage(LiarsPokerTabletStage.roundStarting);
    await _controller?.completeDealing();
  }

  void _onRoundRevealCompleted() {
    if (_stage == LiarsPokerTabletStage.roundStarting) {
      _changeStage(LiarsPokerTabletStage.playing);
    }
  }

  void _onCardsPlayed() {
    if (_stage == LiarsPokerTabletStage.cardsPlaying) {
      _changeStage(LiarsPokerTabletStage.playing);
    }
  }

  void _onCardsRevealed() {
    final game = _controller;
    if (game == null || _stage != LiarsPokerTabletStage.cardsRevealing) return;

    if (game.phase != 'penalty') {
      _changeStage(LiarsPokerTabletStage.playing);
      return;
    }
    if (_penaltyTransitionTimer != null) return;

    // 공개된 카드와 판정 결과를 충분히 확인한 뒤 룰렛 화면으로 전환합니다.
    _penaltyTransitionTimer = Timer(LiarsPokerFlowTiming.revealedCardsHold, () {
      _penaltyTransitionTimer = null;
      if (!mounted) return;
      if (_controller?.phase == 'penalty' &&
          _stage == LiarsPokerTabletStage.cardsRevealing) {
        _changeStage(LiarsPokerTabletStage.penalty);
      }
    });
  }

  void _changeStage(LiarsPokerTabletStage nextStage) {
    if (_stage == nextStage || !mounted) return;
    setState(() => _stage = nextStage);
  }

  //=======================설정 및 결과 화면 명령==============================
  void _restartGame() {
    unawaited(_controller?.restartGame());
  }

  void _endGame() {
    unawaited(_endGameAndReturnToLobby());
  }

  Future<void> _endGameAndReturnToLobby() async {
    if (_isExitingToLobby) return;
    _isExitingToLobby = true;

    final ended = await _controller?.endGame() ?? false;
    if (!mounted) return;
    if (!ended) {
      _isExitingToLobby = false;
      return;
    }

    // 종료를 누르면 정리 과정을 보여주지 않고 곧바로 화면을 닫습니다.
    //
    // 예전에는 매트를 위로 말아 없애는 퇴장 연출(_exitMatController.reverse())을
    // 기다렸습니다. 그 사이 서버 종료가 반영되며 좌석과 프로필이 하나씩 사라지는
    // 모습이 그대로 보여, 끝난 화면을 정리하는 장면을 구경하게 됐습니다.
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
    final args = _sessionArgs;
    if (args != null) ref.watch(liarsPokerSessionProvider(args));
    final controller = args == null
        ? null
        : ref.read(liarsPokerSessionProvider(args).notifier);
    _controller = controller;
    if (controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            _initializationError ?? GameFlowCopy.gameOpenFailed,
            style: const TextStyle(color: Colors.white, fontSize: 17),
          ),
        ),
      );
    }

    // ============================================================================
    // 게임 화면 진입
    // ============================================================================
    // 자리 배치 연출의 테이블과 같은 배경 이미지를 곧바로 보여주고, 서버
    // 데이터는 그 위에서 조용히 채워집니다. 별도 로딩 화면 없이 자연스럽게
    // 이어지도록 합니다.
    return AnimatedBuilder(
      animation: _exitMatController,
      child: _buildGameContent(controller),
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

  /// 카드 분배가 시작되면 배경음악을 켭니다.
  ///
  /// 라운드마다 분배가 반복되지만 [GameBackgroundMusic.start]가 한 번만
  /// 실행되므로 곡이 처음으로 되감기지 않습니다.
  void _startBackgroundMusicOnDeal() {
    if (_backgroundMusic.isPlaying || _stage != LiarsPokerTabletStage.dealing) {
      return;
    }
    // 빌드 도중 재생을 시작하지 않도록 프레임 이후로 미룹니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _backgroundMusic.start(LiarsPokerSounds.background);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // dispose에서는 context를 읽을 수 없으므로 미리 붙잡아 둡니다.
    _backgroundMusic.attach(context);
  }

  Widget _buildGameContent(LiarsPokerController game) {
    _startBackgroundMusicOnDeal();
    final flowConfig = buildLiarsPokerTabletFlowConfig(roundNumber: game.round);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Builder(
        builder: (context) {
          if (game.isInsufficientPlayersEnding) {
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
                  stage: _stage,
                  flowConfig: flowConfig,
                  playerCount: _playerCount,
                  playerSeatIndexes: _seatIndexes,
                  dealPlayerSeatIndexes: _activeSeatIndexes,
                  cardsPerPlayer: cardsPerPlayer,
                  roundNumber: game.round,
                  cardPileVersion: _cardPileVersion,
                  table: game.table,
                  winnerPlayer: _playerByUid(game.winnerUid),
                  remainingCardCounts: _remainingCardCounts,
                  currentTurnPlayerIndex: _currentTurnPlayerIndex,
                  onDealCompleted: _onDealCompleted,
                  onRoundRevealCompleted: _onRoundRevealCompleted,
                  onRestartGame: _restartGame,
                  onExitToLobby: _endGame,
                ),
              ),
              // 제출/공개 이벤트는 서버 미러 상태와 분리된 태블릿 연출입니다.
              if (_shouldShowSubmittedPlay)
                Positioned.fill(
                  child:
                      _stage != LiarsPokerTabletStage.playing &&
                          !flowConfig.stepFor(_stage).animation.enabled
                      ? GameFlowAutoComplete(
                          key: ValueKey(
                            'card-event-skipped-$_activeAnimationPlayId',
                          ),
                          onCompleted:
                              _stage == LiarsPokerTabletStage.cardsRevealing
                              ? _onCardsRevealed
                              : _onCardsPlayed,
                        )
                      : ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            game.isInsufficientPlayersEnding
                                ? const Color(0xA6000000)
                                : const Color(0x00000000),
                            BlendMode.srcATop,
                          ),
                          child: LiarsPokerTabletGameAnimation(
                            key: ValueKey(
                              'card-pile-${game.round}-$_cardPileVersion',
                            ),
                            roundPlays: _roundPlays,
                            activePlayId: _activeAnimationPlayId,
                            playerCount: _playerCount,
                            playerSeatIndexes: _seatIndexes,
                            onCardsPlayed: _onCardsPlayed,
                            onCardsRevealed: _onCardsRevealed,
                          ),
                        ),
                ),

              if (game.isInsufficientPlayersEnding)
                Positioned.fill(
                  child: GameAnnouncementLayer(
                    announcement: GameAnnouncement.persistent(
                      id: 'insufficient-players',
                      text:
                          game.endingMessage ??
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
                      _stage == LiarsPokerTabletStage.penalty &&
                          !game.isInsufficientPlayersEnding
                      ? LiarsPokerTabletGamePenalty(
                          key: ValueKey(
                            '${game.penaltyTargetUid}_'
                            '${game.penaltyAttemptCount}_'
                            '${game.rouletteRetry}',
                          ),
                          attemptCount: game.penaltyAttemptCount,
                          characterId:
                              _playerByUid(
                                game.penaltyTargetUid,
                              )?.characterId ??
                              'frog',
                          isResolving: game.isResolvingPenalty,
                          onResult: game.resolveRoulette,
                        )
                      : null,
                ),
              ),
              Positioned.fill(
                child: LiarsPokerTabletGameOverlay(
                  provider: widget.provider,
                  stage: _stage,
                  tableRank: game.table,
                  onRestartGame: _restartGame,
                  onEndGame: _endGame,
                ),
              ),
              GameInterruptionLayer(
                interruption: game.interruption,
                currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                presentation: GameInterruptionPresentation.tabletController,
                isSubmitting: game.isMenuCommandInFlight,
                onContinue: () async {
                  await game.excludeInterruptedPlayerAndContinue();
                },
                onFinishNow: game.finishInterruptedGameNowFromController,
                onExpired: game.expireInterruptionFromController,
              ),
            ],
          );
        },
      ),
    );
  }

  /// 현재 턴 마감에 맞춰 강제 해결 타이머를 (재)예약합니다.
  ///
  /// 연결 확인(interruption) 중에는 서버가 모든 진행 명령을 거절하므로
  /// 타이머를 내려 두고, 해소되어 상태가 갱신되면 다시 예약합니다.
  void _scheduleTurnTimeoutBackstop(LiarsPokerController game) {
    final isTurnPhase =
        game.phase == 'playing' || game.phase == 'lastCardChallenge';
    final deadline = isTurnPhase && game.interruption == null
        ? game.turnDeadlineAt
        : null;
    if (deadline == null) {
      _turnTimeoutBackstop?.cancel();
      _turnTimeoutBackstop = null;
      _backstopDeadline = null;
      return;
    }
    if (deadline == _backstopDeadline) return;
    _backstopDeadline = deadline;
    _armTurnTimeoutBackstop(deadline);
  }

  void _armTurnTimeoutBackstop(int deadline) {
    _turnTimeoutBackstop?.cancel();
    // 보정 전 계산은 기기 시계 오차일 수 있어 마감 판단을 미룹니다.
    if (!ServerClock.hasSynced) {
      _turnTimeoutBackstop = Timer(_clockSyncRecheck, () {
        if (!mounted || _backstopDeadline != deadline) return;
        _armTurnTimeoutBackstop(deadline);
      });
      return;
    }
    final delay = ServerClock.remainingUntil(deadline) + _backstopGrace;
    _turnTimeoutBackstop = Timer(delay, () async {
      final game = _controller;
      if (!mounted || game == null || game.turnDeadlineAt != deadline) return;
      final success = await game.forceTurnTimeout();
      // 아직 같은 턴이면(휴대폰도 서버도 못 넘긴 상태) 계속 다시 시도합니다.
      if (success || !mounted || _controller?.turnDeadlineAt != deadline) {
        return;
      }
      _turnTimeoutBackstop = Timer(_backstopRetryDelay, () {
        if (!mounted || _controller?.turnDeadlineAt != deadline) return;
        _armTurnTimeoutBackstop(deadline);
      });
    });
  }

  @override
  void dispose() {
    // 배경음악은 반복 재생이라 화면을 떠날 때 반드시 멈춥니다.
    _backgroundMusic.stop();
    _penaltyTransitionTimer?.cancel();
    _turnTimeoutBackstop?.cancel();
    _sessionSubscription?.close();
    _exitMatController.dispose();
    // ---------------------------------------------------------------------------
    // 게임 종료 후 플랫폼 화면 정책 복원
    // ---------------------------------------------------------------------------
    unawaited(AppOrientation.restorePlatform());
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
      child: Assets.games.liarsPoker.images.background.background.game.image(
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
    );
  }
}
