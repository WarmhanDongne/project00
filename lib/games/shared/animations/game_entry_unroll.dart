import 'package:flutter/material.dart';
import 'package:project00/games/shared/animations/mat_unroll_animation.dart';
import 'package:project00/games/shared/animations/one_shot_timeline.dart';

/// 게임 화면이 열릴 때 매트가 위에서 풀려 내려오며 배경을 드러냅니다.
///
/// 태블릿에서 자리 배치 연출의 테이블이 확대되는 시점에 휴대폰도 같은 순간
/// 게임 화면으로 전환되므로, 양쪽이 하나의 연출처럼 이어지도록 휴대폰에서는
/// 이 매트 연출로 배경을 깔아 줍니다.
///
/// [OneShotTimeline]이 첫 프레임이 그려진 뒤 재생을 시작하므로 배경 이미지가
/// 준비된 상태로 펼쳐집니다.
class GameEntryUnroll extends StatelessWidget {
  const GameEntryUnroll({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 900),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: OneShotTimeline(
        duration: duration,
        builder: (context, progress) =>
            MatUnrollAnimation(progress: progress, child: child),
      ),
    );
  }
}
