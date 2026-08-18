import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 모든 태블릿에서 13:9 기준 디자인 비율을 유지하는 게임 모달 프레임입니다.
class TabletGameModalFrame extends StatelessWidget {
  const TabletGameModalFrame({super.key, required this.child});

  static const Size designSize = Size(1300, 900);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaSize.width;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mediaSize.height;
        final scale = math.min(
          math.min(
            (availableWidth * 0.9) / designSize.width,
            (availableHeight * 0.88) / designSize.height,
          ),
          1.0,
        );

        return SizedBox(
          width: designSize.width * scale,
          height: designSize.height * scale,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Container(
              width: designSize.width,
              height: designSize.height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 36,
                    spreadRadius: 3,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class TabletGameDialogButton extends StatelessWidget {
  const TabletGameDialogButton({
    super.key,
    required this.text,
    required this.color,
    this.onPressed,
  });

  final String text;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(270, 70),
        backgroundColor: color,
        elevation: 12,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
      ),
    );
  }
}
