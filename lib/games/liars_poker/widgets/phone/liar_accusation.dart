import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/gen/assets.gen.dart';

class LiarAccusation extends StatefulWidget {
  final VoidCallback? onAccuse;
  final double? width; // 외부에서 너비를 주입받을 수 있도록 추가
  final double? height; // 외부에서 높이를 주입받을 수 있도록 추가

  const LiarAccusation({super.key, this.onAccuse, this.width, this.height});

  @override
  State<LiarAccusation> createState() => _LiarAccusationState();
}

class _LiarAccusationState extends State<LiarAccusation> {
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
          // 외부에서 width가 안 들어왔을 때만 double.infinity 적용 (세로 모드 유지)
          width: widget.width == null ? double.infinity : null,
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Assets.games.liarsPoker.images.phone.liar.image(
            // 파라미터가 있으면 그 값을, 없으면 기존 screenutil 값 적용
            width: widget.width ?? 290.w,
            height: widget.height ?? 193.h,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
