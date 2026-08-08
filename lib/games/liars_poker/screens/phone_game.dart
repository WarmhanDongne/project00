import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/liars_poker/animations/phone_control_entry_animation.dart';
import 'package:project00/games/liars_poker/widgets/phone/hand_card_stack.dart';
import 'package:project00/games/liars_poker/widgets/phone/liar_accusation.dart';
import 'package:project00/games/liars_poker/widgets/phone/top_bar.dart';
import 'package:project00/gen/assets.gen.dart';

class PhoneGame extends StatefulWidget {
  const PhoneGame({super.key});

  @override
  State<PhoneGame> createState() => _PhoneGameState();
}

class _PhoneGameState extends State<PhoneGame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlsEntryController;

  @override
  void initState() {
    super.initState();
    _controlsEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
  }

  void _showGameControls() {
    if (_controlsEntryController.isAnimating ||
        _controlsEntryController.isCompleted) {
      return;
    }
    _controlsEntryController.forward();
  }

  @override
  void dispose() {
    _controlsEntryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Assets.games.liarsPoker.images.background.background.image(
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            top: 50.h,
            left: 20.w,
            right: 20.w,
            child: TopBar(
              entryAnimation: _controlsEntryController,
              leadingWidget: Assets.games.liarsPoker.images.table.tableKingWhite
                  .image(height: 24.h, filterQuality: FilterQuality.high),
            ),
          ),
          Positioned(
            top: 640.h,
            left: 20.w,
            right: 0.w,
            child: PhoneControlEntryAnimation(
              animation: _controlsEntryController,
              style: PhoneControlEntryStyle.heavyDrop,
              begin: 0.02,
              end: 1,
              child: const LiarAccusation(),
            ),
          ),
          Positioned(
            top: 212.h,
            left: 0,
            right: 0,
            height: 350.h,
            child: HandCardStack(
              onRevealCompleted: _showGameControls,
              onSelectionChanged: (indexes) {
                debugPrint('선택된 카드 인덱스: $indexes');
              },
              onCardsSubmitted: (indexes) {
                // 실제 게임에서는 인덱스에 대응하는 cardId를
                // LiarsPokerCommandService.submitCards에 전달합니다.
                debugPrint('제출한 카드 인덱스: $indexes');
              },
            ),
          ),
        ],
      ),
    );
  }
}
