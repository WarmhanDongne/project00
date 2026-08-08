import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';

class LiarAccusationLandscape extends StatefulWidget {
  final VoidCallback? onAccuse;

  const LiarAccusationLandscape({super.key, this.onAccuse});

  @override
  State<LiarAccusationLandscape> createState() =>
      _LiarAccusationLandscapeState();
}

class _LiarAccusationLandscapeState extends State<LiarAccusationLandscape> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onAccuse?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Assets.games.liarsPoker.images.button.buttonLiarWhite.image(
            width: 195, // 가로 모드 뷰포트에 맞춘 고정 너비
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
