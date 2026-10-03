// [ripple_dialog.dart] 는 휴대폰 게임의 공통 리플 다이얼로그 기반을 구성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 게임 화면에서 반복 사용하는 공통 UI를 구성함
//
// 즉, 같은 표시와 조작 방식을 여러 화면에서 재사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ============================================================

/// 상단 아이콘을 원점으로 모달을 원형으로 펼치고 다시 접는 공용 전환입니다.
Future<T?> showPhoneRippleDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required Offset origin,
  Color barrierColor = const Color(0xB8000000),
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // 배경 암전도 원형 마스크 안에서 함께 나타나도록 기본 barrier는 투명하게 둡니다.
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 520),
    pageBuilder: (routeContext, _, _) => _RippleDialogPage(
      barrierColor: barrierColor,
      child: builder(routeContext),
    ),
    transitionBuilder: (context, animation, _, child) {
      return _RippleDialogTransition(
        animation: animation,
        origin: origin,
        child: child,
      );
    },
  );
}

class _RippleDialogPage extends StatelessWidget {
  const _RippleDialogPage({required this.barrierColor, required this.child});

  final Color barrierColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: barrierColor,
      child: Center(child: child),
    );
  }
}

class _RippleDialogTransition extends StatelessWidget {
  const _RippleDialogTransition({
    required this.animation,
    required this.origin,
    required this.child,
  });

  final Animation<double> animation;
  final Offset origin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxRadius = _farthestCornerDistance(size, origin) + 8;

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeInOutCubic.transform(animation.value);
        final radius = maxRadius * progress;

        return ClipPath(
          clipper: _CircleRevealClipper(center: origin, radius: radius),
          child: child,
        );
      },
    );
  }

  double _farthestCornerDistance(Size size, Offset center) {
    final farthestX = math.max(center.dx.abs(), (size.width - center.dx).abs());
    final farthestY = math.max(
      center.dy.abs(),
      (size.height - center.dy).abs(),
    );
    return math.sqrt(farthestX * farthestX + farthestY * farthestY);
  }
}

class _CircleRevealClipper extends CustomClipper<Path> {
  const _CircleRevealClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_CircleRevealClipper oldClipper) =>
      oldClipper.center != center || oldClipper.radius != radius;
}
