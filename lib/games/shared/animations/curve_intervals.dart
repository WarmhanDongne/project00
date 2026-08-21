import 'package:flutter/animation.dart';

/// 전체 진행도 [value]에서 [begin]~[end] 구간만 잘라 0~1로 다시 폅니다.
///
/// 구간 밖 값은 0 또는 1로 고정되므로, 하나의 컨트롤러로 여러 요소를
/// 시차를 두고 움직일 때 씁니다. 여러 애니메이션 파일이 같은 식을 각자
/// 복사해 쓰던 것을 이 함수 하나로 모았습니다.
double intervalProgress(
  double value,
  double begin,
  double end, [
  Curve curve = Curves.linear,
]) {
  final progress = ((value - begin) / (end - begin)).clamp(0.0, 1.0);
  return curve.transform(progress);
}

/// "목표를 살짝 지나쳤다가(peak) 되돌아 눌린 뒤(dip) 안착(end)"하는
/// 3구간 시퀀스입니다.
///
/// 보드 등장, 카드 착지, 버튼 낙하가 모두 이 구조를 쓰고 숫자만 다릅니다.
/// 첫 구간과 마지막 구간은 [Curves.easeOutCubic]으로 고정이며, 가운데
/// 눌림 구간만 [dipCurve]로 바꿀 수 있습니다.
Animatable<double> overshootSettle({
  required double begin,
  required double peak,
  required double dip,
  double end = 1.0,
  required double riseWeight,
  required double dipWeight,
  required double settleWeight,
  Curve dipCurve = Curves.easeInCubic,
}) {
  return TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: begin,
        end: peak,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: riseWeight,
    ),
    TweenSequenceItem(
      tween: Tween(begin: peak, end: dip).chain(CurveTween(curve: dipCurve)),
      weight: dipWeight,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: dip,
        end: end,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: settleWeight,
    ),
  ]);
}
