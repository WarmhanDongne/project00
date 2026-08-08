import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';

class LiarAccusationLandscape extends StatefulWidget {
  final bool enabled;
  final VoidCallback? onAccuse;

  const LiarAccusationLandscape({
    super.key,
    this.enabled = true,
    this.onAccuse,
  });

  @override
  State<LiarAccusationLandscape> createState() =>
      _LiarAccusationLandscapeState();
}

class _LiarAccusationLandscapeState extends State<LiarAccusationLandscape> {
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
          child: Container(
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Assets.games.liarsPoker.images.button.buttonLiarWhite.image(
              width: 195,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
