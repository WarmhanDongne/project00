import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================밤 화면의 새==============================
/// 밤 화면을 가로지르는 새입니다.
///
/// 화면을 **오른쪽에서 왼쪽으로** 날아가며 날갯짓합니다. 계속 나오면 배경이
/// 시끄러워지므로 **한참 뜸을 들이고 한 번씩** 지나갑니다. 지나가는 높이도
/// 매번 달라져 같은 궤도를 반복하지 않습니다.
///
/// 새 프레임 4장은 같은 캔버스(1536 × 1024)에 그려진 투명 이미지입니다. 그래서
/// 네 장을 **같은 자리에 겹쳐** 그리면 날개만 움직이고 몸은 흔들리지 않습니다.
class MafiaTabletNightBird extends StatefulWidget {
  const MafiaTabletNightBird({super.key});

  /// 다음 새가 나오기까지 기다리는 시간의 범위입니다.
  ///
  /// 너무 자주 나오면 시선을 계속 끌어 밤 화면이 산만해집니다.
  static const Duration minGap = Duration(seconds: 14);
  static const Duration maxGap = Duration(seconds: 34);

  /// 화면을 한 번 가로지르는 데 걸리는 시간입니다.
  static const Duration crossDuration = Duration(seconds: 7);

  /// 날개 한 장이 바뀌는 간격입니다.
  static const Duration flapInterval = Duration(milliseconds: 140);

  /// 새가 그려지는 폭입니다(시안 좌표 기준). 캔버스 폭이라 실제 몸통은 이보다
  /// 작게 보입니다.
  static const double canvasWidth = 320;

  /// 새가 지나갈 수 있는 높이 범위입니다(시안 좌표 기준).
  static const double minTop = 40;
  static const double maxTop = 300;

  @override
  State<MafiaTabletNightBird> createState() => _MafiaTabletNightBirdState();
}

class _MafiaTabletNightBirdState extends State<MafiaTabletNightBird>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();
  late final AnimationController _cross;
  Timer? _nextTimer;
  Timer? _flapTimer;

  /// 이번에 지나갈 높이입니다. 매번 새로 뽑습니다.
  double _top = MafiaTabletNightBird.minTop;
  int _frame = 0;
  bool _isFlying = false;

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
    _flapTimer?.cancel();
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
        _isFlying = true;
      });
      _cross.forward(from: 0);
      _startFlapping();
    });
  }

  void _startFlapping() {
    _flapTimer?.cancel();
    _flapTimer = Timer.periodic(MafiaTabletNightBird.flapInterval, (_) {
      if (!mounted) return;
      setState(() => _frame = (_frame + 1) % 4);
    });
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    _flapTimer?.cancel();
    _cross
      ..removeStatusListener(_handleCrossStatus)
      ..dispose();
    super.dispose();
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
    const width = MafiaTabletNightBird.canvasWidth;
    // 캔버스 비율(1536 : 1024)을 지켜야 날개가 찌그러지지 않습니다.
    const height = width * 1024 / 1536;

    return AnimatedBuilder(
      animation: _cross,
      builder: (context, _) {
        // 오른쪽 화면 밖에서 왼쪽 화면 밖까지 지나갑니다.
        final left =
            MafiaTabletDesign.size.width -
            (MafiaTabletDesign.size.width + width) * _cross.value;
        return MafiaTabletBox(
          rect: Rect.fromLTWH(left, _top, width, height),
          child: frames[_frame].image(
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        );
      },
    );
  }
}
