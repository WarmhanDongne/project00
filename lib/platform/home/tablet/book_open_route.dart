// [book_open_route.dart] 는 선반의 책이 열리며 다음 화면으로 들어가는 화면 전환을 구성하는 파일이다.
//
// - [Platform] : 태블릿 로비
// - [Route] : 고른 책 표지가 열리고, 다음 화면이 그 책 자리에서 화면 전체로 커짐
//
// 즉, 게임 준비와 자리 배치 화면 전환을 한 흐름으로 보이게 하기 위해 필요한 파일이다.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

/// 고른 책([origin]) 표지가 왼쪽 축으로 열리고, 그 안에서 다음 화면이 화면
/// 전체로 커지는 전환입니다(로비 연출 5번).
class BookOpenRoute<T> extends PageRouteBuilder<T> {
  BookOpenRoute({
    required this.origin,
    required WidgetBuilder builder,
    this.coverColor = MosiColors.navy,
  }) : super(
         transitionDuration: const Duration(milliseconds: 760),
         reverseTransitionDuration: const Duration(milliseconds: 320),
         pageBuilder: (context, _, _) => builder(context),
       );

  /// 책이 화면에 놓인 자리입니다(전역 좌표).
  final Rect origin;

  /// 열리는 표지 색입니다.
  final Color coverColor;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        final screen = Offset.zero & MediaQuery.sizeOf(context);
        // 0~0.45: 표지가 열림 / 0.3~1: 다음 화면이 책 자리에서 화면 전체로.
        final open = Curves.easeInOutCubic.transform((t / 0.45).clamp(0, 1));
        final grow = Curves.easeInOutCubic.transform(
          ((t - 0.3) / 0.7).clamp(0, 1),
        );
        final rect = Rect.lerp(origin, screen, grow)!;
        return Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8 * (1 - grow)),
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: screen.width,
                  maxWidth: screen.width,
                  minHeight: screen.height,
                  maxHeight: screen.height,
                  child: Transform.translate(
                    offset: -rect.topLeft,
                    child: Opacity(
                      opacity: (t / 0.3).clamp(0, 1),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
            if (open < 1)
              Positioned.fromRect(
                rect: origin,
                child: IgnorePointer(
                  child: Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(-open * math.pi * 0.55),
                    child: Opacity(
                      opacity: 1 - open * 0.6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: coverColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: MosiColors.ink, width: 3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
