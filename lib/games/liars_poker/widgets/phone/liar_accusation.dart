import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/gen/assets.gen.dart';

class LiarAccusation extends StatefulWidget {
  final VoidCallback? onAccuse;
  const LiarAccusation({super.key, this.onAccuse});

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
        // 여기에 탭업 시 프로바이더를 통해 라이어 외침 전달
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,

      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        //curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Assets.games.liarsPoker.images.phone.liar.image(
            width: 290.w,
            height: 193.h,
          ),
        ),
      ),
    );
  }
}
