import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/liars_poker/animations/phone_control_entry_animation.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';
import 'package:project00/games/liars_poker/widgets/phone/hand_card_stack_portrait.dart';
import 'package:project00/games/liars_poker/widgets/phone/liar_accusation.dart';
import 'package:project00/games/liars_poker/widgets/phone/top_bar_portrait.dart';
import 'package:project00/gen/assets.gen.dart';

/// Liar's Poker 휴대폰 세로 게임 화면입니다.
///
/// [controller]를 생략하면 기존 UI 확인용 더미 손패로 동작합니다.
class PhoneGamePortrait extends StatefulWidget {
  const PhoneGamePortrait({super.key, this.controller});

  final PhoneGameController? controller;

  @override
  State<PhoneGamePortrait> createState() => _PhoneGamePortraitState();
}

class _PhoneGamePortraitState extends State<PhoneGamePortrait>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlsEntryController;
  bool _wasDealing = false;

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
    widget.controller?.markHandRevealed();
  }

  void _handleRevealCompleted() {
    widget.controller?.markHandRevealed();
    if (mounted) setState(() {});
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

  @override
  void dispose() {
    _controlsEntryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller == null) return _buildGameScreen(null);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _buildGameScreen(controller),
    );
  }

  Widget _buildGameScreen(PhoneGameController? controller) {
    final isDealing = controller?.phase == 'dealing';
    if (isDealing && !_wasDealing) {
      _wasDealing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controlsEntryController.reset();
      });
    } else if (!isDealing) {
      _wasDealing = false;
    }
    final showControls =
        controller == null ||
        (controller.hasRevealedHand &&
            controller.phase != 'dealing' &&
            controller.handCards.isNotEmpty);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Assets.games.liarsPoker.images.background.backgroundPhone
                .image(fit: BoxFit.cover, filterQuality: FilterQuality.high),
          ),
          if (showControls)
            Positioned(
              top: 50.h,
              left: 20.w,
              right: 20.w,
              child: TopBarPortrait(
                entryAnimation: _controlsEntryController,
                leadingWidget: _tableAsset(
                  controller?.table ?? 'K',
                ).image(height: 24.h, filterQuality: FilterQuality.high),
              ),
            ),
          if (controller != null &&
              !controller.isInitialLoading &&
              controller.phase != 'dealing' &&
              controller.handCards.isNotEmpty)
            Positioned(
              top: 112.h,
              left: 24.w,
              right: 24.w,
              child: Text(
                controller.statusMessage,
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
          if (showControls)
            Positioned(
              top: 640.h,
              left: 20.w,
              right: 0,
              child: PhoneControlEntryAnimation(
                animation: _controlsEntryController,
                style: PhoneControlEntryStyle.heavyDrop,
                begin: 0.02,
                end: 1,
                child: LiarAccusation(
                  enabled: controller?.canCallLiar ?? true,
                  onAccuse: controller == null
                      ? null
                      : () => unawaited(controller.callLiar()),
                ),
              ),
            ),
          if (showControls && controller?.phase == 'lastCardChallenge')
            Positioned(
              top: 590.h,
              left: 70.w,
              right: 70.w,
              child: FilledButton(
                onPressed: controller!.canPassLastCardChallenge
                    ? () => unawaited(controller.passLastCardChallenge())
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF50675A),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0x6650675A),
                ),
                child: const Text('라이어 아님 · 새 라운드 진행'),
              ),
            ),
          Positioned(
            top: 212.h,
            left: 0,
            right: 0,
            height: 350.h,
            child: _buildHand(controller),
          ),
          if (controller?.errorMessage != null)
            Positioned(
              top: 155.h,
              left: 24.w,
              right: 24.w,
              child: GestureDetector(
                onTap: controller!.clearError,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xE62B1717),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      controller.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHand(PhoneGameController? controller) {
    if (controller == null) {
      return HandCardStackPortrait(onRevealCompleted: _showGameControls);
    }

    if (controller.isInitialLoading) {
      return const SizedBox.shrink();
    }

    // 손패 데이터가 먼저 도착해도 태블릿의 실제 배분 연출이 끝날 때까지
    // 카드 위→아래 진입 애니메이션을 생성하지 않습니다.
    if (controller.phase == 'dealing') {
      return const SizedBox.shrink();
    }

    if (controller.handCards.isEmpty && !controller.hasRevealedHand) {
      _showControlsAfterFrame();
      if (!controller.isEliminated) return const SizedBox.shrink();
      return Center(
        child: const Text(
          '내 손패 없음',
          style: TextStyle(color: Colors.white70, fontSize: 17),
        ),
      );
    }

    return HandCardStackPortrait(
      key: ValueKey('portrait-deal-${controller.handDealVersion}'),
      cards: controller.handCardAssets,
      enabled: controller.canSelectCards,
      initiallyRevealed: controller.hasRevealedHand,
      onRevealStarted: _markRevealStarted,
      onRevealCompleted: _handleRevealCompleted,
      onCardsSubmitRequested: controller.submitCardIndexes,
    );
  }

  AssetGenImage _tableAsset(String rank) {
    return switch (rank.toUpperCase()) {
      'A' => Assets.games.liarsPoker.images.table.tableAceWhite,
      'Q' => Assets.games.liarsPoker.images.table.tableQueenWhite,
      _ => Assets.games.liarsPoker.images.table.tableKingWhite,
    };
  }
}
