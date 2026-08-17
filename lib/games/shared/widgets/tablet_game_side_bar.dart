import 'package:flutter/material.dart';

/// 태블릿 게임에서 공통으로 사용하는 우측 상단 룰북·설정 메뉴입니다.
///
/// 사이드바는 배치와 모달 동작만 담당하고, 게임별 아이콘과 모달 내용은
/// 각 게임의 오버레이에서 전달합니다.
class TabletGameSideBar extends StatelessWidget {
  const TabletGameSideBar({
    super.key,
    required this.roleIcon,
    required this.settingIcon,
    required this.roleDialogBuilder,
    required this.settingDialogBuilder,
    this.iconSize = 100,
    this.spacing = 0,
    this.dialogAlignment = const Alignment(0, 0.7),
    this.animateEntry = true,
  });

  final Widget roleIcon;
  final Widget settingIcon;
  final WidgetBuilder roleDialogBuilder;
  final WidgetBuilder settingDialogBuilder;
  final double iconSize;
  final double spacing;
  final Alignment dialogAlignment;
  final bool animateEntry;

  Future<void> _showGameDialog(BuildContext context, WidgetBuilder builder) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Align(
        alignment: dialogAlignment,
        child: Material(
          color: Colors.transparent,
          child: builder(dialogContext),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        //=======================룰북 버튼==============================
        _SideBarButton(
          label: '게임 규칙 열기',
          size: iconSize,
          icon: roleIcon,
          onPressed: () => _showGameDialog(context, roleDialogBuilder),
        ),
        SizedBox(width: spacing),
        //=======================설정 버튼==============================
        _SideBarButton(
          label: '게임 설정 열기',
          size: iconSize,
          icon: settingIcon,
          onPressed: () => _showGameDialog(context, settingDialogBuilder),
        ),
      ],
    );

    if (!animateEntry) return content;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 980),
      curve: Curves.easeOutCubic,
      child: content,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.78 + (0.22 * value),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }
}

class _SideBarButton extends StatelessWidget {
  const _SideBarButton({
    required this.label,
    required this.size,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final double size;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: size, height: size),
        iconSize: size,
        icon: SizedBox.square(dimension: size, child: icon),
      ),
    );
  }
}
