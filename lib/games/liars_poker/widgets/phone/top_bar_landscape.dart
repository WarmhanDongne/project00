import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';

class TopBarLandscape extends StatelessWidget {
  final VoidCallback? onTipPressed;
  final VoidCallback? onSettingPressed;

  const TopBarLandscape({super.key, this.onTipPressed, this.onSettingPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 왼쪽: KING'S TABLE 로고
        Assets.games.liarsPoker.images.phone.kingTable.image(
          height: 35, // 디자인 비율에 맞게 높이 고정
          filterQuality: FilterQuality.high,
        ),

        // 중앙: 빈 공간 (추후 이곳에 타이머 위젯이 들어갈 수 있습니다)
        const Spacer(),

        // 오른쪽: 팁(전구) 및 설정 아이콘
        GestureDetector(
          onTap: onTipPressed,
          behavior: HitTestBehavior.opaque,
          child: Assets.games.liarsPoker.images.phone.bulb.image(
            width: 45, // 가로 모드 공간에 맞게 조절
            height: 45,
          ),
        ),
        const SizedBox(width: 15), // 아이콘 사이 간격
        GestureDetector(
          onTap: onSettingPressed,
          behavior: HitTestBehavior.opaque,
          child: Assets.games.liarsPoker.images.phone.setting.image(
            width: 32,
            height: 32,
          ),
        ),
      ],
    );
  }
}
