import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/liars_poker/widgets/pressable_asset_button.dart';

class LiarAccusation extends StatefulWidget {
  const LiarAccusation({
    super.key,
    required this.isLandscape,
    this.showSubmit = false,
    this.enabled = true,
    this.onAccuse,
    this.onSubmit,
    this.portraitHeight,
  });

  final bool isLandscape;
  final bool showSubmit;
  final bool enabled;
  final VoidCallback? onAccuse;
  final VoidCallback? onSubmit;
  final double? portraitHeight;

  @override
  State<LiarAccusation> createState() => _LiarAccusationState();
}

class _LiarAccusationState extends State<LiarAccusation>
    with SingleTickerProviderStateMixin {
  static const _flipDuration = Duration(milliseconds: 460);

  late final AnimationController _flipController;
  late bool _sourceShowsSubmit;
  late bool _targetShowsSubmit;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _sourceShowsSubmit = widget.showSubmit;
    _targetShowsSubmit = widget.showSubmit;
    _flipController = AnimationController(
      vsync: this,
      duration: _flipDuration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(LiarAccusation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showSubmit == widget.showSubmit) return;

    // 회전 중 선택이 다시 바뀌어도 현재 보이는 면에서 새 목표 면으로 이어집니다.
    _sourceShowsSubmit = _flipController.value < 0.5
        ? _sourceShowsSubmit
        : _targetShowsSubmit;
    _targetShowsSubmit = widget.showSubmit;
    _flipController.forward(from: 0);
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _isPressed = false);
              if (widget.showSubmit) {
                widget.onSubmit?.call();
              } else {
                widget.onAccuse?.call();
              }
            }
          : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _isPressed = false)
          : null,
      behavior: HitTestBehavior.opaque,

      child: AnimatedBuilder(
        animation: _flipController,
        builder: (context, _) {
          final progress = Curves.easeInOutCubic.transform(
            _flipController.value,
          );
          final showsSecondFace = progress >= 0.5;
          final showSubmit = showsSecondFace
              ? _targetShowsSubmit
              : _sourceShowsSubmit;
          final angle = showsSecondFace
              ? -math.pi * (1 - progress)
              : math.pi * progress;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: _buildButtonImage(showSubmit: showSubmit),
          );
        },
      ),
    );
  }

  Widget _buildButtonImage({required bool showSubmit}) {
    final label = showSubmit ? '제출' : 'Liar';

    //=======================가로 버튼==============================
    if (widget.isLandscape) {
      return LiarsPokerArcadeButtonSurface(
        label: label,
        width: 195,
        height: 170,
        pressed: _isPressed,
      );
    }

    //=======================세로 버튼==============================
    final availableHeight = widget.portraitHeight ?? 193.h.clamp(140.0, 193.0);
    return LiarsPokerArcadeButtonSurface(
      label: label,
      width: math.min(305.w, availableHeight * 1.5),
      height: availableHeight,
      pressed: _isPressed,
    );
  }
}
