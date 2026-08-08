import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/gen/assets.gen.dart';

class TopControlBar extends StatelessWidget {
  const TopControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
          child: Assets.games.liarsPoker.images.phone.settings.svg(
            width: 32.w,
            height: 32.h,
          ),
        ),
      ],
    );
  }
}
