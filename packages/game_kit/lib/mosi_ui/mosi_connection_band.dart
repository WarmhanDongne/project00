// [mosi_connection_band.dart] 는 로비 화면 맨 아래에 서버 연결 상태를 알리는 띠를 그리는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 끊김 → 다시 연결 중 → 복구 세 단계를 한 줄 띠로 보여 줌
//
// 즉, 로비에서 연결이 흔들릴 때 화면을 막지 않고 상태만 확실하게 알리기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/recovery/widgets/connection_notice_host.dart';

export 'package:game_kit/recovery/widgets/connection_notice_host.dart'
    show ConnectionNoticePhase;

// ============================================================

/// 띠가 지금 무엇을 보여 주는지입니다(게임 LED 띠와 같은 단계).
typedef MosiConnectionBandPhase = ConnectionNoticePhase;

/// 띠에 들어갈 문구입니다. 앱이 언어에 맞춰 넘깁니다.
@immutable
class MosiConnectionBandLabels {
  const MosiConnectionBandLabels({
    required this.lost,
    required this.reconnecting,
    required this.restored,
  });

  final String lost;
  final String reconnecting;
  final String restored;
}

/// 로비 화면 맨 아래를 덮는 **가장자리 띠** 연결 알림입니다(시안 '서버 연결 알림' 2안).
///
/// 화면을 막지 않고 아래 한 줄만 덮습니다. 흐름은 다음과 같습니다.
///
/// 1. 연결이 끊기고 [graceDelay] 동안 돌아오지 않으면 빨간 '끊김' 띠가 올라옵니다.
///    잠깐 흔들렸다 바로 돌아오는 연결에는 띠를 띄우지 않습니다.
/// 2. [lostHold] 뒤에도 끊겨 있으면 노란 빗금 '다시 연결하는 중' 띠로 바뀝니다.
///    Firebase가 스스로 다시 잇는 동안 화면을 그대로 두라고 알립니다.
/// 3. 연결이 돌아오면 초록 '다시 연결됐어요'를 [restoredHold] 동안 보여 준 뒤 내려갑니다.
///
/// 띠는 게임 화면에는 쓰지 않습니다. 게임은 각자의 복구·중단 안내가 있습니다.
class MosiConnectionBandHost extends StatelessWidget {
  const MosiConnectionBandHost({
    super.key,
    required this.child,
    required this.connectionChanges,
    required this.labels,
    this.graceDelay = const Duration(milliseconds: 1500),
    this.lostHold = const Duration(seconds: 3),
    this.restoredHold = const Duration(seconds: 1),
  });

  final Widget child;

  /// 서버 연결 여부입니다(`.info/connected`). null이면 띠를 그리지 않습니다.
  final Stream<bool>? connectionChanges;
  final MosiConnectionBandLabels labels;
  final Duration graceDelay;
  final Duration lostHold;
  final Duration restoredHold;

  @override
  Widget build(BuildContext context) => ConnectionNoticeHost(
    connectionChanges: connectionChanges,
    graceDelay: graceDelay,
    lostHold: lostHold,
    restoredHold: restoredHold,
    builder: (context, phase, _) =>
        MosiConnectionBand(phase: phase, labels: labels),
    child: child,
  );
}

/// 띠 한 줄입니다. 아래 안전 영역까지 색이 채워집니다.
class MosiConnectionBand extends StatelessWidget {
  const MosiConnectionBand({
    super.key,
    required this.phase,
    required this.labels,
  });

  final MosiConnectionBandPhase phase;
  final MosiConnectionBandLabels labels;

  static const double height = 36;

  static const Color _lostColor = Color(0xFFEF5350);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final locale = Localizations.maybeLocaleOf(context);
    final (label, background, foreground, icon) = switch (phase) {
      MosiConnectionBandPhase.lost || MosiConnectionBandPhase.hidden => (
        labels.lost,
        _lostColor,
        MosiColors.white,
        Icons.wifi_off_rounded,
      ),
      MosiConnectionBandPhase.reconnecting => (
        labels.reconnecting,
        MosiColors.sun,
        MosiColors.ink,
        Icons.sync_rounded,
      ),
      MosiConnectionBandPhase.restored => (
        labels.restored,
        MosiColors.lime,
        MosiColors.ink,
        Icons.check_rounded,
      ),
    };
    final striped = phase == MosiConnectionBandPhase.reconnecting;
    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        color: background,
        foregroundDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: MosiColors.ink, width: 3)),
        ),
        child: Stack(
          children: [
            if (striped) const Positioned.fill(child: _MarchingStripes()),
            Padding(
              padding: EdgeInsets.only(top: 3, bottom: bottomInset),
              child: SizedBox(
                height: height,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          striped
                              ? _SpinningIcon(icon: icon, color: foreground)
                              : Icon(icon, size: 18, color: foreground),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            maxLines: 1,
                            style: MosiFonts.sans(
                              locale: locale,
                              size: 14,
                              weight: FontWeight.w700,
                              color: foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 다시 연결 중 띠의 빗금입니다. 천천히 옆으로 흘러 멈춘 화면이 아님을 알립니다.
class _MarchingStripes extends StatefulWidget {
  const _MarchingStripes();

  @override
  State<_MarchingStripes> createState() => _MarchingStripesState();
}

class _MarchingStripesState extends State<_MarchingStripes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _march = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _march.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _march,
    builder: (context, _) => CustomPaint(painter: _StripePainter(_march.value)),
  );
}

class _StripePainter extends CustomPainter {
  const _StripePainter(this.progress);

  final double progress;

  static const double _period = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x2E111111);
    final shift = progress * _period;
    for (
      var x = -size.height - _period;
      x < size.width + _period;
      x += _period
    ) {
      final left = x + shift;
      canvas.drawPath(
        Path()
          ..moveTo(left, size.height)
          ..lineTo(left + 10, size.height)
          ..lineTo(left + 10 + size.height, 0)
          ..lineTo(left + size.height, 0)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SpinningIcon extends StatefulWidget {
  const _SpinningIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _spin,
    builder: (context, child) =>
        Transform.rotate(angle: -_spin.value * 2 * math.pi, child: child),
    child: Icon(widget.icon, size: 18, color: widget.color),
  );
}
