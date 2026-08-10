import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';
import 'package:project00/games/liars_poker/widgets/phone/hand_card_stack_landscape.dart';
import 'package:project00/games/liars_poker/widgets/phone/liar_accusation_landscape.dart';
import 'package:project00/games/liars_poker/widgets/phone/top_bar_landscape.dart';
import 'package:project00/games/liars_poker/widgets/phone/phone_settings_dialog.dart';
import 'package:project00/games/liars_poker/widgets/phone/phone_timer.dart';
import 'package:project00/games/liars_poker/widgets/phone/turn_action_switcher.dart';
import 'package:project00/gen/assets.gen.dart';

/// Realtime Database 상태와 Cloud Function 명령을 사용하는 가로 게임 화면입니다.
class PhoneGameLandscape extends StatefulWidget {
  const PhoneGameLandscape({super.key, required this.controller});

  final PhoneGameController controller;

  @override
  State<PhoneGameLandscape> createState() => _PhoneGameLandscapeState();
}

class _PhoneGameLandscapeState extends State<PhoneGameLandscape> {
  void _markRevealStarted() {
    widget.controller.markHandRevealed();
  }

  void _handleRevealCompleted() {
    widget.controller.markHandRevealed();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final turnPlayer = controller.players[controller.turnUid];
        final showControls =
            controller.hasRevealedHand &&
            controller.phase != 'dealing' &&
            controller.handCards.isNotEmpty;

        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final controlsWidth = constraints.maxWidth < 720 ? 180.0 : 220.0;
              return Stack(
                children: [
                  //==================================배경화면==================================
                  Positioned.fill(
                    child: Assets.games.liarsPoker.images.background.background
                        .image(
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                  ),
                  if (showControls)
                    Positioned(
                      top: 12,
                      left: 28,
                      right: 28,
                      child: SafeArea(
                        bottom: false,
                        child: TopBarLandscape(
                          leadingWidget: _tableAsset(controller.table).image(
                            height: 30,
                            filterQuality: FilterQuality.high,
                          ),
                          centerWidget: controller.turnDeadlineAt != null &&
                                  controller.phase != 'dealing' &&
                                  controller.isMyTurn
                              ? PhoneTimer(
                                  expiresAt: controller.turnDeadlineAt!,
                                  onTimeout: () {
                                    if (controller.isMyTurn) {
                                      if (controller.canCallLiar) {
                                        unawaited(controller.callLiar());
                                      } else {
                                        unawaited(
                                          controller.submitCardIndexes([0]),
                                        );
                                      }
                                    }
                                  },
                                )
                              : null,
                          onSettingPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const PhoneSettingsDialog(),
                            );
                          },
                        ),
                      ),
                    ),                  //==================================문구==================================
                  if (showControls && controller.statusMessage != null)
                    Positioned(
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
                    top: 72,
                    bottom: 8,
                    left: 16,
                    right: controlsWidth + 24,
                    child: _buildHand(
                      controller,
                      // 손패 영역은 오른쪽 조작부만큼 좁으므로, 최초 덱은
                      // 그 차이만큼 보정해야 실제 화면 정중앙에 표시됩니다.
                      entryCenterOffsetX: controlsWidth / 2 + 4,
                      entryCenterOffsetY: -32,
                    ),
                  ),
                  //=================================라이어 버튼=================================
                  if (showControls)
                    Positioned(
                      right: 50,
                      bottom: 110,
                      width: controlsWidth,
                      child: TurnActionSwitcher(
                        isRow:true,
                        showLiarButton: controller.isMyTurn,
                        turnPlayer: turnPlayer,
                        height: 140,
                        alignment: Alignment.bottomCenter,
                        profileSize: 72,
                        nicknameFontSize: 22,
                        spacing: 8,
                        liarButton: LiarAccusationLandscape(
                          enabled: controller.canCallLiar,
                          onAccuse: () => unawaited(controller.callLiar()),
                        ),
                      ),
                    ),
                  //==================================한쪽이 카드 나 냈을때==================================
                  if (showControls && controller.phase == 'lastCardChallenge')
                    Positioned(
                      top: 104,
                      right: 18,
                      width: controlsWidth,
                      child: FilledButton(
                        onPressed: controller.canPassLastCardChallenge
                            ? () =>
                                  unawaited(controller.passLastCardChallenge())
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF50675A),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0x6650675A),
                        ),
                        child: const Text('라이어 아님 · 새 라운드'),
                      ),
                    ),
                  //==================================오류 메시지==================================
                  if (controller.errorMessage != null)
                    Positioned(
                      top: 76,
                      left: 28,
                      right: 28,
                      child: GestureDetector(
                        onTap: controller.clearError,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xE62B1717),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
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
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHand(
    PhoneGameController controller, {
    required double entryCenterOffsetX,
    required double entryCenterOffsetY,
  }) {
    if (controller.isInitialLoading || controller.phase == 'dealing') {
      return const SizedBox.shrink();
    }
    //==================================손패 없을때==================================
    if (controller.handCards.isEmpty && !controller.hasRevealedHand) {
      return controller.isEliminated
          ? const Center(
              child: Text(
                '내 손패 없음',
                style: TextStyle(color: Colors.white70, fontSize: 17),
              ),
            )
          : const SizedBox.shrink();
    }

    //==================================손패==================================
    return HandCardStackLandscape(
      key: ValueKey('landscape-deal-${controller.handDealVersion}'),
      cards: controller.handCardAssets,
      enabled: controller.canSelectCards,
      submissionEnabled: controller.canSubmitCards,
      initiallyRevealed: controller.hasRevealedHand,
      onRevealStarted: _markRevealStarted,
      onRevealCompleted: _handleRevealCompleted,
      onCardsSubmitRequested: controller.submitCardIndexes,
      entryCenterOffsetX: entryCenterOffsetX,
      entryCenterOffsetY: entryCenterOffsetY,
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
