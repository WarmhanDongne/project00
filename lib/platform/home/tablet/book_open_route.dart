// [book_open_route.dart] 는 선반의 책을 중심으로 자리 배치 화면이 퍼지는 전환을 구성하는 파일이다.
//
// - [Platform] : 태블릿 로비
// - [Route] : 고른 책이 중앙으로 모인 뒤 다음 화면이 책 주변에서 화면 전체로 퍼짐
//
// 즉, 로비와 자리 배치가 페이지 이동이 아니라 한 공간의 변화처럼 보이게 한다.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

const bookOpenTransitionDuration = Duration(milliseconds: 920);

/// 선택한 책이 이동을 마치는 화면 중앙 자리입니다.
///
/// 원래 책 비율과 크기를 유지하되 작은 화면에서는 다음 화면이 퍼질 여백을
/// 남깁니다. 전환 테스트에서도 같은 계산을 사용합니다.
@visibleForTesting
Rect centeredBookRect(Size viewport, Rect origin) {
  if (viewport.isEmpty || origin.isEmpty) return origin;
  final maxHeight = viewport.height * 0.48;
  final maxWidth = viewport.width * 0.3;
  final scale = math.min(
    1.08,
    math.min(maxHeight / origin.height, maxWidth / origin.width),
  );
  final size = Size(origin.width * scale, origin.height * scale);
  return Alignment.center.inscribe(size, Offset.zero & viewport);
}

double _phase(double value, double start, double end, Curve curve) =>
    curve.transform(((value - start) / (end - start)).clamp(0.0, 1.0));

/// 고른 책이 먼저 중앙으로 이동하고, 자리 배치 화면이 그 책 주변에서 사방으로
/// 펼쳐지는 전환입니다. 뒤로 갈 때는 같은 시간축을 그대로 역재생합니다.
class BookOpenRoute<T> extends PageRouteBuilder<T> {
  BookOpenRoute({
    required this.origin,
    required WidgetBuilder builder,
    this.coverColor = MosiColors.navy,
    this.cover,
  }) : super(
         transitionDuration: bookOpenTransitionDuration,
         reverseTransitionDuration: bookOpenTransitionDuration,
         pageBuilder: (context, _, _) => builder(context),
       );

  /// 책이 화면에 놓인 자리입니다(전역 좌표).
  final Rect origin;

  /// 표지 그림이 준비되지 않았을 때 쓰는 책 색입니다.
  final Color coverColor;

  /// 선반과 같은 실제 게임 표지입니다.
  final Widget? cover;

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
        final viewport = MediaQuery.sizeOf(context);
        final screen = Offset.zero & viewport;
        final center = centeredBookRect(viewport, origin);

        // 1) 책이 선반에서 중앙으로 모입니다.
        final gather = _phase(t, 0, 0.34, Curves.easeInOutCubic);
        final bookRect = Rect.lerp(origin, center, gather)!;

        // 2) 책 주위의 화면이 사방으로 퍼집니다. 책이 중앙에 도착하기 직전에
        // 시작해 동작이 잠깐 멈춘 것처럼 보이지 않게 겹칩니다.
        final spread = _phase(t, 0.28, 1, Curves.easeInOutCubicEmphasized);
        final revealRect = Rect.lerp(center, screen, spread)!;
        final pageOpacity = _phase(t, 0.28, 0.42, Curves.easeOut);

        // 새 화면이 책보다 넓어진 뒤 실제 표지는 자연스럽게 그 안으로 섞입니다.
        final coverFade = _phase(t, 0.44, 0.66, Curves.easeInCubic);
        final halo = _phase(t, 0.24, 0.54, Curves.easeOutCubic);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fromRect(
              key: const Key('book-screen-reveal'),
              rect: revealRect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12 * (1 - spread)),
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: screen.width,
                  maxWidth: screen.width,
                  minHeight: screen.height,
                  maxHeight: screen.height,
                  child: Transform.translate(
                    offset: -revealRect.topLeft,
                    child: Opacity(opacity: pageOpacity, child: child),
                  ),
                ),
              ),
            ),
            if (coverFade < 1)
              Positioned.fromRect(
                key: const Key('book-transition-cover'),
                rect: bookRect,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 1 - coverFade,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: coverColor.withValues(
                              alpha: 0.34 * (1 - halo),
                            ),
                            blurRadius: 12 + 42 * halo,
                            spreadRadius: 2 + 16 * halo,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            cover ??
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: coverColor,
                                border: Border.all(
                                  color: MosiColors.ink,
                                  width: 3,
                                ),
                              ),
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
