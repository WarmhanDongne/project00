import 'dart:async';
import 'package:project00/games/shared/game_feedback.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/liars_poker/liars_poker_copy.dart';
import 'package:project00/games/liars_poker/liars_poker_flow_config.dart';
import 'package:project00/games/shared/animations/phone_control_entry_animation.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/liars_poker/controllers/liars_poker_controller.dart';
import 'package:project00/games/liars_poker/widgets/phone/hand_card_stack.dart';
import 'package:project00/games/liars_poker/widgets/phone/liar_accusation.dart';
import 'package:project00/games/liars_poker/widgets/phone/penalty_status.dart';
import 'package:project00/games/liars_poker/widgets/phone/exit_modal.dart';
import 'package:project00/games/liars_poker/widgets/phone/settings_dialog.dart';
import 'package:project00/games/liars_poker/widgets/phone/turn_timer.dart';
import 'package:project00/games/liars_poker/widgets/phone/top_bar.dart';
import 'package:project00/games/liars_poker/widgets/phone/turn_action_switcher.dart';
import 'package:project00/games/liars_poker/widgets/pressable_asset_button.dart';
import 'package:project00/games/shared/widgets/phone_rule_dialog.dart';
import 'package:project00/games/shared/widgets/phone_ripple_dialog.dart';
import 'package:project00/games/shared/widgets/game_announcement_layer.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/core/assets/game_image.dart';

/// 기기 방향에 따라 가로·세로 배치를 전환하는 휴대폰 게임 화면입니다.
///
/// Firebase 구독, 손패 공개 상태, 헤더 진입 상태는 방향이 바뀌어도
/// 하나의 [State]에서 계속 유지합니다.
class LiarsPokerPhoneGameScreen extends StatefulWidget {
  const LiarsPokerPhoneGameScreen({
    super.key,
    this.controller,
    this.onExitRoom,
    this.showSpectatorTopBar = false,
  });

  final LiarsPokerController? controller;
  final Future<bool> Function()? onExitRoom;

  /// 탈락한 관전자가 판정·벌칙 화면을 보고 있을 때도 상단바를 유지합니다.
  final bool showSpectatorTopBar;

  @override
  State<LiarsPokerPhoneGameScreen> createState() =>
      _LiarsPokerPhoneGameScreenState();
}

class _LiarsPokerPhoneGameScreenState extends State<LiarsPokerPhoneGameScreen>
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
      duration: LiarsPokerFlowTiming.phoneControlsEntry,
    );
    if (widget.showSpectatorTopBar ||
        widget.controller?.hasRevealedHand == true) {
      _controlsEntryController.value = 1;
    }
  }

  @override
  void didUpdateWidget(LiarsPokerPhoneGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.showSpectatorTopBar && widget.showSpectatorTopBar) {
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

  GameAnnouncement? _resolveAnnouncement(
    LiarsPokerController? controller, {
    required bool showGameStart,
    required bool showStatusMessage,
    required String? waitingMessage,
    required bool showPenaltyHandOverlay,
  }) {
    // ========================================================================
    // 단계별 공용 안내 문구
    // ========================================================================
    // 이 함수는 문자열과 표시시간만 정하며 서버 상태를 변경하지 않습니다.
    // GameAnnouncementLayer는 모든 포인터를 하위 UI로 통과시키고, 실제 입력
    // 제한은 해당 단계에서 조작 위젯을 숨기거나 비활성화해 처리합니다.
    if (showGameStart) return const GameAnnouncement.gameStart();

    final verdict = controller?.liarVerdictMessage;
    if (showPenaltyHandOverlay && verdict != null) {
      return GameAnnouncement.transient(
        id: 'verdict-${controller?.lastPlayId}-$verdict',
        text: verdict,
        tone: LiarsPokerCopy.verdictTone(verdict),
        duration: LiarsPokerFlowTiming.phoneVerdictAnnouncement,
        blocksInteraction: true,
      );
    }

    if (waitingMessage != null) {
      return GameAnnouncement.transient(
        id: 'waiting-${controller?.round}-${controller?.lastPlayId}-$waitingMessage',
        text: waitingMessage,
      );
    }

    final statusMessage = controller?.statusMessage;
    if (showStatusMessage && statusMessage != null) {
      return GameAnnouncement.persistent(
        id: 'status-${controller?.phase}-$statusMessage',
        text: statusMessage,
      );
    }

    return null;
  }

  GameAnnouncementStyle _announcementStyle(
    GameAnnouncement? announcement, {
    required bool isLandscape,
    double? statusFontSize,
    bool isMyTurn = false,
  }) {
    if (announcement?.kind == GameAnnouncementKind.persistent) {
      return GameAnnouncementStyle(
        fontFamily: null,
        fontSize: statusFontSize ?? (isLandscape ? 15 : 17),
        gameStartFontSize: 58,
        fontWeight: isMyTurn ? FontWeight.w700 : FontWeight.w500,
        height: 1.2,
        letterSpacing: 0,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
      );
    }

    if (announcement?.tone != GameAnnouncementTone.neutral) {
      return GameAnnouncementStyle(
        fontSize: isLandscape ? 34 : 32.sp,
        gameStartFontSize: 58,
        height: 1.15,
        letterSpacing: 0.7,
        shadows: const [Shadow(color: Colors.black, blurRadius: 14)],
        beginScale: 0.96,
        endScale: 0.96,
      );
    }

    return GameAnnouncementStyle(
      fontSize: isLandscape ? 31 : 30.sp,
      gameStartFontSize: 58,
      height: 1.18,
      letterSpacing: 0.5,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 12)],
    );
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

  void _precacheInitialHand(LiarsPokerController? controller) {
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

  Future<void> _showExitModal({Offset? origin}) async {
    final shouldExit = await PhoneExitModal.show(context, origin: origin);
    if (!mounted || shouldExit != true) return;

    // 퇴장에 성공하면 화면 방향 복원과 화면 전환은 라우트를 가진 상위
    // PhoneGame이 처리합니다. 이 화면은 퇴장 도중 관전·배경 화면으로 교체될 수
    // 있어 여기서 pop을 맡으면 홈으로 돌아가지 못하는 경우가 있습니다.
    final left = await widget.onExitRoom?.call() ?? false;
    if (!mounted || left) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(GameFlowCopy.leaveFailed)));
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

  Widget _buildGameScreen(LiarsPokerController? controller) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final turnPlayer = controller?.players[controller.turnUid];
    final waitingMessage = controller?.emptyHandWaitingMessage;
    final showFoldPrompt = controller?.showFoldPrompt ?? false;
    final showPenaltyHandOverlay = controller?.showPenaltyHandOverlay ?? false;
    // 허위 선언 판정 문구를 보여주는 동안에는 기존 요청대로 손패를
    // 어둡게 유지하고, 실제 벌칙 진행 및 결과 표시 단계에서는 숨깁니다.
    final hideHandDuringPenalty =
        showPenaltyHandOverlay &&
        controller?.liarVerdictMessage == null &&
        controller?.isLiarVerdictPending != true;
    final isGameStartReady =
        controller == null ||
        (!controller.isInitialLoading &&
            controller.phase != 'dealing' &&
            controller.handCards.isNotEmpty);
    final showGameStart =
        !widget.showSpectatorTopBar &&
        !_hasCompletedGameStart &&
        isGameStartReady;
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
        widget.showSpectatorTopBar ||
        (_hasCompletedGameStart &&
            (controller == null ||
                (controller.hasRevealedHand &&
                    controller.phase != 'dealing' &&
                    !_isRevealInProgress)));
    final showControls =
        !widget.showSpectatorTopBar &&
        showHeader &&
        (controller == null || controller.handCards.isNotEmpty);

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
        showFoldPrompt: showFoldPrompt,
        showPenaltyHandOverlay: showPenaltyHandOverlay,
        hideHandDuringPenalty: hideHandDuringPenalty,
        showGameStart: showGameStart,
      );
    }

    return _buildPortraitScreen(
      controller,
      turnPlayer: turnPlayer,
      showHeader: showHeader,
      showControls: showControls,
      waitingMessage: waitingMessage,
      showFoldPrompt: showFoldPrompt,
      showPenaltyHandOverlay: showPenaltyHandOverlay,
      hideHandDuringPenalty: hideHandDuringPenalty,
      showGameStart: showGameStart,
    );
  }

  // ============================================================================
  // 세로 화면 배치
  // ============================================================================
  Widget _buildPortraitScreen(
    LiarsPokerController? controller, {
    required PhoneGamePlayer? turnPlayer,
    required bool showHeader,
    required bool showControls,
    required String? waitingMessage,
    required bool showFoldPrompt,
    required bool showPenaltyHandOverlay,
    required bool hideHandDuringPenalty,
    required bool showGameStart,
  }) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _PortraitGameLayout.fromSize(
            Size(constraints.maxWidth, constraints.maxHeight),
            bottomSafeArea: MediaQuery.paddingOf(context).bottom,
          );
          final showStatusMessage =
              controller != null &&
              !controller.isInitialLoading &&
              controller.phase != 'dealing' &&
              controller.handCards.isNotEmpty &&
              waitingMessage == null &&
              !showPenaltyHandOverlay &&
              !showFoldPrompt;
          final announcement = _resolveAnnouncement(
            controller,
            showGameStart: showGameStart,
            showStatusMessage: showStatusMessage,
            waitingMessage: waitingMessage,
            showPenaltyHandOverlay: showPenaltyHandOverlay,
          );
          final isPersistent =
              announcement?.kind == GameAnnouncementKind.persistent;

          return Stack(
            children: [
              // 조건부 레이어가 추가·삭제되어도 손패 State가 다른 Positioned로
              // 재사용되지 않도록 모든 레이어에 역할별 고유 key를 유지합니다.
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
                    onTipPressedAt: _showRules,
                    onOutPressedAt: (origin) =>
                        unawaited(_showExitModal(origin: origin)),
                  ),
                ),
              // 서버 deadline을 표시할 뿐 로컬에서 턴 결과를 판정하지 않습니다.
              if (showHeader &&
                  !widget.showSpectatorTopBar &&
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
              // 서버 권한 상태에 따라 LIAR/SUBMIT 조작을 활성화합니다.
              if (showControls)
                Positioned(
                  key: const ValueKey('portrait-turn-action-slot'),
                  top: layout.actionTop,
                  left: layout.horizontalPadding,
                  right: 0,
                  child: TurnActionSwitcher(
                    isLandscape: false,
                    portraitControlHeight: layout.actionHeight,
                    showLiarButton: controller?.isMyTurn ?? true,
                    turnPlayer: turnPlayer,
                    liarButton: _buildGameActionButton(
                      controller,
                      isLandscape: false,
                      portraitHeight: layout.actionHeight,
                    ),
                  ),
                ),
              // dealing에서는 ROUND/Table 안내 뒤 손패 공개 연출을 실행합니다.
              if (!hideHandDuringPenalty)
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
                      // 손패 영역은 화면 정중앙보다 조금 위에 있으므로 그만큼
                      // 내려 ROUND·기준 카드 문구를 화면 가운데에 놓습니다.
                      announcementCenterOffset: Offset(
                        0,
                        layout.announcementCenterOffsetY,
                      ),
                      dimmed: showFoldPrompt || showPenaltyHandOverlay,
                    ),
                  ),
                ),
              // LIAR 판정 문구와 벌칙 결과는 같은 중앙 슬롯에서 전환합니다.
              if (showPenaltyHandOverlay && controller != null)
                Positioned.fill(
                  key: const ValueKey('portrait-penalty-stage-slot'),
                  child: _PenaltyStageSwitcher(
                    verdictMessage: controller.liarVerdictMessage,
                    verdictPending: controller.isLiarVerdictPending,
                    player: controller.penaltyStatusPlayer,
                    result: controller.visiblePenaltyResult,
                  ),
                ),
              // 잔여카드 보유 생존자가 정확히 한 명일 때만 손패를 잠그고
              // LIAR/FOLD를 표시합니다. 단순한 "마지막 미제출자"가 아닙니다.
              if (showFoldPrompt && controller != null)
                Positioned(
                  key: const ValueKey('portrait-two-player-pass-slot'),
                  top: layout.handTop,
                  left: 0,
                  right: 0,
                  height: layout.handHeight,
                  child: _FoldPrompt(
                    enabled: controller.canFoldLastCardChallenge,
                    onPressed: () =>
                        unawaited(controller.foldLastCardChallenge()),
                  ),
                ),
              // 문구 레이어는 포인터를 가로채지 않으며 같은 슬롯을 유지합니다.
              Positioned.fill(
                key: const ValueKey('portrait-announcement-slot'),
                child: GameAnnouncementLayer(
                  announcement: announcement,
                  alignment: isPersistent
                      ? Alignment.topCenter
                      : Alignment.center,
                  padding: isPersistent
                      ? EdgeInsets.fromLTRB(
                          layout.messagePadding,
                          layout.statusTop,
                          layout.messagePadding,
                          0,
                        )
                      : const EdgeInsets.symmetric(horizontal: 32),
                  style: _announcementStyle(
                    announcement,
                    isLandscape: false,
                    statusFontSize: layout.statusFontSize,
                    isMyTurn: controller?.isMyTurn ?? false,
                  ),
                  onCompleted: (completed) {
                    if (completed.kind == GameAnnouncementKind.gameStart) {
                      _handleGameStartCompleted();
                    }
                  },
                ),
              ),
              // 명령을 3회 재시도한 뒤에도 실패한 경우에만 오류를 표시합니다.
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
            ],
          );
        },
      ),
    );
  }

  // ============================================================================
  // 가로 화면 배치
  // ============================================================================
  Widget _buildLandscapeScreen(
    LiarsPokerController controller, {
    required PhoneGamePlayer? turnPlayer,
    required bool showHeader,
    required bool showControls,
    required String? waitingMessage,
    required bool showFoldPrompt,
    required bool showPenaltyHandOverlay,
    required bool hideHandDuringPenalty,
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
          final showStatusMessage =
              showHeader &&
              controller.statusMessage != null &&
              waitingMessage == null &&
              !showPenaltyHandOverlay &&
              !showFoldPrompt;
          final announcement = _resolveAnnouncement(
            controller,
            showGameStart: showGameStart,
            showStatusMessage: showStatusMessage,
            waitingMessage: waitingMessage,
            showPenaltyHandOverlay: showPenaltyHandOverlay,
          );
          final isPersistent =
              announcement?.kind == GameAnnouncementKind.persistent;

          return Stack(
            children: [
              // 가로 화면도 조건부 레이어의 순서 변화가 손패 State를 교체하지
              // 않도록 모든 Positioned를 역할별 key로 분리합니다.
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
                          !widget.showSpectatorTopBar &&
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
                      onTipPressedAt: _showRules,
                      onOutPressedAt: (origin) =>
                          unawaited(_showExitModal(origin: origin)),
                    ),
                  ),
                ),
              // 방향 전환 전과 동일한 손패 State와 공개 완료값을 유지합니다.
              if (!hideHandDuringPenalty)
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
                      // 가로 손패 영역(top 72 / bottom 8)의 중앙은 화면 중앙보다
                      // 32 아래이므로, 덱과 같은 보정값이 문구에도 맞습니다.
                      announcementCenterOffset: Offset(
                        controlsWidth / 2 + 4,
                        -32,
                      ),
                      dimmed: showFoldPrompt || showPenaltyHandOverlay,
                    ),
                  ),
                ),
              // LIAR 판정 문구와 벌칙 결과는 같은 중앙 슬롯에서 전환합니다.
              if (showPenaltyHandOverlay)
                Positioned.fill(
                  key: const ValueKey('landscape-penalty-stage-slot'),
                  child: _PenaltyStageSwitcher(
                    verdictMessage: controller.liarVerdictMessage,
                    verdictPending: controller.isLiarVerdictPending,
                    player: controller.penaltyStatusPlayer,
                    result: controller.visiblePenaltyResult,
                  ),
                ),
              // 잔여카드 보유 생존자가 정확히 한 명일 때만 제출을 잠급니다.
              if (showFoldPrompt)
                Positioned(
                  key: const ValueKey('landscape-two-player-pass-slot'),
                  top: 72,
                  bottom: 8,
                  left: sidePadding,
                  right: controlsWidth + 24,
                  child: _FoldPrompt(
                    enabled: controller.canFoldLastCardChallenge,
                    onPressed: () =>
                        unawaited(controller.foldLastCardChallenge()),
                  ),
                ),
              // 서버 권한 상태에 따라 LIAR/SUBMIT 조작을 활성화합니다.
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
              // 문구 레이어는 포인터를 가로채지 않으며 같은 슬롯을 유지합니다.
              Positioned.fill(
                key: const ValueKey('landscape-announcement-slot'),
                child: GameAnnouncementLayer(
                  announcement: announcement,
                  alignment: Alignment.center,
                  padding: isPersistent
                      ? EdgeInsets.fromLTRB(
                          sidePadding,
                          72,
                          controlsWidth + 24,
                          8,
                        )
                      : const EdgeInsets.symmetric(horizontal: 32),
                  offset: Offset.zero,
                  style: _announcementStyle(
                    announcement,
                    isLandscape: true,
                    statusFontSize: 15,
                    isMyTurn: controller.isMyTurn,
                  ),
                  onCompleted: (completed) {
                    if (completed.kind == GameAnnouncementKind.gameStart) {
                      _handleGameStartCompleted();
                    }
                  },
                ),
              ),
              // 명령을 3회 재시도한 뒤에도 실패한 경우에만 오류를 표시합니다.
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
            ],
          );
        },
      ),
    );
  }

  void _showRules([Offset? origin]) {
    final screenSize = MediaQuery.sizeOf(context);
    showPhoneRippleDialog<void>(
      context: context,
      origin: origin ?? Offset(screenSize.width - 82, 28),
      builder: (_) => const PhoneGameRuleDialog(
        title: "LIAR'S POKER",
        rules: LiarsPokerCopy.phoneRules,
        surfaceColor: Color(0xFF142119),
        foregroundColor: Colors.white,
        showSurface: false,
        dismissOnAnyTap: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 가로·세로 공통 손패
  // ---------------------------------------------------------------------------
  Widget _buildHand(
    LiarsPokerController? controller, {
    required bool isLandscape,
    required bool dimmed,
    double entryCenterOffsetX = 0,
    double entryCenterOffsetY = 0,
    Offset announcementCenterOffset = Offset.zero,
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
          announcementCenterOffset: announcementCenterOffset,
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
    // 손패가 아직 없거나 모두 소진된 동안에는 빈 상태 문구를 표시합니다.
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
        roundNumber: controller.round,
        tableRank: controller.table,
        onRevealStarted: _markRevealStarted,
        onRevealCompleted: _handleRevealCompleted,
        onCardsSubmitRequested: controller.submitCardIndexes,
        entryCenterOffsetX: entryCenterOffsetX,
        entryCenterOffsetY: entryCenterOffsetY,
        announcementCenterOffset: announcementCenterOffset,
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

  // ---------------------------------------------------------------------------
  // 제한 시간 종료
  // ---------------------------------------------------------------------------
  void _handleTurnTimeout(LiarsPokerController controller) {
    if (!controller.isMyTurn || controller.phase == 'penalty') return;

    // 잔여카드를 가진 마지막 1인이 응답하지 않으면 상대를 의심하지 않고
    // FOLD 처리해 새 라운드로 진행합니다.
    if (controller.showFoldPrompt && controller.canFoldLastCardChallenge) {
      unawaited(controller.foldLastCardChallenge());
      return;
    }

    if (controller.canCallLiar) {
      unawaited(controller.callLiar());
      return;
    }
    unawaited(controller.submitCardIndexes([0]));
  }

  // ---------------------------------------------------------------------------
  // LIAR·SUBMIT 버튼
  // ---------------------------------------------------------------------------
  Widget _buildGameActionButton(
    LiarsPokerController? controller, {
    required bool isLandscape,
    double? portraitHeight,
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
          portraitHeight: portraitHeight,
          showSubmit: showSubmit,
          enabled: enabled,
          onAccuse: controller == null
              ? null
              : () {
                  // 판을 뒤집는 선언이므로 강한 진동으로 확정감을 줍니다.
                  GameFeedback.declare();
                  unawaited(controller.callLiar());
                },
          onSubmit: () {
            // 되돌릴 수 없는 확정 동작이므로 진동으로 알립니다.
            GameFeedback.commit();
            unawaited(_handCardStackController.submitSelectedCards());
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 재시도 후에도 실패한 명령 오류
  // ---------------------------------------------------------------------------
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

  // 손패가 없을 때 가로·세로에서 공통으로 사용하는 문구입니다.
  Widget _emptyHandMessage() {
    return const Center(
      child: Text(
        LiarsPokerCopy.noCards,
        style: TextStyle(color: Colors.white70, fontSize: 17),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 테이블 카드 자산
  // ---------------------------------------------------------------------------
  GameImage _tableAsset(String rank) {
    return switch (rank.toUpperCase()) {
      'A' => Assets.games.liarsPoker.images.table.tableAceWhite.game,
      'Q' => Assets.games.liarsPoker.images.table.tableQueenWhite.game,
      _ => Assets.games.liarsPoker.images.table.tableKingWhite.game,
    };
  }
}

/// 허위 선언 판정에서 벌칙 진행 화면으로 전환합니다.
///
/// 판정 문구와 벌칙 프로필 모두 화면 중앙에서 페이드·미세 확대 애니메이션으로
/// 등장하며, 오른쪽에서 밀려오는 이동은 사용하지 않습니다.
class _PenaltyStageSwitcher extends StatefulWidget {
  const _PenaltyStageSwitcher({
    required this.verdictMessage,
    required this.verdictPending,
    required this.player,
    required this.result,
  });

  final String? verdictMessage;
  final bool verdictPending;
  final PhoneGamePlayer? player;
  final String? result;

  String get stageId => verdictPending
      ? 'verdict-pending'
      : verdictMessage == null
      ? 'penalty-status'
      : 'verdict-$verdictMessage';

  Widget buildStage() {
    if (verdictPending) {
      return const SizedBox.expand(key: ValueKey('verdict-pending'));
    }
    final message = verdictMessage;
    return message != null
        ? SizedBox.expand(key: ValueKey('verdict-$message'))
        : PhonePenaltyStatus(
            key: const ValueKey('penalty-status'),
            player: player,
            result: result,
          );
  }

  @override
  State<_PenaltyStageSwitcher> createState() => _PenaltyStageSwitcherState();
}

class _PenaltyStageSwitcherState extends State<_PenaltyStageSwitcher>
    with SingleTickerProviderStateMixin {
  static const _transitionDuration =
      LiarsPokerFlowTiming.phonePenaltyStageSwitch;

  late final AnimationController _controller;
  late String _displayedStageId;
  late Widget _displayedStage;
  String? _pendingStageId;
  Widget? _pendingStage;
  bool _hasSwappedStage = true;

  @override
  void initState() {
    super.initState();
    _displayedStageId = widget.stageId;
    _displayedStage = widget.buildStage();
    _controller =
        AnimationController(
            vsync: this,
            duration: _transitionDuration,
            value: 1,
          )
          ..addListener(_handleAnimationProgress)
          ..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(_PenaltyStageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextStageId = widget.stageId;
    final nextStage = widget.buildStage();

    if (_controller.isAnimating) {
      if (nextStageId == _pendingStageId) {
        _pendingStage = nextStage;
        if (_hasSwappedStage) _displayedStage = nextStage;
      } else if (nextStageId == _displayedStageId) {
        _displayedStage = nextStage;
      }
      return;
    }

    if (nextStageId == _displayedStageId) {
      _displayedStage = nextStage;
      return;
    }

    _pendingStageId = nextStageId;
    _pendingStage = nextStage;
    _hasSwappedStage = false;
    _controller.forward(from: 0);
  }

  void _handleAnimationProgress() {
    if (_hasSwappedStage || _controller.value < 0.5) return;

    final pendingStageId = _pendingStageId;
    final pendingStage = _pendingStage;
    if (pendingStageId == null || pendingStage == null || !mounted) return;

    setState(() {
      _displayedStageId = pendingStageId;
      _displayedStage = pendingStage;
      _hasSwappedStage = true;
    });
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _pendingStageId = null;
    _pendingStage = null;
    _hasSwappedStage = true;
  }

  @override
  void dispose() {
    _controller.removeListener(_handleAnimationProgress);
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travelDistance = constraints.maxWidth;

          return AnimatedBuilder(
            animation: _controller,
            child: _displayedStage,
            builder: (context, child) {
              final value = _controller.value;
              final isExitingVerdict =
                  value < 0.5 && _displayedStageId.startsWith('verdict-');
              if (isExitingVerdict) {
                final exitProgress = Curves.easeInCubic.transform(value * 2);
                return Opacity(
                  opacity: 1 - exitProgress,
                  child: Transform.scale(
                    scale: 1 - (0.04 * exitProgress),
                    child: child,
                  ),
                );
              }

              final isCenteredEntry =
                  value >= 0.5 &&
                  (_displayedStageId == 'penalty-status' ||
                      _displayedStageId.startsWith('verdict-'));
              if (isCenteredEntry) return child ?? const SizedBox();

              final offsetX = value < 0.5
                  ? -travelDistance * Curves.easeInCubic.transform(value * 2)
                  : travelDistance *
                        (1 - Curves.easeOutCubic.transform((value - 0.5) * 2));

              return Transform.translate(
                offset: Offset(offsetX, 0),
                child: child,
              );
            },
          );
        },
      ),
    );
  }
}

/// 잔여카드를 가진 마지막 플레이어의 손패를 잠그고 FOLD 선택을 표시합니다.
class _FoldPrompt extends StatelessWidget {
  const _FoldPrompt({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final foldButton = LiarsPokerPressableAssetButton(
      asset: Assets.games.liarsPoker.images.button.buttonFold.game,
      // width: isLandscape ? 190 : 255.w,
      width: isLandscape ? 190 : 255.w,
      enabled: enabled,
      semanticsLabel: 'FOLD하고 패널티 진행',
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
              foldButton,
              SizedBox(height: isLandscape ? 8 : 12.h),
              Text(
                'FOLD를 선택하면 내가 패널티를 진행합니다.\n'
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
    required this.actionHeight,
    required this.horizontalPadding,
    required this.messagePadding,
    required this.actionHorizontalPadding,
    required this.tableHeight,
    required this.statusFontSize,
    required this.height,
  });

  factory _PortraitGameLayout.fromSize(
    Size size, {
    required double bottomSafeArea,
  }) {
    final height = size.height;
    final width = size.width;
    final headerTop = (height * 0.059).clamp(32.0, 56.0);
    final timerTop = (height * 0.124).clamp(78.0, 112.0);
    final statusTop = (height * 0.19).clamp(122.0, 166.0);
    final handTop = (height * 0.251).clamp(164.0, 218.0);
    // 화면 실제 높이를 기준으로 버튼·턴 정보·배치 영역이 같은 높이를
    // 사용합니다. ScreenUtil 높이와 LayoutBuilder 높이를 섞으면 작은 기기에서
    // 1~수 px 차이로 RenderFlex overflow가 발생할 수 있습니다.
    final actionHeight = (height * 0.225).clamp(140.0, 193.0);
    final actionBottom = math.max(
      bottomSafeArea + 4,
      (height * 0.045).clamp(18.0, 42.0),
    );
    final preferredActionTop = math.max(
      handTop + (height * 0.245).clamp(190.0, 210.0),
      height - actionHeight - actionBottom,
    );
    // 부동소수점 반올림과 하단 시스템 영역까지 고려해 안전 여백을 둡니다.
    final actionTop = math.min(
      preferredActionTop,
      math.max(handTop, height - actionHeight - actionBottom),
    );
    final handBottom = actionTop - (height * 0.025).clamp(14.0, 24.0);
    // 작은 화면에서 최소 높이를 강제하지 않습니다. 손패 위젯이 주어진 공간에
    // 맞춰 카드 크기와 간격을 자체 축소하므로 영역끼리 겹치지 않습니다.
    final handHeight = math.max(1.0, handBottom - handTop);

    return _PortraitGameLayout(
      headerTop: headerTop,
      timerTop: timerTop,
      statusTop: statusTop,
      handTop: handTop,
      handHeight: handHeight,
      actionTop: actionTop,
      actionHeight: actionHeight,
      horizontalPadding: (width * 0.051).clamp(16.0, 24.0),
      messagePadding: (width * 0.062).clamp(20.0, 30.0),
      actionHorizontalPadding: (width * 0.18).clamp(54.0, 82.0),
      tableHeight: (height * 0.0285).clamp(20.0, 26.0),
      statusFontSize: (width * 0.041).clamp(14.0, 17.0),
      height: height,
    );
  }

  final double headerTop;
  final double timerTop;
  final double statusTop;
  final double handTop;
  final double handHeight;
  final double actionTop;
  final double actionHeight;
  final double horizontalPadding;
  final double messagePadding;
  final double actionHorizontalPadding;
  final double tableHeight;
  final double statusFontSize;

  /// 배치 계산에 사용한 화면 높이입니다.
  final double height;

  /// 손패 영역 기준 중앙을 화면 정중앙으로 옮기는 세로 보정값입니다.
  ///
  /// 손패 영역은 상단 정보와 하단 조작부 사이에 있어 화면 정중앙보다 조금
  /// 위에 놓입니다. 그만큼 내려 주어야 안내 문구가 정확히 화면 가운데 뜹니다.
  double get announcementCenterOffsetY =>
      height / 2 - (handTop + handHeight / 2);
}

// ============================================================================
// 가로·세로 공통 배경 위젯
// ============================================================================
class _PhoneGameBackground extends StatelessWidget {
  const _PhoneGameBackground({required this.isLandscape});

  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    final asset = isLandscape
        ? Assets.games.liarsPoker.images.background.background.game
        : Assets.games.liarsPoker.images.background.backgroundPhone.game;

    return asset.image(fit: BoxFit.cover, filterQuality: FilterQuality.high);
  }
}
