// [game_screen.dart] 휴대폰에서 보이는 손패, 턴 정보,
// LIAR·FOLD·SUBMIT 버튼과 벌칙 표시를 배치하는 실제 게임 화면 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:game_kit/game_feedback.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:game_liars_poker/game_copy.dart';
import 'package:game_liars_poker/phone/phone_board.dart';
import 'package:game_kit/phone/animations/control_entry_animation.dart';
import 'package:game_kit/game_flow/game_announcement.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/game_flow/leave_failure_notice.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_liars_poker/shared/providers/game_controller.dart';
import 'package:game_liars_poker/phone/widgets/hand_card_stack.dart';
import 'package:game_liars_poker/phone/widgets/liar_accusation.dart';
import 'package:game_liars_poker/phone/widgets/penalty_status.dart';
import 'package:game_liars_poker/phone/widgets/exit_modal.dart';
import 'package:game_liars_poker/phone/widgets/settings_dialog.dart';
import 'package:game_liars_poker/phone/widgets/turn_timer.dart';
import 'package:game_liars_poker/phone/widgets/top_bar.dart';
import 'package:game_liars_poker/phone/widgets/turn_action_switcher.dart';
import 'package:game_liars_poker/shared/widgets/pressable_button.dart';
import 'package:game_kit/widgets/phone_rule_dialog.dart';
import 'package:game_kit/widgets/phone_ripple_dialog.dart';
import 'package:game_kit/widgets/game_announcement_layer.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_liars_poker/game_theme.dart';
import 'package:game_liars_poker/phone/providers/game_stage.dart';

part 'game_screen/landscape_view.dart';
part 'game_screen/penalty_stage_switcher.dart';
part 'game_screen/portrait_view.dart';
part 'game_screen/supporting_view.dart';
// ============================================================

// LiarsPokerPhoneGameScreen
// │
// ├─ ① 생명주기와 조작 상태
// ├─ ② 세로·가로 화면 레이아웃
// ├─ ③ 손패, CALL/FOLD, 턴 타이머와 오류 안내
// └─ ④ 라이어 판정, 벌칙, 폴드 확인 화면

/// 기기 방향에 따라 가로·세로 배치를 전환하는 휴대폰 게임 화면입니다.
///
/// Firebase 구독, 손패 공개 상태, 헤더 진입 상태는 방향이 바뀌어도
/// 하나의 [State]에서 계속 유지합니다.
class LiarsPokerPhoneGameScreen extends StatefulWidget {
  const LiarsPokerPhoneGameScreen({
    super.key,
    this.controller,
    this.provider,
    this.onExitRoom,
    this.showSpectatorTopBar = false,
    required this.flowConfig,
  });

  final LiarsPokerController? controller;
  final GameRoomContext? provider;
  final Future<bool> Function()? onExitRoom;
  final GameFlowConfig<LiarsPokerPhoneStage> flowConfig;

  /// 탈락한 관전자가 판정·벌칙 화면을 보고 있을 때도 상단바를 유지합니다.
  final bool showSpectatorTopBar;

  @override
  State<LiarsPokerPhoneGameScreen> createState() =>
      _LiarsPokerPhoneGameScreenState();
}

class _LiarsPokerPhoneGameScreenState extends State<LiarsPokerPhoneGameScreen>
    with SingleTickerProviderStateMixin {
  bool _isExitModalOpen = false;
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
      duration: LiarsPokerPhoneTiming.phoneControlsEntry,
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
    // 모달을 열기 전에 판정합니다. 가드가 없으면 빠른 두 번 탭에 확인 모달이
    // 두 개 쌓입니다.
    if (_isExitModalOpen) return;
    _isExitModalOpen = true;
    final shouldExit = await PhoneExitModal.show(context, origin: origin);
    _isExitModalOpen = false;
    if (!mounted || shouldExit != true) return;

    // 퇴장에 성공하면 화면 방향 복원과 화면 전환은 라우트를 가진 상위
    // PhoneGame이 처리합니다. 이 화면은 퇴장 도중 관전·배경 화면으로 교체될 수
    // 있어 여기서 pop을 맡으면 홈으로 돌아가지 못하는 경우가 있습니다.
    final left = await widget.onExitRoom?.call() ?? false;
    if (!mounted || left) return;

    showLeaveFailureNotice(context, widget.provider);
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

    final stage = resolveLiarsPokerPhoneStage(
      game: controller,
      gameStartCompleted: _hasCompletedGameStart,
      revealInProgress: _isRevealInProgress,
      showSpectatorTopBar: widget.showSpectatorTopBar,
    );
    final flowStep = widget.flowConfig.stepFor(stage);
    final regions = flowStep.phoneRegions ?? const PhoneGameRegions();
    final showHeader = regions.showTopBar;
    final showControls =
        regions.showActions &&
        !widget.showSpectatorTopBar &&
        (controller == null || controller.handCards.isNotEmpty);
    final announcement = flowStep.buildAnnouncement();

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
        showFoldPrompt: showFoldPrompt,
        showPenaltyHandOverlay: showPenaltyHandOverlay,
        hideHandDuringPenalty: hideHandDuringPenalty,
        announcement: announcement,
        regions: regions,
      );
    }

    return _buildPortraitScreen(
      controller,
      turnPlayer: turnPlayer,
      showHeader: showHeader,
      showControls: showControls,
      showFoldPrompt: showFoldPrompt,
      showPenaltyHandOverlay: showPenaltyHandOverlay,
      hideHandDuringPenalty: hideHandDuringPenalty,
      announcement: announcement,
      regions: regions,
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
        surfaceColor: LiarsPokerColors.spectatorSurface,
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
          flowConfig: widget.flowConfig,
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
        tableCardValue: controller.table,
        onRevealStarted: _markRevealStarted,
        onRevealCompleted: _handleRevealCompleted,
        onCardsSubmitRequested: controller.submitCardIndexes,
        entryCenterOffsetX: entryCenterOffsetX,
        entryCenterOffsetY: entryCenterOffsetY,
        announcementCenterOffset: announcementCenterOffset,
        flowConfig: widget.flowConfig,
      ),
      dimmed: dimmed,
    );
  }

  /// 투명한 손패 영역은 유지하고 실제 카드 픽셀만 어둡게 처리합니다.
  Widget _dimHandCards(Widget child, {required bool dimmed}) {
    const normal = ColorFilter.mode(Colors.transparent, BlendMode.dst);
    const dark = ColorFilter.matrix([
      .34,
      0,
      0,
      0,
      0,
      0,
      .34,
      0,
      0,
      0,
      0,
      0,
      .34,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);

    return ColorFiltered(colorFilter: dimmed ? dark : normal, child: child);
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
  GameImage _tableAsset(String cardValue) {
    return switch (cardValue.toUpperCase()) {
      'A' => Assets.games.liarsPoker.images.table.tableAceWhite.game,
      'Q' => Assets.games.liarsPoker.images.table.tableQueenWhite.game,
      _ => Assets.games.liarsPoker.images.table.tableKingWhite.game,
    };
  }
}
