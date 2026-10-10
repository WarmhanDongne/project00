// [pressable_button.dart] 라이어스 포커 자산에
// 눌림 표현·입력 차단·접근성을 추가하는 공용 이미지 버튼 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_liars_poker/game_assets.dart';

// ============================================================

/// Liar's Poker에서 사용하는 이미지 버튼의 공통 눌림 동작입니다.
///
/// 버튼 크기는 유지하고, 그림자가 짧아지면서 버튼 면만 아래로 움직입니다.
class LiarsPokerPressableAssetButton extends StatefulWidget {
  const LiarsPokerPressableAssetButton({
    super.key,
    required this.asset,
    required this.width,
    required this.onPressed,
    this.height,
    this.enabled = true,
    this.semanticsLabel,
  });

  final GameImage asset;
  final double width;
  final double? height;
  final bool enabled;
  final String? semanticsLabel;
  final VoidCallback onPressed;

  @override
  State<LiarsPokerPressableAssetButton> createState() =>
      _LiarsPokerPressableAssetButtonState();
}

class _LiarsPokerPressableAssetButtonState
    extends State<LiarsPokerPressableAssetButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value || !mounted) return;
    setState(() => _isPressed = value);
  }

  @override
  void didUpdateWidget(LiarsPokerPressableAssetButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _isPressed) _isPressed = false;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
        onTapUp: widget.enabled
            ? (_) {
                _setPressed(false);
                widget.onPressed();
              }
            : null,
        onTapCancel: widget.enabled ? () => _setPressed(false) : null,
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1 : 0.5,
          duration: const Duration(milliseconds: 180),
          child: LiarsPokerButtonSurface(
            asset: widget.asset,
            width: widget.width,
            height: widget.height,
            pressed: _isPressed,
          ),
        ),
      ),
    );
  }
}

/// 결과·FOLD처럼 기존 이미지 버튼에 사용하는 공통 눌림 표면입니다.
class LiarsPokerButtonSurface extends StatelessWidget {
  const LiarsPokerButtonSurface({
    super.key,
    required this.asset,
    required this.width,
    required this.pressed,
    this.height,
  });

  static const _pressDuration = Duration(milliseconds: 105);

  final GameImage asset;
  final double width;
  final double? height;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final resolvedHeight = height ?? width;

    return SizedBox(
      width: width,
      height: resolvedHeight,
      child: _buildButtonSurface(resolvedHeight),
    );
  }

  Widget _assetImage(GameImage image) {
    return image.image(
      width: width,
      height: height ?? width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }

  Widget _buildButtonSurface(double resolvedHeight) {
    Widget image() => _assetImage(asset);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // ---------------------------------------------------------------------------
        // 버튼 그림자
        // ---------------------------------------------------------------------------
        AnimatedContainer(
          duration: _pressDuration,
          width: width * 0.72,
          height: resolvedHeight * 0.52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: pressed ? 0.25 : 0.58),
                blurRadius: pressed ? 4 : 13,
                offset: Offset(0, pressed ? 4 : 11),
              ),
            ],
          ),
        ),
        AnimatedSlide(
          offset: pressed ? const Offset(0, 0.045) : Offset.zero,
          duration: _pressDuration,
          curve: pressed ? Curves.easeInCubic : Curves.easeOutBack,
          child: image(),
        ),
      ],
    );
  }
}
