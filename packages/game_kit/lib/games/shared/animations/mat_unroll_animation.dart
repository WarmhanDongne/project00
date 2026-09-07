import 'package:flutter/material.dart';

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
