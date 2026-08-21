import 'package:flutter/material.dart';

/// 짧은 안내 요소를 Fade In → Hold → Fade Out 순서로 한 번 재생합니다.
class FadeHoldFade extends StatefulWidget {
  const FadeHoldFade({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1900),
    this.beginScale = 1,
    this.endScale = 1,
    this.onCompleted,
  });

  final Widget child;
  final Duration duration;
  final double beginScale;
  final double endScale;
  final VoidCallback? onCompleted;

  @override
  State<FadeHoldFade> createState() => _FadeHoldFadeState();
}

class _FadeHoldFadeState extends State<FadeHoldFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_handleStatus);
    _opacity = _inHoldOut(from: 0, to: 0);
    _scale = _inHoldOut(from: widget.beginScale, to: widget.endScale);
    _controller.forward();
  }

  /// [from]에서 1로 들어와 잠시 유지한 뒤 [to]로 빠지는 공통 구간입니다.
  Animation<double> _inHoldOut({required double from, required double to}) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: from,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 58),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: to,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 24,
      ),
    ]).animate(_controller);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onCompleted?.call();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
