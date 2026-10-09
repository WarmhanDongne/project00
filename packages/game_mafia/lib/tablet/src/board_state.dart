// 세션 수명·구독 해제·재접속·타이머를 관리하는 내부 구현입니다.
// 화면 연출 설정은 ../tablet_board.dart에서 수정합니다.
// board와 같은 Dart library의 part로 유지해 private 상태를 외부에 노출하지 않습니다.
part of '../tablet_board.dart';

class _MafiaTabletGameState extends ConsumerState<MafiaTabletGame> {
  MafiaController? _controller;
  MafiaSessionArgs? _sessionArgs;
  ProviderSubscription<MafiaGameState>? _subscription;
  final GameBackgroundMusic _bgm = GameBackgroundMusic();

  /// 밤·토론·투표의 마지막 5초 초읽기 소리입니다.
  ///
  /// 마피아의 제한시간은 같은 순간에 모두의 휴대폰에 함께 뜹니다. 기기마다
  /// 울리면 방 안에서 여러 번 겹쳐 들리므로, 우승 발표와 같이 방 가운데
  /// 태블릿에서만 냅니다.
  final CountdownTickCue _countdownTick = CountdownTickCue();

  /// 지금 화면에 보여 주는 단계입니다. 서버 단계를 연출 단위로 옮긴 값입니다.
  MafiaTabletStage _stage = MafiaTabletStage.connecting;

  /// 같은 밤에도 세부 단계별로 한 번씩 완료를 알려야 합니다.
  final _advanceCommand = GameProgressCommand();
  int? _previousGameStartedAt;
  final _presentationClock = GamePresentationClock();
  late final Stream<bool> _connectionChanges;
  Timer? _deadlineTimer;

  PresentationTimer? _stageTimer;

  /// 승부 없이 끝난 판에서 게임 화면을 닫는 타이머입니다.
  Timer? _closingExitTimer;

  // ---------------------------------------------------------------------------
  // 밤 늑대 하울링 (확정 2026-08)
  // ---------------------------------------------------------------------------
  // 밤마다 한 번, 무작위 시각에 멀리서 늑대가 웁니다. 정해진 시각이면 몇 판만
  // 해도 박자가 읽혀 분위기가 죽습니다.
  /// 밤이 시작되고 이만큼 지난 뒤부터 울릴 수 있습니다.

  /// 밤이 끝나기 이만큼 전까지만 울립니다.
  ///
  /// 하울링은 약 6초입니다. 여유를 두지 않으면 소리가 아침 발표로 넘어가거나
  /// 마지막 5초 초읽기와 겹칩니다.

  PresentationTimer? _howlTimer;
  final math.Random _howlRandom = math.Random();

  /// 지금 깔아 둔 곡입니다. null이면 아무것도 깔지 않은 상태입니다.
  String? _bgmAsset;

  // ---------------------------------------------------------------------------
  // 직업 효과음 (확정 2026-08)
  // ---------------------------------------------------------------------------
  // 총성 등 직업 소리는 밤이 시작될 때 자동으로 울리지 않고, 그 직업이
  // **선택을 완료한 순간** 이 태블릿에서 울립니다. 서버가 행동 종류만 담은
  // 신호를 올려 주고(`public.nightActionCue`), 여기서 소리로 옮깁니다.
  //
  // 휴대폰에서 내지 않는 이유: 그 사람의 기기에서 총성이 나면 옆 사람에게
  // 마피아가 그대로 드러납니다. 방 가운데 태블릿은 누가 냈는지 알려 주지
  // 않으면서 모두에게 같은 순간을 들려줍니다.
  /// 신호를 소리로 옮기는 규칙입니다([MafiaNightCueSpeaker]).
  final MafiaNightCueSpeaker _nightCueSpeaker = MafiaNightCueSpeaker();

  // ---------------------------------------------------------------------------
  // 밤 시작 안내 (확정 흐름)
  // ---------------------------------------------------------------------------
  // 전원 확인 → '게임을 시작하겠습니다'(2.5초, 소리 한 방) → 10초 대기
  // → '밤이 되었습니다' 안내 2.5초 → 서버에 밤 시작.
  // 확인 제한(서버 1분)이 끝나도 같은 안내를 거쳐 넘어갑니다.

  /// '게임을 시작하겠습니다'를 보여 주는 시간입니다(확정 2026-08).

  /// 승리 효과음 뒤에 나레이션을 이어 내기까지의 간격입니다.

  PresentationTimer? _winVoiceTimer;
  PresentationTimer? _gameStartNoticeTimer;
  bool _showsGameStartNotice = false;

  /// 서버 시각 보정을 아직 못 받았을 때 다시 확인하기까지의 간격입니다.
  static const Duration _clockSyncRecheck = Duration(milliseconds: 500);
  PresentationTimer? _nightNoticeTimer;
  bool _showsNightNotice = false;
  bool _nightNoticeScheduled = false;

  @override
  void initState() {
    super.initState();
    // 공용 연결 모니터의 broadcast 스트림을 연출 정지와 지연 안내가 함께
    // 구독합니다. 각 구독에는 최신 연결 상태가 즉시 재생됩니다.
    _connectionChanges = widget.provider.watchServerConnection();
    _presentationClock.addListener(_syncPresentationAudio);
    unawaited(AppSystemUi.enterGameFullscreen());
    unawaited(AppOrientation.lockTabletGameLandscape());
    unawaited(GameAssetStore.instance.prepareGame('mafia').catchError((_) {}));
    // 배경·달·새 등 첫 연출 이미지를 미리 디코딩합니다. context가 필요한
    // 작업이라 첫 프레임 뒤로 미룹니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          _controller!.prepareScreen(
            () => preloadMafiaAssets(context, isPhone: false),
          ),
        );
      }
    });

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final args = MafiaSessionArgs(
      roomCode: widget.roomCode,
      uid: uid,
      service: widget.gameService,
      // 태블릿은 신분을 받지 않습니다.
      watchPrivate: false,
    );
    _sessionArgs = args;
    final provider = mafiaSessionProvider(args);
    _subscription = ref.listenManual(provider, (_, _) => _handleState());
    _controller = ref.read(provider.notifier);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bgm.attach(context);
    _countdownTick.attach(context);
  }

  @override
  void dispose() {
    _presentationClock.removeListener(_syncPresentationAudio);
    _presentationClock.dispose();
    _deadlineTimer?.cancel();
    _advanceCommand.dispose();
    _stageTimer?.cancel();
    _closingExitTimer?.cancel();
    _howlTimer?.cancel();
    _nightNoticeTimer?.cancel();
    _gameStartNoticeTimer?.cancel();
    _winVoiceTimer?.cancel();
    _bgm.stop();
    _countdownTick.stop();
    _subscription?.close();
    unawaited(AppOrientation.restorePlatform());
    unawaited(AppSystemUi.showPlatformSystemBars());
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 단계 해석 — 한곳에서만
  // ---------------------------------------------------------------------------
  void _handleState() {
    final game = _controller;
    if (game == null || !mounted) return;
    // Boundary의 다음 build를 기다리기 전에 서버 중단을 연출 시계에 반영합니다.
    _presentationClock.setPaused(
      'mafia-server-interruption',
      game.interruption != null,
    );
    final newGame = _previousGameStartedAt != game.gameStartedAt;
    if (newGame) {
      _previousGameStartedAt = game.gameStartedAt;
      _advanceCommand.cancel();
      _winVoiceTimer?.cancel();
      _closingExitTimer?.cancel();
      _closingExitTimer = null;
    }

    // 승부가 나지 않은 종료(수동 종료·인원 부족·즉시 종료)는 결과 화면을 띄우지
    // 않고 대기실로 돌아갑니다. 사유를 나열하지 않고 '정상 결과가 아니면
    // 나간다'로 판단합니다(휴대폰 3게임·파이널 콜 태블릿과 같은 규칙).
    //
    // 이 분기가 없으면 인원 부족 종료 시 태블릿이 승자 없는 결과 화면에 머물러,
    // 진행자가 HOME을 직접 누를 때까지 대기실로 돌아가지 못했습니다.
    if (game.isFinished && !game.isNaturalResult) {
      _deadlineTimer?.cancel();
      _advanceCommand.cancel();
      _stageTimer?.cancel();
      _nightNoticeTimer?.cancel();
      _gameStartNoticeTimer?.cancel();
      _howlTimer?.cancel();
      _winVoiceTimer?.cancel();
      _bgm.stop();
      _countdownTick.stop();
      _closingExitTimer ??= Timer(MafiaTabletTiming.closingRouteDelay, () {
        // maybePop은 위에 쌓인 설정·룰북 다이얼로그만 닫아 게임 화면에
        // 갇힙니다(game_route_exit.dart 참고).
        if (mounted) exitGameRoute(context);
      });
      setState(() {});
      return;
    }

    final nextStage = resolveMafiaTabletStage(game);
    if (newGame || nextStage != _stage) {
      _stage = nextStage;
      _onStageEntered(game, nextStage);
      // 단계가 바뀌면 밤 안내 상태를 처음으로 돌립니다(재시작 대비).
      _nightNoticeTimer?.cancel();
      _showsNightNotice = false;
      _nightNoticeScheduled = false;
      _gameStartNoticeTimer?.cancel();
      _showsGameStartNotice = false;
    }
    _maybeScheduleNightNotice(game);
    _playNightActionCue(game);
    _syncBackgroundMusic(game);
    _scheduleDeadlineCheck(game);
    // 제한시간이 있는 단계(밤·토론·투표)에서만 초읽기를 겁니다. 역할 확인은
    // 마감이 있어도 화면에 남은 시간을 보여 주지 않으므로 제외합니다.
    _countdownTick.schedule(
      _stage.hasDeadline && !_presentationClock.paused
          ? game.turnDeadlineAt
          : null,
    );
    setState(() {});
  }

  /// 단계에 처음 들어온 순간 한 번만 하는 일입니다.
  void _onStageEntered(MafiaController game, MafiaTabletStage stage) {
    _stageTimer?.cancel();
    _howlTimer?.cancel();
    if (stage == MafiaTabletStage.night) _scheduleWolfHowl(game);
    if (stage == MafiaTabletStage.finished) _playWinSounds(game);
    final hold = stage.announcementHoldOf(game);
    if (hold == null) return;

    // 발표 연출은 정해진 시간만 보여 준 뒤 서버에 완료를 알립니다.
    _stageTimer = _presentationClock.schedule(hold, () {
      if (!mounted) return;
      _advance(game, stage);
    });
  }

  /// 이번 밤의 늑대 하울링을 무작위 시각에 한 번 예약합니다.
  ///
  /// 밤은 조기 종료가 없어 마감까지 반드시 이어지므로, 마감 기준으로 잡으면
  /// 밤 길이가 바뀌어도 알아서 따라갑니다. 남은 시간이 창(窓)보다 짧으면
  /// (재접속으로 밤 끝자락에 붙은 경우) 이번 밤은 건너뜁니다.
  void _scheduleWolfHowl(MafiaController game) {
    final deadline = game.turnDeadlineAt;
    if (deadline == null) return;

    final latest =
        ServerClock.remainingUntil(deadline) -
        MafiaTabletTiming.howlLatestBeforeEnd;
    if (latest <= MafiaTabletTiming.howlEarliest) return;

    final spanMs = (latest - MafiaTabletTiming.howlEarliest).inMilliseconds;
    final delay =
        MafiaTabletTiming.howlEarliest +
        Duration(milliseconds: _howlRandom.nextInt(spanMs + 1));
    _howlTimer = _presentationClock.schedule(delay, () {
      // 밤을 벗어났으면 울리지 않습니다.
      if (!mounted || _stage != MafiaTabletStage.night) return;
      SoundEffects.play(context, MafiaSounds.wolfHowl);
    });
  }

  /// 승리 발표에 효과음과 나레이션을 냅니다.
  ///
  /// 방 가운데 태블릿에서만 냅니다 — 휴대폰까지 같이 울리면 말이 겹칩니다.
  ///
  /// 확정(2026-08): 효과음이 먼저 한 방 울리고, [MafiaTabletTiming.winVoiceDelay] 뒤에 나레이션이
  /// 이어집니다. 동시에 내면 말이 효과음에 묻힙니다. 파일이 없는 진영은 그
  /// 자리를 조용히 지나갑니다(시민·중립 효과음은 아직 없습니다).
  void _playWinSounds(MafiaController game) {
    final faction = game.winnerFaction;
    final effect = MafiaSounds.winEffectFor(faction);
    if (effect != null) SoundEffects.play(context, effect);

    final voice = MafiaSounds.winVoiceFor(faction);
    if (voice == null) return;
    if (effect == null) {
      SoundEffects.play(context, voice);
      return;
    }
    _winVoiceTimer = _presentationClock.schedule(
      MafiaTabletTiming.winVoiceDelay,
      () {
        if (mounted) SoundEffects.play(context, voice);
      },
    );
  }

  /// 누군가 밤 행동을 마친 순간 그 직업의 효과음을 냅니다.
  ///
  /// 낼지 말지는 [MafiaNightCueSpeaker]가 정합니다(같은 신호 두 번 금지,
  /// 붙는 순간의 신호 금지).
  void _playNightActionCue(MafiaController game) {
    final sound = _nightCueSpeaker.soundFor(game.nightActionCue);
    if (sound == null || _presentationClock.paused) return;
    SoundEffects.play(context, sound);
  }

  /// 단계에 맞는 곡을 깔거나 내립니다([mafiaBackgroundMusicFor]).
  ///
  /// 확정(2026-08): **밤에만** 곡이 깔립니다. 아침이 되면 서서히 작아지며
  /// 사라집니다 — 뚝 끊으면 소리만 먼저 사라져 화면 전환과 어긋납니다.
  void _syncBackgroundMusic(MafiaController game) {
    if (_presentationClock.paused) return;
    final target = mafiaBackgroundMusicFor(
      isNight: game.isNight,
      isFinished: game.isFinished,
    );
    if (target == _bgmAsset) return;
    _bgmAsset = target;

    if (target == null) {
      _bgm.fadeOut(duration: mafiaBgmFadeOut);
      return;
    }
    // 곡을 갈아 끼울 때는 지금 곡을 확실히 멈춰야 겹쳐 들리지 않습니다.
    _bgm.stop();
    _bgm.start(target);
  }

  void _syncPresentationAudio() {
    if (_presentationClock.paused) {
      _bgm.stop();
      _countdownTick.stop();
      _bgmAsset = null;
    } else {
      final game = _controller;
      if (game == null || !mounted) return;
      _syncBackgroundMusic(game);
      _countdownTick.schedule(_stage.hasDeadline ? game.turnDeadlineAt : null);
    }
  }

  /// 전원이 역할을 확인하면 게임 시작을 알리고, 10초 뒤 밤 안내를 예약합니다.
  ///
  /// 확정(2026-08): 전원이 확인한 순간 '게임을 시작하겠습니다'를 소리와 함께
  /// 띄웁니다. 그 뒤 남은 10초는 카드를 한 번 더 볼 시간이고, 이어서 '밤이
  /// 되었습니다'로 넘어갑니다.
  void _maybeScheduleNightNotice(MafiaController game) {
    if (_stage != MafiaTabletStage.roleDeal || _nightNoticeScheduled) return;
    final total = game.players.length;
    if (total == 0 || game.roleConfirmedCount < total) return;

    _nightNoticeScheduled = true;
    _showGameStartNotice();
    _nightNoticeTimer = _presentationClock.schedule(
      MafiaTabletTiming.nightNoticeDelay,
      _showNightNotice,
    );
  }

  /// '게임을 시작하겠습니다'를 소리와 함께 잠깐 띄웁니다.
  void _showGameStartNotice() {
    if (!mounted) return;
    setState(() => _showsGameStartNotice = true);
    SoundEffects.play(context, MafiaSounds.gameStart);
    _gameStartNoticeTimer = _presentationClock.schedule(
      MafiaTabletTiming.gameStartNoticeHold,
      () {
        if (mounted) setState(() => _showsGameStartNotice = false);
      },
    );
  }

  /// '밤이 되었습니다'를 잠시 보여 준 뒤 서버에 밤 시작을 알립니다.
  void _showNightNotice() {
    if (!mounted || _stage != MafiaTabletStage.roleDeal) return;
    setState(() => _showsNightNotice = true);
    _nightNoticeTimer = _presentationClock.schedule(
      MafiaTabletTiming.nightNoticeHold,
      () {
        if (!mounted) return;
        final game = _controller;
        if (game != null) _advance(game, MafiaTabletStage.roleDeal);
      },
    );
  }

  /// 마감이 있는 단계는 시간이 지났을 때 서버에 알립니다.
  ///
  /// 서버는 스스로 시간을 재지 않으므로 이 호출이 없으면 그 단계에서 멈춥니다.
  /// 마감 전 호출은 서버가 무시하므로 조금 늦게 불러도 안전합니다.
  void _scheduleDeadlineCheck(MafiaController game) {
    _deadlineTimer?.cancel();
    final deadline = game.turnDeadlineAt;
    final stage = _stage;
    // 서버 시각 보정이 도착하기 전의 '마감 지남' 판단은 기기 시계 오차일 수
    // 있습니다. 그 상태로 진행 명령을 보내면 서버가 아직 마감 전이라고
    // 응답하고, 그 단계는 재시도 없이 멈춥니다([ServerClock.hasSynced] 주석
    // 참고). 보정이 올 때까지 판단을 미룹니다.
    if (deadline != null && !ServerClock.hasSynced) {
      _deadlineTimer = Timer(_clockSyncRecheck, () {
        if (!mounted) return;
        final current = _controller;
        if (current != null) _scheduleDeadlineCheck(current);
      });
      return;
    }
    // 역할 확인의 제한시간(서버 1분)이 끝나면 곧바로 넘기지 않고 같은
    // '밤이 되었습니다' 안내를 거칩니다.
    if (stage == MafiaTabletStage.roleDeal) {
      if (deadline == null || _nightNoticeScheduled) return;
      if (ServerClock.hasPassed(deadline)) {
        _nightNoticeScheduled = true;
        _showNightNotice();
        return;
      }
      _deadlineTimer = Timer(
        ServerClock.remainingUntil(deadline) +
            const Duration(milliseconds: 250),
        () {
          if (!mounted || _nightNoticeScheduled) return;
          _nightNoticeScheduled = true;
          _showNightNotice();
        },
      );
      return;
    }
    if (deadline == null || !stage.hasDeadline) return;

    if (ServerClock.hasPassed(deadline)) {
      _advance(game, stage);
      return;
    }
    final remaining = ServerClock.remainingUntil(deadline);
    _deadlineTimer = Timer(remaining + const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _advance(game, _stage);
    });
  }

  /// 서버에 다음 단계로 넘기라고 알립니다. 같은 단계는 한 번만 넘깁니다.
  void _advance(MafiaController game, MafiaTabletStage stage) {
    final command = stage.advance(game);
    if (command == null) return;
    // stage+round만 사용하면 첫 밤 시간 초과 이후 같은 밤의 support/wrapUp이
    // 이미 처리된 것으로 오인됩니다. 마감 변경도 구분해 재접속 후 재개합니다.
    Object currentKey() => (
      game.gameStartedAt,
      game.round,
      stage,
      stage == MafiaTabletStage.night ? game.nightStage : null,
      stage.hasDeadline ? game.turnDeadlineAt : null,
    );
    final key = currentKey();
    _advanceCommand.run(
      key: key,
      isCurrent: () =>
          mounted && !game.isFinished && _stage == stage && currentKey() == key,
      send: () => game.interruption != null || _presentationClock.paused
          ? Future.value(false)
          : command(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 다시 그리기는 ref.watch가 맡습니다(세 게임 공통). listenManual은 소리·
    // 단계 전환 같은 부수효과만 처리합니다.
    final args = _sessionArgs;
    if (args != null) ref.watch(mafiaSessionProvider(args));
    final game = _controller;
    if (game == null) {
      // 스피너 대신 게임 바탕을 먼저 깝니다. 상태가 오면 그 위로 장면이
      // 겹쳐 들어와 '로딩 중' 화면을 거치지 않습니다.
      return const Scaffold(
        backgroundColor: MafiaColors.noirInk,
        body: MafiaNoirRays.night(),
      );
    }

    return GamePresentationBoundary(
      clock: _presentationClock,
      connectionChanges: _connectionChanges,
      interrupted: game.interruption != null,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GameRecoveryLayer(
          session: game.recoverySession,
          request: GameRequestRecovery(
            message: game.errorMessage,
            onRetry: () {
              if (_advanceCommand.needsRetry) {
                _advanceCommand.retry();
              } else {
                unawaited(game.retryLastCommand());
              }
            },
          ),
          connection: GameConnectionRecovery(
            isWaiting: _stage == MafiaTabletStage.connecting,
            onExit: () => exitGameRoute(context),
            onRetry: () => unawaited(_retryConnection()),
          ),
          interruption: GameInterruptionRecovery(
            state: game.interruption,
            currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
            presentation: GameInterruptionPresentation.tabletController,
            isSubmitting: game.commandInFlight,
            failureMessage: game.errorMessage,
            onContinue: game.excludeInterruptedPlayerAndContinue,
            onWaitMore: game.waitMoreForInterruptedPlayer,
            onFinishNow: game.endGame,
            onExpired: game.expireInterruption,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 낮·밤 배경입니다. 태블릿용 가로 고해상도 파일을 씁니다.
              MafiaTabletBackground(isNight: game.usesNightScene),
              // 태블릿 토론 타이머도 1초마다 움직여야 합니다. 서버 상태만 보고
              // 그리면 상태가 안 바뀌는 동안 숫자가 굳습니다(2026-08 수정).
              GameTurnCountdown(
                expiresAt: game.turnDeadlineAt,
                builder: (context, remaining) => MafiaTabletStageView(
                  key: ValueKey(game.gameStartedAt),
                  stage: _stage,
                  controller: game,
                  playerLayout: widget.playerLayout,
                  // 마감 뒤 서버 응답이 늦어져도 0초가 화면에 붙어 있지 않게
                  // 타이머만 감추고 마지막 정상 장면을 그대로 유지합니다.
                  remainingSeconds: game.actionDeadlinePassed
                      ? null
                      : remaining?.inSeconds,
                  showsNightNotice: _showsNightNotice,
                  showsGameStartNotice: _showsGameStartNotice,
                  onRulebookPressed: _openRulebook,
                  onSettingsPressed: () => _openSettings(game),
                  onRestart: game.commandInFlight
                      ? null
                      : () => unawaited(game.restartGame()),
                  onHome: game.commandInFlight
                      ? null
                      : () => unawaited(_endGameAndLeave(game)),
                ),
              ),
              MafiaDelayedConnectionHint(
                connectionChanges: _connectionChanges,
                enabled: _stage != MafiaTabletStage.connecting,
                alignment: Alignment.topRight,
                margin: const EdgeInsets.only(top: 28, right: 104),
              ),
              if (game.isFinished && !game.isNaturalResult)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black87,
                    child: Center(
                      child: Text(
                        game.finishReason == 'insufficientPlayers'
                            ? '계속 진행할 인원이 부족해 게임이 종료되었습니다.\n대기실로 이동합니다.'
                            : '게임이 종료되었습니다.\n대기실로 이동합니다.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                ),

              // 태블릿은 좌석을 받지 않아 서버 `eligibleVoterUids`에 들지 않습니다.
              // 그래서 진행자 화면에는 투표 UI를 띄우지 않고, presentation으로
              // 진행자용 분기를 고릅니다(라이어스 포커·파이널 콜과 동일).
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retryConnection() async {
    try {
      await widget.provider.retryConnectionRecovery();
      await _controller?.retryRecovery();
    } catch (_) {
      // 현재 화면을 보존합니다. 서버 상태가 확인되기 전 임의로 종료하지 않습니다.
    }
  }

  // ---------------------------------------------------------------------------
  // 룰북·설정
  // ---------------------------------------------------------------------------
  void _openRulebook() {
    showDialog<void>(
      context: context,
      builder: (_) => TabletGameRulebookDialog(
        title: '마피아',
        markdown: _controller == null
            ? MafiaCopy.tabletRulebook
            : MafiaCopy.rulesFor(_controller!.ruleState),
        // 역할 카드를 함께 보여 줍니다. 규칙을 읽으며 카드를 대조할 수 있습니다.
        cardImages: [
          for (final role in MafiaRoles.implemented)
            if (role.card != null) role.card!,
        ],
      ),
    );
  }

  void _openSettings(MafiaController game) {
    showDialog<void>(
      context: context,
      builder: (_) => TabletGameSettingsDialog(
        provider: widget.provider,
        // ⚠️ 여기서 다이얼로그를 닫지 마세요. 공용 설정 다이얼로그가 버튼을
        // 누른 순간 **이미 닫고 나서** 이 콜백을 부릅니다. 여기서 한 번 더
        // 닫으면 그 pop이 게임 화면을 닫아, 설정에서 재시작·종료를 누르면
        // 게임이 그대로 튕겨 나갔습니다(2026-08 수정).
        onRestartGame: () => unawaited(game.restartGame()),
        onEndGame: () => unawaited(_endGameAndLeave(game)),
      ),
    );
  }

  /// 게임을 끝내고 화면을 즉시 닫습니다.
  ///
  /// 정리되는 모습(프로필이 사라지는 장면)을 보여 주지 않기 위해 서버 응답을
  /// 받은 뒤 곧바로 닫습니다.
  Future<void> _endGameAndLeave(MafiaController game) async {
    final ended = await game.endGame();
    if (!mounted || !ended) return;
    Navigator.of(context).maybePop();
  }
}
