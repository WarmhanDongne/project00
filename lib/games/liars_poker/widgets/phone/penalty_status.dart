import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:project00/games/shared/animations/fade_hold_fade.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';
import 'package:project00/games/liars_poker/widgets/phone/turn_action_switcher.dart';
import 'package:project00/gen/assets.gen.dart';

/// 벌칙 대상 프로필과 룰렛 결과 스탬프 연출을 표시합니다.
///
/// 룰렛 결과가 확정되면 1인칭 원근으로 스탬프가 프로필에 접근해 찍힙니다.
/// 본체는 0.7초간 눌린 채 유지된 뒤 카메라 쪽으로 빠지고 결과 자국만 남습니다.
class PhonePenaltyStatus extends StatefulWidget {
  const PhonePenaltyStatus({
    super.key,
    required this.player,
    required this.result,
  });

  final PhoneGamePlayer? player;
  final String? result;

  @override
  State<PhonePenaltyStatus> createState() => _PhonePenaltyStatusState();
}

class _PhonePenaltyStatusState extends State<PhonePenaltyStatus>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _waitingExitController;
  late final AnimationController _stampController;
  bool _didPrecacheStamp = false;

  bool get _hasResolvedResult =>
      widget.result == 'safe' || widget.result == 'eliminated';

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _waitingExitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      value: widget.result == null ? 0 : 1,
    );
    _stampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1580),
    );
    if (_hasResolvedResult) _stampController.forward();
  }

  @override
  void didUpdateWidget(PhonePenaltyStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result == widget.result) return;

    if (widget.result != null) {
      _waitingExitController.forward();
    } else {
      _waitingExitController.reverse();
    }

    if (oldWidget.result != widget.result && _hasResolvedResult) {
      _stampController.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheStamp) return;
    _didPrecacheStamp = true;
    precacheImage(
      Assets.games.liarsPoker.images.other.stamp.provider(),
      context,
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _waitingExitController.dispose();
    _stampController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final profileSize = isLandscape ? 112.0 : 118.0;

    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _entryController,
            _waitingExitController,
            _stampController,
          ]),
          builder: (context, _) {
            final entryProgress = Curves.easeOutCubic.transform(
              _entryController.value,
            );
            final shake = _cameraShake(_stampController.value);

            return Opacity(
              opacity: entryProgress,
              child: Transform.scale(
                scale: 0.96 + (0.04 * entryProgress),
                child: Transform.translate(
                  offset: shake,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildWaitingTitle(),
                      const SizedBox(height: 14),
                      _StampedProfile(
                        player: widget.player,
                        size: profileSize,
                        stampProgress: _stampController.value,
                        result: widget.result,
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          widget.player?.nickname ?? '플레이어',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 10),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWaitingTitle() {
    final progress = Curves.easeInCubic.transform(_waitingExitController.value);
    return Opacity(
      opacity: 1 - progress,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: 7 * progress,
          sigmaY: 7 * progress,
        ),
        child: const FadeHoldFade(
          duration: Duration(milliseconds: 2500),
          child: Text('벌칙 진행 중', style: _PenaltyTextStyle.title),
        ),
      ),
    );
  }

  Offset _cameraShake(double value) {
    if (value < 0.30 || value > 0.332) return Offset.zero;
    final local = (value - 0.30) / 0.032;
    final strength = (1 - local) * 2;
    return Offset(
      math.sin(local * math.pi * 6) * strength,
      math.cos(local * math.pi * 4) * strength * 0.5,
    );
  }
}

class _StampedProfile extends StatelessWidget {
  const _StampedProfile({
    required this.player,
    required this.size,
    required this.stampProgress,
    required this.result,
  });

  final PhoneGamePlayer? player;
  final double size;
  final double stampProgress;
  final String? result;

  @override
  Widget build(BuildContext context) {
    //=======================1인칭 스탬프 타임라인==============================
    // 0.00~0.30: 카메라 가까이의 큰 도장이 프로필 방향으로 깊게 접근합니다.
    // 0.30~0.332: 약 50ms 충돌 hit-stop입니다.
    // 0.30~0.743: 정확히 약 0.7초 동안 프로필에 눌린 채 유지됩니다.
    // 0.743~1.00: 도장이 다시 카메라 쪽으로 빠지며 사라집니다.
    final approachProgress = (stampProgress / 0.30).clamp(0.0, 1.0);
    final retreatProgress = ((stampProgress - 0.743) / 0.257).clamp(0.0, 1.0);
    final easedApproach = Curves.easeInCubic.transform(approachProgress);
    final easedRetreat = Curves.easeInCubic.transform(retreatProgress);
    final hasHit = stampProgress >= 0.30;

    // 카메라 앞에서는 크고 기울어진 상태이며, 접촉 시 정면으로 평평해집니다.
    final stampScale = stampProgress < 0.30
        ? 1.72 - (0.72 * easedApproach)
        : 1.0 + (0.62 * easedRetreat);
    final stampTilt = stampProgress < 0.30
        ? -0.58 * (1 - easedApproach)
        : -0.38 * easedRetreat;
    final stampOffsetY = stampProgress < 0.30
        ? -54 * (1 - easedApproach)
        : -42 * easedRetreat;
    final stampOpacity = stampProgress < 0.743
        ? 1.0
        : 1 - Curves.easeInCubic.transform(retreatProgress);
    final isEliminated = result == 'eliminated';
    final stampLabel = isEliminated ? 'FAIL' : 'SURVIVED';
    final stampColor = isEliminated
        ? const Color(0xFFD51119)
        : const Color(0xFF2EBD68);

    final profile = player == null
        ? _ProfileFallback(size: size)
        : PhonePlayerProfile(player: player!, size: size);

    return SizedBox(
      width: size * 1.82,
      height: size * 1.25,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          profile,
          if (hasHit)
            Transform.rotate(
              angle: -0.10,
              child: _ResultInkMark(
                size: size,
                label: stampLabel,
                color: stampColor,
              ),
            ),
          if (stampProgress > 0 && stampProgress < 1)
            Transform.translate(
              offset: Offset(0, stampOffsetY),
              child: Opacity(
                opacity: stampOpacity,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0018)
                    ..rotateX(stampTilt)
                    ..scaleByDouble(stampScale, stampScale, 1, 1),
                  child: Assets.games.liarsPoker.images.other.stamp.image(
                    width: size * 1.82,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 화면에 남는 잉크 자국입니다. 살짝 번진 이중 선으로 고무 도장의 질감을 냅니다.
class _ResultInkMark extends StatelessWidget {
  const _ResultInkMark({
    required this.size,
    required this.label,
    required this.color,
  });

  final double size;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.62,
      height: size * 0.58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 4.5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: color.withAlpha(85), blurRadius: 2, spreadRadius: 1),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(1.2, 0.8),
            child: Text(label, style: _stampTextStyle(color.withAlpha(102))),
          ),
          Text(label, style: _stampTextStyle(color)),
        ],
      ),
    );
  }

  TextStyle _stampTextStyle(Color textColor) {
    return TextStyle(
      color: textColor,
      fontFamily: 'BebasNeue',
      fontSize: label == 'FAIL' ? 40 : 33,
      height: 1,
      fontWeight: FontWeight.w900,
      letterSpacing: label == 'FAIL' ? 2 : 1.4,
    );
  }
}

class _ProfileFallback extends StatelessWidget {
  const _ProfileFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Icon(Icons.person, color: Colors.white, size: size * 0.4),
    );
  }
}

abstract final class _PenaltyTextStyle {
  static const title = TextStyle(
    fontFamily: 'BebasNeue',
    color: Colors.white,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    shadows: [Shadow(color: Colors.black, blurRadius: 12)],
  );
}
