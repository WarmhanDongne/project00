import 'package:flutter/material.dart';

/// 게임 화면 진입 시 GAME START를 부드럽게 등장·퇴장시킵니다.
///
/// 애니메이션이 완전히 사라진 다음에만 [onCompleted]를 호출하므로 손패 진입
/// 애니메이션과 동시에 실행되지 않습니다.
class PhoneGameStartAnimation extends StatefulWidget {
  const PhoneGameStartAnimation({
    super.key,
    required this.onCompleted,
    this.textColor = Colors.white,
  });

  final VoidCallback onCompleted;
  final Color textColor;

  @override
  State<PhoneGameStartAnimation> createState() =>
      _PhoneGameStartAnimationState();
}

class _PhoneGameStartAnimationState extends State<PhoneGameStartAnimation>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1700);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener(_handleStatus)
      ..forward();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onCompleted();
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final entry = _interval(
            _controller.value,
            0,
            0.22,
            Curves.easeOutBack,
          );
          final exit = _interval(
            _controller.value,
            0.66,
            1,
            Curves.easeInOutCubic,
          );
          final textOpacity = entry * (1 - exit);
          final scale = (0.88 + entry * 0.12) * (1 - exit * 0.12);

          return Center(
            child: Opacity(
              opacity: textOpacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Text(
                  'GAME START',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    color: widget.textColor,
                    fontSize: 58,
                    height: 1,
                    letterSpacing: 5,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _interval(double value, double begin, double end, Curve curve) {
    final progress = ((value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(progress);
  }
}
