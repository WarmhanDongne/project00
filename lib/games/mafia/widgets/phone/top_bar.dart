import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/mafia_copy.dart';
import 'package:project00/games/shared/widgets/phone_game_top_bar.dart';
import 'package:project00/games/shared/widgets/phone_rule_dialog.dart';
import 'package:project00/games/shared/widgets/phone_ripple_dialog.dart';
import 'package:project00/gen/assets.gen.dart';

/// 상단바가 차지하는 높이입니다(위 여백 4 + 바 50).
///
/// 상단바는 공용 셸이 화면 위에 겹쳐 그리므로, 게임 화면은 이 높이를 비워 두어야
/// 시안 좌표가 밀리지 않습니다.
const double mafiaPhoneTopBarHeight = 54;

/// 마피아 휴대폰 상단바입니다.
///
/// 시안은 룰(책)과 나가기 두 개만 둡니다. 표시 시점과 등장 연출은 공용 셸이
/// 제어하고 이 위젯은 내용만 그립니다.
class MafiaPhoneTopBar extends StatelessWidget {
  const MafiaPhoneTopBar({
    super.key,
    required this.onExitRoom,
    required this.onRulesPressed,
  });

  final VoidCallback onExitRoom;
  final ValueChanged<Offset?> onRulesPressed;

  @override
  Widget build(BuildContext context) {
    final icons = Assets.games.mafia.images.icons;
    return Padding(
      // 시안 기준 tip left 295 / out left 343 → 오른쪽 정렬로 같은 자리에 옵니다.
      padding: const EdgeInsets.fromLTRB(18, 4, 14, 0),
      child: SharedPhoneGameTopBar(
        isLandscape: false,
        bookIcon: icons.iconTipBook.game.image(fit: BoxFit.contain),
        outIcon: icons.iconOut.game.image(fit: BoxFit.contain),
        onOutPressed: onExitRoom,
        onBookPressed: () => onRulesPressed(null),
        onBookPressedAt: onRulesPressed,
        bookSemanticLabel: '게임 규칙 열기',
        outSemanticLabel: '게임 나가기',
      ),
    );
  }
}

/// 룰 다이얼로그를 엽니다. 상단바 책 버튼이 부릅니다.
///
/// 배경이 밝은 시안이라 파이널콜과 달리 흰 바탕 + 검은 글자를 씁니다.
void showMafiaRules(BuildContext context, [Offset? origin]) {
  final screenSize = MediaQuery.sizeOf(context);
  showPhoneRippleDialog<void>(
    context: context,
    origin: origin ?? Offset(screenSize.width - 82, 28),
    builder: (_) => const PhoneGameRuleDialog(
      title: '마피아',
      rules: MafiaCopy.phoneRules,
      surfaceColor: Color(0xFFECEBEB),
      foregroundColor: Color(0xFF212730),
      dismissOnAnyTap: true,
    ),
  );
}
