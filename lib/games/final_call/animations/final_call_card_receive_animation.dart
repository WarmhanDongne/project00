import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';
import 'package:project00/games/shared/animations/phone_card_receive_animation.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/core/assets/game_image.dart';

/// Liar's Poker와 같은 진입 → 탭 → 좌우 회전 → 펼침 순서를 사용합니다.
class FinalCallPhoneCardReceiveAnimation extends StatelessWidget {
  const FinalCallPhoneCardReceiveAnimation({
    super.key,
    required this.cards,
    required this.isLandscape,
    required this.onRevealStarted,
    required this.onCompleted,
  });

  final List<FinalCallCard> cards;
  final bool isLandscape;
  final VoidCallback onRevealStarted;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 펼침 완료 프레임과 실제 게임 손패의 크기·중심·간격을 동일하게
        // 계산해 화면 전환 순간 카드가 다시 이동하는 현상을 막습니다.
        final contentHeight = isLandscape
            ? math.max(1.0, constraints.maxHeight - 52)
            : constraints.maxHeight;
        final handWidth = isLandscape
            ? math.max(1.0, constraints.maxWidth * 8 / 11 - 28)
            : constraints.maxWidth;
        final maxByWidth = math.max(1.0, (handWidth - 48) / 4);
        final maxByHeight = math.max(
          1.0,
          (contentHeight - 78) / finalCallCardHeightRatio,
        );
        final controlSafeWidth = isLandscape
            ? math.max(1.0, (contentHeight - 112) / finalCallCardHeightRatio)
            : 92.0;
        final cardWidth = math.min(
          isLandscape ? 138.0 : 92.0,
          math.min(maxByWidth, math.min(maxByHeight, controlSafeWidth)),
        );
        final targetOffsetX = isLandscape
            ? -(constraints.maxWidth * 3 / 22)
            : 0.0;
        final targetOffsetY = isLandscape ? 26.0 : 0.0;
        return PhoneCardReceiveAnimation(
          frontCardAssets: cards
              .map(finalCallCardAsset)
              .toList(growable: false),
          backCardAsset: Assets.games.finalCall.images.cards.cardBack.game,
          cardWidth: cardWidth,
          spreadStepX: isLandscape ? cardWidth + 14 : 30,
          spreadStepY: isLandscape ? 0 : 30,
          spreadToLeft: isLandscape,
          spreadCenterOffsetX: targetOffsetX,
          spreadCenterOffsetY: targetOffsetY,
          totalDuration: const Duration(milliseconds: 2300),
          onRevealStarted: onRevealStarted,
          onCompleted: onCompleted,
        );
      },
    );
  }
}
