import 'package:flutter/material.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';
import 'package:project00/games/liars_poker/animations/phone_card_receive_animation.dart';
import 'package:project00/gen/assets.gen.dart';

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
    return PhoneCardReceiveAnimation(
      frontCardAssets: cards.map(finalCallCardAsset).toList(growable: false),
      backCardAsset: Assets.games.finalCall.images.cards.cardBack,
      cardWidth: isLandscape ? 108 : 104,
      spreadStepX: isLandscape ? 92 : 30,
      spreadStepY: isLandscape ? 0 : 30,
      spreadToLeft: isLandscape,
      totalDuration: const Duration(milliseconds: 2100),
      onRevealStarted: onRevealStarted,
      onCompleted: onCompleted,
    );
  }
}
