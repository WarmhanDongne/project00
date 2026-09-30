// [tablet_game_menu_overlay.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 게임 화면에서 반복 사용하는 공통 UI를 구성함
//
// 즉, 같은 표시와 조작 방식을 여러 화면에서 재사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/widgets/tablet_game_side_bar.dart';
// ============================================================

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
