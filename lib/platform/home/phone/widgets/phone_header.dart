import 'package:flutter/material.dart';
import 'package:project00/platform/home/phone/widgets/phone_profile.dart';
import 'package:project00/platform/theme/platform_theme.dart';

class PhoneHeader extends StatelessWidget {
  const PhoneHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Text(
            '모시겜',
            style: TextStyle(
              color: colors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          // 그룹 참여 버튼은 화면 하단 고정 바(PhoneHome)로 옮겼습니다.
          const PhoneProfile(),
        ],
      ),
    );
  }
}
