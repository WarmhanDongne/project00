import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/sound/app_sounds.dart';
import 'package:project00/core/sound/providers/sound_provider.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/models/room_character.dart';
import 'package:roulette/roulette.dart';
import 'package:project00/core/assets/game_image.dart';

enum RouletteResult { safe, eliminated }

class PenaltyRoulette extends StatefulWidget {
  const PenaltyRoulette({
    super.key,
    required this.attemptCount,
    required this.onResult,
    this.centerCharacterId,
  });

  final int attemptCount;
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
  /// 모든 iPad에서 이 1300 × 900 화면을 기준으로
  /// 전체 룰렛 UI가 동일한 비율로 확대/축소됩니다.
  /// ============================================================
  static const double _designWidth = 1300;
  static const double _designHeight = 900;

  final RouletteController _controller = RouletteController();
  final math.Random _random = math.Random.secure();

  bool _isSpinning = false;
  bool _isLeverLocked = false;
  bool _isLeverDragActive = false;

  late final AnimationController _leverController;

  /// 원판이 도는 시간입니다. 효과음도 이 길이에 맞춰 끝을 정렬합니다.
  static const Duration _spinDuration = Duration(seconds: 4);

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
  }

  // ============================================================
  // 레버
  // ============================================================

  void _onLeverDragStart(DragStartDetails details) {
    if (_isLeverLocked || _isSpinning) return;

    /// GestureDetector 자체도 1300 × 900 기준 캔버스와
    /// 같이 스케일링되기 때문에 이 좌표를 기기별로
    /// 다시 계산할 필요가 없습니다.
    const initialHeadCenter = Offset(265, 150);

    _isLeverDragActive =
        (details.localPosition - initialHeadCenter).distance <= 200;
  }

  void _onLeverDragUpdate(DragUpdateDetails details) {
    if (!_isLeverDragActive || _isLeverLocked || _isSpinning) {
      return;
    }

    final nextValue = _leverController.value + (details.delta.dy / 400);

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
  List<bool> get _sections {
    switch (widget.attemptCount) {
      case 0:

        /// 총 16칸
        /// 탈락 4
        /// 생존 12
        ///
        /// 탈락 : 생존 = 1 : 3
        return List.generate(16, (index) => index % 4 == 0);

      case 1:

        /// 총 15칸
        /// 탈락 5
        /// 생존 10
        ///
        /// 탈락 : 생존 = 1 : 2
        return List.generate(15, (index) => index % 3 == 0);

      default:

        /// 총 12칸
        /// 탈락 11
        /// 생존 1
        return List<bool>.generate(12, (index) => index != 0);
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

  // ============================================================
  // 룰렛 실행
  // ============================================================

  Future<void> _spin() async {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
    });

    // 룰렛 사운드는 파일이 회전보다 깁니다. 뒤를 끊으면 멈추는 순간의 소리와
    // 여운이 사라지므로, 앞부분을 건너뛰어 회전이 끝나는 시점에 소리도
    // 자연스럽게 끝나도록 맞춥니다. 정지는 화면이 사라질 때만 합니다.
    _sound?.playSustainedEffect(AppSounds.roulette, window: _spinDuration);

    final sections = _sections;

    final selectedIndex = _random.nextInt(sections.length);

    final completed = await _controller.rollTo(
      selectedIndex,
      offset: 0.15 + (_random.nextDouble() * 0.7),
      animationConfig: const CurveAnimationConfig(
        duration: _spinDuration,
        curve: Curves.easeOutCubic,
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
      return;
    }

    final isEliminated = sections[selectedIndex];

    widget.onResult(
      isEliminated ? RouletteResult.eliminated : RouletteResult.safe,
    );
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
        /// 룰렛
        Center(
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

// ================================================================
// 룰렛 원판
// ================================================================

class RouletteWheel extends StatelessWidget {
  const RouletteWheel({
    super.key,
    required this.controller,
    required this.group,
    required this.leverProgress,
    required this.centerCharacterId,
  });

  /// 룰렛 자체의 기준 크기
  static const double _rouletteSize = 700;

  final RouletteController controller;
  final RouletteGroup group;
  final double leverProgress;
  final String? centerCharacterId;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _rouletteSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // ========================================================
          // 기본 룰렛
          // ========================================================
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

          // ========================================================
          // 실버 링
          // ========================================================
          const _SilverRing(size: 440, width: 5),

          const _SilverRing(size: 290, width: 10),

          // ========================================================
          // 기본 화살표
          // ========================================================
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

          // ========================================================
          // 룰렛 외부 테두리
          // ========================================================
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.translate(
                offset: const Offset(0, 35),
                child: Transform.scale(
                  scale: 1.6,
                  child: Assets.images.widgets.roulette.border.game.image(
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // ========================================================
          // 중앙 스톤
          // ========================================================
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.translate(
                offset: const Offset(0, 22),
                child: Transform.scale(
                  scale: 0.9,
                  child: Assets.images.widgets.roulette.centerStone.game.image(
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // ========================================================
          // 중앙 프로필
          // ========================================================
          if (centerCharacterId != null)
            Positioned(
              top: (_rouletteSize - 320) / 2 + 22,
              left: (_rouletteSize - 270) / 2,
              child: IgnorePointer(
                child: SizedBox.square(
                  dimension: 270,
                  child: ClipOval(
                    child: Image.asset(
                      roomCharacterAssetPath(centerCharacterId),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),

          // ========================================================
          // 상단 포인터
          // ========================================================
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.translate(
                offset: const Offset(0, -410),
                child: Transform.scale(
                  scale: 0.8,
                  child: Assets.images.widgets.roulette.pointer.game.image(
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // ========================================================
          // 레버 바닥
          // ========================================================
          Positioned(
            right: -400,
            top: 0,
            bottom: 0,
            child: Center(
              child: SizedBox(
                width: 450,
                child: Assets.images.widgets.roulette.leverBottom.game.image(
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // ========================================================
          // 레버 중앙 검은 원
          // ========================================================
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

          // ========================================================
          // 레버 스틱 - 위
          // ========================================================
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
                    child: Assets.images.widgets.roulette.leverStick.game.image(
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

          // ========================================================
          // 레버 스틱 - 아래
          // ========================================================
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
                      child: Assets.images.widgets.roulette.leverStick.game
                          .image(fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),

          // ========================================================
          // 빨간 레버 손잡이
          // ========================================================
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
                      child: Assets.images.widgets.roulette.leverHead.game
                          .image(fit: BoxFit.contain),
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

// ================================================================
// 룰렛 중앙 실버 링
// ================================================================

class _SilverRing extends StatelessWidget {
  const _SilverRing({required this.size, required this.width});

  final double size;
  final double width;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xfffafafa), width: width),
        ),
      ),
    );
  }
}
