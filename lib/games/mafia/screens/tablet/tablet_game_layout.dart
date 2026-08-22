import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/games/mafia/animations/ejection_text.dart';
import 'package:project00/games/mafia/sound/mafia_sounds.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================태블릿 화면 공용 골격==============================
// 태블릿 시안은 모두 가로 1194 × 834이고, 아래 네 가지를 공유합니다.
//
//   종이/밤 배경 → 해(sun) → 룰북 아이콘 → 설정 아이콘 → (단계별 내용)
//
// ⚠️ 시안의 자식은 Figma에서 −90° 회전 상태로 적혀 있습니다. 여기 적은 값은
// **이미 가로로 변환된 좌표**입니다. Flutter에서는 회전하지 않고 그대로 놓습니다.
// 변환 규칙은 `lib/games/mafia/README.md`에 있습니다.

/// 시안 좌표를 실제 화면 크기로 옮기는 기준값입니다.
abstract final class MafiaTabletDesign {
  static const Size size = Size(1194, 834);

  /// 가로 중앙입니다. 시안의 중앙 정렬 요소가 모두 이 값에 옵니다.
  static const double centerX = 597;

  //=======================모든 단계가 공유하는 요소==============================
  static const Rect sun = Rect.fromLTWH(196, 18, 802, 802);
  static const Rect settingIcon = Rect.fromLTWH(1048, 18, 123, 123);
  static const Rect rulebookIcon = Rect.fromLTWH(886, 31, 149, 98);

  /// 시안의 top 값을 실제 높이에 맞춘 값으로 바꿉니다.
  static double top(Size actual, double designTop) =>
      actual.height * (designTop / size.height);

  /// 시안의 left 값을 실제 폭에 맞춘 값으로 바꿉니다.
  static double left(Size actual, double designLeft) =>
      actual.width * (designLeft / size.width);

  /// 시안 대비 확대 비율입니다. 글자·테두리에 곱합니다.
  ///
  /// 가로·세로 중 작은 쪽을 씁니다. 기기 비율이 시안과 달라도 요소가 화면 밖으로
  /// 나가지 않습니다.
  static double scaleOf(Size actual) =>
      actual.width / size.width < actual.height / size.height
      ? actual.width / size.width
      : actual.height / size.height;

  static Size resolve(BoxConstraints constraints) => Size(
    constraints.hasBoundedWidth ? constraints.maxWidth : size.width,
    constraints.hasBoundedHeight ? constraints.maxHeight : size.height,
  );
}

/// 시안 사각형을 그 자리에 놓습니다.
///
/// 태블릿 시안은 좌표가 촘촘해서 `Positioned`를 매번 쓰면 값이 흩어집니다.
/// 시안 사각형을 그대로 넘기면 되게 묶어 둡니다.
class MafiaTabletBox extends StatelessWidget {
  const MafiaTabletBox({
    super.key,
    required this.rect,
    required this.child,
    this.ignorePointer = true,
  });

  /// 시안(1194 × 834) 기준 사각형입니다.
  final Rect rect;
  final Widget child;
  final bool ignorePointer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaTabletDesign.resolve(constraints);
        final scale = MafiaTabletDesign.scaleOf(size);
        // 화면 비율이 시안과 다를 때 전체를 가운데로 모읍니다.
        final offsetX = (size.width - MafiaTabletDesign.size.width * scale) / 2;
        final offsetY =
            (size.height - MafiaTabletDesign.size.height * scale) / 2;

        final content = SizedBox(
          width: rect.width * scale,
          height: rect.height * scale,
          child: child,
        );
        return Stack(
          children: [
            Positioned(
              left: offsetX + rect.left * scale,
              top: offsetY + rect.top * scale,
              child: ignorePointer ? IgnorePointer(child: content) : content,
            ),
          ],
        );
      },
    );
  }
}

/// 태블릿 배경입니다. 낮은 종이, 밤은 어두운 배경을 씁니다.
class MafiaTabletBackground extends StatefulWidget {
  const MafiaTabletBackground({super.key, required this.isNight});

  final bool isNight;

  @override
  State<MafiaTabletBackground> createState() => _MafiaTabletBackgroundState();
}

class _MafiaTabletBackgroundState extends State<MafiaTabletBackground>
    with SingleTickerProviderStateMixin {
  /// 낮↔밤이 바뀔 때 새 배경이 12시부터 시계 방향으로 쓸려 들어오는
  /// 라디얼 와이프 시간입니다(확정 2026-08).
  static const Duration _wipeDuration = Duration(milliseconds: 900);

  late final AnimationController _controller;

  /// 지금 그리려는(새) 배경과, 전환 동안 밑에 깔려 있는 직전 배경입니다.
  late bool _currentIsNight;
  bool? _previousIsNight;

  @override
  void initState() {
    super.initState();
    _currentIsNight = widget.isNight;
    _controller = AnimationController(
      vsync: this,
      duration: _wipeDuration,
      // 첫 화면은 전환 없이 바로 보입니다.
      value: 1,
    )..addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previousIsNight != null) {
      setState(() => _previousIsNight = null);
    }
  }

  @override
  void didUpdateWidget(MafiaTabletBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isNight == _currentIsNight) return;
    // 밤↔낮이 바뀌면 옛 배경을 깔아 두고 새 배경을 쓸어 넣습니다.
    _previousIsNight = _currentIsNight;
    _currentIsNight = widget.isNight;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  /// 낮 또는 밤 배경 한 겹입니다.
  Widget _buildLayer(bool isNight) {
    final background = Assets.games.mafia.images.background;
    final image = isNight
        ? background.backgroundNight.game
        : background.backgroundMorning.game;
    return ColoredBox(
      color: isNight ? const Color(0xFF10131A) : const Color(0xFFE9E9E9),
      child: image.image(fit: BoxFit.cover, filterQuality: FilterQuality.high),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previous = _previousIsNight;
    if (previous == null) return _buildLayer(_currentIsNight);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Curves.easeInOut.transform(_controller.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildLayer(previous),
            ClipPath(
              clipper: _RadialWipeClipper(progress),
              child: _buildLayer(_currentIsNight),
            ),
          ],
        );
      },
    );
  }
}

/// 12시 방향에서 시작해 시계 방향으로 쓸어 내는 부채꼴 클리퍼입니다.
class _RadialWipeClipper extends CustomClipper<Path> {
  const _RadialWipeClipper(this.progress);

  /// 0 = 아무것도 안 보임, 1 = 전부 보임.
  final double progress;

  @override
  Path getClip(Size size) {
    if (progress >= 1) {
      return Path()..addRect(Offset.zero & size);
    }
    final path = Path();
    if (progress <= 0) return path;
    final center = Offset(size.width / 2, size.height / 2);
    // 화면 모서리까지 확실히 덮는 반지름입니다.
    final radius = size.longestSide;
    const startAngle = -math.pi / 2;
    path
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx, center.dy - radius)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        math.pi * 2 * progress,
        false,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_RadialWipeClipper oldClipper) =>
      oldClipper.progress != progress;
}

/// 낮 화면 가운데의 햇살입니다. 시안에서 발표·투표 화면의 시선이 모이는 곳입니다.
class MafiaTabletSun extends StatelessWidget {
  const MafiaTabletSun({super.key});

  @override
  Widget build(BuildContext context) {
    return MafiaTabletBox(
      rect: MafiaTabletDesign.sun,
      child: Assets.games.mafia.images.other.sun.game.image(
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// 밤 화면 가운데의 달입니다. 시안의 밤 화면에는 이것 말고 아무 것도 없습니다.
class MafiaTabletMoon extends StatefulWidget {
  const MafiaTabletMoon({super.key});

  /// 시안 좌표입니다. 가운데(597, 419)에 옵니다.
  static const Rect rect = Rect.fromLTWH(352, 174, 490, 490);

  //=======================달빛 반짝임==============================
  // 확정(2026-08): 달 위에서 작은 빛이 10초에 한 번쯤 무작위로 반짝입니다.
  // 밤 화면은 달만 떠 있어 완전히 멈춘 그림처럼 보이는데, 이 작은 빛이
  // 화면이 살아 있다는 느낌을 줍니다.

  /// 반짝임 사이의 간격입니다(평균 10초).
  static const Duration minSparkleGap = Duration(seconds: 7);
  static const Duration maxSparkleGap = Duration(seconds: 13);

  /// 빛 하나가 떠올라 사라지는 데 걸리는 시간입니다.
  static const Duration sparkleDuration = Duration(milliseconds: 1400);

  /// 빛의 크기 범위입니다(시안 좌표 기준).
  static const double minSparkleSize = 26;
  static const double maxSparkleSize = 52;

  @override
  State<MafiaTabletMoon> createState() => _MafiaTabletMoonState();
}

class _MafiaTabletMoonState extends State<MafiaTabletMoon>
    with SingleTickerProviderStateMixin {
  final math.Random _random = math.Random();
  late final AnimationController _sparkle;
  Timer? _nextTimer;

  /// 이번 빛의 자리(달 안쪽 비율 좌표)와 크기입니다.
  Offset _spot = Offset.zero;
  double _size = MafiaTabletMoon.minSparkleSize;
  bool _isSparkling = false;

  @override
  void initState() {
    super.initState();
    _sparkle = AnimationController(
      vsync: this,
      duration: MafiaTabletMoon.sparkleDuration,
    )..addStatusListener(_handleSparkleStatus);
    _scheduleNext();
  }

  void _handleSparkleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _isSparkling = false);
    _scheduleNext();
  }

  void _scheduleNext() {
    _nextTimer?.cancel();
    final span =
        MafiaTabletMoon.maxSparkleGap.inMilliseconds -
        MafiaTabletMoon.minSparkleGap.inMilliseconds;
    _nextTimer = Timer(
      Duration(
        milliseconds:
            MafiaTabletMoon.minSparkleGap.inMilliseconds +
            _random.nextInt(span),
      ),
      () {
        if (!mounted) return;
        setState(() {
          // 달은 둥글기 때문에 각도와 반지름으로 자리를 뽑아야 원 안에
          // 들어갑니다. 사각형 안에서 뽑으면 네 귀퉁이(달 밖)가 나옵니다.
          final angle = _random.nextDouble() * math.pi * 2;
          // 가장자리에 너무 붙지 않게 안쪽까지만 씁니다.
          final radius = math.sqrt(_random.nextDouble()) * 0.38;
          _spot = Offset(
            0.5 + math.cos(angle) * radius,
            0.5 + math.sin(angle) * radius,
          );
          _size =
              MafiaTabletMoon.minSparkleSize +
              _random.nextDouble() *
                  (MafiaTabletMoon.maxSparkleSize -
                      MafiaTabletMoon.minSparkleSize);
          _isSparkling = true;
        });
        _sparkle.forward(from: 0);
      },
    );
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    _sparkle
      ..removeStatusListener(_handleSparkleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MafiaTabletBox(
      rect: MafiaTabletMoon.rect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Assets.games.mafia.images.other.moon.game.image(
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          if (_isSparkling) _buildSparkle(),
        ],
      ),
    );
  }

  Widget _buildSparkle() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 달 그림은 BoxFit.contain이라 실제로 그려진 정사각형 안쪽만 씁니다.
        final side = constraints.biggest.shortestSide;
        final size = side * _size / MafiaTabletMoon.rect.width;

        return AnimatedBuilder(
          animation: _sparkle,
          builder: (context, _) {
            // 떠올랐다가 사라집니다. 커지면서 밝아지고, 사그라들며 조금 더
            // 퍼집니다.
            final progress = _sparkle.value;
            final glow = math.sin(progress * math.pi);
            final scale = 0.6 + progress * 0.6;

            // Positioned는 Stack 안에만 놓일 수 있습니다. LayoutBuilder가
            // 사이에 있으므로 여기서 Stack을 한 겹 둡니다.
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: constraints.maxWidth * _spot.dx - size / 2,
                  top: constraints.maxHeight * _spot.dy - size / 2,
                  width: size,
                  height: size,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (glow * 0.85).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: scale,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(0xFFFFFDF0),
                                Color(0x66FFF6D6),
                                Color(0x00FFF6D6),
                              ],
                              stops: [0, 0.35, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

//=======================단계 안내==============================
/// 단계가 바뀔 때 화면 가운데에 잠깐 띄우는 안내입니다.
///
/// 확정(2026-08): '아침이 되었습니다' → 사망자 발표 → '토론을 시작합니다' →
/// 토론, 그리고 밤으로 갈 때는 '밤이 되었습니다'를 띄운 뒤 배경이 바뀝니다.
///
/// 뒤 화면을 완전히 가리지 않고 살짝 덮습니다. 낮에는 밝은 막에 검은 글씨,
/// 밤에는 어두운 막에 흰 글씨입니다.
///
/// 글자는 어몽어스 추방 발표처럼 **내려찍힙니다**([MafiaEjectionText]).
///
/// 밤 안내가 뜨는 순간에는 나레이션('밤이 되었습니다')을 한 번 냅니다. 안내가
/// 뜨는 곳이 두 군데(첫 밤·매 밤)라 화면마다 소리를 넣으면 한쪽을 빠뜨리기
/// 쉬워서, **안내가 화면에 붙는 순간**에 여기서 냅니다.
class MafiaTabletNotice extends StatefulWidget {
  const MafiaTabletNotice({
    super.key,
    required this.text,
    this.isNight = false,
  });

  const MafiaTabletNotice.day({super.key, required this.text})
    : isNight = false;

  const MafiaTabletNotice.night({super.key, required this.text})
    : isNight = true;

  final String text;
  final bool isNight;

  @override
  State<MafiaTabletNotice> createState() => _MafiaTabletNoticeState();
}

class _MafiaTabletNoticeState extends State<MafiaTabletNotice> {
  @override
  void initState() {
    super.initState();
    if (!widget.isNight) return;
    // context를 쓰는 일이라 첫 프레임 뒤로 미룹니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SoundEffects.play(context, MafiaSounds.voiceNight);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final isNight = widget.isNight;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaTabletDesign.resolve(constraints);
        final scale = MafiaTabletDesign.scaleOf(size);

        return ColoredBox(
          color: isNight ? const Color(0xCC10131A) : const Color(0xCCF2F2F2),
          child: Center(
            child: MafiaEjectionText(
              // 단계 안내는 짧아서 한 박자로 찍습니다.
              beats: [text],
              style: TextStyle(
                color: isNight ? Colors.white : Colors.black,
                fontSize: 64 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 우상단 룰북·설정 아이콘입니다.
///
/// 시안은 밤에 **밝은색 아이콘**을 쓰고 크기·위치도 조금 다릅니다(설정 132 vs
/// 123, 룰북 154×105 vs 149×98). 같은 아이콘이 단계마다 튀어 보이는 것은
/// 시안 작업 중 생긴 차이로 보고 **낮 좌표로 통일**하고 그림만 바꿉니다.
///
/// ⚠️ 시안의 펼친 책·전용 설정 아이콘 4개가 저장소에 없습니다. 지금은 있는
/// 아이콘으로 대신 그립니다.
class MafiaTabletChrome extends StatelessWidget {
  const MafiaTabletChrome({
    super.key,
    this.onRulebookPressed,
    this.onSettingsPressed,
  });

  final VoidCallback? onRulebookPressed;
  final VoidCallback? onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    // 다른 게임 태블릿 사이드바와 같은 이름을 씁니다(icon_role · icon_setting).
    // 마피아 테마 아이콘은 낮·밤 공용이라 시간대로 갈라 쓰지 않습니다.
    final icons = Assets.games.mafia.images.icons;
    return Stack(
      children: [
        MafiaTabletBox(
          rect: MafiaTabletDesign.rulebookIcon,
          ignorePointer: false,
          child: _button(
            icons.iconRole.game.image(fit: BoxFit.contain),
            onRulebookPressed,
            '룰북 열기',
          ),
        ),
        MafiaTabletBox(
          rect: MafiaTabletDesign.settingIcon,
          ignorePointer: false,
          child: _button(
            icons.iconSetting.game.image(fit: BoxFit.contain),
            onSettingsPressed,
            '설정 열기',
          ),
        ),
      ],
    );
  }

  Widget _button(Widget icon, VoidCallback? onPressed, String label) {
    return Semantics(
      button: onPressed != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: icon,
      ),
    );
  }
}

/// 태블릿의 큰 안내 문구입니다. 시안의 `탈락자 닉네임`(64px)이 기준입니다.
class MafiaTabletHeadline extends StatelessWidget {
  const MafiaTabletHeadline({
    super.key,
    required this.text,
    required this.top,
    this.fontSize = 64,
    this.color = Colors.black,
    this.fontWeight = FontWeight.w700,
  });

  final String text;

  /// 시안 기준 top입니다.
  final double top;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaTabletDesign.resolve(constraints);
        final scale = MafiaTabletDesign.scaleOf(size);
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: MafiaTabletDesign.top(size, top),
              child: IgnorePointer(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: fontSize * scale,
                      fontWeight: fontWeight,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 태블릿의 **안내 문구**입니다. [MafiaTabletHeadline]과 같은 자리에 놓이지만,
/// 어몽어스 추방 발표처럼 내려찍히고 긴 문장은 두 박자로 나눠 띄웁니다
/// ([MafiaEjectionText]).
///
/// 헤드라인과 나눠 둔 이유: 확인 현황('5 / 6')처럼 **계속 바뀌는 숫자**는
/// 찍을 때마다 흔들리면 읽기 어렵습니다. 그런 곳은 헤드라인을 그대로 씁니다.
class MafiaTabletAnnouncement extends StatelessWidget {
  const MafiaTabletAnnouncement({
    super.key,
    required this.beats,
    required this.top,
    this.fontSize = 64,
    this.color = Colors.black,
    this.fontWeight = FontWeight.w700,
    this.beatHold = MafiaEjectionText.defaultBeatHold,
  });

  /// 차례로 찍을 문구들입니다. 하나면 한 번만 찍습니다.
  final List<String> beats;

  /// 시안 기준 top입니다.
  final double top;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;

  /// 마지막이 아닌 박자가 머무는 시간입니다.
  final Duration beatHold;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaTabletDesign.resolve(constraints);
        final scale = MafiaTabletDesign.scaleOf(size);
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: MafiaTabletDesign.top(size, top),
              child: IgnorePointer(
                child: MafiaEjectionText(
                  beats: beats,
                  beatHold: beatHold,
                  style: TextStyle(
                    color: color,
                    fontSize: fontSize * scale,
                    fontWeight: fontWeight,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
