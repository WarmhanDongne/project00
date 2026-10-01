// [control_entry_animation.dart] 는 휴대폰 조작 요소의 등장 연출을 관리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Animation] : 게임 화면의 등장·전환·카드 연출 시간을 관리함
//
// 즉, 게임 진행과 화면 연출이 같은 타이밍으로 움직이게 구성하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:game_kit/shared/animations/curve_intervals.dart';
// ============================================================

/// 카드 공개가 끝난 뒤 나타나는 휴대폰 게임 조작 요소의 등장 방식입니다.
enum ControlEntryStyle {
  /// 헤더 요소가 위쪽에서 짧고 단단하게 들어옵니다.
  header,

  /// 큰 버튼이 위에서 떨어져 작은 착지 반동 후 멈춥니다.
  heavyDrop,
}

/// 하나의 화면 컨트롤러를 공유하면서 요소마다 짧은 시차를 줄 수 있습니다.
class ControlEntryAnimation extends StatelessWidget {
  const ControlEntryAnimation({
    super.key,
    required this.animation,
    required this.child,
    required this.style,
    this.begin = 0,
    this.end = 1,
  }) : assert(begin >= 0 && begin < end),
       assert(end <= 1);

  final Animation<double> animation;
  final Widget child;
  final ControlEntryStyle style;
  final double begin;
  final double end;

  static final Animatable<double> _heavyDropOffset = overshootSettle(
    begin: -1.0,
    peak: 0.075,
    dip: -0.018,
    end: 0.0,
    riseWeight: 72,
    dipWeight: 12,
    settleWeight: 16,
    dipCurve: Curves.easeInOutCubic,
  );

  static final Animatable<double> _heavyDropScale = overshootSettle(
    begin: 0.93,
    peak: 1.025,
    dip: 0.992,
    riseWeight: 72,
    dipWeight: 12,
    settleWeight: 16,
    dipCurve: Curves.easeInOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final progress = intervalProgress(animation.value, begin, end);
        final opacity = Curves.easeOutCubic.transform(
          (progress / 0.34).clamp(0.0, 1.0),
        );

        return IgnorePointer(
          ignoring: progress < 1,
          child: Opacity(
            opacity: opacity,
            child: switch (style) {
              ControlEntryStyle.header => _buildHeaderEntry(
                progress,
                child!,
              ),
              ControlEntryStyle.heavyDrop => _buildHeavyDrop(
                progress,
                child!,
              ),
            },
          ),
        );
      },
    );
  }

  Widget _buildHeaderEntry(double progress, Widget child) {
    final curved = Curves.easeOutCubic.transform(progress);
    final offsetY = lerpDouble(-32, 0, curved)!;
    final scale = lerpDouble(0.95, 1, Curves.easeOutBack.transform(progress))!;

    return Transform.translate(
      offset: Offset(0, offsetY),
      child: Transform.scale(scale: scale, child: child),
    );
  }

  Widget _buildHeavyDrop(double progress, Widget child) {
    final offsetY = _heavyDropOffset.transform(progress) * 112;
    final scale = _heavyDropScale.transform(progress);

    return Transform.translate(
      offset: Offset(0, offsetY),
      child: Transform.scale(scale: scale, child: child),
    );
  }
}
