// 세션 수명·구독 해제·재접속·타이머를 관리하는 내부 구현입니다.
// 화면 연출 설정은 ../phone_board.dart에서 수정합니다.
// board와 같은 Dart library의 part로 유지해 private 상태를 외부에 노출하지 않습니다.
part of '../phone_board.dart';

class _MafiaPhoneGameState extends ConsumerState<MafiaPhoneGame> {
  MafiaController? controller;
  MafiaSessionArgs? sessionArgs;
  ProviderSubscription<MafiaGameState>? sessionSubscription;
  String? initializationError;
  bool hasScheduledManualExit = false;
  bool _isLeavingRoom = false;
  bool _isExitModalOpen = false;
  String? previousStatus;
  final _presentationClock = GamePresentationClock();
  late final Stream<bool> _connectionChanges;
  Timer? _closingTimer;

  @override
  void initState() {
    super.initState();
    // 공용 연결 모니터의 broadcast 스트림을 화면 연출 정지와 지연 안내가
    // 함께 구독합니다. 각 구독에는 최신 연결 상태가 즉시 재생됩니다.
    _connectionChanges = widget.provider.watchServerConnection();
    // 게임에 들어가면 시스템 UI를 감추고 시안대로 세로로 고정합니다.
    // 플랫폼 화면으로 돌아갈 때 dispose에서 복원합니다.
    unawaited(AppSystemUi.enterGameFullscreen());
    unawaited(AppOrientation.applyPhoneGame(PhoneGameOrientation.portraitOnly));
    // 서버 에셋 도입 대비 훅입니다. 실패해도 번들 폴백으로 진행합니다.
    unawaited(GameAssetStore.instance.prepareGame('mafia').catchError((_) {}));

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      initializationError = GameFlowCopy.authenticationRequired;
      return;
    }
    final args = MafiaSessionArgs(
      roomCode: widget.roomCode,
      uid: uid,
      service: widget.gameService,
      // 휴대폰만 내 역할·조사 결과를 구독합니다.
      watchPrivate: true,
    );
    sessionArgs = args;
    final provider = mafiaSessionProvider(args);
    sessionSubscription = ref.listenManual(provider, (_, _) => _handleState());
    controller = ref.read(provider.notifier);
    // 첫 조작이 콜드스타트로 늦지 않게 서버를 미리 깨웁니다.
    unawaited(controller!.warmUp());
    // 첫 화면(P1) 이미지와 효과음을 미리 준비합니다. context가 필요한
    // 작업이라 첫 프레임 뒤로 미룹니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(preloadMafiaAssets(context, isPhone: true));
    });
  }

  void _handleState() {
    final game = controller;
    if (game == null || !mounted) return;
    if (previousStatus == 'finished' && !game.isFinished) {
      hasScheduledManualExit = false;
    }
    previousStatus = game.status;

    // 나가야 할 종료 사유를 나열하지 않고 '정상 결과가 아니면 나간다'로 뒤집어
    // 판단합니다. 사유 목록 방식은 서버에 사유가 하나만 늘어도 휴대폰이 결과
    // 화면에 갇힙니다.
    if (game.isFinished && !game.isNaturalResult) {
      if (_isLeavingRoom || hasScheduledManualExit) return;
      hasScheduledManualExit = true;
      _closingTimer = Timer(MafiaPhoneTiming.closingRouteDelay, () {
        if (mounted && game.isFinished && !game.isNaturalResult) {
          exitGameRoute(context);
        }
      });
      return;
    }
    hasScheduledManualExit = false;
    _closingTimer?.cancel();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _closingTimer?.cancel();
    _presentationClock.dispose();
    sessionSubscription?.close();
    unawaited(AppOrientation.restorePlatform());
    unawaited(AppSystemUi.showPlatformSystemBars());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = initializationError;
    if (error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, style: const TextStyle(color: Colors.white)),
              TextButton(
                onPressed: () => exitGameRoute(context),
                child: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      );
    }
    final args = sessionArgs;
    // 다시 그리기는 ref.watch가 맡습니다(세 게임 공통). listenManual은 소리·
    // 단계 전환 같은 부수효과만 처리합니다.
    if (args != null) ref.watch(mafiaSessionProvider(args));
    final game = controller;
    if (game == null) {
      // 스피너 대신 게임 바탕을 먼저 깝니다. 상태가 오면 그 위로 장면이
      // 겹쳐 들어와 '로딩 중' 화면을 거치지 않습니다.
      return const Scaffold(
        backgroundColor: MafiaColors.noirInk,
        body: MafiaNoirRays.night(),
      );
    }

    final stage = resolveMafiaPhoneStage(game);
    final closingMessage = switch (game.finishReason) {
      'interruptionVoteExpired' => GameFlowCopy.interruptionVoteExpired,
      'insufficientPlayers' => GameFlowCopy.insufficientPlayers,
      _ => GameFlowCopy.gameFinished,
    };
    final flowConfig = buildMafiaPhoneFlowConfig(
      closingMessage: closingMessage,
    );

    return GameConnectionLedHost(
      connectionChanges: _connectionChanges,
      style: mafiaConnectionLed,
      child: GamePresentationBoundary(
        clock: _presentationClock,
        connectionChanges: _connectionChanges,
        interrupted: game.interruption != null,
        child: GameRecoveryLayer(
          request: GameRequestRecovery(
            visible: !game.isFinished,
            // 플레이 입력은 각 화면이 즉시 완료 상태로 전환합니다. 여기서 전역
            // 로딩 알림까지 띄우면 느린 네트워크가 그대로 드러나고 화면 아래
            // 액션과 겹치므로, 실제 실패만 마지막 정상 화면 위에 표시합니다.
            busy: false,
            message: game.errorMessage,
            onRetry:
                game.isRoleReveal &&
                    !game.hasConfirmedRole &&
                    game.privateDataReady
                ? () => unawaited(game.confirmRole())
                : null,
          ),
          connection: GameConnectionRecovery(
            isWaiting: stage == MafiaPhoneStage.connecting,
            exitDelay: const Duration(seconds: 10),
            message: '게임 정보를 불러오고 있습니다.\n연결이 복구되면 현재 게임으로 돌아갑니다.',
            onExit: () => unawaited(_leaveRoom()),
            onRetry: () => unawaited(_retryConnection()),
          ),
          interruption: GameInterruptionRecovery(
            state: game.interruption,
            currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
            isSubmitting: game.commandInFlight,
            failureMessage: game.errorMessage,
            onVote: () async {
              await game.voteToContinueInterruption();
            },
            onFinishNow: game.finishInterruptedGameNow,
            onExpired: game.expireInterruption,
          ),
          child: PhoneGameShell<MafiaPhoneStage>(
            flowConfig: flowConfig,
            stage: stage,
            stageRole: stage.shellRole,
            roundNumber: game.round,
            closingMessage: closingMessage,
            introTextColor: Colors.black,
            // 연결·종료 단계에서 보이는 바탕입니다. 진행 화면은 각 시안 위젯이
            // 자기 배경을 그립니다.
            background: MafiaPhoneBackground(isNight: game.usesNightScene),
            onIntroCompleted: () {},
            onRoundIntroCompleted: () {},
            // 아래 복구 안내가 담당합니다. 셸의 20초 탈출 버튼과 중복하지 않습니다.
            onConnectingExit: null,
            topBar: MafiaPhoneTopBar(
              me: game.me,
              subtitle: MafiaPhoneTopBar.subtitleFor(
                phase: game.phase,
                round: game.round,
              ),
              // 결과 화면도 먹색 바탕이라 밤과 같은 밝은 글자를 씁니다.
              isNight: game.usesNightScene || game.isFinished,
              spectating: game.isSpectating,
              onExitRoom: () => unawaited(_leaveRoom()),
              onRulesPressed: (origin) => showMafiaRules(
                context,
                origin,
                MafiaCopy.rulesFor(game.ruleState),
              ),
            ),
            // 확정(2026-08): 승리 그림 2초 → 전원 신분 명단.
            result: game.isNaturalResult
                ? MafiaPhoneScreens.result(
                    winner: game.winnerFaction,
                    // 중립은 이긴 **역할**로 포스터가 갈립니다(광대/처형자/
                    // 연쇄살인마/교단).
                    winnerRoleIds: game.winnerRoleIds,
                    // 중립은 "중립 승리"로는 무슨 일이 있었는지 알 수 없어
                    // 역할 이름으로 알려 줍니다(예: `광대 승리`).
                    winnerLabel: game.winnerLabel,
                    players: game.orderedPlayers,
                    revealedRoles: {
                      for (final player in game.orderedPlayers)
                        player.uid: game.revealedRoleOf(player.uid),
                    },
                    myRole: game.myRole,
                    myUid: game.uid,
                    didWin: game.didWin,
                    allies: game.allyPlayers,
                  )
                : const SizedBox.shrink(),
            content: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: MafiaPhoneScreens.playing(
                    key: ValueKey(game.gameStartedAt),
                    controller: game,
                    stage: stage,
                    regions: flowConfig.stepFor(stage).phoneRegions!,
                  ),
                ),
                MafiaDelayedConnectionHint(
                  connectionChanges: _connectionChanges,
                  enabled: stage != MafiaPhoneStage.connecting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _retryConnection() async {
    try {
      await widget.provider.retryConnectionRecovery();
    } catch (_) {
      // 복구를 확정하거나 퇴장시키지 않습니다. 기존 연결 가드와 재시도 버튼을 유지합니다.
    }
  }

  Future<void> _leaveRoom() async {
    // 확인 모달보다 앞에서 판정합니다. 뒤에서 판정하면 빠른 두 번 탭에 모달이
    // 두 개 쌓인 뒤 두 번째 확인이 삼켜집니다.
    if (_isLeavingRoom || _isExitModalOpen) return;
    _isExitModalOpen = true;
    final leave = await SharedPhoneExitModal.show(
      context,
      doorImage: const _ExitBadge(color: _mafiaExitColor),
      imageHeight: 150,
      maxWidth: 320,
      surfaceColor: Colors.white,
      titleColor: Colors.black,
      descriptionColor: Colors.black,
      primaryColor: _mafiaExitColor,
    );
    _isExitModalOpen = false;
    if (leave != true || !mounted) return;
    _isLeavingRoom = true;
    final left = await widget.onExitRoom();
    if (!mounted) return;
    if (left) {
      // 서버 퇴장 성공 뒤에 게임 라우트를 먼저 닫습니다. 방향 복원을 먼저
      // 기다리면 회전 응답이 지연될 때 화면에 갇힐 수 있습니다.
      Navigator.of(context).pop(true);
      return;
    }
    _isLeavingRoom = false;
    showLeaveFailureNotice(context, widget.provider);
  }
}

const Color _mafiaExitColor = MafiaColors.ink;

// ---------------------------------------------------------------------------
// 퇴장 모달 표시
// ---------------------------------------------------------------------------
/// 퇴장 모달 위쪽 표시입니다.
///
/// 마피아다운 리볼버 그림을 씁니다. 그림을 불러오지 못하면 아이콘으로 대신
/// 그려, 모달 자체가 비어 보이지 않게 합니다.
class _ExitBadge extends StatelessWidget {
  const _ExitBadge({required this.color});

  /// 그림을 불러오지 못했을 때 쓰는 아이콘 색입니다.
  final Color color;

  /// 퇴장 모달의 리볼버 그림입니다. 파일을 넣으면 자동으로 보입니다.
  static const String revolverAsset =
      'packages/game_mafia/assets/games/mafia/images/other/exit_revolver.webp';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        revolverAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stack) => _FallbackBadge(color: color),
      ),
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.logout_rounded, size: 42, color: color),
      ),
    );
  }
}
