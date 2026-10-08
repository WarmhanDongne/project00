import 'package:flutter/material.dart';

/// 머리줄·방 패널을 움직이지 않고 왼쪽 로비 요소만 화면 바깥으로 퇴장시킵니다.
class TabletLobbyContentTransition extends StatelessWidget {
  const TabletLobbyContentTransition({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: child.key == const ValueKey('lobby-shelf')
              ? const Offset(-0.18, 0)
              : const Offset(0.14, 0),
          end: Offset.zero,
        ).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [
          for (final child in previous)
            ExcludeFocus(
              child: ExcludeSemantics(child: IgnorePointer(child: child)),
            ),
          ?current,
        ],
      ),
      child: child,
    ),
  );
}
