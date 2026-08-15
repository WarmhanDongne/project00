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
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 58),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 24,
      ),
    ]).animate(_controller);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: widget.beginScale,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 58),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: widget.endScale,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 24,
      ),
    ]).animate(_controller);
    _controller.forward();
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
