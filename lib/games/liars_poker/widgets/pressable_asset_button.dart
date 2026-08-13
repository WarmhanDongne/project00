import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';

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

  final AssetGenImage asset;
  final double width;
  final double? height;
  final bool enabled;
  final String? semanticsLabel;
  final VoidCallback onPressed;

  @override
  State<LiarsPokerPressableAssetButton> createState() =>
      _LiarsPokerPressableAssetButtonState();
}

/// PNG 대신 Flutter 레이어로 표현한 입체 아케이드 버튼입니다.
///
/// 외곽 크기는 고정하고 윗면만 실제 스위치처럼 아래로 이동시켜 터치 중
/// 버튼이 축소되지 않고 베이스 안으로 눌리는 느낌을 만듭니다.
class LiarsPokerArcadeButtonSurface extends StatelessWidget {
  const LiarsPokerArcadeButtonSurface({
    super.key,
    required this.label,
    required this.width,
    required this.height,
    required this.pressed,
  });

  static const _pressDuration = Duration(milliseconds: 115);

  final String label;
  final double width;
  final double height;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final diameter = width < height ? width : height;
    final baseSize = diameter * 0.82;
    final capSize = diameter * 0.72;
    final travel = diameter * 0.045;
    final capTop = pressed ? diameter * 0.125 + travel : diameter * 0.08;

    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: SizedBox.square(
          dimension: diameter,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              //=======================바닥 그림자==============================
              Positioned(
                top: diameter * 0.22,
                child: AnimatedContainer(
                  duration: _pressDuration,
                  curve: Curves.easeOutCubic,
                  width: baseSize * (pressed ? 0.91 : 1),
                  height: baseSize * (pressed ? 0.78 : 0.84),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: pressed ? 0.34 : 0.56,
                        ),
                        blurRadius: pressed ? 7 : 16,
                        spreadRadius: pressed ? 0 : 2,
                        offset: Offset(0, pressed ? 5 : 13),
                      ),
                    ],
                  ),
                ),
              ),
              //=======================금속 베이스==============================
              Positioned(
                top: diameter * 0.13,
                child: Container(
                  width: baseSize,
                  height: baseSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFBFC3C6),
                        Color(0xFFF8F8F8),
                        Color(0xFF8E9397),
                      ],
                      stops: [0, 0.32, 0.64, 1],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 5,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(diameter * 0.035),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFD6D8DA),
                      ),
                    ),
                  ),
                ),
              ),
              //=======================버튼 측면==============================
              AnimatedPositioned(
                duration: _pressDuration,
                curve: pressed ? Curves.easeInCubic : Curves.easeOutCubic,
                top: capTop + diameter * 0.045,
                child: Container(
                  width: capSize,
                  height: capSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF9F9F9), Color(0xFFAEB1B4)],
                    ),
                  ),
                ),
              ),
              //=======================버튼 윗면==============================
              AnimatedPositioned(
                duration: _pressDuration,
                curve: pressed ? Curves.easeInCubic : Curves.easeOutBack,
                top: capTop,
                child: AnimatedContainer(
                  duration: _pressDuration,
                  width: capSize,
                  height: capSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.22, -0.32),
                      radius: pressed ? 0.94 : 0.86,
                      colors: pressed
                          ? const [
                              Color(0xFFFFFFFF),
                              Color(0xFFFDFDFD),
                              Color(0xFFE7E7E7),
                            ]
                          : const [
                              Color(0xFFFFFFFF),
                              Color(0xFFF7F7F7),
                              Color(0xFFD4D5D6),
                            ],
                      stops: const [0, 0.72, 1],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: pressed
                            ? const Color(0xBFFFFFFF)
                            : const Color(0x44000000),
                        blurRadius: pressed ? 14 : 6,
                        spreadRadius: pressed ? 2 : 0,
                        offset: Offset(0, pressed ? 0 : 4),
                      ),
                      const BoxShadow(
                        color: Color(0x99FFFFFF),
                        blurRadius: 5,
                        offset: Offset(-3, -4),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: diameter * 0.1),
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          color: const Color(0xFF111111),
                          fontFamily: label == 'Liar' ? 'Georgia' : null,
                          fontFamilyFallback: const [
                            'Times New Roman',
                            'serif',
                          ],
                          fontSize: diameter * (label == 'Liar' ? 0.25 : 0.2),
                          fontWeight: FontWeight.w900,
                          letterSpacing: label == 'Liar' ? -2 : -1,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              //=======================유광 반사==============================
              AnimatedPositioned(
                duration: _pressDuration,
                top: capTop + diameter * 0.055,
                left: diameter * 0.28,
                child: IgnorePointer(
                  child: Container(
                    width: diameter * 0.31,
                    height: diameter * 0.095,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(diameter),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: pressed ? 0.35 : 0.7),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

/// 결과·PASS처럼 기존 이미지 버튼에 사용하는 공통 눌림 표면입니다.
class LiarsPokerButtonSurface extends StatelessWidget {
  const LiarsPokerButtonSurface({
    super.key,
    required this.asset,
    required this.width,
    required this.pressed,
    this.height,
  });

  static const _pressDuration = Duration(milliseconds: 105);

  final AssetGenImage asset;
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

  Widget _assetImage(AssetGenImage image) {
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
        //=======================버튼 그림자==============================
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
