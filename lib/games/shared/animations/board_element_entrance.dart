import 'package:flutter/material.dart';

/// 탑뷰 보드 위의 물체가 바닥에서 카메라 쪽으로 솟아오르는 공통 등장 곡선입니다.
///
/// Liar's Poker의 라운드 시작(테이블·잔여 카드) 연출이 기준이며, 다른 게임의
/// 보드 요소도 같은 값을 써야 등장 느낌이 동일하게 유지됩니다.
abstract final class BoardEntranceCurves {
  static const Duration duration = Duration(milliseconds: 980);

  /// 작게 솟아올라 살짝 지나쳤다가 제자리에 안착합니다.
  static final Animatable<double> depthScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.58,
        end: 1.045,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 64,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.045,
        end: 0.978,
      ).chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 14,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.978,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 22,
    ),
  ]);

  /// 공중에 떠 있을 때 그림자를 넓히고 착지 순간 다시 단단하게 모읍니다.
  static final Animatable<double> elevation = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 42,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 58,
    ),
  ]);

  static double opacityFor(double progress) =>
      Curves.easeOutCubic.transform((progress / 0.2).clamp(0.0, 1.0));
}

/// [BoardEntranceCurves]를 그대로 적용해 자식을 등장시키는 래퍼입니다.
///
/// 그림자까지 직접 제어해야 하는 화면은 곡선만 가져다 쓰고, 단순히 같은 느낌으로
/// 등장시키면 되는 요소는 이 위젯으로 감싸면 됩니다.
class BoardElementEntrance extends StatefulWidget {
  const BoardElementEntrance({
    super.key,
    required this.child,
    this.duration = BoardEntranceCurves.duration,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration duration;

  /// 여러 요소를 조금씩 시차를 두고 띄울 때 씁니다.
  final Duration delay;

  @override
  State<BoardElementEntrance> createState() => _BoardElementEntranceState();
}

class _BoardElementEntranceState extends State<BoardElementEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = _controller.value;
        return Opacity(
          opacity: BoardEntranceCurves.opacityFor(progress),
          child: Transform.scale(
            scale: BoardEntranceCurves.depthScale.transform(progress),
            child: child,
          ),
        );
      },
    );
  }
}
