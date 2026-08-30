import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

//=======================게임 재접속 화면==============================
/// 연결이 끊겼거나 돌아갈 세션이 있을 때 보여 주는 화면입니다.
///
/// 쓰이는 곳이 두 군데입니다.
/// - `ControllerReconnectGuard`: 태블릿이 사라진 동안 게임 입력을 막고 기다립니다.
///   [actions] 없이 [onHome]만 쓰며, 일정 시간 뒤 나가기 버튼이 나타납니다.
/// - `SessionReturnPrompt`: 앱을 다시 켰을 때 기존 방·게임으로 돌아갈지 묻습니다.
///   [actions]를 넘겨 기다림 표시 대신 선택 버튼을 보여 줍니다(P-01).
///
/// 휴대폰(세로)·태블릿(가로)을 한 위젯으로 그립니다. 배경의 연보라 원은 그림
/// 파일이 아니라 **코드로 그립니다.** 그래야 기기 비율이 달라도 원이 잘리거나
/// 늘어나지 않고, 큰 배경 그림 두 장(약 2MB)을 넣지 않아도 됩니다.
class GameReconnectScreen extends StatefulWidget {
  const GameReconnectScreen({
    super.key,
    this.title = '게임에 다시 접속하는 중',
    this.message = '잠시만 기다려 주세요',
    this.illustrationAsset = defaultIllustrationAsset,
    this.sparkleAsset = defaultSparkleAsset,
    this.homeButtonDelay = defaultHomeButtonDelay,
    this.homeLabel = '홈으로',
    this.onHome,
    this.actions = const [],
  });

  /// 가운데 큰 문구입니다.
  final String title;

  /// 그 아래 작은 문구입니다.
  final String message;

  /// 가운데 그림입니다. 파일이 없으면 그림 없이 문구만 보여 줍니다.
  final String illustrationAsset;

  /// 게임기 주변에서 반짝이는 별 그림입니다.
  final String sparkleAsset;

  /// 조이스틱 그림 자리입니다. 파일을 넣으면 자동으로 보입니다.
  static const String defaultIllustrationAsset =
      'assets/images/reconnect/game_controller.webp';

  /// 별 그림 자리입니다. 파일을 넣으면 자동으로 보입니다.
  static const String defaultSparkleAsset = 'assets/images/reconnect/star.webp';

  /// 이 시간이 지나도 접속되지 않으면 아래 기다림 표시가 **홈으로 버튼**으로
  /// 바뀝니다(확정 2026-08).
  ///
  /// 계속 기다리게만 두면 나갈 방법이 없어 앱을 강제 종료하게 됩니다.
  /// 공용 연결 화면([GameConnectingOverlay])의 나가기 버튼과 같은 20초입니다.
  final Duration homeButtonDelay;

  /// 시간이 지난 뒤 나타나는 버튼 문구입니다.
  final String homeLabel;

  /// 그 버튼을 눌렀을 때입니다. null이면 눌러도 아무 일도 하지 않습니다
  /// (배선 전 디자인 확인용).
  final VoidCallback? onHome;

  /// 기다림 표시 자리에 대신 놓을 버튼들입니다.
  ///
  /// 비어 있지 않으면 점 애니메이션과 [homeButtonDelay] 타이머를 쓰지 않고
  /// 이 버튼들을 바로 보여 줍니다. 기다리는 화면이 아니라 **고르는 화면**이
  /// 되기 때문입니다.
  final List<Widget> actions;

  static const Duration defaultHomeButtonDelay = Duration(seconds: 20);

  //=======================색==============================
  /// 배경 크림색입니다.
  static const Color background = Color(0xFFF8F5F2);

  /// 모서리에서 번지는 연보라 원입니다.
  static const Color corner = Color(0xFFE1DDF4);

  /// 큰 문구 색입니다.
  static const Color titleColor = Color(0xFF4A4458);

  /// 작은 문구·점 색입니다.
  static const Color messageColor = Color(0xFF8A8399);

  /// 기다림을 알리는 점 색입니다(그림의 보라와 같은 계열).
  static const Color accent = Color(0xFF8B7BE8);

  @override
  State<GameReconnectScreen> createState() => _GameReconnectScreenState();
}

class _GameReconnectScreenState extends State<GameReconnectScreen>
    with TickerProviderStateMixin {
  /// 그림이 아주 조금 떠오르내리는 시간입니다.
  static const Duration _floatCycle = Duration(milliseconds: 3200);

  /// 기다림을 알리는 점 세 개가 한 바퀴 도는 시간입니다.
  static const Duration _dotsCycle = Duration(milliseconds: 1400);

  late final AnimationController _float;
  late final AnimationController _dots;

  /// 시간이 지나 홈으로 버튼을 보여 줄지입니다.
  bool _showsHomeButton = false;
  Timer? _homeTimer;

  @override
  void initState() {
    super.initState();
    // 회전하는 큰 표시(스피너) 대신, 그림이 숨 쉬듯 움직이고 점이 순서대로
    // 밝아지게 합니다. 기다리는 화면이 조용해 보이도록 한 선택입니다.
    _float = AnimationController(vsync: this, duration: _floatCycle)..repeat();
    _dots = AnimationController(vsync: this, duration: _dotsCycle)..repeat();
    // 오래 기다렸는데도 접속되지 않으면 나갈 길을 내줍니다.
    _startHomeTimer();
  }

  @override
  void didUpdateWidget(covariant GameReconnectScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 같은 자리에서 문구와 대기 시간만 바꿔 다시 쓰는 경우(예: 패치 화면의
    // 단계 전환)가 있습니다. 이전 시계를 그대로 두면 새 시간이 무시됩니다.
    if (oldWidget.homeButtonDelay != widget.homeButtonDelay) {
      _showsHomeButton = false;
      _startHomeTimer();
    }
  }

  void _startHomeTimer() {
    _homeTimer?.cancel();
    // 고르는 화면에서는 기다림 타이머가 필요 없습니다.
    if (widget.actions.isNotEmpty) return;
    _homeTimer = Timer(widget.homeButtonDelay, () {
      if (mounted) setState(() => _showsHomeButton = true);
    });
  }

  @override
  void dispose() {
    _homeTimer?.cancel();
    _float.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameReconnectScreen.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final isWide = size.width > size.height;
          // 글자·그림 크기는 짧은 변을 기준으로 잡습니다. 태블릿 가로에서
          // 글자가 화면 폭을 따라 과하게 커지지 않습니다.
          final unit = size.shortestSide;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 배경: 크림색 바탕 + 대각선 두 모서리의 연보라 원.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CornerBlobsPainter(isWide: isWide),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: unit * 0.08),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildIllustration(unit: unit, isWide: isWide),
                        SizedBox(height: unit * (isWide ? 0.05 : 0.07)),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: GameReconnectScreen.titleColor,
                            fontSize: unit * (isWide ? 0.048 : 0.062),
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: unit * 0.022),
                        Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: GameReconnectScreen.messageColor,
                            fontSize: unit * (isWide ? 0.03 : 0.04),
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: unit * (isWide ? 0.05 : 0.06)),
                        // 기다림 표시가 있던 자리에 홈으로 버튼이 들어옵니다.
                        // 버튼 높이만큼 자리를 미리 비워 두어, 점이 버튼으로
                        // 바뀔 때 위쪽 그림과 문구가 밀려 올라가지 않습니다.
                        if (widget.actions.isEmpty)
                          SizedBox(
                            height: _homeSlotHeight(unit),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 320),
                                child: _showsHomeButton
                                    ? _buildHomeButton(unit: unit)
                                    : _buildDots(unit: unit),
                              ),
                            ),
                          )
                        else
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: unit * 0.03,
                            runSpacing: unit * 0.025,
                            children: widget.actions,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 가운데 그림입니다.
  ///
  /// 게임기는 **위아래로 아주 조금 흔들흔들** 하고(확정 2026-08), 그 주변에서
  /// 별이 무작위로 생겼다 사라집니다.
  Widget _buildIllustration({required double unit, required bool isWide}) {
    final side = unit * (isWide ? 0.34 : 0.52);
    // 별이 게임기 밖에서도 뜰 수 있도록 그림보다 넓은 자리를 잡습니다.
    final field = side * 1.5;

    return SizedBox(
      width: field,
      height: field,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 별은 게임기 뒤에 둡니다. 앞에 두면 그림을 가립니다.
          _SparkleField(asset: widget.sparkleAsset, controllerSide: side),
          AnimatedBuilder(
            animation: _float,
            builder: (context, child) {
              final phase = _float.value * math.pi * 2;
              // 위아래 흔들림과 좌우 기울임을 조금 어긋나게 겹쳐, 같은 자리를
              // 반복하는 기계적인 움직임처럼 보이지 않게 합니다.
              return Transform.translate(
                offset: Offset(0, math.sin(phase) * unit * 0.014),
                child: Transform.rotate(
                  angle: math.sin(phase + math.pi / 3) * 0.035,
                  child: child,
                ),
              );
            },
            child: SizedBox(
              width: side,
              height: side,
              child: Image.asset(
                widget.illustrationAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                // 그림 파일이 아직 없어도 화면이 깨지지 않게 자리만 비웁니다.
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 기다림 표시와 홈으로 버튼이 함께 쓰는 자리의 높이입니다.
  ///
  /// 둘 중 큰 쪽(버튼)에 맞춰 두어야 바뀌는 순간에도 화면이 움직이지
  /// 않습니다. 태블릿에서는 글자 배율이 작아 버튼도 조금 낮습니다.
  double _homeSlotHeight(double unit) => unit * (unit > 700 ? 0.092 : 0.105);

  /// 시간이 지나 나타나는 홈으로 버튼입니다.
  ///
  /// 기다림 표시(점)와 같은 자리·같은 보라색을 씁니다. 기다리라는 표시가
  /// 나갈 수 있는 버튼으로 바뀌는 것이 한눈에 읽히게 하려는 것입니다.
  Widget _buildHomeButton({required double unit}) {
    return Semantics(
      button: true,
      label: widget.homeLabel,
      child: GestureDetector(
        onTap: widget.onHome,
        child: Container(
          height: _homeSlotHeight(unit),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: unit * 0.075),
          decoration: BoxDecoration(
            color: GameReconnectScreen.accent,
            borderRadius: BorderRadius.circular(unit * 0.06),
            boxShadow: [
              BoxShadow(
                color: GameReconnectScreen.accent.withValues(alpha: 0.35),
                blurRadius: unit * 0.04,
                offset: Offset(0, unit * 0.012),
              ),
            ],
          ),
          child: Text(
            widget.homeLabel,
            style: TextStyle(
              color: Colors.white,
              fontSize: unit * (unit > 700 ? 0.028 : 0.038),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  /// 점 세 개가 순서대로 밝아지며 기다리는 중임을 알립니다.
  Widget _buildDots({required double unit}) {
    final diameter = unit * 0.022;

    return AnimatedBuilder(
      animation: _dots,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < 3; index += 1) ...[
              if (index > 0) SizedBox(width: diameter * 0.9),
              Opacity(
                opacity: _dotOpacity(index),
                child: Container(
                  width: diameter,
                  height: diameter,
                  decoration: const BoxDecoration(
                    color: GameReconnectScreen.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// [index]번째 점의 진하기입니다. 왼쪽에서 오른쪽으로 물결처럼 지나갑니다.
  double _dotOpacity(int index) {
    // 점마다 1/3씩 위상을 늦춰 순서대로 밝아지게 합니다.
    final phase = (_dots.value - index / 3) % 1;
    final wave = math.sin(phase * math.pi);
    return 0.25 + 0.75 * wave.clamp(0.0, 1.0);
  }
}

//=======================배경 원==============================
/// 대각선 두 모서리에서 화면 안으로 번져 들어오는 연보라 원입니다.
///
/// 원 지름은 짧은 변에 비례하므로, 세로 휴대폰과 가로 태블릿에서 같은 느낌으로
/// 보입니다. [isWide]에 따라 원이 조금 작아져 가로 화면에서 과하게 커지지
/// 않습니다.
class _CornerBlobsPainter extends CustomPainter {
  const _CornerBlobsPainter({required this.isWide});

  final bool isWide;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = GameReconnectScreen.background;
    canvas.drawRect(Offset.zero & size, paint);

    final radius = size.shortestSide * (isWide ? 0.28 : 0.36);
    final blob = Paint()..color = GameReconnectScreen.corner;
    // 원 중심을 화면 밖으로 조금 빼서 모서리에서 잘려 들어오게 합니다.
    final inset = radius * 0.28;
    canvas
      ..drawCircle(Offset(-inset, -inset), radius, blob)
      ..drawCircle(
        Offset(size.width + inset, size.height + inset),
        radius,
        blob,
      );
  }

  @override
  bool shouldRepaint(_CornerBlobsPainter oldDelegate) =>
      oldDelegate.isWide != isWide;
}

//=======================별 반짝임==============================
/// 게임기 주변에서 별이 무작위로 생겼다 사라지는 자리입니다.
///
/// 확정(2026-08): 정해진 자리에서 깜빡이면 규칙이 눈에 보여 장식이 아니라
/// 반복 재생처럼 보입니다. 그래서 별마다 **자리·크기·기울기·머무는 시간**을
/// 새로 뽑고, 사라진 뒤 잠깐 쉬었다가 다른 곳에서 다시 태어납니다.
///
/// 별은 게임기를 가리지 않도록 **바깥쪽 고리** 안에서만 태어납니다.
class _SparkleField extends StatefulWidget {
  const _SparkleField({required this.asset, required this.controllerSide});

  final String asset;

  /// 게임기 그림의 한 변입니다. 별이 태어날 고리를 이 값으로 잡습니다.
  final double controllerSide;

  /// 한 화면에 함께 떠 있을 수 있는 별 수입니다.
  static const int count = 4;

  @override
  State<_SparkleField> createState() => _SparkleFieldState();
}

class _SparkleFieldState extends State<_SparkleField>
    with SingleTickerProviderStateMixin {
  /// 시계 한 바퀴입니다. 값 자체는 쓰지 않고 흐른 시간만 읽습니다.
  static const Duration _clock = Duration(minutes: 1);

  final math.Random _random = math.Random();
  late final AnimationController _ticker;
  late final List<_Sparkle> _sparkles;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: _clock)..repeat();
    // 처음부터 한꺼번에 나타나지 않도록 시작 시간을 흩어 놓습니다.
    _sparkles = List.generate(
      _SparkleField.count,
      (index) => _spawn(startMs: -_random.nextDouble() * 2600),
    );
  }

  /// 별 하나를 새로 만듭니다.
  _Sparkle _spawn({required double startMs}) {
    final side = widget.controllerSide;
    // 게임기 가운데에서 얼마나 떨어진 곳에 뜰지입니다(고리 안쪽~바깥쪽).
    final distance = side * (0.42 + _random.nextDouble() * 0.32);
    final angle = _random.nextDouble() * math.pi * 2;
    return _Sparkle(
      // 게임기는 세로보다 가로가 넓어, 좌우로 조금 더 벌려야 자연스럽습니다.
      offset: Offset(
        math.cos(angle) * distance * 1.15,
        math.sin(angle) * distance * 0.82,
      ),
      size: side * (0.09 + _random.nextDouble() * 0.07),
      tilt: (_random.nextDouble() - 0.5) * 0.9,
      startMs: startMs,
      // 떠 있는 시간과, 사라진 뒤 다시 태어나기까지 쉬는 시간입니다.
      lifeMs: 1100 + _random.nextDouble() * 900,
      restMs: 250 + _random.nextDouble() * 1400,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, _) {
        final elapsedMs = _ticker.value * _clock.inMilliseconds;
        return Stack(
          alignment: Alignment.center,
          children: [
            for (var index = 0; index < _sparkles.length; index += 1)
              _buildSparkle(index, elapsedMs),
          ],
        );
      },
    );
  }

  Widget _buildSparkle(int index, double elapsedMs) {
    var sparkle = _sparkles[index];
    var age = elapsedMs - sparkle.startMs;
    // 시계가 한 바퀴 돌아 시간이 되감기면 나이가 음수가 됩니다. 그때는 새로
    // 태어난 것으로 봅니다.
    if (age < 0) {
      sparkle = _sparkles[index] = _spawn(startMs: elapsedMs);
      age = 0;
    }
    // 다 살고 쉬는 시간까지 지났으면 다른 자리에서 새로 태어납니다.
    if (age > sparkle.lifeMs + sparkle.restMs) {
      sparkle = _sparkles[index] = _spawn(startMs: elapsedMs);
      age = 0;
    }

    final opacity = sparkle.opacityAt(age);
    if (opacity <= 0) return const SizedBox.shrink();

    return Transform.translate(
      offset: sparkle.offset,
      child: Transform.rotate(
        angle: sparkle.tilt,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            // 작게 돋았다가 제 크기가 됩니다.
            scale: 0.55 + 0.45 * opacity,
            child: SizedBox(
              width: sparkle.size,
              height: sparkle.size,
              child: Image.asset(
                widget.asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                // 별 그림이 아직 없어도 화면이 깨지지 않습니다.
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 별 하나의 성질입니다. 태어날 때 정해지고 사라질 때까지 바뀌지 않습니다.
@immutable
class _Sparkle {
  const _Sparkle({
    required this.offset,
    required this.size,
    required this.tilt,
    required this.startMs,
    required this.lifeMs,
    required this.restMs,
  });

  /// 게임기 가운데를 기준으로 한 자리입니다.
  final Offset offset;
  final double size;
  final double tilt;

  /// 태어난 시각과, 떠 있는 시간·쉬는 시간입니다.
  final double startMs;
  final double lifeMs;
  final double restMs;

  /// [age]밀리초 지난 시점의 진하기입니다.
  ///
  /// 절반까지 밝아지고 절반부터 사그라듭니다. 나타나는 쪽을 조금 빠르게 해
  /// '반짝' 하는 느낌을 줍니다.
  double opacityAt(double age) {
    if (age < 0 || age > lifeMs) return 0;
    final progress = age / lifeMs;
    final wave = progress < 0.4
        ? Curves.easeOut.transform(progress / 0.4)
        : Curves.easeIn.transform(1 - (progress - 0.4) / 0.6);
    return wave.clamp(0.0, 1.0);
  }
}
