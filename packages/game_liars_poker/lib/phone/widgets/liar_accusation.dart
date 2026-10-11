// [liar_accusation.dart] 휴대폰에서 LIAR 선언과
// 카드 SUBMIT 행동을 선택하는 조작 영역을 구성하는 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:game_liars_poker/game_theme.dart';
import 'package:game_liars_poker/shared/widgets/noir_ui.dart';

// ============================================================

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

  /// 퍽 아래 안내 문구 높이까지 포함한 퍽 크기입니다.
  double get _puckSize {
    if (widget.isLandscape) return 116;
    final available = widget.portraitHeight ?? 193.h.clamp(140.0, 193.0);
    return math.min(128.0, available - _hintSpace);
  }

  static const double _hintSpace = 40;

  @override
  Widget build(BuildContext context) {
    final puck = GestureDetector(
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
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.showSubmit ? '고른 카드 제출' : 'LIAR 외치기',
        excludeSemantics: true,
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
              child: _buildPuck(showSubmit: showSubmit),
            );
          },
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        puck,
        SizedBox(height: widget.isLandscape ? 10 : 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text.rich(
            key: ValueKey(widget.showSubmit),
            widget.showSubmit
                ? const TextSpan(text: '카드를 다시 누르면 선택이 풀려요')
                : const TextSpan(
                    children: [
                      TextSpan(text: '카드를 고르면 '),
                      TextSpan(
                        text: '제출',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: LiarsPokerColors.goldLight,
                        ),
                      ),
                      TextSpan(text: ' 버튼으로 바뀌어요'),
                    ],
                  ),
            textAlign: TextAlign.center,
            style: LiarsPokerFonts.text(
              size: widget.isLandscape ? 12 : 13,
              color: LiarsPokerColors.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPuck({required bool showSubmit}) => NoirPuck(
    label: showSubmit ? '제출' : 'Liar',
    western: !showSubmit,
    ringColor: showSubmit ? LiarsPokerColors.gold : LiarsPokerColors.red,
    size: _puckSize,
    pressed: _isPressed,
    enabled: widget.enabled,
  );
}
