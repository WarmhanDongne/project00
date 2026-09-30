// [card_receive_animation.dart] 는 파이널콜에서 사용하는 화면 전환과 게임 연출의 진행 시간을 관리하는 파일이다.
//
// - [Package] : 파이널콜
// - [Animation] : 화면 전환과 게임 연출의 진행 시간을 관리함
//
// 즉, 같은 연출을 예측 가능한 순서와 속도로 재생하기 위해 필요한 파일이다.

import 'package:game_final_call/phone/phone_board.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/widgets/card_view.dart';
import 'package:game_kit/phone/animations/card_receive_animation.dart';
import 'package:game_final_call/gen/assets.gen.dart';
import 'package:game_final_call/game_assets.dart';
// ============================================================

/// Liar's Poker와 같은 진입 → 탭 → 좌우 회전 → 펼침 순서를 사용합니다.
class FinalCallCardReceiveAnimation extends StatelessWidget {
  const FinalCallCardReceiveAnimation({
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
        return CardReceiveAnimation(
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
          totalDuration: FinalCallPhoneTiming.cardReceive,
          onRevealStarted: onRevealStarted,
          onCompleted: onCompleted,
        );
      },
    );
  }
}
