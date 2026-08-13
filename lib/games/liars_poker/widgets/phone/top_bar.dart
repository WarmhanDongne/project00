import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/animations/phone_control_entry_animation.dart';
import 'package:project00/games/shared/widgets/phone_game_top_bar.dart';
import 'package:project00/gen/assets.gen.dart';

/// Liar's Poker 자산을 공용 휴대폰 상단 바에 연결합니다.
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
    return SharedPhoneGameTopBar(
      isLandscape: isLandscape,
      leading: leadingWidget,
      center: centerWidget,
      bookIcon: Assets.games.liarsPoker.images.icons.iconRole.image(
        fit: BoxFit.contain,
      ),
      outIcon: Assets.games.liarsPoker.images.icons.iconOut.image(
        fit: BoxFit.contain,
      ),
      onBookPressed: onTipPressed ?? onSettingPressed,
      onOutPressed: onOutPressed ?? onSettingPressed,
      itemBuilder: _buildEntry,
    );
  }

  Widget _buildEntry(int index, Widget child) {
    final animation = entryAnimation;
    if (animation == null || isLandscape) return child;

    final begin = switch (index) {
      0 => 0.0,
      1 => 0.0,
      2 => 0.04,
      3 => 0.06,
      _ => 0.12,
    };
    final end = switch (index) {
      0 => 0.76,
      1 => 0.76,
      2 => 0.8,
      3 => 0.84,
      _ => 0.9,
    };

    return PhoneControlEntryAnimation(
      animation: animation,
      style: PhoneControlEntryStyle.header,
      begin: begin,
      end: end,
      child: child,
    );
  }
}
