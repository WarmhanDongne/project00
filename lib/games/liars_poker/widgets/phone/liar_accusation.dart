import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/gen/assets.gen.dart';

class LiarAccusation extends StatefulWidget {
  const LiarAccusation({
    super.key,
    required this.isLandscape,
    this.showSubmit = false,
    this.enabled = true,
    this.onAccuse,
    this.onSubmit,
  });

  final bool isLandscape;
  final bool showSubmit;
  final bool enabled;
  final VoidCallback? onAccuse;
  final VoidCallback? onSubmit;

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

      child: AnimatedSlide(
        offset: _isPressed ? const Offset(0, 0.045) : Offset.zero,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: _isPressed ? 0.91 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
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
        ),
      ),
    );
  }

  Widget _buildButtonImage({required bool showSubmit}) {
    final asset = showSubmit
        ? Assets.games.liarsPoker.images.button.buttonSubmit
        : Assets.games.liarsPoker.images.button.buttonLiar;

    //==================================가로==================================
    if (widget.isLandscape) {
      return _ShadowedButtonImage(
        asset: asset,
        width: 195,
        height: 170,
        pressed: _isPressed,
      );
    }

    //==================================세로==================================
    return _ShadowedButtonImage(
      asset: asset,
      width: 305.w,
      height: 205.h,
      pressed: _isPressed,
    );
  }
}

/// PNG의 투명 영역을 제외한 실제 버튼 형태에만 그림자를 적용합니다.
class _ShadowedButtonImage extends StatelessWidget {
  const _ShadowedButtonImage({
    required this.asset,
    required this.width,
    required this.height,
    required this.pressed,
  });

  final AssetGenImage asset;
  final double width;
  final double height;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    Widget image() => asset.image(
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedSlide(
            offset: pressed ? const Offset(0, 0.015) : const Offset(0, 0.065),
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: pressed ? 0.3 : 0.72,
              duration: const Duration(milliseconds: 110),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: pressed ? 3 : 8,
                  sigmaY: pressed ? 3 : 8,
                ),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcIn,
                  ),
                  child: image(),
                ),
              ),
            ),
          ),
          image(),
        ],
      ),
    );
  }
}
