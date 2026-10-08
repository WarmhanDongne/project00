import 'package:flutter/material.dart';
import 'package:game_holdem/game_copy.dart';
import 'package:game_holdem/game_theme.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_kit/phone/widgets/game_top_bar.dart';
import 'package:game_kit/phone/widgets/rule_dialog.dart';
import 'package:game_kit/phone/widgets/ripple_dialog.dart';

/// 휴대폰 상단의 게임 이름과 규칙·나가기 버튼입니다.
class HoldemPhoneTopBar extends StatelessWidget {
  const HoldemPhoneTopBar({
    super.key,
    required this.game,
    required this.onExit,
  });
  final HoldemGameState game;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 14, 0),
      child: SharedPhoneGameTopBar(
        isLandscape: false,
        leading: Text(
          "HOLD'EM",
          style: HoldemFonts.title(
            shadows: const [
              Shadow(color: Color(0x59000000), offset: Offset(0, 2)),
            ],
          ),
        ),
        bookIcon: const Icon(
          Icons.menu_book_rounded,
          size: 40,
          color: HoldemColors.ivory,
        ),
        outIcon: const Icon(
          Icons.exit_to_app_rounded,
          size: 32,
          color: HoldemColors.ivory,
        ),
        onBookPressed: () => showHoldemRules(context),
        onBookPressedAt: (origin) => showHoldemRules(context, origin),
        onOutPressed: onExit,
      ),
    );
  }
}

void showHoldemRules(BuildContext context, [Offset? origin]) {
  final screenSize = MediaQuery.sizeOf(context);
  showPhoneRippleDialog<void>(
    context: context,
    origin: origin ?? Offset(screenSize.width - 82, 28),
    builder: (_) => const PhoneGameRuleDialog(
      title: 'TEXAS HOLD’EM',
      rules: HoldemCopy.phoneRules,
      surfaceColor: HoldemColors.sheet,
      foregroundColor: HoldemColors.ivory,
      dismissOnAnyTap: true,
    ),
  );
}
