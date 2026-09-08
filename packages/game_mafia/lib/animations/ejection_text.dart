import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

//=======================추방 발표 글자==============================
/// 안내 문구를 **내려찍듯이** 띄웁니다(확정 2026-08).
///
/// 어몽어스의 추방 발표(`○○ was ejected`) 글자 연출을 기준으로 삼았습니다.
/// 네 박자로 이루어집니다.
///
/// 1. **내려찍기** — 글자가 크고 넓게 벌어진 채 투명하게 나타나, 제자리
///    크기·자간으로 빠르게 좁혀 들어옵니다([slamDuration]).
/// 2. **충격** — 찍힌 직후 좌우로 짧게 흔들리며 잦아듭니다([impactDuration]).
/// 3. **머무르기** — [beatHold] 동안 읽을 시간을 줍니다.
/// 4. **퇴장** — 살짝 커지며 자간이 벌어지고 사라집니다([exitDuration]).
///
/// [beats]에 문구를 여러 개 주면 **한 자리에서 차례로** 찍습니다. 확정(2026-08):
/// 너무 긴 문장은 두 박자로 나눠 띄웁니다. 예를 들어
/// `'가나님은 밤을 넘기지 못했습니다'`는 `['가나님은', '밤을 넘기지 못했습니다']`가
/// 됩니다. 한 번에 다 읽히지 않는 긴 줄보다 짧은 두 방이 훨씬 세게 박힙니다.
///
/// 나눠 찍을 때는 전체 박자가 [multiBeatSpeed]배 **빠르게** 지나갑니다. 같은
/// 속도로 두 번 찍으면 한 문장을 읽는 데 두 배가 걸려 늘어집니다.
///
/// **마지막 박자는 물러나지 않습니다.** 그 자리에 남아 있고, 화면을 걷어 가는
/// 것은 부모(단계 전환·[MafiaAnnouncementReveal])의 몫입니다.
class MafiaEjectionText extends StatefulWidget {
  const MafiaEjectionText({
    super.key,
    required this.beats,
    required this.style,
    this.textAlign = TextAlign.center,
    this.beatHold = defaultBeatHold,
  });

  /// 차례로 내려찍을 문구들입니다. 하나면 한 번 찍고 그대로 남습니다.
  final List<String> beats;

  /// 글자 모양입니다. 자간은 이 연출이 정하므로 넣어도 무시됩니다.
  final TextStyle style;

  final TextAlign textAlign;

  /// 마지막이 아닌 박자가 머무는 시간입니다.
  final Duration beatHold;

  //=======================연출 시간==============================
  /// 글자가 제자리로 내려찍히는 시간입니다.
  static const Duration slamDuration = Duration(milliseconds: 300);

  /// 찍힌 뒤 흔들림이 잦아드는 시간입니다.
  static const Duration impactDuration = Duration(milliseconds: 180);

  /// 다음 박자에 자리를 넘기며 물러나는 시간입니다.
  static const Duration exitDuration = Duration(milliseconds: 240);

  /// 마지막이 아닌 박자가 머무는 기본 시간입니다.
  static const Duration defaultBeatHold = Duration(milliseconds: 1500);

  /// 처음 크기 배율입니다. 1.7배로 나타나 1배로 찍힙니다.
  static const double startScale = 1.7;

  /// 처음 자간입니다(글자 크기 대비). 벌어진 글자가 좁혀지며 모입니다.
  static const double startTracking = 0.3;

  /// 두 박자 이상으로 나눠 찍을 때의 배속입니다.
  ///
  /// 확정(2026-08): 긴 문장을 두 박자로 나누면 읽는 호흡이 두 번 필요해 전체가
  /// 늘어집니다. 나눠 찍을 때만 조금 빠르게 지나가 한 문장을 읽는 것과 비슷한
  /// 호흡을 유지합니다. 한 박자짜리 문구의 속도는 그대로입니다.
  static const double multiBeatSpeed = 1.25;

  /// 박자 수에 맞춘 실제 연출 시간입니다. 나눠 찍을 때만 빨라집니다.
  static Duration scaledFor(Duration duration, int beatCount) {
    if (beatCount <= 1) return duration;
    return Duration(
      microseconds: (duration.inMicroseconds / multiBeatSpeed).round(),
    );
  }

  /// 박자 하나가 다음 박자로 넘어가기까지 걸리는 시간입니다.
  ///
  /// 부모가 주는 시간 안에 박자가 다 들어가는지 계산할 때 씁니다. 넘어가는
  /// 구간은 나눠 찍을 때만 생기므로 항상 배속이 적용됩니다.
  static Duration beatCycle(Duration beatHold) =>
      scaledFor(slamDuration + impactDuration + beatHold + exitDuration, 2);

  /// [beats]를 모두 찍는 데 걸리는 시간입니다(마지막 박자가 찍히는 순간까지).
  static Duration totalCycle(int beatCount, Duration beatHold) =>
      beatCycle(beatHold) * (beatCount - 1) +
      scaledFor(slamDuration + impactDuration, beatCount);

  @override
  State<MafiaEjectionText> createState() => _MafiaEjectionTextState();
}

class _MafiaEjectionTextState extends State<MafiaEjectionText>
    with TickerProviderStateMixin {
  /// 내려찍기 + 충격을 한 컨트롤러로 돌립니다. 흔들림이 찍힌 순간에 정확히
  /// 이어져야 해서 둘을 나누면 프레임이 어긋납니다.
  late final AnimationController _slam;
  late final AnimationController _exit;
  Timer? _holdTimer;

  /// 지금 찍고 있는 박자입니다.
  int _index = 0;

  /// 나눠 찍는 문구인지입니다. 박자가 둘 이상이면 전체가 빨라집니다.
  int get _beatCount => widget.beats.length;

  /// 내려찍기 전체에서 '찍히는' 구간이 차지하는 비율입니다.
  static double get _slamRatio =>
      MafiaEjectionText.slamDuration.inMilliseconds /
      (MafiaEjectionText.slamDuration + MafiaEjectionText.impactDuration)
          .inMilliseconds;

  bool get _isLastBeat => _index >= widget.beats.length - 1;

  @override
  void initState() {
    super.initState();
    _slam = AnimationController(
      vsync: this,
      duration: MafiaEjectionText.scaledFor(
        MafiaEjectionText.slamDuration + MafiaEjectionText.impactDuration,
        _beatCount,
      ),
    )..addStatusListener(_handleSlamStatus);
    _exit = AnimationController(
      vsync: this,
      duration: MafiaEjectionText.scaledFor(
        MafiaEjectionText.exitDuration,
        _beatCount,
      ),
    )..addStatusListener(_handleExitStatus);
    _playCurrentBeat();
  }

  @override
  void didUpdateWidget(MafiaEjectionText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 문구가 갈리면(닉네임이 바뀌는 등) 처음 박자부터 다시 찍습니다.
    if (listEquals(widget.beats, oldWidget.beats)) return;
    // 박자 수가 바뀌면 배속도 달라집니다.
    if (widget.beats.length != oldWidget.beats.length) {
      _slam.duration = MafiaEjectionText.scaledFor(
        MafiaEjectionText.slamDuration + MafiaEjectionText.impactDuration,
        _beatCount,
      );
      _exit.duration = MafiaEjectionText.scaledFor(
        MafiaEjectionText.exitDuration,
        _beatCount,
      );
    }
    _index = 0;
    _playCurrentBeat();
  }

  void _playCurrentBeat() {
    _holdTimer?.cancel();
    _exit.value = 0;
    _slam.forward(from: 0);
  }

  void _handleSlamStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    // 마지막 박자는 물러나지 않습니다. 부모가 화면을 걷어 갑니다.
    if (_isLastBeat) return;
    _holdTimer = Timer(
      MafiaEjectionText.scaledFor(widget.beatHold, _beatCount),
      () {
        if (mounted) _exit.forward(from: 0);
      },
    );
  }

  void _handleExitStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _index += 1);
    _playCurrentBeat();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _slam
      ..removeStatusListener(_handleSlamStatus)
      ..dispose();
    _exit
      ..removeStatusListener(_handleExitStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.beats.isEmpty) return const SizedBox.shrink();
    final text = widget.beats[_index.clamp(0, widget.beats.length - 1)];
    final fontSize = widget.style.fontSize ?? 24;

    return AnimatedBuilder(
      animation: Listenable.merge([_slam, _exit]),
      builder: (context, _) {
        final progress = _slam.value;

        // 1·2박자: 크고 넓게 벌어진 글자가 제자리로 찍히고, 그 충격으로
        // 짧게 흔들립니다.
        final slammed = Curves.easeOutQuart.transform(
          (progress / _slamRatio).clamp(0.0, 1.0),
        );
        final appearing = (progress / (_slamRatio * 0.45)).clamp(0.0, 1.0);
        final impact = ((progress - _slamRatio) / (1 - _slamRatio)).clamp(
          0.0,
          1.0,
        );
        // 잦아드는 좌우 흔들림입니다. 무작위가 아니라 정해진 파형이라
        // 같은 문구가 늘 같게 흔들립니다.
        final shake = impact <= 0 || impact >= 1
            ? 0.0
            : math.sin(impact * math.pi * 5) * (1 - impact) * fontSize * 0.07;

        // 4박자: 살짝 커지며 자간이 벌어지고 사라집니다.
        final leaving = Curves.easeIn.transform(_exit.value);

        final scale =
            (1 + (MafiaEjectionText.startScale - 1) * (1 - slammed)) *
            (1 + 0.06 * leaving);
        final tracking =
            fontSize *
            (MafiaEjectionText.startTracking * (1 - slammed) + 0.1 * leaving);

        return Opacity(
          opacity: (appearing * (1 - leaving)).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(shake, 0),
            child: Transform.scale(
              scale: scale,
              // 닉네임이 길어도 한 줄을 지킵니다(모든 안내 문구 공통).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  textAlign: widget.textAlign,
                  style: widget.style.copyWith(letterSpacing: tracking),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
