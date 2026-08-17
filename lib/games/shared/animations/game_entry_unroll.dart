import 'package:flutter/material.dart';
import 'package:project00/games/shared/animations/mat_unroll_animation.dart';

/// 게임 화면이 열릴 때 매트가 위에서 풀려 내려오며 배경을 드러냅니다.
///
/// 태블릿에서 자리 배치 연출의 테이블이 확대되는 시점에 휴대폰도 같은 순간
/// 게임 화면으로 전환되므로, 양쪽이 하나의 연출처럼 이어지도록 휴대폰에서는
/// 이 매트 연출로 배경을 깔아 줍니다.
class GameEntryUnroll extends StatefulWidget {
  const GameEntryUnroll({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 900),
  });

  final Widget child;
  final Duration duration;

  @override
  State<GameEntryUnroll> createState() => _GameEntryUnrollState();
}

class _GameEntryUnrollState extends State<GameEntryUnroll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    // 첫 프레임이 그려진 뒤 시작해야 배경 이미지가 준비된 상태로 펼쳐집니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) =>
            MatUnrollAnimation(progress: _controller.value, child: child!),
      ),
    );
  }
}
