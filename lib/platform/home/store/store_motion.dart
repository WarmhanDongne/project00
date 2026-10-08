import 'package:flutter/material.dart';

/// 하나의 상점 진입 route 시간축에서 조명·액자·안내를 겹쳐서 등장시킵니다.
class StoreEntrance extends StatelessWidget {
  const StoreEntrance({
    super.key,
    required this.child,
    this.start = 0,
    this.end = 1,
    this.offset = const Offset(0, 36),
  });
  final Widget child;
  final double start;
  final double end;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = Interval(
          start,
          end,
          curve: Curves.easeOutCubic,
        ).transform(animation.value);
        return IgnorePointer(
          ignoring: t < 1,
          child: Opacity(
            opacity: t,
            child: Transform.translate(offset: offset * (1 - t), child: child),
          ),
        );
      },
    );
  }
}

class StoreExit extends StatelessWidget {
  const StoreExit({
    super.key,
    required this.progress,
    required this.offset,
    required this.child,
  });
  final Animation<double> progress;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    child: child,
    builder: (context, child) {
      final t = Curves.easeInCubic.transform(progress.value);
      return IgnorePointer(
        ignoring: t > 0,
        child: Opacity(
          opacity: 1 - t,
          child: FractionalTranslation(translation: offset * t, child: child),
        ),
      );
    },
  );
}
