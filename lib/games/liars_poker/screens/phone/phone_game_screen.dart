import 'dart:async';
import 'dart:math' as math;

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
import 'package:project00/games/liars_poker/widgets/pressable_asset_button.dart';
import 'package:project00/games/shared/widgets/phone_rule_dialog.dart';
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

  //=======================세로 화면==============================
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _PortraitGameLayout.fromSize(
            Size(constraints.maxWidth, constraints.maxHeight),
          );

          return Stack(
            children: [
              // 조건부 레이어가 추가·삭제되어도 손패 State가 다른 Positioned로
              // 재사용되지 않도록 모든 레이어에 역할별 고유 key를 유지합니다.
              //=======================배경 화면==============================
              const Positioned.fill(
                key: ValueKey('portrait-background-slot'),
                child: _PhoneGameBackground(isLandscape: false),
              ),
              if (showHeader)
                Positioned(
                  key: const ValueKey('portrait-header-slot'),
                  top: layout.headerTop,
                  left: layout.horizontalPadding,
                  right: layout.horizontalPadding,
                  child: PhoneGameTopBar(
                    isLandscape: false,
                    entryAnimation: _controlsEntryController,
                    leadingWidget: _tableAsset(controller?.table ?? 'K').image(
                      height: layout.tableHeight,
                      filterQuality: FilterQuality.high,
                    ),
                    onSettingPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const PhoneSettingsDialog(),
                      );
                    },
                    onTipPressed: _showRules,
                    onOutPressed: () => unawaited(_showExitModal()),
                  ),
                ),
              //=======================타이머==============================
              if (showHeader &&
                  controller != null &&
                  controller.turnDeadlineAt != null &&
                  !controller.isInitialLoading &&
                  controller.phase != 'dealing' &&
                  controller.phase != 'penalty' &&
                  controller.isMyTurn)
                Positioned(
                  key: const ValueKey('portrait-timer-slot'),
                  top: layout.timerTop,
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
              //=======================상태 문구==============================
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
                  top: layout.statusTop,
                  left: layout.messagePadding,
                  right: layout.messagePadding,
                  child: Text(
                    controller.statusMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: layout.statusFontSize,
                      fontWeight: controller.isMyTurn
                          ? FontWeight.w700
                          : FontWeight.w500,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              //=======================턴 정보·게임 버튼==============================
              if (showControls)
                Positioned(
                  key: const ValueKey('portrait-turn-action-slot'),
                  top: layout.actionTop,
                  left: layout.horizontalPadding,
                  right: 0,
                  child: TurnActionSwitcher(
                    isLandscape: false,
                    showLiarButton: controller?.isMyTurn ?? true,
                    turnPlayer: turnPlayer,
                    liarButton: _buildGameActionButton(
                      controller,
                      isLandscape: false,
                    ),
                  ),
                ),
              //=======================마지막 카드 선택==============================
              if (showControls &&
                  controller?.phase == 'lastCardChallenge' &&
                  !showTwoPlayerPassPrompt)
                Positioned(
                  key: const ValueKey('portrait-last-card-slot'),
                  top: layout.actionTop - 10,
                  left: layout.actionHorizontalPadding,
                  right: layout.actionHorizontalPadding,
                  child: FilledButton(
                    onPressed: controller!.canPassLastCardChallenge
                        ? () => unawaited(controller.passLastCardChallenge())
                        : null,
                    style: _lastCardButtonStyle(),
                    child: const Text('라이어 아님 · 새 라운드 진행'),
                  ),
                ),
              //=======================손패==============================
              Positioned(
                key: const ValueKey('portrait-hand-slot'),
                top: layout.handTop,
                left: 0,
                right: 0,
                height: layout.handHeight,
                child: RepaintBoundary(
                  child: _buildHand(
                    controller,
                    isLandscape: false,
                    dimmed: showTwoPlayerPassPrompt || showPenaltyHandOverlay,
                  ),
                ),
              ),
              //=======================라이어 판정·벌칙 문구==============================
              if (showPenaltyHandOverlay && controller != null)
                Positioned(
                  key: const ValueKey('portrait-penalty-message-slot'),
                  top: layout.handTop,
                  left: 0,
                  right: 0,
                  height: layout.handHeight,
                  child: controller.liarVerdictMessage != null
                      ? _PenaltyHandOverlay(
                          message: controller.liarVerdictMessage!,
                          isFalseDeclaration: controller.liarVerdictIsFalse,
                        )
                      : const SizedBox.shrink(),
                ),
              if (showPenaltyHandOverlay &&
                  controller != null &&
                  controller.liarVerdictMessage == null)
                Positioned.fill(
                  key: const ValueKey('portrait-penalty-status-slot'),
                  child: PhonePenaltyStatus(
                    player: controller.penaltyStatusPlayer,
                    result: controller.visiblePenaltyResult,
                  ),
                ),
              //=======================2인 PASS 선택==============================
              if (showTwoPlayerPassPrompt && controller != null)
                Positioned(
                  key: const ValueKey('portrait-two-player-pass-slot'),
                  top: layout.handTop,
                  left: 0,
                  right: 0,
                  height: layout.handHeight,
                  child: _TwoPlayerPassPrompt(
                    enabled: controller.canPassLastCardChallenge,
                    onPressed: () =>
                        unawaited(controller.passLastCardChallenge()),
                  ),
                ),
              //=======================빈 손패 대기 문구==============================
              if (waitingMessage != null)
                Positioned.fill(
                  key: const ValueKey('portrait-waiting-message-slot'),
                  child: _CenteredGameMessage(message: waitingMessage),
                ),
              //=======================오류 메시지==============================
              if (controller?.errorMessage != null)
                Positioned(
                  key: const ValueKey('portrait-error-slot'),
                  top: layout.statusTop - 5,
                  left: layout.messagePadding,
                  right: layout.messagePadding,
                  child: _buildErrorMessage(
                    controller!.errorMessage!,
                    onTap: controller.clearError,
                    verticalPadding: 10,
                  ),
                ),
              //=======================게임 시작==============================
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
          );
        },
      ),
    );
  }

  //=======================가로 화면==============================
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
          final controlsWidth = (constraints.maxWidth * 0.27).clamp(
            170.0,
            230.0,
          );
          final sidePadding = (constraints.maxWidth * 0.025).clamp(16.0, 28.0);

          return Stack(
            children: [
              // 가로 화면도 조건부 레이어의 순서 변화가 손패 State를 교체하지
              // 않도록 모든 Positioned를 역할별 key로 분리합니다.
              //=======================배경 화면==============================
              Positioned.fill(
                key: const ValueKey('landscape-background-slot'),
                child: const _PhoneGameBackground(isLandscape: true),
              ),
              if (showHeader)
                Positioned(
                  key: const ValueKey('landscape-header-slot'),
                  top: 12,
                  left: sidePadding,
                  right: sidePadding,
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
                      onTipPressed: _showRules,
                      onOutPressed: () => unawaited(_showExitModal()),
                    ),
                  ),
                ),
              //=======================상태 문구==============================
              if (showHeader &&
                  controller.statusMessage != null &&
                  waitingMessage == null &&
                  !showPenaltyHandOverlay &&
                  !showTwoPlayerPassPrompt)
                Positioned(
                  key: const ValueKey('landscape-status-slot'),
                  top: 72,
                  left: sidePadding,
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
              //=======================손패==============================
              Positioned(
                key: const ValueKey('landscape-hand-slot'),
                top: 72,
                bottom: 8,
                left: sidePadding,
                right: controlsWidth + 24,
                child: RepaintBoundary(
                  child: _buildHand(
                    controller,
                    isLandscape: true,
                    // 손패 영역은 오른쪽 조작부만큼 좁으므로, 최초 덱은
                    // 그 차이만큼 보정해야 실제 화면 정중앙에 표시됩니다.
                    entryCenterOffsetX: controlsWidth / 2 + 4,
                    entryCenterOffsetY: -32,
                    dimmed: showTwoPlayerPassPrompt || showPenaltyHandOverlay,
                  ),
                ),
              ),
              //=======================라이어 판정·벌칙 문구==============================
              if (showPenaltyHandOverlay &&
                  controller.liarVerdictMessage != null)
                Positioned(
                  key: const ValueKey('landscape-penalty-message-slot'),
                  top: 72,
                  bottom: 8,
                  left: sidePadding,
                  right: controlsWidth + 24,
                  child: _PenaltyHandOverlay(
                    message: controller.liarVerdictMessage!,
                    isFalseDeclaration: controller.liarVerdictIsFalse,
                  ),
                ),
              if (showPenaltyHandOverlay &&
                  controller.liarVerdictMessage == null)
                Positioned.fill(
                  key: const ValueKey('landscape-penalty-status-slot'),
                  child: PhonePenaltyStatus(
                    player: controller.penaltyStatusPlayer,
                    result: controller.visiblePenaltyResult,
                  ),
                ),
              //=======================2인 PASS 선택==============================
              if (showTwoPlayerPassPrompt)
                Positioned(
                  key: const ValueKey('landscape-two-player-pass-slot'),
                  top: 72,
                  bottom: 8,
                  left: sidePadding,
                  right: controlsWidth + 24,
                  child: _TwoPlayerPassPrompt(
                    enabled: controller.canPassLastCardChallenge,
                    onPressed: () =>
                        unawaited(controller.passLastCardChallenge()),
                  ),
                ),
              //=======================빈 손패 대기 문구==============================
              if (waitingMessage != null)
                Positioned.fill(
                  key: const ValueKey('landscape-waiting-message-slot'),
                  child: _CenteredGameMessage(message: waitingMessage),
                ),
              //=======================턴 정보·게임 버튼==============================
              if (showControls)
                Positioned(
                  key: const ValueKey('landscape-turn-action-slot'),
                  right: sidePadding,
                  top: 72,
                  bottom: 8,
                  width: controlsWidth,
                  child: Center(
                    child: TurnActionSwitcher(
                      isLandscape: true,
                      showLiarButton: controller.isMyTurn,
                      turnPlayer: turnPlayer,
                      liarButton: _buildGameActionButton(
                        controller,
                        isLandscape: true,
                      ),
                    ),
                  ),
                ),
              //=======================마지막 카드 선택==============================
              if (showControls &&
                  controller.phase == 'lastCardChallenge' &&
                  !showTwoPlayerPassPrompt)
                Positioned(
                  key: const ValueKey('landscape-last-card-slot'),
                  top: 104,
                  right: sidePadding,
                  width: controlsWidth,
                  child: FilledButton(
                    onPressed: controller.canPassLastCardChallenge
                        ? () => unawaited(controller.passLastCardChallenge())
                        : null,
                    style: _lastCardButtonStyle(),
                    child: const Text('라이어 아님 · 새 라운드'),
                  ),
                ),
              //=======================오류 메시지==============================
              if (controller.errorMessage != null)
                Positioned(
                  key: const ValueKey('landscape-error-slot'),
                  top: 76,
                  left: sidePadding,
                  right: sidePadding,
                  child: _buildErrorMessage(
                    controller.errorMessage!,
                    onTap: controller.clearError,
                    verticalPadding: 9,
                  ),
                ),
              //=======================게임 시작==============================
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

  void _showRules() {
    showDialog<void>(
      context: context,
      builder: (_) => const PhoneGameRuleDialog(
        title: "LIAR'S POKER",
        rules:
            '자신의 차례에는 1~3장의 카드를 선택해 제출합니다. 선언은 '
            '진실일 수도, 거짓일 수도 있으며 다음 플레이어는 LIAR를 선언할 '
            '수 있습니다.\n\n카드 공개 결과 선언이 거짓이면 카드를 낸 플레이어가, '
            '선언이 진실이면 LIAR를 외친 플레이어가 벌칙을 진행합니다. '
            '마지막까지 살아남은 플레이어가 승리합니다.',
        surfaceColor: Color(0xFF142119),
        foregroundColor: Colors.white,
      ),
    );
  }

  //=======================가로·세로 공통 손패==============================
  Widget _buildHand(
    PhoneGameController? controller, {
    required bool isLandscape,
    required bool dimmed,
    double entryCenterOffsetX = 0,
    double entryCenterOffsetY = 0,
  }) {
    if (!_hasCompletedGameStart) return const SizedBox.shrink();

    if (controller == null) {
      return _dimHandCards(
        PhoneHandCardStack(
          isLandscape: isLandscape,
          controller: _handCardStackController,
          onRevealCompleted: _showGameControls,
          entryCenterOffsetX: entryCenterOffsetX,
          entryCenterOffsetY: entryCenterOffsetY,
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
    //=======================손패 없음==============================
    if (controller.handCards.isEmpty && !controller.hasRevealedHand) {
      _showControlsAfterFrame();
      if (!controller.isEliminated) return const SizedBox.shrink();
      return _emptyHandMessage();
    }

    return _dimHandCards(
      PhoneHandCardStack(
        key: ValueKey(
          '${isLandscape ? 'landscape' : 'portrait'}-deal-'
          '${controller.handDealVersion}',
        ),
        isLandscape: isLandscape,
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

  //=======================제한 시간 종료==============================
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

  //=======================LIAR·SUBMIT 버튼==============================
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

  //=======================오류 메시지==============================
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

  //=======================마지막 카드 버튼==============================
  ButtonStyle _lastCardButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: const Color(0xFF50675A),
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0x6650675A),
      elevation: 9,
      shadowColor: const Color(0x99000000),
    );
  }

  //=======================손패 없음==============================
  Widget _emptyHandMessage() {
    return const Center(
      child: Text(
        '내 손패 없음',
        style: TextStyle(color: Colors.white70, fontSize: 17),
      ),
    );
  }

  //=======================테이블 카드 자산==============================
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

    final passButton = LiarsPokerPressableAssetButton(
      asset: Assets.games.liarsPoker.images.button.buttonPass,
      // width: isLandscape ? 190 : 255.w,
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

/// 세로 화면의 실제 크기를 기준으로 주요 영역을 비례 배치합니다.
class _PortraitGameLayout {
  const _PortraitGameLayout({
    required this.headerTop,
    required this.timerTop,
    required this.statusTop,
    required this.handTop,
    required this.handHeight,
    required this.actionTop,
    required this.horizontalPadding,
    required this.messagePadding,
    required this.actionHorizontalPadding,
    required this.tableHeight,
    required this.statusFontSize,
  });

  factory _PortraitGameLayout.fromSize(Size size) {
    final height = size.height;
    final width = size.width;
    final headerTop = (height * 0.059).clamp(32.0, 56.0);
    final timerTop = (height * 0.124).clamp(78.0, 112.0);
    final statusTop = (height * 0.19).clamp(122.0, 166.0);
    final handTop = (height * 0.251).clamp(164.0, 218.0);
    final actionHeight = (height * 0.229).clamp(168.0, 205.0);
    final actionBottom = (height * 0.058).clamp(24.0, 52.0);
    final actionTop = math.max(
      handTop + 210,
      height - actionHeight - actionBottom,
    );
    final handBottom = actionTop - (height * 0.025).clamp(14.0, 24.0);
    final handHeight = math.max(210.0, handBottom - handTop);

    return _PortraitGameLayout(
      headerTop: headerTop,
      timerTop: timerTop,
      statusTop: statusTop,
      handTop: handTop,
      handHeight: handHeight,
      actionTop: actionTop,
      horizontalPadding: (width * 0.051).clamp(16.0, 24.0),
      messagePadding: (width * 0.062).clamp(20.0, 30.0),
      actionHorizontalPadding: (width * 0.18).clamp(54.0, 82.0),
      tableHeight: (height * 0.0285).clamp(20.0, 26.0),
      statusFontSize: (width * 0.041).clamp(14.0, 17.0),
    );
  }

  final double headerTop;
  final double timerTop;
  final double statusTop;
  final double handTop;
  final double handHeight;
  final double actionTop;
  final double horizontalPadding;
  final double messagePadding;
  final double actionHorizontalPadding;
  final double tableHeight;
  final double statusFontSize;
}

//=======================가로·세로 공통 배경 위젯==============================
class _PhoneGameBackground extends StatelessWidget {
  const _PhoneGameBackground({required this.isLandscape});

  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    final asset = isLandscape
        ? Assets.games.liarsPoker.images.background.background
        : Assets.games.liarsPoker.images.background.backgroundPhone;

    return asset.image(fit: BoxFit.cover, filterQuality: FilterQuality.high);
  }
}
