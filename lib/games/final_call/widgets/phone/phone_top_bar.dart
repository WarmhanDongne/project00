import 'package:flutter/material.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_controller.dart';
import 'package:project00/games/final_call/widgets/final_call_timer.dart';
import 'package:project00/games/shared/widgets/phone_game_top_bar.dart';
import 'package:project00/gen/assets.gen.dart';

class FinalCallPhoneTopBar extends StatelessWidget {
  const FinalCallPhoneTopBar({
    super.key,
    required this.controller,
    required this.onOutPressed,
    required this.onBookPressed,
    required this.isLandscape,
  });

  final PhoneGameController controller;
  final VoidCallback onOutPressed;
  final VoidCallback onBookPressed;
  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    final me = controller.players[controller.uid];
    final timerVisible =
        controller.turnDeadlineAt != null &&
        controller.isMyTurn &&
        controller.status == 'playing' &&
        controller.phase != 'roundResult' &&
        controller.phase != 'dealing';

    return Stack(
      alignment: Alignment.center,
      children: [
        SharedPhoneGameTopBar(
          isLandscape: isLandscape,
          trailingLeading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < (me?.lives ?? 0); index++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Assets.games.finalCall.images.icons.iconHeart.image(
                    width: isLandscape ? 18 : 20,
                  ),
                ),
            ],
          ),
          bookIcon: Assets.games.finalCall.images.icons.iconRole.image(
            fit: BoxFit.contain,
          ),
          outIcon: Assets.games.finalCall.images.icons.iconOut.image(
            fit: BoxFit.contain,
          ),
          onBookPressed: onBookPressed,
          onOutPressed: onOutPressed,
        ),
        //=======================내 턴 타이머==============================
        if (timerVisible)
          Transform.translate(
            offset: const Offset(62, 0),
            child: FinalCallTimer(
              key: ValueKey(controller.turnDeadlineAt),
              deadline: controller.turnDeadlineAt!,
            ),
          ),
      ],
    );
  }
}
