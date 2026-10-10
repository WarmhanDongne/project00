// 세션 수명·구독 해제·재접속·타이머를 관리하는 내부 구현입니다.
// 화면 연출 설정은 ../phone_board.dart에서 수정합니다.
// board와 같은 Dart library의 part로 유지해 private 상태를 외부에 노출하지 않습니다.
part of '../phone_board.dart';

class _FinalCallPhoneGameState extends ConsumerState<FinalCallPhoneGame> {
  /// 화면 맨 아래 LED 연결 띠가 듣는 서버 연결 상태입니다. 다시 그려도 같은 스트림을 씁니다.
  late final Stream<bool> _serverConnection = widget.provider
      .watchServerConnection();

  FinalCallController? controller;
  FinalCallSessionArgs? sessionArgs;
  ProviderSubscription<FinalCallGameState>? sessionSubscription;
  String? initializationError;
  String? selectedCardId;
  final Set<String> selectedFinalCardIds = <String>{};
  String? visibleCallerUid;
  String? observedCallerUid;
  int revealedRound = 0;
  Timer? callNoticeTimer;
  bool hasScheduledManualExit = false;
  bool gameStartCompleted = false;
  int? previousGameStartedAt;
  int? announcedRound;
  String? previousStatus;
  bool replacementInProgress = false;
  String? replacingCardId;
  int? _turnSubmissionRevision;

  /// 최종 조합을 미리 골라 둔 라운드입니다. 사용자가 모두 해제해도 같은
  /// 라운드에서 다시 채우지 않습니다.
  int? _presetFinalSelectionRound;
  bool _isLeavingRoom = false;
  bool _isExitModalOpen = false;
  bool _wasMyTurn = false;

  /// 에셋 사전 준비는 첫 상태 수신 때 한 번만 합니다(캐릭터 목록이 필요).
  bool _hasPreloadedAssets = false;

  @override
  void initState() {
    super.initState();
    // ========================================================================
    // 게임 진입 환경
    // ========================================================================
    // 게임을 시작하면 시스템 UI를 숨기고 Final Call 휴대폰 정책인 가로 방향으로
    // 고정합니다. 플랫폼 화면으로 돌아갈 때 dispose에서 반드시 복원합니다.
    unawaited(AppSystemUi.enterGameFullscreen());
    // Final Call 휴대폰 UI는 가로만 지원합니다. 태블릿은 별도 공용 불변
    // 조건에 따라 게임 종류와 관계없이 항상 가로 고정됩니다.
    unawaited(
      AppOrientation.applyPhoneGame(PhoneGameOrientation.landscapeOnly),
    );
    // 서버 에셋 도입 대비 훅입니다. 실패해도 번들 폴백으로 진행합니다.
    unawaited(
      GameAssetStore.instance.prepareGame('final_call').catchError((_) {}),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      initializationError = GameFlowCopy.authenticationRequired;
      return;
    }
    final args = FinalCallSessionArgs(
      roomCode: widget.roomCode,
      uid: uid,
      service: widget.gameService,
      watchPrivateHand: true,
    );
    sessionArgs = args;
    final provider = finalCallSessionProvider(args);
    sessionSubscription = ref.listenManual(provider, (_, _) {
      _handleState();
    });
    controller = ref.read(provider.notifier);
  }

  void _handleState() {
    final game = controller;
    if (game == null || !mounted) return;
    if (_turnSubmissionRevision case final revision?) {
      if (game.revision != revision ||
          game.pendingDrawUid != game.uid ||
          !game.isMyTurn) {
        _turnSubmissionRevision = null;
        replacementInProgress = false;
        replacingCardId = null;
      }
    }
    // 첫 스냅샷이 오면 이미지·캐릭터를 미리 디코딩합니다(LP와 같은 규약).
    if (!_hasPreloadedAssets && game.players.isNotEmpty) {
      _hasPreloadedAssets = true;
      unawaited(
        game.prepareScreen(
          () => preloadFinalCallAssets(
            context,
            isPhone: true,
            characterIds: game.players.values.map(
              (player) => player.characterId,
            ),
          ),
        ),
      );
    }
    if (previousGameStartedAt != game.gameStartedAt ||
        (previousStatus == 'finished' && !game.isFinished)) {
      previousGameStartedAt = game.gameStartedAt;
      gameStartCompleted = false;
      announcedRound = null;
      revealedRound = 0;
    }
    previousStatus = game.status;
    // ------------------------------------------------------------------------
    // 승부가 나지 않은 종료 처리
    // ------------------------------------------------------------------------
    // 나가야 할 종료 사유를 나열하지 않고, '정상 결과가 아니면 나간다'로 뒤집어
    // 판단합니다. 사유 목록 방식은 서버에 종료 사유가 하나만 늘어도 휴대폰이
    // 결과 화면에 갇힙니다. 라이어스포커와 같은 규칙입니다.
    final shouldCloseGame = game.isFinished && !game.isNaturalResult;
    if (shouldCloseGame) {
      if (_isLeavingRoom) return;
      if (hasScheduledManualExit) return;
      hasScheduledManualExit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) exitGameRoute(context);
      });
      return;
    }
    hasScheduledManualExit = false;
    // 내 턴이 시작되면 화면을 보고 있지 않아도 알 수 있게 진동을 울립니다.
    final wasMyTurn = _wasMyTurn;
    _wasMyTurn = game.isMyTurn;
    if (!wasMyTurn && game.isMyTurn && !game.isFinished) {
      GameFeedback.alert();
    }
    if (selectedCardId != null &&
        !game.hand.any((card) => card.id == selectedCardId)) {
      selectedCardId = null;
    }
    if (game.isFinalSubmitPhase) selectedCardId = null;
    if (!game.isFinalSubmitPhase && selectedFinalCardIds.isNotEmpty) {
      selectedFinalCardIds.clear();
    }
    // 최종 제출이 열리면 가장 높은 조합을 미리 골라 둡니다.
    if (game.isFinalSubmitPhase &&
        _presetFinalSelectionRound != game.round &&
        game.hand.isNotEmpty) {
      _presetFinalSelectionRound = game.round;
      if (selectedFinalCardIds.isEmpty) {
        selectedFinalCardIds.addAll(
          finalCallBestCombination(game.hand).cardIds,
        );
      }
    }
    if (game.callerUid == null) {
      observedCallerUid = null;
      visibleCallerUid = null;
      callNoticeTimer?.cancel();
    } else if (game.callerUid != observedCallerUid) {
      observedCallerUid = game.callerUid;
      visibleCallerUid = game.callerUid;
      // 다른 플레이어의 CALL 선언은 진동으로도 알립니다. 선언한 본인은
      // 버튼을 누를 때 이미 declare 진동을 받았습니다.
      if (game.callerUid != game.uid) GameFeedback.alert();
      callNoticeTimer?.cancel();
      callNoticeTimer = Timer(FinalCallPhoneTiming.callNotice, () {
        if (!mounted) return;
        setState(() => visibleCallerUid = null);
      });
    }
    setState(() {});
  }

  Future<void> _leaveRoom() async {
    // 확인 모달보다 앞에서 판정합니다. 뒤에서 판정하면 빠른 두 번 탭에 모달이
    // 두 개 쌓인 뒤 두 번째 확인이 삼켜집니다.
    if (_isLeavingRoom || _isExitModalOpen) return;
    _isExitModalOpen = true;
    final leave = await SharedPhoneExitModal.show(
      context,
      doorImage: Assets.games.finalCall.images.modal.modalImageDoor.game.image(
        fit: BoxFit.contain,
      ),
      surfaceColor: Colors.white,
      titleColor: Colors.white,
      descriptionColor: Colors.white,
      primaryColor: const Color(0xFF171717),
      showSurface: false,
      showText: true,
    );
    _isExitModalOpen = false;
    if (leave != true || !mounted) return;
    _isLeavingRoom = true;
    final left = await widget.onExitRoom();
    if (!mounted) return;
    if (left) {
      // 서버 퇴장 성공 뒤에는 게임 라우트를 먼저 닫습니다. 세로 복원 Future를
      // 먼저 기다리면 iOS 회전 응답이 지연될 때 게임 화면에 갇힐 수 있습니다.
      // 방향 복원은 dispose와 상위 대기 화면이 비동기로 처리합니다.
      Navigator.of(context).pop(true);
      return;
    }
    _isLeavingRoom = false;
    showLeaveFailureNotice(context, widget.provider);
  }

  Future<void> _completeTurn(String? replaceCardId) async {
    final game = controller;
    if (game == null || replacementInProgress || !game.canCompleteTurn) return;
    final expectedTurnUid = game.turnUid;
    final expectedDeadline = game.turnDeadlineAt;
    final submittedRevision = game.revision;

    // 버리기와 교체 모두 카드를 먼저 떠나보냅니다. 서버 응답 시점에
    // 애니메이션을 되돌리지 않고 공개 상태가 바뀔 때까지 유지합니다.
    setState(() {
      replacementInProgress = true;
      replacingCardId = replaceCardId;
    });
    await Future<void>.delayed(FinalCallPhoneTiming.phoneCardReplace);
    if (!mounted) return;

    if (game.turnUid != expectedTurnUid ||
        (expectedDeadline != null && ServerClock.hasPassed(expectedDeadline)) ||
        !game.canCompleteTurn) {
      game.clearError();
      setState(() {
        replacementInProgress = false;
        replacingCardId = null;
        _turnSubmissionRevision = null;
      });
      return;
    }

    final completed = await game.completeTurn(replaceCardId);
    if (!mounted) return;
    setState(() {
      if (completed) {
        selectedCardId = null;
        if (game.revision == submittedRevision &&
            game.pendingDrawUid == game.uid &&
            game.isMyTurn) {
          _turnSubmissionRevision = submittedRevision;
        } else {
          replacementInProgress = false;
          replacingCardId = null;
        }
      } else {
        replacementInProgress = false;
        replacingCardId = null;
        _turnSubmissionRevision = null;
      }
    });
    if (!completed) {
      if (game.turnUid != expectedTurnUid ||
          (expectedDeadline != null &&
              ServerClock.hasPassed(expectedDeadline)) ||
          !game.canCompleteTurn) {
        game.clearError();
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(game.actionErrorMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  void dispose() {
    callNoticeTimer?.cancel();
    sessionSubscription?.close();
    // ---------------------------------------------------------------------------
    // 게임 종료 후 플랫폼 화면 정책 복원
    // ---------------------------------------------------------------------------
    unawaited(AppOrientation.restorePlatform());
    unawaited(AppSystemUi.showPlatformSystemBars());
    super.dispose();
  }

  // ============================================================================
  // 게임 화면 진입
  // ============================================================================
  // 태블릿에서 테이블이 확대되는 순간과 맞춰 매트가 풀리며 게임 배경이
  // 드러납니다. 서버 데이터는 그 뒤에서 채워집니다.
  @override
  Widget build(BuildContext context) => _buildGameScreen(context);

  Widget _buildGameScreen(BuildContext context) {
    final args = sessionArgs;
    if (args != null) ref.watch(finalCallSessionProvider(args));
    final game = args == null
        ? null
        : ref.read(finalCallSessionProvider(args).notifier);
    controller = game;
    if (game == null) {
      return Scaffold(
        body: Center(
          child: Text(initializationError ?? GameFlowCopy.gameOpenFailed),
        ),
      );
    }

    final stage = resolveFinalCallPhoneStage(
      game: game,
      gameStartCompleted: gameStartCompleted,
      announcedRound: announcedRound,
      handRevealed: revealedRound == game.round,
    );
    final closingMessage = switch (game.finishReason) {
      'interruptionVoteExpired' => GameFlowCopy.interruptionVoteExpired,
      'insufficientPlayers' => GameFlowCopy.insufficientPlayers,
      _ => GameFlowCopy.gameFinished,
    };
    final flowConfig = buildFinalCallPhoneFlowConfig(
      roundNumber: game.round,
      closingMessage: closingMessage,
    );
    final winners = game.winners;
    final resultNickname = game.finishReason == 'draw'
        ? '무승부'
        : winners.map((winner) => winner.nickname).join(' · ');
    final resultProfile = winners.isEmpty ? null : winners.first;
    final resultLabel = game.finishReason == 'draw'
        ? 'DRAW'
        : '${game.winningTeam?.name.toUpperCase() ?? ''} TEAM WINNER'.trim();

    return GameConnectionLedHost(
      connectionChanges: _serverConnection,
      style: finalCallConnectionLed,
      child: GameRecoveryLayer(
        session: game.recoverySession,
        request: GameRequestRecovery(
          message: game.errorMessage,
          onRetry: () => unawaited(game.retryLastCommand()),
        ),
        onExit: () => unawaited(_leaveRoom()),
        interruption: GameInterruptionRecovery(
          state: game.interruption,
          currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
          isSubmitting: game.commandInFlight,
          failureMessage: game.errorMessage,

          onExpired: game.expireInterruption,
        ),
        child: PhoneGameShell<FinalCallPhoneStage>(
          flowConfig: flowConfig,
          stage: stage,
          stageRole: stage.shellRole,
          roundNumber: game.round,
          closingMessage: closingMessage,
          introTextColor: Colors.white,
          background: const FinalCallPopBackground(),
          // 손패가 준비되고 펼치기가 끝나야 상단바가 등장합니다.
          contentReady: game.isEliminated || game.hand.isNotEmpty,
          contentRevealed: game.isEliminated || revealedRound == game.round,
          onIntroCompleted: () {
            if (mounted) setState(() => gameStartCompleted = true);
          },
          onRoundIntroCompleted: () {
            if (mounted) setState(() => announcedRound = game.round);
          },
          topBar: FinalCallPhoneTopBar(
            controller: game,
            visibleCallerUid: visibleCallerUid,
            onExitRoom: () => unawaited(_leaveRoom()),
            onRulesPressed: (origin) => showFinalCallRules(context, origin),
          ),
          // 정상 승자/무승부가 확정된 경우에만 결과 위젯을 구성합니다.
          // 수동 종료나 인원 부족 종료가 phase 분기 오류로 result에 도달해도
          // 승자 없는 결과 화면이 노출되지 않게 하는 마지막 안전장치입니다.
          result: game.isNaturalResult
              ? FinalCallPhoneScreens.result(
                  nickname: resultNickname.isEmpty ? 'WINNER' : resultNickname,
                  characterId: resultProfile?.characterId ?? 'frog',
                  resultLabel: resultLabel,
                )
              : const SizedBox.shrink(),
          content: RepaintBoundary(
            child: game.isEliminated
                ? FinalCallSpectatorView(
                    remainingTeamCount: game.remainingTeamCount,
                    waitingForResult: game.isFinished,
                  )
                : FinalCallPhoneScreens.playing(
                    controller: game,
                    handRevealed: revealedRound == game.round,
                    selectedCardId: selectedCardId,
                    selectedFinalCardIds: selectedFinalCardIds,
                    visibleCallerUid: visibleCallerUid,
                    onRevealStarted: () {},
                    onRevealCompleted: () =>
                        setState(() => revealedRound = game.round),
                    onSelectedCardChanged: (id) =>
                        setState(() => selectedCardId = id),
                    onFinalCardSelected: (id) => setState(() {
                      if (!selectedFinalCardIds.remove(id)) {
                        selectedFinalCardIds.add(id);
                      }
                    }),
                    onCompleteTurn: _completeTurn,
                    replacingCardId: replacingCardId,
                    replacementInProgress: replacementInProgress,
                    onExitRoom: () => unawaited(_leaveRoom()),
                    regions: flowConfig.stepFor(stage).phoneRegions!,
                  ),
          ),
        ),
      ),
    );
  }
}
