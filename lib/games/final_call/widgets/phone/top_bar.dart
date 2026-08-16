import 'package:flutter/material.dart';
import 'package:project00/games/final_call/controllers/final_call_controller.dart';
import 'package:project00/games/shared/widgets/phone_game_top_bar.dart';
import 'package:project00/games/shared/widgets/phone_rule_dialog.dart';
import 'package:project00/games/shared/widgets/phone_ripple_dialog.dart';
import 'package:project00/gen/assets.gen.dart';

/// 상단바가 차지하는 높이입니다(위 여백 4 + 바 48).
///
/// 상단바는 공용 셸이 화면 위에 겹쳐 그리므로, 게임 화면은 같은 높이를 비워
/// 두어야 카드·조작부 위치가 달라지지 않습니다.
const double finalCallPhoneTopBarHeight = 52;

/// Final Call 휴대폰 상단바입니다.
///
/// 표시 시점과 등장 연출은 공용 셸이 제어하고, 이 위젯은 내용만 그립니다.
class FinalCallPhoneTopBar extends StatelessWidget {
  const FinalCallPhoneTopBar({
    super.key,
    required this.controller,
    required this.onExitRoom,
    required this.onRulesPressed,
  });

  final FinalCallController controller;
  final VoidCallback onExitRoom;
  final ValueChanged<Offset?> onRulesPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 16, 0),
      child: SharedPhoneGameTopBar(
        isLandscape: true,
        trailingLeading: _buildLives(),
        bookIcon: Assets.games.finalCall.images.icons.iconTipBlack.image(
          fit: BoxFit.contain,
        ),
        outIcon: Assets.games.finalCall.images.icons.iconOut.image(
          fit: BoxFit.contain,
        ),
        onOutPressed: onExitRoom,
        onBookPressed: () => onRulesPressed(null),
        onBookPressedAt: onRulesPressed,
      ),
    );
  }

  Widget _buildLives() {
    final lives = controller.players[controller.uid]?.lives ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < lives; index++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Assets.games.finalCall.images.icons.iconHeart.image(
              width: 38,
              fit: BoxFit.contain,
            ),
          ),
      ],
    );
  }
}

/// Final Call 규칙 다이얼로그를 엽니다.
void showFinalCallRules(BuildContext context, [Offset? origin]) {
  final screenSize = MediaQuery.sizeOf(context);
  showPhoneRippleDialog<void>(
    context: context,
    origin: origin ?? Offset(screenSize.width - 82, 28),
    builder: (_) => const PhoneGameRuleDialog(
      title: 'FINAL CALL',
      rules:
          '같은 숫자 카드의 합과 같은 색 카드의 합 중 더 높은 값이 '
          '최종 점수입니다. 자신의 턴에는 공개 카드 또는 카드 더미에서 '
          '한 장을 가져와 손패와 교체하거나 버릴 수 있습니다.\n\n'
          'CALL을 선언하면 나머지 플레이어가 마지막 교체를 한 번 진행합니다. '
          '가장 낮은 점수의 플레이어는 생명 1개를 잃고, CALL을 선언한 '
          '플레이어가 최하위라면 생명 2개를 잃습니다. 마지막 생존자가 승리합니다.',
      surfaceColor: Color.fromARGB(255, 0, 0, 0),
      foregroundColor: Color.fromARGB(255, 255, 255, 255),
      showSurface: false,
      dismissOnAnyTap: true,
    ),
  );
}
