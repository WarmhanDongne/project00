import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/widgets/phone/hand_card_stack_portrait.dart';
import 'package:project00/gen/assets.gen.dart';

/// 가로 화면용 손패입니다.
///
/// 세로 화면과 같은 선택·다중 선택·드래그 제출 로직을 공유하고,
/// 카드만 수평으로 배치합니다. 오른쪽 카드가 마지막에 그려져 가장 위에 보입니다.
class HandCardStackLandscape extends StatelessWidget {
  const HandCardStackLandscape({
    super.key,
    this.cards,
    this.enabled = true,
    this.submissionEnabled = true,
    this.maxSelection = 3,
    this.initiallyRevealed = false,
    this.onRevealStarted,
    this.onRevealCompleted,
    this.onCardsSubmitRequested,
    this.entryCenterOffsetX = 0,
    this.entryCenterOffsetY = 0,
  });

  final List<AssetGenImage>? cards;
  final bool enabled;
  final bool submissionEnabled;
  final int maxSelection;
  final bool initiallyRevealed;
  final VoidCallback? onRevealStarted;
  final VoidCallback? onRevealCompleted;
  final Future<bool> Function(List<int> indexes)? onCardsSubmitRequested;
  final double entryCenterOffsetX;
  final double entryCenterOffsetY;

  @override
  Widget build(BuildContext context) {
    return HandCardStackPortrait(
      cards: cards,
      enabled: enabled,
      submissionEnabled: submissionEnabled,
      maxSelection: maxSelection,
      initiallyRevealed: initiallyRevealed,
      cardWidth: 140, //카드크기
      spreadStepX: 110, //카드 펼친 정도
      spreadStepY: 0,
      rightCardOnTop: true,
      spreadToLeft: true,
      entryCenterOffsetX: entryCenterOffsetX,
      entryCenterOffsetY: entryCenterOffsetY,
      onRevealStarted: onRevealStarted,
      onRevealCompleted: onRevealCompleted,
      onCardsSubmitRequested: onCardsSubmitRequested,
    );
  }
}
