import 'package:flutter/material.dart';

typedef OneShotTimelineBuilder =
    Widget Function(BuildContext context, double progress);

/// 0→1 타임라인을 한 번 재생하는 공용 애니메이션 수명주기입니다.
///
/// 복합 게임 연출은 시간 구간과 화면만 계산하고, AnimationController 생성·시작·
/// 완료·dispose는 이 위젯에 맡깁니다. 같은 수명주기 코드가 screen/layer 파일에
/// 반복되는 것을 막습니다.
class OneShotTimeline extends StatefulWidget {
  const OneShotTimeline({
    super.key,
    required this.duration,
    required this.builder,
    this.onCompleted,
  });

  final Duration duration;
  final OneShotTimelineBuilder builder;
  final VoidCallback? onCompleted;

  @override
  State<OneShotTimeline> createState() => _OneShotTimelineState();
}

class _OneShotTimelineState extends State<OneShotTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_handleStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(OneShotTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value),
    );
  }
}
