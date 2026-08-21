import 'package:flutter/material.dart';
import 'package:project00/platform/home/phone/widgets/phone_profile.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class PhoneHeader extends StatelessWidget {
  final VoidCallback onPressed;
  final String buttonText;

  const PhoneHeader({
    super.key,
    required this.onPressed,
    required this.buttonText,
  });

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
          SizedBox(
            width: 108,
            child: PlatformButton(
              label: buttonText,
              height: 40,
              expand: false,
              onPressed: onPressed,
            ),
          ),
          const SizedBox(width: 8),
          const PhoneProfile(),
        ],
      ),
    );
  }
}
