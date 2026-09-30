// [game_entry_unroll.dart] 는 휴대폰 게임 화면의 진입 연출을 관리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Animation] : 화면 전환과 게임 연출의 진행 시간을 관리함
//
// 즉, 같은 연출을 예측 가능한 순서와 속도로 재생하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/shared/animations/mat_unroll_animation.dart';
import 'package:game_kit/shared/animations/one_shot_timeline.dart';
// ============================================================

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
