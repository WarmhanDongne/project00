import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/tablet_game_side_bar.dart';

/// 태블릿 게임의 룰북·설정 사이드바 위치와 안전 영역을 통일합니다.
class TabletGameMenuOverlay extends StatelessWidget {
  const TabletGameMenuOverlay({
    super.key,
    required this.visible,
    required this.roleIcon,
    required this.settingIcon,
    required this.roleDialogBuilder,
    required this.settingDialogBuilder,
  });

  final bool visible;
  final Widget roleIcon;
  final Widget settingIcon;
  final WidgetBuilder roleDialogBuilder;
  final WidgetBuilder settingDialogBuilder;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.expand();
    final inset = (MediaQuery.sizeOf(context).shortestSide * 0.025).clamp(
      16.0,
      24.0,
    );
    return SizedBox.expand(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: TabletGameSideBar(
              roleIcon: roleIcon,
              settingIcon: settingIcon,
              roleDialogBuilder: roleDialogBuilder,
              settingDialogBuilder: settingDialogBuilder,
            ),
          ),
        ),
      ),
    );
  }
}
