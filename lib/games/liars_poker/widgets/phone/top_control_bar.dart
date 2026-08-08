import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/gen/assets.gen.dart';

class TopControlBar extends StatelessWidget {
  final Widget leadingWidget; // 부모로부터 주입 받을 위젯 선언
  final VoidCallback? onTipPressed; // 팁 버튼 클릭 시 동작 함수
  final VoidCallback? onSettingPressed; // 세팅 버튼 클릭 시 동작 함수

  const TopControlBar({
    super.key,
    required this.leadingWidget,
    this.onTipPressed,
    this.onSettingPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leadingWidget, // 부모로부터 주입 받은 킹, 퀸, 에이스 테이블 표시 이미지
        GestureDetector(
          onTap: () {},
          child: Assets.games.liarsPoker.images.phone.bulb.svg(
            width: 32.w,
            height: 32.h,
          ),
        ),
        SizedBox(width: 10),
        GestureDetector(
          onTap: () {},
          child: Assets.games.liarsPoker.images.phone.setting.svg(
            width: 32.w,
            height: 32.h,
          ),
        ),
      ],
    );
  }
}
