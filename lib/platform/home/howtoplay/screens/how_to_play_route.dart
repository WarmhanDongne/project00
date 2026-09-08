import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/platform/home/howtoplay/screens/how_to_play_screen.dart';
import 'package:project00/platform/theme/platform_theme.dart';

//=======================아이콘에서 펼쳐지는 화면 전환==============================
// 홈에서 누른 아이콘 자리에서 원이 커지며 안내 화면이 화면 전체를 덮습니다.
// 눌린 아이콘과 열린 화면이 같은 것이라는 느낌을 주기 위한 연출입니다.

/// [origin]은 화면 전체 기준(global) 좌표입니다.
Future<void> openHowToPlay(BuildContext context, {Offset? origin}) {
  final size = MediaQuery.sizeOf(context);
  return Navigator.of(context).push<void>(
    HowToPlayRevealRoute(
      origin: origin ?? Offset(size.width / 2, size.height / 2),
    ),
  );
}

class HowToPlayRevealRoute extends PageRouteBuilder<void> {
  HowToPlayRevealRoute({required this.origin})
    : super(
        // 홈 화면이 원 바깥에 계속 보여야 하므로 불투명 경로로 두지 않습니다.
        opaque: false,
        barrierColor: null,
        transitionDuration: const Duration(milliseconds: 560),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HowToPlayScreen(),
      );

  final Offset origin;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final colors = context.platformColors;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final reveal = Curves.easeInOutCubic.transform(animation.value);
        // 내용은 원이 어느 정도 퍼진 뒤에 떠오릅니다.
        final content = const Interval(
          0.35,
          1,
          curve: Curves.easeOut,
        ).transform(animation.value);

        return Stack(
          children: [
            ClipPath(
              clipper: _CircleRevealClipper(origin: origin, fraction: reveal),
              child: Opacity(opacity: content, child: child),
            ),
            // 눌린 아이콘이 그대로 커지며 사라지는 잔상입니다.
            if (reveal < 0.55)
              Positioned(
                left: origin.dx,
                top: origin.dy,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: Opacity(
                    opacity: (1 - reveal / 0.55).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1 + reveal * 5,
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 26,
                        color: colors.primary,
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

class _CircleRevealClipper extends CustomClipper<Path> {
  const _CircleRevealClipper({required this.origin, required this.fraction});

  final Offset origin;
  final double fraction;

  @override
  Path getClip(Size size) {
    // 화면 네 귀퉁이 중 가장 먼 곳까지 덮어야 빈 곳이 남지 않습니다.
    final corners = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    var maxRadius = 0.0;
    for (final corner in corners) {
      maxRadius = math.max(maxRadius, (corner - origin).distance);
    }
    return Path()
      ..addOval(Rect.fromCircle(center: origin, radius: maxRadius * fraction));
  }

  @override
  bool shouldReclip(covariant _CircleRevealClipper oldClipper) =>
      oldClipper.fraction != fraction || oldClipper.origin != origin;
}
