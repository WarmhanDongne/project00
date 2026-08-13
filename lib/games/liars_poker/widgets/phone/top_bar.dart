import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/liars_poker/animations/phone_control_entry_animation.dart';
import 'package:project00/gen/assets.gen.dart';

/// 화면 방향에 따라 크기와 간격을 조절하는 휴대폰 게임 상단 바입니다.
class PhoneGameTopBar extends StatelessWidget {
  const PhoneGameTopBar({
    super.key,
    required this.isLandscape,
    required this.onSettingPressed,
    this.leadingWidget,
    this.centerWidget,
    this.entryAnimation,
    this.onTipPressed,
    this.onOutPressed,
  });

  final bool isLandscape;
  final Widget? leadingWidget;
  final Widget? centerWidget;
  final Animation<double>? entryAnimation;
  final VoidCallback? onTipPressed;
  final VoidCallback? onOutPressed;
  final VoidCallback onSettingPressed;

  @override
  Widget build(BuildContext context) {
    return isLandscape ? _buildLandscape() : _buildPortrait();
  }

  //==================================세로==================================
  Widget _buildPortrait() {
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
            onTap: onOutPressed ?? onSettingPressed,
            child: Assets.games.liarsPoker.images.icons.iconOut.image(
              width: 32.w,
              height: 32.h,
            ),
          ),
        ),
      ],
    );
  }

  //==================================가로==================================
  Widget _buildLandscape() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 왼쪽: 현재 테이블 카드
        leadingWidget ??
            Assets.games.liarsPoker.images.table.tableKingWhite.image(
              height: 30,
              filterQuality: FilterQuality.high,
            ),

        // 중앙: 현재 턴 플레이어의 타이머
        Expanded(
          child: centerWidget != null
              ? Center(child: centerWidget)
              : const SizedBox(),
        ),

        // 오른쪽: 팁 및 나가기 아이콘
        GestureDetector(
          onTap: onTipPressed,
          behavior: HitTestBehavior.opaque,
          child: Assets.games.liarsPoker.images.icons.iconTip.image(
            width: 45,
            height: 45,
          ),
        ),
        const SizedBox(width: 15),
        GestureDetector(
          onTap: onOutPressed ?? onSettingPressed,
          behavior: HitTestBehavior.opaque,
          child: Assets.games.liarsPoker.images.icons.iconOut.image(
            width: 32,
            height: 32,
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
