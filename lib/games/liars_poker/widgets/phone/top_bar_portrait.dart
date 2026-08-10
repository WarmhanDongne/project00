import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/liars_poker/animations/phone_control_entry_animation.dart';
import 'package:project00/gen/assets.gen.dart';

class TopBarPortrait extends StatelessWidget {
  const TopBarPortrait({
    super.key,
    required this.leadingWidget,
    this.entryAnimation,
    this.onTipPressed,
    this.onOutPressed, required Null Function() onSettingPressed,
  });

  final Widget leadingWidget;
  final Animation<double>? entryAnimation;
  final VoidCallback? onTipPressed;
  final VoidCallback? onOutPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildEntry(
          begin: 0,
          end: 0.76,
          child: SizedBox(width: 240.w, height: 50.h, child: leadingWidget),
        ),
        const Spacer(),
        _buildEntry(
          begin: 0.06,
          end: 0.84,
          child: GestureDetector(
            onTap: onTipPressed,
            child: Assets.games.liarsPoker.images.icons.iconTip.image(
              width: 40.w,
              height: 40.h,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        _buildEntry(
          begin: 0.12,
          end: 0.9,
          child: GestureDetector(
            onTap: onOutPressed,
            child: Assets.games.liarsPoker.images.icons.iconOut.image(
              width: 32.w,
              height: 32.h,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntry({
    required double begin,
    required double end,
    required Widget child,
  }) {
    final animation = entryAnimation;
    if (animation == null) return child;

    return PhoneControlEntryAnimation(
      animation: animation,
      style: PhoneControlEntryStyle.header,
      begin: begin,
      end: end,
      child: child,
    );
  }
}
