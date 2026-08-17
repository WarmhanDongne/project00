import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/phone_game_top_bar.dart';
import 'package:project00/games/shared/widgets/phone_ripple_dialog.dart';
import 'package:project00/games/shared/widgets/phone_rule_dialog.dart';
import 'package:project00/gen/assets.gen.dart';

class MafiaPhoneTopBar extends StatelessWidget {
  const MafiaPhoneTopBar({super.key, required this.isMorning});

  final bool isMorning;

  @override
  Widget build(BuildContext context) {
    final icons = Assets.games.mafia.images.icons;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: SharedPhoneGameTopBar(
          isLandscape:
              MediaQuery.orientationOf(context) == Orientation.landscape,
          bookIcon: icons.tip.image(fit: BoxFit.contain),
          outIcon: (isMorning ? icons.settingBlack : icons.settingWhite).image(
            fit: BoxFit.contain,
          ),
          outSemanticLabel: '게임 설정 열기',
          onBookPressed: () => _showRules(context),
          onBookPressedAt: (origin) => _showRules(context, origin),
          onOutPressed: () {},
        ),
      ),
    );
  }

  void _showRules(BuildContext context, [Offset? origin]) {
    final size = MediaQuery.sizeOf(context);
    showPhoneRippleDialog<void>(
      context: context,
      origin: origin ?? Offset(size.width - 82, 28),
      builder: (_) => PhoneGameRuleDialog(
        title: 'MAFIA',
        rules:
            '밤에는 각 역할에 맞는 능력을 사용하고, 낮에는 토론과 투표로 '
            '마피아를 찾아냅니다. 시민 팀은 모든 마피아를 제거하면 승리하고, '
            '마피아 팀은 생존 마피아 수가 시민 수 이상이 되면 승리합니다.',
        surfaceColor: isMorning ? Colors.white : const Color(0xFF171421),
        foregroundColor: isMorning ? Colors.black : Colors.white,
        showSurface: false,
        dismissOnAnyTap: true,
      ),
    );
  }
}
