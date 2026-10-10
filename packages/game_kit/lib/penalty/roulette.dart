// [roulette.dart] 는 여러 게임이 함께 사용하는 패널티 룰렛의 상태와 회전 결과를 표현하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Roulette] : 패널티 룰렛의 상태와 회전 결과를 표현함
//
// 즉, 룰렛 연출과 서버 결과를 같은 값으로 연결하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_kit/core/diagnostics/game_communication_log.dart';
import 'package:game_kit/sound/app_sounds.dart';
import 'package:game_kit/sound/providers/sound_provider.dart';
import 'package:game_kit/sound/sound_effects.dart';
import 'package:roulette/roulette.dart';

// ============================================================

enum RouletteResult { safe, eliminated }

class PenaltyRoulette extends StatefulWidget {
  const PenaltyRoulette({
    super.key,
    required this.attemptCount,
    required this.onPrepareResult,
    required this.onResult,
    this.centerCharacterId,
  });

  final int attemptCount;
  final Future<RouletteResult?> Function() onPrepareResult;
  final ValueChanged<RouletteResult> onResult;
  final String? centerCharacterId;

  @override
  State<PenaltyRoulette> createState() => _PenaltyRouletteState();
}

class _PenaltyRouletteState extends State<PenaltyRoulette>
    with SingleTickerProviderStateMixin {
  /// ============================================================
  /// 기준 디자인 사이즈
  ///
  /// 정사각형 1000 × 1000 캔버스를 기준으로 전체 룰렛 UI가 같은 비율로
  /// 확대/축소됩니다. 정사각형이라 게임이 대상 플레이어 쪽으로 통째로
  /// 돌려도 잘리지 않습니다. 포인터와 레버는 캔버스 위쪽(대상 쪽)에 있습니다.
  /// ============================================================
  static const double _designWidth = 1000;
  static const double _designHeight = 1000;

  static const List<bool> _firstAttemptSections = [
    true,
    false,
    false,
    false,
    true,
    false,
    false,
    false,
    true,
    false,
    false,
    false,
    true,
    false,
    false,
    false,
  ];
  static const List<bool> _secondAttemptSections = [
    true,
    false,
    false,
    true,
    false,
    false,
    true,
    false,
    false,
    true,
    false,
    false,
    true,
    false,
    false,
  ];
  static const List<bool> _finalAttemptSections = [
    false,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
  ];

  final RouletteController _controller = RouletteController();
  final math.Random _random = math.Random.secure();

  bool _isSpinning = false;
  bool _isLeverLocked = false;
  bool _isLeverDragActive = false;

  late final AnimationController _leverController;
  late RouletteGroup _group;

  /// 서버 응답이 빠를 때의 전체 연출 시간입니다. 효과음 재생 구간도 함께 늘어납니다.
  /// 길게 설정할수록 마지막 칸을 천천히 지나는 시간이 늘어납니다.
  static const Duration _spinDuration = Duration(seconds: 6);

  /// 서버 결과를 기다리는 동안 한 바퀴에 걸리는 시간입니다.
  /// 300ms = 초당 약 3.3바퀴입니다(기존 125ms = 초당 8바퀴).
  /// 값을 늘리면 시작 속도가 느려집니다. 가속 구간 없이 이 속도로 시작합니다.
  static const Duration _fastSpinPeriod = Duration(milliseconds: 300);

  /// 서버가 늦게 응답해도 마지막 감속을 급하게 압축하지 않습니다.
  /// 이 경우 전체 회전은 6초보다 길어질 수 있습니다. 결과 수신 후 최소 4초 동안
  /// 감속하며, 네트워크 지연 중에는 클라이언트가 임의의 결과 칸에 멈추지 않습니다.
  static const Duration _minimumSettleDuration = Duration(seconds: 4);

  /// dispose에서도 사운드를 멈춰야 해서 미리 잡아 둡니다.
  SoundProvider? _sound;

  @override
  void initState() {
    super.initState();

    _leverController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          setState(() {});
        });
    _group = _createGroup(_sections);
  }

  @override
  void didUpdateWidget(covariant PenaltyRoulette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attemptCount != widget.attemptCount) {
      _group = _createGroup(_sections);
    }
  }

  // ============================================================
  // 레버
  // ============================================================

  void _onLeverDragStart(DragStartDetails details) {
    if (_isLeverLocked || _isSpinning) return;

    /// GestureDetector 자체도 1000 × 1000 기준 캔버스와
    /// 같이 스케일링되기 때문에 이 좌표를 기기별로
    /// 다시 계산할 필요가 없습니다. 레버 손잡이의 처음 중심입니다.
    const initialHeadCenter = Offset(
      RouletteWheel.leverGestureWidth / 2,
      RouletteWheel.leverHeadTop + RouletteWheel.leverHeadSize / 2,
    );

    _isLeverDragActive =
        (details.localPosition - initialHeadCenter).distance <= 200;
  }

  void _onLeverDragUpdate(DragUpdateDetails details) {
    if (!_isLeverDragActive || _isLeverLocked || _isSpinning) {
      return;
    }

    final nextValue =
        _leverController.value + (details.delta.dy / RouletteWheel.leverTravel);

    _leverController.value = nextValue.clamp(0.0, 1.0).toDouble();
  }

  Future<void> _onLeverDragEnd(DragEndDetails details) async {
    if (!_isLeverDragActive || _isLeverLocked || _isSpinning) {
      return;
    }

    _isLeverDragActive = false;

    if (_leverController.value < 0.75) {
      await _leverController.reverse();
      return;
    }

    _isLeverLocked = true;

    // 레버가 잠기는 순간에 재생합니다. 이어지는 회전 효과음과 짧게 겹치면서
    // 레버를 내려 원판이 돌기 시작하는 흐름으로 들립니다.
    SoundEffects.play(context, AppSounds.lever);

    await _leverController.animateTo(1, curve: Curves.easeOutCubic);

    if (!mounted) return;

    await _spin();
  }

  // ============================================================
  // 룰렛 확률
  // ============================================================

  /// true  = 탈락
  /// false = 생존
  /// 회차별 탈락 확률은 고정 목록을 재사용합니다. 각 불 프레임마다
  /// 같은 불 목록을 다시 만들 필요가 없습니다.
  List<bool> get _sections => switch (widget.attemptCount) {
    0 => _firstAttemptSections,
    1 => _secondAttemptSections,
    _ => _finalAttemptSections,
  };

  RouletteGroup _createGroup(List<bool> sections) {
    return RouletteGroup.uniform(
      sections.length,
      colorBuilder: (index) {
        final isEliminated = sections[index];

        if (isEliminated) return const Color(0xFFE0243A);
        return index.isEven ? const Color(0xFF24152E) : const Color(0xFF34204A);
      },
      textBuilder: (_) => '',
    );
  }

  // ============================================================
  // 룰렛 실행
  // ============================================================

  Future<void> _spin() async {
    if (_isSpinning) return;

    GameCommunicationLog.instance.add(
      level: GameCommunicationLevel.info,
      title: '룰렛 시작',
      detail: '원판을 바로 돌리며 서버 추첨 결과를 기다립니다.',
      operation: 'liars_poker_roulette',
    );
    setState(() {
      _isSpinning = true;
    });

    // 룰렛 사운드는 파일이 회전보다 깁니다. 뒤를 끊으면 멈추는 순간의 소리와
    // 여운이 사라지므로, 앞부분을 건너뛰어 회전이 끝나는 시점에 소리도
    // 자연스럽게 끝나도록 맞춥니다. 정지는 화면이 사라질 때만 합니다.
    _sound?.playSustainedEffect(AppSounds.roulette, window: _spinDuration);

    // 서버가 추첨할 때까지 원판을 멈춰 두면 네트워크 응답 시간이 그대로
    // 레버 지연으로 보입니다. 처음부터 빠른 일정 속도로 회전하고, 서버 결과가
    // 오면 이 속도를 넘지 않는 회전 수로 감속합니다. 결과를 기다리는 동안에는
    // 임의의 칸에서 멈추거나 클라이언트가 생존/탈락을 결정하지 않습니다.
    final spinElapsed = Stopwatch()..start();
    unawaited(
      _controller.rollInfinitely(period: _fastSpinPeriod, curve: Curves.linear),
    );

    final result = await widget.onPrepareResult();
    if (!mounted) return;
    if (result == null) {
      spinElapsed.stop();
      _controller.stop();
      GameCommunicationLog.instance.add(
        level: GameCommunicationLevel.failure,
        title: '룰렛 추첨 중단',
        detail: '서버 추첨 결과를 받지 못해 레버 잠금을 풀었습니다.',
        operation: 'liars_poker_roulette',
      );
      setState(() {
        _isSpinning = false;
        _isLeverLocked = false;
      });
      unawaited(_leverController.reverse());
      return;
    }

    spinElapsed.stop();
    GameCommunicationLog.instance.add(
      level: GameCommunicationLevel.success,
      title: '룰렛 추첨 결과 수신',
      detail:
          '결과=${result.name} · 응답 ${spinElapsed.elapsedMilliseconds}ms · '
          '목표 칸 감속 시작',
      operation: 'liars_poker_roulette',
    );

    final sections = _sections;
    final shouldEliminate = result == RouletteResult.eliminated;
    final matchingIndexes = <int>[
      for (var index = 0; index < sections.length; index++)
        if (sections[index] == shouldEliminate) index,
    ];
    final selectedIndex =
        matchingIndexes[_random.nextInt(matchingIndexes.length)];

    final remaining = _spinDuration - spinElapsed.elapsed;
    final settleDuration = remaining > _minimumSettleDuration
        ? remaining
        : _minimumSettleDuration;

    // 기본 12바퀴를 고정하면 서버 응답이 늦을수록 짧은 시간에 더 빨리 돌아
    // '느림 → 급가속 → 감속'이 됩니다. 감속 구간의 시작 속도가 대기 회전보다
    // 빨라지지 않도록, 남은 시간과 시작 속도에 맞춰 회전 수를 제한합니다.
    // 전용 감속 곡선의 최대 기울기는 시작점의 3입니다. 목표 칸까지의
    // 추가 각도(최대 한 바퀴)도 예산에 포함하려고 계산값에서 1을 뺍니다.
    final settleCircles = math.max(
      1,
      (settleDuration.inMicroseconds /
                  (_fastSpinPeriod.inMicroseconds *
                      _SuspenseDecelerationCurve.initialSlope))
              .floor() -
          1,
    );

    final completed = await _controller.rollTo(
      selectedIndex,
      minRotateCircles: settleCircles,
      offset: 0.15 + (_random.nextDouble() * 0.7),
      animationConfig: CurveAnimationConfig(
        duration: settleDuration,
        // 중반부터 확실히 감속하고 마지막에는 몇 칸을 천천히 지나갑니다.
        // 가짜 정지/재가속 없이 끝까지 같은 방향으로 서버 결과 칸에 도착합니다.
        curve: const _SuspenseDecelerationCurve(),
      ),
    );

    if (!mounted) return;

    setState(() {
      _isSpinning = false;
    });

    if (!completed) {
      // 회전이 완료 신호 없이 끝나면(중단·취소) 레버를 되돌려 다시 당길 수
      // 있게 합니다. 잠금을 유지하면 결과가 전송되지 않아 벌칙 단계가
      // 영구히 멈춥니다.
      setState(() => _isLeverLocked = false);
      unawaited(_leverController.reverse());
      GameCommunicationLog.instance.add(
        level: GameCommunicationLevel.warning,
        title: '룰렛 회전 취소',
        detail: '애니메이션 완료 신호가 없어 결과 반영 요청을 보내지 않았습니다.',
        operation: 'liars_poker_roulette',
      );
      return;
    }

    GameCommunicationLog.instance.add(
      level: GameCommunicationLevel.info,
      title: '룰렛 회전 완료',
      detail: '서버에 결과 반영 요청을 전달합니다.',
      operation: 'liars_poker_roulette',
    );
    widget.onResult(result);
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,

          /// ------------------------------------------------------
          /// 핵심
          ///
          /// 내부 UI는 무조건 1300 × 900으로 제작하고
          /// 실제 iPad 크기에 맞춰 전체를 한꺼번에
          /// 확대/축소합니다.
          ///
          /// 따라서 iPad mini / 11 / 13인치에서도
          /// 내부 요소들의 상대적인 크기와 위치가 같습니다.
          /// ------------------------------------------------------
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: SizedBox(
              width: _designWidth,
              height: _designHeight,
              child: _buildDesignCanvas(),
            ),
          ),
        );
      },
    );
  }

  /// ============================================================
  /// 1300 × 900 기준 디자인 캔버스
  /// ============================================================

  Widget _buildDesignCanvas() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        /// 룰렛 · 포인터 · 레버
        Positioned.fill(
          child: RouletteWheel(
            controller: _controller,
            group: _group,
            leverProgress: _leverController.value,
            centerCharacterId: widget.centerCharacterId,
          ),
        ),

        /// ========================================================
        /// 레버 터치 영역
        ///
        /// 이것도 디자인 캔버스 내부에 있기 때문에
        /// 룰렛과 함께 동일한 비율로 스케일됩니다.
        /// ========================================================
        Positioned(
          left: RouletteWheel.leverLeft - 50,
          top: 0,
          width: RouletteWheel.leverGestureWidth,
          height: RouletteWheel.leverGestureHeight,
          child: IgnorePointer(
            ignoring: _isLeverLocked || _isSpinning,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: _onLeverDragStart,
              onVerticalDragUpdate: _onLeverDragUpdate,
              onVerticalDragEnd: _onLeverDragEnd,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sound ??= SoundEffects.of(context);
  }

  @override
  void dispose() {
    // 회전 도중 화면이 사라져도 17초짜리 사운드가 남지 않도록 정지시킵니다.
    _sound?.stopSustainedEffect();
    _leverController.dispose();
    _controller.dispose();

    super.dispose();
  }
}

/// 진행률 1 - (1 - t)³: 속도가 3(1 - t)²로 줄어드는 감속 전용 곡선입니다.
///
/// 기본 6초 연출에서 마지막 2초에 이동 거리의 약 3.7%만 남겨, 포인터 아래
/// 몇 칸을 천천히 지나는 긴장감을 만듭니다. 끝에 별도 정지 시간을 붙이지 않아
/// 결과를 이미 보여 준 채 callback만 지연시키는 연출이 되지 않습니다.
/// 곡선을 바꿀 때 initialSlope도 함께 바꿔야 서버 응답 직후 급가속을 막을 수 있습니다.
class _SuspenseDecelerationCurve extends Curve {
  const _SuspenseDecelerationCurve();

  static const double initialSlope = 3;

  @override
  double transformInternal(double t) {
    final remaining = 1 - t;
    return 1 - remaining * remaining * remaining;
  }
}

// ================================================================
// 룰렛 원판
// ================================================================

/// 금색 테두리 원판, 가운데 축, 위쪽 포인터와 오른쪽 위 레버입니다.
///
/// 1000 × 1000 캔버스 기준 좌표로 그립니다. 위쪽이 룰렛을 돌리는 사람
/// 쪽이며, 레버는 그 사람이 손을 뻗기 쉬운 오른쪽 위에 있습니다.
class RouletteWheel extends StatelessWidget {
  const RouletteWheel({
    super.key,
    required this.controller,
    required this.group,
    required this.leverProgress,
    required this.centerCharacterId,
  });

  /// 원판(금색 테두리 포함)의 지름입니다.
  static const double _rouletteSize = 700;
  static const double _canvas = 1000;

  static const double leverLeft = 800;
  static const double leverWidth = 120;
  static const double leverHeadTop = 40;
  static const double leverHeadSize = 84;

  /// 손잡이가 끝까지 내려가는 거리입니다. 드래그 거리와 같습니다.
  static const double leverTravel = 200;
  static const double leverGestureWidth = leverWidth + 100;
  static const double leverGestureHeight = 420;

  static const Color _gold = Color(0xFFC9A25B);
  static const Color _abyss = Color(0xFF0D0912);
  static const Color _ivory = Color(0xFFF3EEE6);
  static const Color _red = Color(0xFFE0243A);
  static const Color _plum = Color(0xFF3A2350);

  final RouletteController controller;
  final RouletteGroup group;
  final double leverProgress;

  /// 이전 디자인의 가운데 얼굴 자리입니다. 새 디자인은 축만 그립니다.
  final String? centerCharacterId;

  @override
  Widget build(BuildContext context) {
    const wheelInset = (_canvas - _rouletteSize) / 2;
    const rim = _rouletteSize * 12 / 480;
    const sectorInset = _rouletteSize * 22 / 480;
    const sectorSize = _rouletteSize - sectorInset * 2;
    const hub = _rouletteSize * 100 / 480;
    const knob = _rouletteSize * 40 / 480;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 금색 테두리와 그 안쪽 검은 고리입니다.
        Positioned(
          left: wheelInset,
          top: wheelInset,
          width: _rouletteSize,
          height: _rouletteSize,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _gold,
                // 게임이 원판을 돌려 놓아도 어느 쪽에서나 같도록 그림자를
                // 한쪽으로 밀지 않고 고르게 퍼뜨립니다.
                boxShadow: [
                  BoxShadow(color: Color(0x99000000), blurRadius: 90),
                ],
              ),
              padding: const EdgeInsets.all(rim),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _abyss,
                ),
              ),
            ),
          ),
        ),
        // 회전하는 칸입니다.
        Positioned(
          left: wheelInset + sectorInset,
          top: wheelInset + sectorInset,
          width: sectorSize,
          height: sectorSize,
          child: Roulette(
            group: group,
            controller: controller,
            style: const RouletteStyle(
              dividerThickness: 2,
              dividerColor: Color(0x59F3EEE6),
              centerStickSizePercent: 0,
              centerStickerColor: Colors.transparent,
            ),
          ),
        ),
        // 가운데 축입니다.
        const Positioned(
          left: (_canvas - hub) / 2,
          top: (_canvas - hub) / 2,
          width: hub,
          height: hub,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _abyss,
                border: Border.fromBorderSide(
                  BorderSide(color: _gold, width: 9),
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: (_canvas - knob) / 2,
          top: (_canvas - knob) / 2,
          width: knob,
          height: knob,
          child: IgnorePointer(child: _GoldKnob()),
        ),
        // 위쪽 포인터입니다.
        const Positioned(
          left: (_canvas - 64) / 2,
          top: wheelInset - 26,
          width: 64,
          height: 76,
          child: IgnorePointer(
            child: CustomPaint(painter: _PointerPainter(_ivory)),
          ),
        ),
        // 레버: 받침 · 막대 · 빨간 손잡이 순서로 쌓습니다.
        Positioned(
          left: leverLeft,
          top: leverHeadTop + leverHeadSize / 2,
          width: leverWidth,
          height: leverTravel + 80,
          child: IgnorePointer(
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: leverTravel + 20,
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                Container(
                  width: leverWidth,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _plum,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _gold, width: 4),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: leverLeft + (leverWidth - leverHeadSize) / 2,
          top: leverHeadTop + leverTravel * leverProgress,
          width: leverHeadSize,
          height: leverHeadSize,
          child: const IgnorePointer(child: _LeverBall(color: _red)),
        ),
      ],
    );
  }
}

class _GoldKnob extends StatelessWidget {
  const _GoldKnob();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: Alignment(-.3, -.35),
        radius: .9,
        colors: [Color(0xFFE2C27E), Color(0xFFC9A25B), Color(0xFF8E7038)],
        stops: [0, .55, 1],
      ),
    ),
  );
}

class _LeverBall extends StatelessWidget {
  const _LeverBall({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-.35, -.4),
        radius: .9,
        colors: [
          Color.lerp(color, Colors.white, .4)!,
          color,
          Color.lerp(color, Colors.black, .35)!,
        ],
        stops: const [0, .5, 1],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x80000000),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    ),
  );
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas
      ..drawShadow(path, Colors.black, 6, false)
      ..drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => color != oldDelegate.color;
}
