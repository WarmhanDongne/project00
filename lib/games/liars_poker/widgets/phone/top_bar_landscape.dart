import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';

class TopBarLandscape extends StatelessWidget {
  final Widget? leadingWidget;
  final Widget? centerWidget;
  final VoidCallback? onTipPressed;
  final VoidCallback? onOutPressed;

  const TopBarLandscape({
    super.key,
    this.leadingWidget,
    this.centerWidget,
    this.onTipPressed,
    this.onOutPressed, required Null Function() onSettingPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 왼쪽: KING'S TABLE 로고
        leadingWidget ??
            Assets.games.liarsPoker.images.table.tableKingWhite.image(
              height: 30,
              filterQuality: FilterQuality.high,
            ),

        // 중앙: 타이머 위젯 등
        Expanded(
          child: centerWidget != null
              ? Center(child: centerWidget)
              : const SizedBox(),
        ),

        // 오른쪽: 팁(전구) 및 설정 아이콘
        GestureDetector(
          onTap: onTipPressed,
          behavior: HitTestBehavior.opaque,
          child: Assets.games.liarsPoker.images.icons.iconTip.image(
            width: 45, // 가로 모드 공간에 맞게 조절
            height: 45,
          ),
        ),
        const SizedBox(width: 15), // 아이콘 사이 간격
        GestureDetector(
          onTap: onOutPressed,
          behavior: HitTestBehavior.opaque,
          child: Assets.games.liarsPoker.images.icons.iconOut.image(
            width: 32,
            height: 32,
          ),
        ),
      ],
    );
  }
}
