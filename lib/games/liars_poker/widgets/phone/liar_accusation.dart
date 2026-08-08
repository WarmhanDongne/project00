import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/gen/assets.gen.dart';

class LiarAccusation extends StatefulWidget {
  const LiarAccusation({super.key, this.enabled = true, this.onAccuse});

  final bool enabled;
  final VoidCallback? onAccuse;

  @override
  State<LiarAccusation> createState() => _LiarAccusationState();
}

class _LiarAccusationState extends State<LiarAccusation> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _isPressed = false);
              widget.onAccuse?.call();
            }
          : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _isPressed = false)
          : null,
      behavior: HitTestBehavior.opaque,

      child: AnimatedOpacity(
        opacity: widget.enabled ? 1 : 0.42,
        duration: const Duration(milliseconds: 180),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: SizedBox(
            width: double.infinity,
            child: Assets.games.liarsPoker.images.button.buttonLiarWhite.image(
              width: 290.w,
              height: 193.h,
            ),
          ),
        ),
      ),
    );
  }
}
