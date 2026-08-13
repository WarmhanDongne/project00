import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/liars_poker/animations/phone_control_entry_animation.dart';
import 'package:project00/games/liars_poker/animations/phone_game_start_animation.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';
import 'package:project00/games/liars_poker/widgets/phone/hand_card_stack.dart';
import 'package:project00/games/liars_poker/widgets/phone/liar_accusation.dart';
import 'package:project00/games/liars_poker/widgets/phone/penalty_status.dart';
import 'package:project00/games/liars_poker/widgets/phone/phone_exit_modal.dart';
import 'package:project00/games/liars_poker/widgets/phone/phone_settings_dialog.dart';
import 'package:project00/games/liars_poker/widgets/phone/phone_timer.dart';
import 'package:project00/games/liars_poker/widgets/phone/top_bar.dart';
import 'package:project00/games/liars_poker/widgets/phone/turn_action_switcher.dart';
import 'package:project00/gen/assets.gen.dart';

/// 기기 방향에 따라 가로·세로 배치를 전환하는 휴대폰 게임 화면입니다.
///
/// Firebase 구독, 손패 공개 상태, 헤더 진입 상태는 방향이 바뀌어도
/// 하나의 [State]에서 계속 유지합니다.
class PhoneGameScreen extends StatefulWidget {
  const PhoneGameScreen({super.key, this.controller, this.onExitRoom});

  final PhoneGameController? controller;
  final Future<bool> Function()? onExitRoom;

  @override
  State<PhoneGameScreen> createState() => _PhoneGameScreenState();
}

class _PhoneGameScreenState extends State<PhoneGameScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlsEntryController;
  final PhoneHandCardStackController _handCardStackController =
      PhoneHandCardStackController();
  bool _wasDealing = false;
  bool _isRevealInProgress = false;
  bool _hasCompletedGameStart = false;
  bool _hasPrecachedInitialHand = false;

  @override
  void initState() {
    super.initState();
    _controlsEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    if (widget.controller?.hasRevealedHand == true) {
      _controlsEntryController.value = 1;
    }
  }

  void _markRevealStarted() {
    if (mounted) {
      setState(() => _isRevealInProgress = true);
    }
    widget.controller?.markHandRevealed();
  }

  void _handleRevealCompleted() {
    widget.controller?.markHandRevealed();
    if (mounted) {
      setState(() => _isRevealInProgress = false);
    }
    _showGameControls();
  }

  void _showGameControls() {
    if (_controlsEntryController.isAnimating ||
        _controlsEntryController.isCompleted) {
      return;
    }
    _controlsEntryController.forward();
  }

  void _showControlsAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showGameControls();
    });
  }

  void _handleGameStartCompleted() {
    if (!mounted || _hasCompletedGameStart) return;
    setState(() => _hasCompletedGameStart = true);
  }

  void _precacheInitialHand(PhoneGameController? controller) {
    if (_hasPrecachedInitialHand || controller == null) return;
    _hasPrecachedInitialHand = true;

    // GAME START가 보이는 동안 카드 이미지를 미리 디코딩합니다. 서버 상태와
    // 손패는 이미 준비된 뒤이므로 문구 종료 후 추가 await 없이 바로 내려옵니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final asset in controller.handCardAssets) {
        precacheImage(asset.provider(), context);
      }
    });
  }

  Future<void> _showExitModal() async {
    final shouldExit = await PhoneExitModal.show(context);
    if (!mounted || shouldExit != true) return;

    final left = await widget.onExitRoom?.call() ?? false;
    if (!mounted) return;
    if (left) {
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('게임에서 퇴장하지 못했습니다.')));
  }

  @override
  void dispose() {
    _handCardStackController.dispose();
    _controlsEntryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Firebase 상태는 상위 PhoneGame에서 한 번만 구독합니다. 이 화면은 전달된
    // 최신 상태만 그려 카드·컨트롤 애니메이션이 중복 rebuild되지 않게 합니다.
    return _buildGameScreen(widget.controller);
  }

  Widget _buildGameScreen(PhoneGameController? controller) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final turnPlayer = controller?.players[controller.turnUid];
    final waitingMessage = controller?.emptyHandWaitingMessage;
    final showTwoPlayerPassPrompt =
        controller?.showTwoPlayerPassPrompt ?? false;
    final showPenaltyHandOverlay = controller?.showPenaltyHandOverlay ?? false;
    final isGameStartReady =
        controller == null ||
        (!controller.isInitialLoading &&
            controller.phase != 'dealing' &&
            controller.handCards.isNotEmpty);
    final showGameStart = !_hasCompletedGameStart && isGameStartReady;
    if (showGameStart) _precacheInitialHand(controller);

    final isDealing = controller?.phase == 'dealing';
    if (isDealing && !_wasDealing) {
      _wasDealing = true;
      _isRevealInProgress = false;
      final dealingRound = controller?.round;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            widget.controller?.phase != 'dealing' ||
            widget.controller?.round != dealingRound) {
          return;
        }
        _controlsEntryController.reset();
      });
    } else if (!isDealing) {
      _wasDealing = false;
    }

    final showHeader =
        _hasCompletedGameStart &&
        (controller == null ||
            (controller.hasRevealedHand &&
                controller.phase != 'dealing' &&
                !_isRevealInProgress));
    final showControls =
        showHeader && (controller == null || controller.handCards.isNotEmpty);

    // 공개 완료 콜백 전에 화면이 재생성되거나 hot reload된 경우에도
    // 헤더가 투명도 0에 멈추지 않도록 현재 상태에서 진입을 보장합니다.
    if (!isLandscape && showHeader && _controlsEntryController.isDismissed) {
      _showControlsAfterFrame();
    }

    if (isLandscape && controller != null) {
      return _buildLandscapeScreen(
        controller,
        turnPlayer: turnPlayer,
        showHeader: showHeader,
        showControls: showControls,
        waitingMessage: waitingMessage,
        showTwoPlayerPassPrompt: showTwoPlayerPassPrompt,
        showPenaltyHandOverlay: showPenaltyHandOverlay,
        showGameStart: showGameStart,
      );
    }

    return _buildPortraitScreen(
      controller,
      turnPlayer: turnPlayer,
      showHeader: showHeader,
      showControls: showControls,
      waitingMessage: waitingMessage,
      showTwoPlayerPassPrompt: showTwoPlayerPassPrompt,
      showPenaltyHandOverlay: showPenaltyHandOverlay,
      showGameStart: showGameStart,
    );
  }

  //==================================세로 화면==================================
  Widget _buildPortraitScreen(
    PhoneGameController? controller, {
    required PhoneGamePlayer? turnPlayer,
    required bool showHeader,
    required bool showControls,
    required String? waitingMessage,
    required bool showTwoPlayerPassPrompt,
    required bool showPenaltyHandOverlay,
    required bool showGameStart,
  }) {
    return Scaffold(
      body: Stack(
        children: [
          // 조건부 레이어가 추가·삭제되어도 손패 State가 다른 Positioned로
          // 재사용되지 않도록 모든 레이어에 역할별 고유 key를 유지합니다.
          //==================================배경화면==================================
          const Positioned.fill(
            key: ValueKey('portrait-background-slot'),
            child: _PortraitGameBackground(),
          ),
          if (showHeader)
            Positioned(
              key: const ValueKey('portrait-header-slot'),
              top: 50.h,
              left: 20.w,
              right: 20.w,
              child: PhoneGameTopBar(
                isLandscape: false,
                entryAnimation: _controlsEntryController,
                leadingWidget: _tableAsset(
                  controller?.table ?? 'K',
                ).image(height: 24.h, filterQuality: FilterQuality.high),
                onSettingPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const PhoneSettingsDialog(),
                  );
                },
                onOutPressed: () => unawaited(_showExitModal()),
              ),
            ),
          //==================================타이머==================================
          if (showHeader &&
              controller != null &&
              controller.turnDeadlineAt != null &&
              !controller.isInitialLoading &&
              controller.phase != 'dealing' &&
              controller.phase != 'penalty' &&
              controller.isMyTurn)
            Positioned(
              key: const ValueKey('portrait-timer-slot'),
              top: 105.h,
              left: 0,
              right: 0,
              child: Center(
                child: PhoneControlEntryAnimation(
                  animation: _controlsEntryController,
                  style: PhoneControlEntryStyle.header,
                  begin: 0,
                  end: 0.76,
                  child: PhoneTimer(
                    expiresAt: controller.turnDeadlineAt!,
                    onTimeout: () => _handleTurnTimeout(controller),
                  ),
                ),
              ),
            ),
          //==================================문구==================================
          if (controller != null &&
              !controller.isInitialLoading &&
              controller.phase != 'dealing' &&
              controller.handCards.isNotEmpty &&
              controller.statusMessage != null &&
              waitingMessage == null &&
              !showPenaltyHandOverlay &&
              !showTwoPlayerPassPrompt)
            Positioned(
              key: const ValueKey('portrait-status-slot'),
              top: 160.h,
              left: 24.w,
              right: 24.w,
              child: Text(
                controller.statusMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: controller.isMyTurn
                      ? FontWeight.w700
                      : FontWeight.w500,
                  shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                ),
              ),
            ),
          //==================================라이어 버튼==================================
          if (showControls)
            Positioned(
              key: const ValueKey('portrait-turn-action-slot'),
              top: 600.h,
              left: 20.w,
              right: 0,
              child: TurnActionSwitcher(
                isRow: false,
                showLiarButton: controller?.isMyTurn ?? true,
                turnPlayer: turnPlayer,
                height: 193.h,
                alignment: Alignment.topCenter,
                liarButton: _buildGameActionButton(
                  controller,
                  isLandscape: false,
                ),
              ),
            ),
          //==================================한쪽이 카드 나 냈을때==================================
          if (showControls &&
              controller?.phase == 'lastCardChallenge' &&
              !showTwoPlayerPassPrompt)
            Positioned(
              key: const ValueKey('portrait-last-card-slot'),
              top: 590.h,
              left: 70.w,
              right: 70.w,
              child: FilledButton(
                onPressed: controller!.canPassLastCardChallenge
                    ? () => unawaited(controller.passLastCardChallenge())
                    : null,
                style: _lastCardButtonStyle(),
                child: const Text('라이어 아님 · 새 라운드 진행'),
              ),
            ),
          //==================================손패==================================
          Positioned(
            key: const ValueKey('portrait-hand-slot'),
            top: 212.h,
            left: 0,
            right: 0,
            height: 350.h,
            child: RepaintBoundary(
              child: _buildPortraitHand(
                controller,
                dimmed: showTwoPlayerPassPrompt || showPenaltyHandOverlay,
              ),
            ),
          ),
          //==================================라이어 판정·패널티 문구==================================
          if (showPenaltyHandOverlay && controller != null)
            Positioned(
              key: const ValueKey('portrait-penalty-message-slot'),
              top: 212.h,
              left: 0,
              right: 0,
              height: 350.h,
              child: controller.liarVerdictMessage != null
                  ? _PenaltyHandOverlay(
                      message: controller.liarVerdictMessage!,
                      isFalseDeclaration: controller.liarVerdictIsFalse,
                    )
                  : PhonePenaltyStatus(
                      player: controller.penaltyStatusPlayer,
                      result: controller.visiblePenaltyResult,
                    ),
            ),
          //==================================2인 마지막 카드 선택==================================
          if (showTwoPlayerPassPrompt && controller != null)
            Positioned(
              key: const ValueKey('portrait-two-player-pass-slot'),
              top: 212.h,
              left: 0,
              right: 0,
              height: 350.h,
              child: _TwoPlayerPassPrompt(
                enabled: controller.canPassLastCardChallenge,
                onPressed: () => unawaited(controller.passLastCardChallenge()),
              ),
            ),
          //==================================빈 손패 대기 문구==================================
          if (waitingMessage != null)
            Positioned.fill(
              key: const ValueKey('portrait-waiting-message-slot'),
              child: _CenteredGameMessage(message: waitingMessage),
            ),
          //==================================오류 메시지==================================
          if (controller?.errorMessage != null)
            Positioned(
              key: const ValueKey('portrait-error-slot'),
              top: 155.h,
              left: 24.w,
              right: 24.w,
              child: _buildErrorMessage(
                controller!.errorMessage!,
                onTap: controller.clearError,
                verticalPadding: 10,
              ),
            ),
          //==================================게임 시작==================================
          if (showGameStart)
            Positioned.fill(
              key: const ValueKey('portrait-game-start-slot'),
              child: IgnorePointer(
                child: PhoneGameStartAnimation(
                  onCompleted: _handleGameStartCompleted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  //==================================가로 화면==================================
  Widget _buildLandscapeScreen(
    PhoneGameController controller, {
    required PhoneGamePlayer? turnPlayer,
    required bool showHeader,
    required bool showControls,
    required String? waitingMessage,
    required bool showTwoPlayerPassPrompt,
    required bool showPenaltyHandOverlay,
    required bool showGameStart,
  }) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final controlsWidth = constraints.maxWidth < 720 ? 180.0 : 220.0;

          return Stack(
            children: [
              // 가로 화면도 조건부 레이어의 순서 변화가 손패 State를 교체하지
              // 않도록 모든 Positioned를 역할별 key로 분리합니다.
              //==================================배경화면==================================
              Positioned.fill(
                key: const ValueKey('landscape-background-slot'),
                child: Assets.games.liarsPoker.images.background.background
                    .image(
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
              ),
              if (showHeader)
                Positioned(
                  key: const ValueKey('landscape-header-slot'),
                  top: 12,
                  left: 28,
                  right: 28,
                  child: SafeArea(
                    bottom: false,
                    child: PhoneGameTopBar(
                      isLandscape: true,
                      leadingWidget: _tableAsset(
                        controller.table,
                      ).image(height: 30, filterQuality: FilterQuality.high),
                      centerWidget:
                          controller.turnDeadlineAt != null &&
                              controller.phase != 'dealing' &&
                              controller.phase != 'penalty' &&
                              controller.isMyTurn
                          ? PhoneTimer(
                              expiresAt: controller.turnDeadlineAt!,
                              onTimeout: () => _handleTurnTimeout(controller),
                            )
                          : null,
                      onSettingPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const PhoneSettingsDialog(),
                        );
                      },
                      onOutPressed: () => unawaited(_showExitModal()),
                    ),
                  ),
                ),
              //==================================문구==================================
              if (showHeader &&
                  controller.statusMessage != null &&
                  waitingMessage == null &&
                  !showPenaltyHandOverlay &&
                  !showTwoPlayerPassPrompt)
                Positioned(
                  key: const ValueKey('landscape-status-slot'),
                  top: 72,
                  left: 28,
                  right: controlsWidth + 36,
                  child: Text(
                    controller.statusMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: controller.isMyTurn
                          ? FontWeight.w700
                          : FontWeight.w500,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              //==================================손패==================================
              Positioned(
                key: const ValueKey('landscape-hand-slot'),
                top: 72,
                bottom: 8,
                left: 16,
                right: controlsWidth + 24,
                child: RepaintBoundary(
                  child: _buildLandscapeHand(
                    controller,
                    // 손패 영역은 오른쪽 조작부만큼 좁으므로, 최초 덱은
                    // 그 차이만큼 보정해야 실제 화면 정중앙에 표시됩니다.
                    entryCenterOffsetX: controlsWidth / 2 + 4,
                    entryCenterOffsetY: -32,
                    dimmed: showTwoPlayerPassPrompt || showPenaltyHandOverlay,
                  ),
                ),
              ),
              //==================================라이어 판정·패널티 문구==================================
              if (showPenaltyHandOverlay)
                Positioned(
                  key: const ValueKey('landscape-penalty-message-slot'),
                  top: 72,
                  bottom: 8,
                  left: 16,
                  right: controlsWidth + 24,
                  child: controller.liarVerdictMessage != null
                      ? _PenaltyHandOverlay(
                          message: controller.liarVerdictMessage!,
                          isFalseDeclaration: controller.liarVerdictIsFalse,
                        )
                      : PhonePenaltyStatus(
                          player: controller.penaltyStatusPlayer,
                          result: controller.visiblePenaltyResult,
                        ),
                ),
              //==================================2인 마지막 카드 선택==================================
              if (showTwoPlayerPassPrompt)
                Positioned(
                  key: const ValueKey('landscape-two-player-pass-slot'),
                  top: 72,
                  bottom: 8,
                  left: 16,
                  right: controlsWidth + 24,
                  child: _TwoPlayerPassPrompt(
                    enabled: controller.canPassLastCardChallenge,
                    onPressed: () =>
                        unawaited(controller.passLastCardChallenge()),
                  ),
                ),
              //==================================빈 손패 대기 문구==================================
              if (waitingMessage != null)
                Positioned.fill(
                  key: const ValueKey('landscape-waiting-message-slot'),
                  child: _CenteredGameMessage(message: waitingMessage),
                ),
              //=================================라이어 버튼=================================
              if (showControls)
                Positioned(
                  key: const ValueKey('landscape-turn-action-slot'),
                  right: 50,
                  bottom: 110,
                  width: controlsWidth,
                  child: TurnActionSwitcher(
                    isRow: true,
                    showLiarButton: controller.isMyTurn,
                    turnPlayer: turnPlayer,
                    height: 140,
                    alignment: Alignment.bottomCenter,
                    profileSize: 72,
                    nicknameFontSize: 22,
                    spacing: 8,
                    liarButton: _buildGameActionButton(
                      controller,
                      isLandscape: true,
                    ),
                  ),
                ),
              //==================================한쪽이 카드 나 냈을때==================================
              if (showControls &&
                  controller.phase == 'lastCardChallenge' &&
                  !showTwoPlayerPassPrompt)
                Positioned(
                  key: const ValueKey('landscape-last-card-slot'),
                  top: 104,
                  right: 18,
                  width: controlsWidth,
                  child: FilledButton(
                    onPressed: controller.canPassLastCardChallenge
                        ? () => unawaited(controller.passLastCardChallenge())
                        : null,
                    style: _lastCardButtonStyle(),
                    child: const Text('라이어 아님 · 새 라운드'),
                  ),
                ),
              //==================================오류 메시지==================================
              if (controller.errorMessage != null)
                Positioned(
                  key: const ValueKey('landscape-error-slot'),
                  top: 76,
                  left: 28,
                  right: 28,
                  child: _buildErrorMessage(
                    controller.errorMessage!,
                    onTap: controller.clearError,
                    verticalPadding: 9,
                  ),
                ),
              //==================================게임 시작==================================
              if (showGameStart)
                Positioned.fill(
                  key: const ValueKey('landscape-game-start-slot'),
                  child: IgnorePointer(
                    child: PhoneGameStartAnimation(
                      onCompleted: _handleGameStartCompleted,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  //==================================세로 손패==================================
  Widget _buildPortraitHand(
    PhoneGameController? controller, {
    required bool dimmed,
  }) {
    if (!_hasCompletedGameStart) return const SizedBox.shrink();

    if (controller == null) {
      return _dimHandCards(
        PhoneHandCardStack(
          isLandscape: false,
          controller: _handCardStackController,
          onRevealCompleted: _showGameControls,
        ),
        dimmed: dimmed,
      );
    }

    if (controller.isInitialLoading) {
      return const SizedBox.shrink();
    }

    // 손패 데이터가 먼저 도착해도 태블릿의 실제 배분 연출이 끝날 때까지
    // 카드 위→아래 진입 애니메이션을 생성하지 않습니다.
    if (controller.phase == 'dealing') {
      return const SizedBox.shrink();
    }
    //==================================손패 없을떄==================================
    if (controller.handCards.isEmpty && !controller.hasRevealedHand) {
      _showControlsAfterFrame();
      if (!controller.isEliminated) return const SizedBox.shrink();
      return _emptyHandMessage();
    }

    return _dimHandCards(
      PhoneHandCardStack(
        key: ValueKey('portrait-deal-${controller.handDealVersion}'),
        isLandscape: false,
        controller: _handCardStackController,
        cards: controller.handCardAssets,
        enabled: controller.canSelectCards,
        submissionEnabled: controller.canSubmitCards,
        initiallyRevealed: controller.hasRevealedHand,
        onRevealStarted: _markRevealStarted,
        onRevealCompleted: _handleRevealCompleted,
        onCardsSubmitRequested: controller.submitCardIndexes,
      ),
      dimmed: dimmed,
    );
  }

  //==================================가로 손패==================================
  Widget _buildLandscapeHand(
    PhoneGameController controller, {
    required double entryCenterOffsetX,
    required double entryCenterOffsetY,
    required bool dimmed,
  }) {
    if (!_hasCompletedGameStart) return const SizedBox.shrink();

    if (controller.isInitialLoading || controller.phase == 'dealing') {
      return const SizedBox.shrink();
    }
    //==================================손패 없을때==================================
    if (controller.handCards.isEmpty && !controller.hasRevealedHand) {
      return controller.isEliminated
          ? _emptyHandMessage()
          : const SizedBox.shrink();
    }

    //==================================손패==================================
    return _dimHandCards(
      PhoneHandCardStack(
        key: ValueKey('landscape-deal-${controller.handDealVersion}'),
        isLandscape: true,
        controller: _handCardStackController,
        cards: controller.handCardAssets,
        enabled: controller.canSelectCards,
        submissionEnabled: controller.canSubmitCards,
        initiallyRevealed: controller.hasRevealedHand,
        onRevealStarted: _markRevealStarted,
        onRevealCompleted: _handleRevealCompleted,
        onCardsSubmitRequested: controller.submitCardIndexes,
        entryCenterOffsetX: entryCenterOffsetX,
        entryCenterOffsetY: entryCenterOffsetY,
      ),
      dimmed: dimmed,
    );
  }

  /// 투명한 손패 영역은 유지하고 실제 카드 픽셀만 어둡게 처리합니다.
  Widget _dimHandCards(Widget child, {required bool dimmed}) {
    return ColorFiltered(
      // 어두움 전환 전후에도 동일한 ColorFiltered 부모를 유지해야 손패
      // State와 진행 중인 카드 애니메이션이 재생성되지 않습니다.
      colorFilter: dimmed
          ? const ColorFilter.matrix([
              0.34,
              0,
              0,
              0,
              0,
              0,
              0.34,
              0,
              0,
              0,
              0,
              0,
              0.34,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ])
          : const ColorFilter.matrix([
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
      child: child,
    );
  }

  //==================================제한시간 종료==================================
  void _handleTurnTimeout(PhoneGameController controller) {
    if (!controller.isMyTurn || controller.phase == 'penalty') return;

    // 1대1 마지막 카드 선택에서 응답하지 않으면 상대를 의심하지 않고
    // PASS 처리해 새 라운드로 진행합니다.
    if (controller.showTwoPlayerPassPrompt &&
        controller.canPassLastCardChallenge) {
      unawaited(controller.passLastCardChallenge());
      return;
    }

    if (controller.canCallLiar) {
      unawaited(controller.callLiar());
      return;
    }
    unawaited(controller.submitCardIndexes([0]));
  }

  //==================================LIAR·SUBMIT 버튼==================================
  Widget _buildGameActionButton(
    PhoneGameController? controller, {
    required bool isLandscape,
  }) {
    return AnimatedBuilder(
      animation: _handCardStackController,
      builder: (context, _) {
        final showSubmit = _handCardStackController.hasSelection;
        final enabled = controller == null
            ? true
            : showSubmit
            ? controller.canSubmitCards
            : controller.canCallLiar;

        return LiarAccusation(
          isLandscape: isLandscape,
          showSubmit: showSubmit,
          enabled: enabled,
          onAccuse: controller == null
              ? null
              : () => unawaited(controller.callLiar()),
          onSubmit: () =>
              unawaited(_handCardStackController.submitSelectedCards()),
        );
      },
    );
  }

  //==================================오류 메시지==================================
  Widget _buildErrorMessage(
    String message, {
    required VoidCallback onTap,
    required double verticalPadding,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE62B1717),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: verticalPadding,
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  //==================================마지막 카드 버튼==================================
  ButtonStyle _lastCardButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: const Color(0xFF50675A),
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0x6650675A),
      elevation: 9,
      shadowColor: const Color(0x99000000),
    );
  }

  //==================================손패 없음==================================
  Widget _emptyHandMessage() {
    return const Center(
      child: Text(
        '내 손패 없음',
        style: TextStyle(color: Colors.white70, fontSize: 17),
      ),
    );
  }

  //==================================알파벳에 따라 카드 불러오기==================================
  AssetGenImage _tableAsset(String rank) {
    return switch (rank.toUpperCase()) {
      'A' => Assets.games.liarsPoker.images.table.tableAceWhite,
      'Q' => Assets.games.liarsPoker.images.table.tableQueenWhite,
      _ => Assets.games.liarsPoker.images.table.tableKingWhite,
    };
  }
}

/// 손패를 모두 낸 플레이어가 서버의 다음 결정을 기다릴 때 표시합니다.
class _CenteredGameMessage extends StatelessWidget {
  const _CenteredGameMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: isLandscape ? 31 : 30.sp,
              height: 1.18,
              letterSpacing: 0.5,
              color: Colors.white,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 12)],
            ),
          ),
        ),
      ),
    );
  }
}

/// 라이어 판정 공개와 패널티 진행 상태를 손패 중앙에 표시합니다.
class _PenaltyHandOverlay extends StatelessWidget {
  const _PenaltyHandOverlay({
    required this.message,
    required this.isFalseDeclaration,
  });

  final String message;
  final bool isFalseDeclaration;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return IgnorePointer(
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Text(
            message,
            key: ValueKey(message),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: isLandscape ? 34 : 32.sp,
              height: 1.15,
              letterSpacing: 0.7,
              color: isFalseDeclaration
                  ? const Color(0xFFFF3B30)
                  : Colors.white,
              shadows: const [Shadow(color: Colors.black, blurRadius: 14)],
            ),
          ),
        ),
      ),
    );
  }
}

/// 2인 상황에서 남은 플레이어의 손패를 잠그고 새 라운드 진행을 선택합니다.
class _TwoPlayerPassPrompt extends StatelessWidget {
  const _TwoPlayerPassPrompt({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final passButton = _PressableAssetButton(
      asset: Assets.games.liarsPoker.images.button.buttonPass,
      width: isLandscape ? 190 : 255.w,
      enabled: enabled,
      semanticsLabel: '패스하고 패널티 진행',
      onPressed: onPressed,
    );

    return IgnorePointer(
      ignoring: !enabled,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isLandscape ? 18 : 26.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              passButton,
              SizedBox(height: isLandscape ? 8 : 12.h),
              Text(
                'PASS를 선택하면 내가 패널티를 진행합니다.\n'
                'LIAR 판정에 실패하면 이번 패널티 확률이 증가합니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLandscape ? 13 : 13.sp,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이미지 버튼이 눌린 동안 높이와 그림자가 함께 줄어드는 공통 버튼입니다.
class _PressableAssetButton extends StatefulWidget {
  const _PressableAssetButton({
    required this.asset,
    required this.width,
    required this.enabled,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final AssetGenImage asset;
  final double width;
  final bool enabled;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  State<_PressableAssetButton> createState() => _PressableAssetButtonState();
}

class _PressableAssetButtonState extends State<_PressableAssetButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Widget image() => widget.asset.image(
      width: widget.width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) => setState(() => _isPressed = true)
            : null,
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _isPressed = false);
                widget.onPressed();
              }
            : null,
        onTapCancel: widget.enabled
            ? () => setState(() => _isPressed = false)
            : null,
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1 : 0.5,
          duration: const Duration(milliseconds: 180),
          child: AnimatedSlide(
            offset: _isPressed ? const Offset(0, 0.04) : Offset.zero,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: _isPressed ? 0.91 : 1,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOutCubic,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedSlide(
                    offset: _isPressed
                        ? const Offset(0, 0.015)
                        : const Offset(0, 0.065),
                    duration: const Duration(milliseconds: 110),
                    child: AnimatedOpacity(
                      opacity: _isPressed ? 0.28 : 0.68,
                      duration: const Duration(milliseconds: 110),
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: _isPressed ? 3 : 8,
                          sigmaY: _isPressed ? 3 : 8,
                        ),
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.black,
                            BlendMode.srcIn,
                          ),
                          child: image(),
                        ),
                      ),
                    ),
                  ),
                  image(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortraitGameBackground extends StatelessWidget {
  const _PortraitGameBackground();

  @override
  Widget build(BuildContext context) {
    return Assets.games.liarsPoker.images.background.backgroundPhone.image(
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
  }
}
