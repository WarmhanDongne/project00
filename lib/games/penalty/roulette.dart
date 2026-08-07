import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:roulette/roulette.dart';

enum RouletteResult { safe, eliminated }

class PenaltyRoulette extends StatefulWidget {
  const PenaltyRoulette({
    super.key,
    required this.attemptCount,
    required this.onResult,
  });
  final int attemptCount;
  final ValueChanged<RouletteResult> onResult;

  @override
  State<PenaltyRoulette> createState() => _PenaltyRouletteState();
}

class _PenaltyRouletteState extends State<PenaltyRoulette>
    with SingleTickerProviderStateMixin {
  final RouletteController _controller = RouletteController();
  final Random _random = Random.secure();

  bool _isSpinning = false;
  bool _isLeverLocked = false;
  bool _isLeverDragActive = false;
  late final AnimationController _leverController;

  @override
  void initState() {
    super.initState();
    _leverController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          debugPrint('leverProgress: ${_leverController.value}');

          setState(() {});
        });
  }

  void _onLeverDragStart(DragStartDetails details) {
    if (_isLeverLocked || _isSpinning) return;

    // 원래 디자인의 빨간 손잡이가 놓인 위치만 드래그를 허용한다.
    const initialHeadCenter = Offset(265, 150);
    _isLeverDragActive =
        (details.localPosition - initialHeadCenter).distance <= 200;
  }

  void _onLeverDragUpdate(DragUpdateDetails details) {
    if (!_isLeverDragActive || _isLeverLocked || _isSpinning) return;

    final nextValue = _leverController.value + (details.delta.dy / 400);
    _leverController.value = nextValue.clamp(0.0, 1.0).toDouble();
  }

  Future<void> _onLeverDragEnd(DragEndDetails details) async {
    if (!_isLeverDragActive || _isLeverLocked || _isSpinning) return;
    _isLeverDragActive = false;

    if (_leverController.value < 0.75) {
      await _leverController.reverse();
      return;
    }

    _isLeverLocked = true;
    await _leverController.animateTo(1, curve: Curves.easeOutCubic);
    if (!mounted) return;
    await _spin();
  }

  /// true = 탈락
  /// false = 생존
  List<bool> get _sections {
    switch (widget.attemptCount) {
      case 0:
        // 총 16칸 → 탈락 4 : 생존 12 (1 : 3)
        return List.generate(16, (index) => index % 4 == 0);
      case 1:
        // 총 15칸 → 탈락 5 : 생존 10 (1 : 2)
        return List.generate(15, (index) => index % 3 == 0);
      default:
        // 총 12칸 → 전부 탈락
        return List<bool>.filled(12, true);
    }
  }

  RouletteGroup get _group {
    final sections = _sections;

    return RouletteGroup.uniform(
      sections.length,
      colorBuilder: (index) {
        final isEliminated = sections[index];

        return isEliminated ? const Color(0xffd10000) : const Color(0xff111111);
      },
      textBuilder: (_) => '',
    );
  }

  Future<void> _spin() async {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
    });

    final sections = _sections;
    final selectedIndex = _random.nextInt(sections.length);

    final completed = await _controller.rollTo(
      selectedIndex,
      offset: 0.15 + (_random.nextDouble() * 0.7),
      animationConfig: const CurveAnimationConfig(
        duration: Duration(seconds: 4),
        curve: Curves.easeOutCubic,
      ),
    );

    if (!mounted) return;

    setState(() {
      _isSpinning = false;
    });

    if (!completed) return;

    final isEliminated = sections[selectedIndex];

    widget.onResult(
      isEliminated ? RouletteResult.eliminated : RouletteResult.safe,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1300,
      height: 900,
      child: Stack(
        children: [
          Center(
            child: RouletteWheel(
              controller: _controller,
              group: _group,
              leverProgress: _leverController.value,
            ),
          ),
          Positioned(
            top: 120,
            right: -150,
            bottom: 120,
            width: 420,
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
      ),
    );
  }

  @override
  void dispose() {
    _leverController.dispose();
    _controller.dispose();
    super.dispose();
  }
}

/// 룰렛 원판 위젯
class RouletteWheel extends StatelessWidget {
  const RouletteWheel({
    super.key,
    required this.controller,
    required this.group,
    required this.leverProgress,
  });

  static const double _rouletteSize = 700;

  final RouletteController controller;
  final RouletteGroup group;
  final double leverProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _rouletteSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: _rouletteSize,
            child: Roulette(
              group: group,
              controller: controller,
              style: const RouletteStyle(
                dividerThickness: 5,
                dividerColor: Color(0xfffafafa),
                centerStickSizePercent: 0.12,
                centerStickerColor: Color(0xfffafafa),
              ),
            ),
          ),

          _SilverRing(size: 440, width: 5),
          _SilverRing(size: 290, width: 10),

          const Positioned(
            top: -32,
            child: Icon(
              Icons.arrow_drop_down,
              size: 70,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),

          //테두리
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(0, 35),
                child: Transform.scale(
                  scale: 1.6, // 8% 확대
                  child: Image(
                    image: AssetImage(
                      'assets/images/widgets/roulette/border.png',
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // 중간 스톤
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(0, 22),
                child: Transform.scale(
                  scale: 0.9, // 8% 확대
                  child: Image(
                    image: AssetImage(
                      'assets/images/widgets/roulette/centerStone.png',
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          //포인터
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(0, -410),
                child: Transform.scale(
                  scale: 0.8, // 8% 확대
                  child: Image(
                    image: AssetImage(
                      'assets/images/widgets/roulette/pointer.png',
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          //lever
          Positioned(
            right: -400,
            top: 0,
            bottom: 0,
            child: Center(
              child: SizedBox(
                width: 450,
                child: Image.asset(
                  'assets/images/widgets/roulette/lever_bottom.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: 330,
            right: -175,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          //stick: 원래 디자인과 위치를 그대로 유지한다.
          if (leverProgress < 0.27499999999999986)
            Positioned(
              right: -230,
              top: -120,
              bottom: 0,
              child: Center(
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/widgets/roulette/lever_stick.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          if (leverProgress > 0.7387499999999977)
            Positioned(
              right: -230,
              top: 120,
              bottom: 0,
              child: Center(
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: ClipOval(
                    child: Transform.rotate(
                      angle: math.pi,
                      child: Image.asset(
                        'assets/images/widgets/roulette/lever_stick.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          //레버 아래로 이동
          Positioned(
            right: -470,
            top: 0,
            bottom: 400,
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(0, 400 * leverProgress),
                child: Center(
                  child: SizedBox(
                    width: 630,
                    child: Transform.scale(
                      scale: 1.3,
                      child: Image.asset(
                        'assets/images/widgets/roulette/lever_head.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 룰렛 중앙 실버 링
class _SilverRing extends StatelessWidget {
  const _SilverRing({required this.size, required this.width});

  final double size;
  final double width;
  final gap = 50.0;
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [_RingBorder(size: size, width: width)],
        ),
      ),
    );
  }
}

/// 실버 링 한 줄
class _RingBorder extends StatelessWidget {
  const _RingBorder({required this.size, required this.width});

  final double size;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xfffafafa), width: width),
      ),
    );
  }
}
