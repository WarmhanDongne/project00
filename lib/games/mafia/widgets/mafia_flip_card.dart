import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';

/// 마피아 역할 카드가 뒷면에서 앞면으로 뒤집히는 공통 연출입니다.
///
/// 역할 확인(P1)·처형 발표(휴대폰/태블릿)가 같은 회전·그림자·원근 값을
/// 복사해 쓰던 것을 하나로 모았습니다. [progress]는 이미 곡선이 적용된
/// 0~1 값을 받습니다(세 화면 모두 [Curves.easeInOutCubic]을 사용).
class MafiaFlipCard extends StatelessWidget {
  const MafiaFlipCard({
    super.key,
    required this.progress,
    required this.front,
    required this.back,
    required this.borderRadius,
    this.backOverlay,
  });

  /// 곡선이 적용된 뒤집기 진행도입니다.
  final double progress;

  /// 앞면이 아직 없으면(null) 끝까지 뒷면으로 돕니다.
  final GameImage? front;
  final GameImage back;
  final BorderRadius borderRadius;

  /// 뒷면 위에만 얹는 위젯입니다(처형 대상의 원형 사진 등). 절반을 지나
  /// 앞면으로 바뀌면 표시하지 않습니다.
  final Widget? backOverlay;

  @override
  Widget build(BuildContext context) {
    final front = this.front;
    // 절반을 지나면 앞면으로 바꿔, 뒤집히는 도중에 글자가 거울처럼 반사되어
    // 보이지 않게 합니다.
    final showsFront = progress >= 0.5 && front != null;
    final angle = showsFront ? math.pi * (1 - progress) : math.pi * progress;
    final face = (showsFront ? front : back).image(
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
    final overlay = backOverlay;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateY(angle),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 4,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: overlay == null
              ? face
              : Stack(
                  fit: StackFit.expand,
                  children: [face, if (!showsFront) overlay],
                ),
        ),
      ),
    );
  }
}
