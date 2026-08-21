import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================밤 화면의 까마귀==============================
/// 밤 화면을 가로지르는 까마귀입니다.
///
/// 화면을 **오른쪽에서 왼쪽으로** 지나갑니다. 계속 나오면 배경이 시끄러워지므로
/// **한참 뜸을 들이고 한 번씩** 지나가고, 높이·속도·크기가 매번 달라집니다.
///
/// 날개 그림 4장은 같은 캔버스(1536 × 1024)에 그려진 투명 이미지입니다.
/// 0 = 날개를 완전히 든 자세, 3 = 활짝 펼친 활공 자세입니다.
///
/// 자연스럽게 보이도록 네 가지를 지킵니다(2026-08 개선):
///
/// 1. **왕복 날갯짓** — 0→3으로 갔다가 되돌아옵니다. 0→3→0으로 잇는 예전
///    방식은 되돌아가는 순간 날개가 순간이동해 딱딱해 보였습니다.
/// 2. **사이 프레임 섞기** — 인접한 두 장을 겹쳐 그려(투명도 보간) 4장으로도
///    끊김 없이 이어지게 합니다. 날개 끝이 번지며 잔상처럼 보입니다.
/// 3. **날갯짓 → 활공 반복** — 까마귀는 몇 번 젓고 잠깐 활공합니다.
///    쉬는 동안에는 펼친 자세(3)로 고정됩니다.
/// 4. **반동과 곡선 궤도** — 날개를 들 때 몸이 살짝 내려앉고, 지나가는 길도
///    완만한 곡선입니다. 직선 등속으로 지나가면 종이 인형처럼 보입니다.
class MafiaTabletNightBird extends StatefulWidget {
  const MafiaTabletNightBird({super.key});

  /// 다음 까마귀가 나오기까지 기다리는 시간의 범위입니다.
  ///
  /// 너무 자주 나오면 시선을 계속 끌어 밤 화면이 산만해집니다.
  static const Duration minGap = Duration(seconds: 14);
  static const Duration maxGap = Duration(seconds: 34);

  /// 화면을 한 번 가로지르는 데 걸리는 시간입니다(느린 쪽 기준).
  ///
  /// 실제 시간은 매번 이 값의 70~100% 사이에서 뽑습니다.
  static const Duration crossDuration = Duration(seconds: 9);

  /// 까마귀가 그려지는 폭입니다(시안 좌표 기준).
  ///
  /// 캔버스 폭이라 실제 몸통은 이보다 작게 보입니다. 매번 ±15% 안에서
  /// 달라져 멀고 가까운 느낌을 줍니다.
  static const double canvasWidth = 190;

  /// 까마귀가 지나갈 수 있는 높이 범위입니다(시안 좌표 기준).
  static const double minTop = 40;
  static const double maxTop = 300;

  //=======================날갯짓 리듬==============================
  /// 날개를 한 번 젓는 데 걸리는 시간입니다(까마귀는 초당 3회 정도 젓습니다).
  static const Duration flapCycle = Duration(milliseconds: 320);

  /// 한 번에 몇 번 젓고 활공에 들어가는지입니다.
  static const int flapsPerBurst = 3;

  /// 날갯짓 사이에 펼친 자세로 쉬는 시간입니다.
  static const Duration glideDuration = Duration(milliseconds: 900);

  /// 날개를 들 때 몸이 내려앉는 폭입니다(시안 좌표 기준).
  static const double bobAmplitude = 9;

  @override
  State<MafiaTabletNightBird> createState() => _MafiaTabletNightBirdState();
}

class _MafiaTabletNightBirdState extends State<MafiaTabletNightBird>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();
  late final AnimationController _cross;
  Timer? _nextTimer;

  bool _isFlying = false;

  //=======================이번 비행의 성질==============================
  // 지나갈 때마다 새로 뽑습니다. 같은 궤도를 반복하면 배경 장식이 아니라
  // 반복 재생처럼 보입니다.
  double _top = MafiaTabletNightBird.minTop;
  double _scale = 1;

  /// 지나가는 동안의 높이 변화입니다(양수면 내려가며 지나갑니다).
  double _drift = 0;

  /// 곡선 궤도의 굽은 정도와 시작 위상입니다.
  double _curve = 0;
  double _curvePhase = 0;

  /// 날갯짓 위상의 시작점입니다. 항상 같은 자세로 등장하지 않게 합니다.
  double _flapOffsetMs = 0;

  @override
  void initState() {
    super.initState();
    _cross = AnimationController(
      vsync: this,
      duration: MafiaTabletNightBird.crossDuration,
    )..addStatusListener(_handleCrossStatus);
    _scheduleNext(first: true);
  }

  void _handleCrossStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted) return;
    setState(() => _isFlying = false);
    _scheduleNext();
  }

  /// 다음 등장을 예약합니다. 간격은 매번 무작위입니다.
  void _scheduleNext({bool first = false}) {
    _nextTimer?.cancel();
    final span =
        MafiaTabletNightBird.maxGap.inMilliseconds -
        MafiaTabletNightBird.minGap.inMilliseconds;
    var wait = Duration(
      milliseconds:
          MafiaTabletNightBird.minGap.inMilliseconds + _random.nextInt(span),
    );
    // 밤이 시작된 직후에 바로 지나가면 놓치기 쉬워 조금 늦게 시작합니다.
    if (first) wait = wait ~/ 2;

    _nextTimer = Timer(wait, () {
      if (!mounted) return;
      setState(() {
        _top =
            MafiaTabletNightBird.minTop +
            _random.nextDouble() *
                (MafiaTabletNightBird.maxTop - MafiaTabletNightBird.minTop);
        // 멀리 나는 개체는 작고 느립니다.
        _scale = 0.85 + _random.nextDouble() * 0.3;
        _drift = (_random.nextDouble() - 0.5) * 90;
        _curve = 10 + _random.nextDouble() * 26;
        _curvePhase = _random.nextDouble() * pi * 2;
        _flapOffsetMs =
            _random.nextDouble() *
            MafiaTabletNightBird.flapCycle.inMilliseconds;
        _isFlying = true;
      });
      // 작은 개체가 더 느리게 지나가 원근이 느껴집니다.
      _cross.duration = Duration(
        milliseconds:
            (MafiaTabletNightBird.crossDuration.inMilliseconds *
                    (1.35 - _scale * 0.35))
                .round(),
      );
      _cross.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    _cross
      ..removeStatusListener(_handleCrossStatus)
      ..dispose();
    super.dispose();
  }

  //=======================날갯짓 계산==============================
  /// 날갯짓·활공 한 묶음의 길이입니다.
  int get _patternMs =>
      MafiaTabletNightBird.flapCycle.inMilliseconds *
          MafiaTabletNightBird.flapsPerBurst +
      MafiaTabletNightBird.glideDuration.inMilliseconds;

  /// 지금이 날갯짓 중이라면 그 한 번 안에서의 위치(0~1), 활공이면 null입니다.
  double? _flapPosition(double elapsedMs) {
    final position = (elapsedMs + _flapOffsetMs) % _patternMs;
    final burstMs =
        MafiaTabletNightBird.flapCycle.inMilliseconds *
        MafiaTabletNightBird.flapsPerBurst;
    if (position >= burstMs) return null;
    return (position % MafiaTabletNightBird.flapCycle.inMilliseconds) /
        MafiaTabletNightBird.flapCycle.inMilliseconds;
  }

  /// 날개를 얼마나 들었는지입니다(0 = 활짝 펼침, 1 = 완전히 든 자세).
  ///
  /// 드는 동작은 느리고(60%), 내려치는 동작은 빠릅니다(40%). 새는 내려칠 때
  /// 힘을 쓰기 때문에 이 비대칭이 있어야 살아 있는 느낌이 납니다.
  double _raise(double elapsedMs) {
    final position = _flapPosition(elapsedMs);
    // 활공 중에는 펼친 자세를 유지합니다.
    if (position == null) return 0;
    if (position < 0.6) {
      return Curves.easeInOut.transform(position / 0.6);
    }
    return 1 - Curves.easeIn.transform((position - 0.6) / 0.4);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isFlying) return const SizedBox.shrink();

    final bird = Assets.games.mafia.images.background.bird;
    final frames = [
      bird.nightBird0.game,
      bird.nightBird1.game,
      bird.nightBird2.game,
      bird.nightBird3.game,
    ];
    final width = MafiaTabletNightBird.canvasWidth * _scale;
    // 캔버스 비율(1536 : 1024)을 지켜야 날개가 찌그러지지 않습니다.
    final height = width * 1024 / 1536;

    return AnimatedBuilder(
      animation: _cross,
      builder: (context, _) {
        final progress = _cross.value;
        final elapsedMs = progress * _cross.duration!.inMilliseconds;
        final raise = _raise(elapsedMs);

        // 오른쪽 화면 밖에서 왼쪽 화면 밖까지 지나갑니다.
        final left =
            MafiaTabletDesign.size.width -
            (MafiaTabletDesign.size.width + width) * progress;
        // 높이: 완만한 곡선 + 전체적인 오르내림 + 날갯짓 반동.
        final top =
            _top +
            _drift * progress +
            _curve * sin(progress * pi * 1.3 + _curvePhase) +
            MafiaTabletNightBird.bobAmplitude * _scale * raise;

        return MafiaTabletBox(
          rect: Rect.fromLTWH(left, top, width, height),
          // 날개를 들 때 살짝 뒤로 젖혀집니다.
          child: Transform.rotate(
            angle: -0.07 * raise,
            child: _buildWings(frames, raise),
          ),
        );
      },
    );
  }

  /// 인접한 두 장을 겹쳐 그려 사이 자세를 만듭니다.
  ///
  /// [raise]가 0.4라면 3번과 2번 장 사이 어딘가입니다. 두 장을 각각 알맞은
  /// 투명도로 겹쳐 그리면 4장만으로도 날개가 이어져 움직입니다.
  Widget _buildWings(List<GameImage> frames, double raise) {
    // raise 0 → 3번(펼침), 1 → 0번(든 자세).
    final position = (1 - raise) * (frames.length - 1);
    final lower = position.floor().clamp(0, frames.length - 1);
    final upper = (lower + 1).clamp(0, frames.length - 1);
    final blend = position - lower;

    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 1 - blend,
          child: frames[lower].image(
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
        if (upper != lower && blend > 0)
          Opacity(
            opacity: blend,
            child: frames[upper].image(
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
      ],
    );
  }
}
