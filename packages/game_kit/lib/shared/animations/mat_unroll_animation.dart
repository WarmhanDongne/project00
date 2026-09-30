// [mat_unroll_animation.dart] 는 여러 기기가 공유하는 매트 펼침 연출을 관리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Animation] : 화면 전환과 게임 연출의 진행 시간을 관리함
//
// 즉, 같은 연출을 예측 가능한 순서와 속도로 재생하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
// ============================================================

/// 화면 위에서 매트가 풀려 내려오고 다시 말려 올라가는 전환입니다.
///
/// [progress]가 0이면 완전히 말린 상태, 1이면 화면 전체를 덮은 상태입니다.
/// 게임별 배경과 내용은 [child]로 주입하여 같은 애니메이션을 공유합니다.
class MatUnrollAnimation extends StatelessWidget {
  const MatUnrollAnimation({
    super.key,
    required this.progress,
    required this.child,
  });

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curvedProgress = Curves.easeInOutCubicEmphasized.transform(progress);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final edgeTop = (height * curvedProgress - 9).clamp(0.0, height - 18);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            ClipRect(
              clipper: _MatRevealClipper(curvedProgress),
              child: SizedBox.expand(child: child),
            ),
            if (curvedProgress > 0 && curvedProgress < 1)
              Positioned(
                top: edgeTop,
                left: 0,
                right: 0,
                height: 18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF08040C),
                        Color(0xFF3A174D),
                        Color(0xFF100717),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black87,
                        blurRadius: 14,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MatRevealClipper extends CustomClipper<Rect> {
  const _MatRevealClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * progress);

  @override
  bool shouldReclip(_MatRevealClipper oldClipper) =>
      oldClipper.progress != progress;
}
