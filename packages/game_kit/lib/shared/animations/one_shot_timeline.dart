// [one_shot_timeline.dart] 는 여러 기기가 공유하는 일회성 연출 타임라인을 관리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Animation] : 게임 화면의 등장·전환·카드 연출 시간을 관리함
//
// 즉, 게임 진행과 화면 연출이 같은 타이밍으로 움직이게 구성하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
// ============================================================

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
