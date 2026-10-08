import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_liars_poker/gen/assets.gen.dart' as liar;
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_liars_poker/shared/widgets/pressable_button.dart';
import 'package:game_final_call/gen/assets.gen.dart' as final_call;
import 'package:game_final_call/game_assets.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/widgets/card_view.dart';
import 'package:game_mafia/shared/models/role_catalog.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

//=======================게임 상세 · 플레이 미리보기와 구성품==============================
// 시안(게임 상세)의 CSS 키프레임을 그대로 옮긴 반복 연출입니다. 모든 장면은
// 시안 크기(694×560)로 그린 뒤 상자 크기에 맞춰 줄입니다.

const _designSize = Size(694, 560);
const _stageSize = Size(680, 540);
const _deepest = Color(0xFF05031F);

/// 등록된 게임이면 플레이 미리보기를, 아니면 null을 돌려줍니다.
Widget? buildGamePlayPreview(String gameId) => switch (gameId) {
  'liars_poker' => const _LiarPlayScene(),
  'final_call' => const _FinalPlayScene(),
  'mafia' => const _MafiaPlayScene(),
  _ => null,
};

/// 등록된 게임이면 구성품 판을, 아니면 null을 돌려줍니다.
Widget? buildGameParts(String gameId) => switch (gameId) {
  'liars_poker' => const _LiarParts(),
  'final_call' => const _FinalParts(),
  'mafia' => const _MafiaParts(),
  _ => null,
};

/// 구성품 판을 상자에 꽉 채워 그립니다.
///
/// 논리 크기(최소 694×510)를 상자 비율에 맞춰 늘린 뒤 확대해, 좌우·위아래에
/// 빈 공간이 생기지 않게 합니다(구성품 카드는 폭에 맞춰 늘어납니다).
/// 플레이 미리보기는 스스로 상자를 채우므로 감싸지 않습니다.
class GameDetailStage extends StatelessWidget {
  const GameDetailStage({super.key, required this.child});

  final Widget child;

  /// 구성품 판이 넘치지 않는 가장 작은 논리 크기입니다. 높이가 낮을수록
  /// 크게 보입니다.
  static const double _partsMinWidth = 694;
  static const double _partsMinHeight = 510;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 더 빠듯한 쪽에 맞춰 확대하고, 남는 쪽은 논리 크기를 늘려 상자를
        // 꽉 채웁니다. 그래서 어느 비율의 상자에서도 빈 띠가 생기지 않습니다.
        final scale = math.min(
          constraints.maxWidth / _partsMinWidth,
          constraints.maxHeight / _partsMinHeight,
        );
        return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: constraints.maxWidth / scale,
            height: constraints.maxHeight / scale,
            child: child,
          ),
        );
      },
    );
  }
}

//=======================키프레임 도우미==============================
/// CSS `@keyframes`처럼 [stops]의 (퍼센트, 값) 사이를 ease로 잇습니다.
double _kf(double pct, List<(double, double)> stops) {
  if (pct <= stops.first.$1) return stops.first.$2;
  for (var i = 1; i < stops.length; i++) {
    final (p1, v1) = stops[i];
    if (pct <= p1) {
      final (p0, v0) = stops[i - 1];
      if (p1 == p0) return v1;
      final t = Curves.ease.transform((pct - p0) / (p1 - p0));
      return v0 + (v1 - v0) * t;
    }
  }
  return stops.last.$2;
}

/// [period] 주기로 반복하며 지금 위치를 퍼센트(0~100)로 넘겨줍니다.
class _Loop extends StatefulWidget {
  const _Loop({required this.period, required this.builder});

  final Duration period;
  final Widget Function(BuildContext context, double pct) builder;

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value * 100),
    );
  }
}

Widget _at(double left, double top, Widget child) =>
    Positioned(left: left, top: top, child: child);

Widget _rotated(double degrees, Widget child) =>
    Transform.rotate(angle: degrees * math.pi / 180, child: child);

Widget _fade(double opacity, Widget child) =>
    Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);

/// 시안 장면 공통 바탕: 아래쪽 비스듬한 띠 + 680×540 무대.
class _SceneBackdrop extends StatelessWidget {
  const _SceneBackdrop({required this.band, required this.stage, this.overlay});

  final Color band;
  final List<Widget> stage;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: ClipPath(
            clipper: const _BandClipper(),
            child: ColoredBox(color: band),
          ),
        ),
        ?overlay,
        // 바탕 띠는 상자 전체에 깔고, 무대만 상자에 맞춰 줄입니다.
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox.fromSize(
              size: _designSize,
              child: Center(
                child: SizedBox.fromSize(
                  size: _stageSize,
                  child: Stack(clipBehavior: Clip.none, children: stage),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BandClipper extends CustomClipper<Path> {
  const _BandClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, size.height * 0.72)
    ..lineTo(size.width, size.height * 0.48)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 태블릿 그림: 흰 테두리 300×210.
class _TabletFrame extends StatelessWidget {
  const _TabletFrame({required this.screen});

  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 210,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: MosiColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MosiColors.ink, width: 3),
        boxShadow: const [BoxShadow(color: _deepest, offset: Offset(10, 10))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: screen),
    );
  }
}

/// 휴대폰 그림입니다. [glow]가 0보다 크면 [glowColor] 테두리가 빛납니다.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({
    required this.screenColor,
    required this.child,
    this.width = 110,
    this.height = 200,
    this.glow = 0,
    this.glowColor = MosiColors.lime,
    this.small = false,
  });

  final Color screenColor;
  final Widget child;
  final double width;
  final double height;
  final double glow;
  final Color glowColor;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final shadow = small ? 6.0 : 8.0;
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(small ? 4 : 5),
      decoration: BoxDecoration(
        color: MosiColors.white,
        borderRadius: BorderRadius.circular(small ? 16 : 18),
        border: Border.all(color: MosiColors.ink, width: 3),
        boxShadow: [
          if (glow > 0)
            BoxShadow(
              color: glowColor.withValues(alpha: glow),
              spreadRadius: 6,
            ),
          BoxShadow(color: _deepest, offset: Offset(shadow, shadow)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(small ? 9 : 10),
        child: ColoredBox(
          color: screenColor,
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}

Widget _nameTag(
  String name,
  Color background,
  Color foreground, {
  double size = 11,
}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
  decoration: BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(999),
  ),
  child: Text(
    name,
    style: MosiFonts.sans(
      size: size,
      weight: FontWeight.w700,
      color: foreground,
    ),
  ),
);

/// 작은 카드 뒷면/앞면(휴대폰 화면 안의 손패).
Widget _miniCard({
  required double width,
  required double height,
  required Color background,
  required Color border,
  double borderWidth = 2,
  double radius = 3,
  String? label,
  Color labelColor = MosiColors.white,
  double labelSize = 18,
}) => Container(
  width: width,
  height: height,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border, width: borderWidth),
  ),
  child: label == null
      ? null
      : Text(
          label,
          style: MosiFonts.playfair(size: labelSize, color: labelColor),
        ),
);

/// 말풍선입니다. [tail]은 꼬리가 붙는 모서리입니다.
Widget _speech(
  String text, {
  required Color background,
  Color foreground = MosiColors.navy,
  double fontSize = 18,
  bool serif = false,
  bool tailRight = false,
}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  decoration: BoxDecoration(
    color: background,
    border: Border.all(color: MosiColors.ink, width: 3),
    borderRadius: BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(tailRight ? 14 : 3),
      bottomRight: Radius.circular(tailRight ? 3 : 14),
    ),
  ),
  child: Text(
    text,
    style: serif
        ? MosiFonts.playfair(size: fontSize, color: foreground)
        : MosiFonts.sans(
            size: fontSize,
            weight: FontWeight.w700,
            color: foreground,
          ),
  ),
);

/// 팀 대화 말풍선(왼쪽에 팀 색 띠).
Widget _teamBubble(String text, {required Color tint, required Color team}) =>
    Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MosiColors.ink, width: 2.5),
        boxShadow: const [BoxShadow(color: _deepest, offset: Offset(3, 3))],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: team),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 11, 7),
              child: Text(
                text,
                style: MosiFonts.sans(
                  size: 12,
                  weight: FontWeight.w700,
                  color: const Color(0xFF141414),
                ),
              ),
            ),
          ],
        ),
      ),
    );

//=======================라이어스 포커 미리보기 (8초)==============================
class _LiarPlayScene extends StatelessWidget {
  const _LiarPlayScene();

  static const _violet = Color(0xFF4A1A5E);

  @override
  Widget build(BuildContext context) {
    return _Loop(
      period: const Duration(seconds: 8),
      builder: (context, p) {
        final shake = _kf(p, [(66, 0), (67, -7), (69, 7), (71, -3), (73, 0)]);
        final backScale = _kf(p, [(56, 1), (59, 0)]);
        final frontScale = _kf(p, [(59, 0), (62, 1)]);

        Widget flyingCard({
          required double fromX,
          required double fromY,
          required double toRotate,
          required double start,
          required double visible,
          required double land,
          required Widget front,
        }) {
          final x = _kf(p, [(start, fromX), (land, 0)]);
          final y = _kf(p, [(start, fromY), (land, 0)]);
          final rot = _kf(p, [(start, -30), (land, toRotate)]);
          final scale = _kf(p, [(start, 0.7), (land, 1)]);
          final opacity = _kf(p, [(start, 0), (visible, 1), (92, 1), (100, 0)]);
          return _fade(
            opacity,
            Transform.translate(
              offset: Offset(x, y),
              child: _rotated(
                rot,
                Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: 44,
                    height: 62,
                    child: Stack(
                      children: [
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(backScale, 1, 1),
                          child: const _LiarCardBack(),
                        ),
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(frontScale, 1, 1),
                          child: front,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final glowA = _kf(p, [(20, 1), (24, 0)]);
        final glowB = _kf(p, [(30, 0), (34, 1), (62, 1), (66, 0)]);
        final claimOpacity = _kf(p, [(18, 0), (21, 1), (40, 1), (43, 0)]);
        final claimScale = _kf(p, [(18, 0.6), (21, 1)]);
        final resultOpacity = _kf(p, [(72, 0), (76, 1), (90, 1), (94, 0)]);
        final resultY = _kf(p, [(72, 8), (76, 0)]);
        final btnScale = _kf(p, [
          (33, 1),
          (38, 1.14),
          (42, 1.14),
          (45, 0.86),
          (48, 1),
        ]);
        final ringOpacity = _kf(p, [(34, 0), (40, 1), (47, 0)]);
        final ringScale = _kf(p, [(34, 0.8), (40, 1.15), (47, 1.7)]);
        final callOpacity = _kf(p, [(45, 0), (48, 1), (62, 1), (66, 0)]);
        final callScale = _kf(p, [(45, 0.6), (48, 1)]);
        final stampOpacity = _kf(p, [(63, 0), (67, 1), (90, 1), (94, 0)]);
        final stampScale = _kf(p, [(63, 2.4), (67, 0.95), (70, 1)]);

        Widget hand(
          List<double> rotations, {
          double gap = 20,
          double base = 14,
        }) => Stack(
          children: [
            for (var i = 0; i < rotations.length; i++)
              Positioned(
                left: base + i * gap,
                bottom: rotations[i] == 0 && rotations.length == 3 ? 16 : 12,
                child: _rotated(
                  rotations[i],
                  _miniCard(
                    width: rotations.length == 3 ? 24 : 22,
                    height: rotations.length == 3 ? 34 : 30,
                    background: MosiColors.white,
                    border: MosiColors.ink,
                  ),
                ),
              ),
          ],
        );

        return _SceneBackdrop(
          band: MosiColors.violet,
          stage: [
            _at(
              190 + shake,
              30,
              _TabletFrame(
                screen: ColoredBox(
                  color: _violet,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: MosiColors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '기준 카드 · A',
                            style: MosiFonts.sans(
                              size: 11,
                              weight: FontWeight.w700,
                              color: const Color(0xFF1B1022),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 12,
                        child: Text(
                          'TABLE',
                          style: MosiFonts.grotesk(
                            size: 10,
                            color: const Color(0xFFC7B8CC),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      Center(
                        child: Transform.translate(
                          offset: const Offset(0, 5),
                          child: MosiDashedBorder(
                            color: const Color(0x47FFFFFF),
                            radius: 55,
                            child: const SizedBox(width: 110, height: 110),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        bottom: 9,
                        child: Text(
                          '사라 → 다음은 민준',
                          style: MosiFonts.sans(
                            size: 11,
                            weight: FontWeight.w600,
                            color: const Color(0xFFE2D2E8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _at(
              292,
              102,
              flyingCard(
                fromX: -226,
                fromY: 262,
                toRotate: -6,
                start: 3,
                visible: 5,
                land: 17,
                front: const _LiarCardFace(label: 'A'),
              ),
            ),
            _at(
              340,
              106,
              flyingCard(
                fromX: -262,
                fromY: 258,
                toRotate: 8,
                start: 7,
                visible: 9,
                land: 21,
                front: const _LiarCardFace(
                  label: 'K',
                  background: Color(0xFFFFE3E7),
                  color: Color(0xFFC0283C),
                ),
              ),
            ),
            // 휴대폰 1: 사라
            _at(
              40,
              262,
              _rotated(
                -8,
                SizedBox(
                  width: 110,
                  height: 200,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _PhoneFrame(
                        screenColor: _violet,
                        glow: glowA,
                        glowColor: MosiColors.lime,
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Column(
                                  children: [
                                    _nameTag(
                                      '사라',
                                      MosiColors.lime,
                                      MosiColors.navy,
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      '내 차례',
                                      style: MosiFonts.sans(
                                        size: 10,
                                        weight: FontWeight.w600,
                                        color: const Color(0xFFE2D2E8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned.fill(child: hand([-12, 0, 12])),
                          ],
                        ),
                      ),
                      Positioned(
                        left: -2,
                        top: -60,
                        child: _fade(
                          claimOpacity,
                          Transform.scale(
                            scale: claimScale,
                            alignment: const Alignment(-0.8, 1),
                            child: _speech(
                              'A 두 장!',
                              background: MosiColors.lime,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -2,
                        top: -60,
                        child: _fade(
                          resultOpacity,
                          Transform.translate(
                            offset: Offset(0, resultY),
                            child: _speech(
                              '들켰다… 룰렛으로',
                              background: MosiColors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 휴대폰 2: 민준
            _at(
              530,
              262,
              _rotated(
                8,
                SizedBox(
                  width: 110,
                  height: 200,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _PhoneFrame(
                        screenColor: _violet,
                        glow: glowB,
                        glowColor: MosiColors.coral,
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Column(
                                  children: [
                                    _nameTag(
                                      '민준',
                                      MosiColors.sky,
                                      MosiColors.navy,
                                    ),
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      width: 58,
                                      height: 58,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: -7,
                                            top: -7,
                                            right: -7,
                                            bottom: -7,
                                            child: _fade(
                                              ringOpacity,
                                              Transform.scale(
                                                scale: ringScale,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: MosiColors.coral,
                                                      width: 3,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Transform.scale(
                                            scale: btnScale,
                                            child: Container(
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: MosiColors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: MosiColors.ink,
                                                  width: 3,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color(0xFFCFC9D4),
                                                    offset: Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                'Liar',
                                                style: MosiFonts.playfair(
                                                  size: 17,
                                                  color: MosiColors.ink,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: hand([-8, 8], gap: 22, base: 22),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: -6,
                        top: -60,
                        child: _fade(
                          callOpacity,
                          Transform.scale(
                            scale: callScale,
                            alignment: const Alignment(0.8, 1),
                            child: _speech(
                              'LIAR! 거짓말',
                              background: MosiColors.coral,
                              tailRight: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 휴대폰 3: 하린
            _at(
              285,
              300,
              _PhoneFrame(
                screenColor: _violet,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          children: [
                            _nameTag('하린', MosiColors.sun, MosiColors.navy),
                            const SizedBox(height: 14),
                            Text(
                              '지켜보는 중',
                              style: MosiFonts.sans(
                                size: 10,
                                weight: FontWeight.w600,
                                color: const Color(0xFFE2D2E8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(child: hand([-8, 8], gap: 22, base: 22)),
                  ],
                ),
              ),
            ),
            _at(
              250,
              168,
              _fade(
                stampOpacity,
                _rotated(
                  -12,
                  Transform.scale(
                    scale: stampScale,
                    child: Container(
                      width: 180,
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: MosiColors.red,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MosiColors.ink, width: 4),
                      ),
                      child: Text(
                        'LIAR!',
                        style: MosiFonts.playfair(
                          size: 34,
                          color: MosiColors.white,
                          letterSpacing: 1,
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
  }
}

class _LiarCardBack extends StatelessWidget {
  const _LiarCardBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 62,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: MosiColors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: MosiColors.ink, width: 2.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: MosiColors.ink, width: 1),
        ),
        alignment: Alignment.center,
        child: _rotated(
          45,
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(color: MosiColors.ink, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiarCardFace extends StatelessWidget {
  const _LiarCardFace({
    required this.label,
    this.background = MosiColors.white,
    this.color = MosiColors.ink,
  });

  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: MosiColors.ink, width: 2.5),
      ),
      child: Text(label, style: MosiFonts.playfair(size: 30, color: color)),
    );
  }
}

//=======================파이널콜 미리보기 (14.66초)==============================
class _FinalPlayScene extends StatelessWidget {
  const _FinalPlayScene();

  static const _black = Color(0xFF141414);
  static const _red = Color(0xFFE0302E);
  static const _blue = Color(0xFF2F5BEA);
  static const _yellow = Color(0xFFE5DB00);
  static const _green = Color(0xFF2EB872);

  @override
  Widget build(BuildContext context) {
    return _Loop(
      period: const Duration(milliseconds: 14660),
      builder: (context, p) {
        Widget handCard(
          Color border,
          double rotate, {
          double w = 20,
          double h = 28,
        }) => _rotated(
          rotate,
          _miniCard(
            width: w,
            height: h,
            background: const Color(0xFF111111),
            border: border,
            borderWidth: 1.5,
            radius: 2,
          ),
        );

        final drawX = _kf(p, [(1.6, 230), (9.2, 0)]);
        final drawY = _kf(p, [(1.6, -274), (9.2, 0)]);
        final drawScale = _kf(p, [(1.6, 0.7), (9.2, 1)]);
        final drawOpacity = _kf(p, [(1.6, 0), (2.7, 1), (14.7, 1), (16.4, 0)]);
        final discardX = _kf(p, [(15.8, -271), (23.5, 0)]);
        final discardY = _kf(p, [(15.8, 268), (23.5, 0)]);
        final discardRot = _kf(p, [(15.8, -20), (23.5, 7)]);
        final discardScale = _kf(p, [(15.8, 0.7), (23.5, 1)]);
        final discardOpacity = _kf(p, [
          (15.8, 0),
          (16.9, 1),
          (96.6, 1),
          (100, 0),
        ]);
        final glowA = _kf(p, [(22.9, 1), (25.5, 0)]);
        final btnScale = _kf(p, [
          (83, 1),
          (85.7, 1.14),
          (86.9, 1.14),
          (89.1, 0.86),
          (91, 1),
        ]);
        final ringOpacity = _kf(p, [(83, 0), (86.3, 1), (91, 0)]);
        final ringScale = _kf(p, [(83, 0.85), (86.3, 1.1), (91, 1.5)]);
        final callOpacity = _kf(p, [(85, 0), (86.9, 1), (91.8, 1), (94.3, 0)]);
        final callScale = _kf(p, [(85, 0.6), (86.9, 1)]);
        final bannerOpacity = _kf(p, [
          (86.9, 0),
          (89.1, 1),
          (95.9, 1),
          (98, 0),
        ]);
        final bannerY = _kf(p, [(86.9, -8), (89.1, 0)]);
        final scoreOpacity = _kf(p, [(87.7, 0), (90.2, 1), (95.9, 1), (98, 0)]);
        final scoreScale = _kf(p, [(87.7, 0.4), (90.2, 1)]);
        final heartOpacity = _kf(p, [
          (91.8, 1),
          (93.5, 1),
          (95.9, 0),
          (98.4, 0),
          (100, 1),
        ]);
        final heartScale = _kf(p, [
          (91.8, 1),
          (93.5, 1.5),
          (95.9, 0.6),
          (98.4, 0.6),
          (100, 1),
        ]);
        final heartY = _kf(p, [(93.5, 0), (95.9, -14), (98.4, -14), (100, 0)]);
        final shakeC = _kf(p, [
          (92.5, 0),
          (93, -6),
          (94.3, 6),
          (95.5, -3),
          (96.7, 0),
        ]);
        final t1 = _kf(p, [(5.5, 0), (7.4, 1), (13.7, 1), (15.6, 0)]);
        final t2 = _kf(p, [(68.9, 0), (70.9, 1), (75.4, 1), (77.5, 0)]);
        final t3 = _kf(p, [(72, 0), (73.8, 1), (78.7, 1), (80.4, 0)]);
        final t4 = _kf(p, [(76.1, 0), (77.9, 1), (82.2, 1), (84.3, 0)]);
        final teamRed = _kf(p, [
          (4.9, 0),
          (7.4, 1),
          (22.1, 1),
          (24.6, 0),
          (66.3, 0),
          (69.7, 1),
          (75.4, 1),
          (77.9, 0),
        ]);
        final teamBlue = _kf(p, [(71.4, 0), (73.8, 1), (82.8, 1), (85.3, 0)]);
        final zoomDim = _kf(p, [(23.7, 0), (28.7, 1), (64.9, 1), (69.3, 0)]);
        // 사라 폰이 가로로 돌면서 커집니다.
        final zoomT = _kf(p, [(24.1, 0), (31.5, 1), (63.5, 1), (68.6, 0)]);
        final zoomOpacity = _kf(p, [
          (24.1, 0),
          (25.3, 1),
          (68.6, 1),
          (69.3, 0),
        ]);
        final r7 = _kf(p, [
          (35.7, 0),
          (38.5, -16),
          (45.4, -16),
          (48.2, 0),
          (50.3, -16),
          (58, -16),
          (60.7, 0),
        ]);
        final r3y = _kf(p, [(35.7, 0), (38.5, -16), (45.4, -16), (48.2, 0)]);
        final r3o = _kf(p, [(53.8, 1), (56.6, 0.35), (63.5, 0.35), (66.3, 1)]);
        final b7 = _kf(p, [(47.5, 0), (50.3, -16), (58, -16), (60.7, 0)]);
        final y2 = _kf(p, [(35.7, 1), (38.5, 0.35), (60.7, 0.35), (63.5, 1)]);
        final l1o = _kf(p, [
          (35.7, 0),
          (39.2, 1),
          (53.8, 1),
          (56.6, 0.4),
          (63.5, 0.4),
          (66.3, 0),
        ]);
        final l1x = _kf(p, [(35.7, -10), (39.2, 0)]);
        final x1 = _kf(p, [(53.8, 0), (56.6, 1), (63.5, 1), (66.3, 0)]);
        final l2o = _kf(p, [(48.2, 0), (51.7, 1), (63.5, 1), (66.3, 0)]);
        final l2x = _kf(p, [(48.2, -10), (51.7, 0)]);
        final bigO = _kf(p, [(55.9, 0), (58.6, 1), (63.5, 1), (66.3, 0)]);
        final bigS = _kf(p, [(55.9, 2.2), (58.6, 1)]);
        final bigR = _kf(p, [(55.9, -12), (58.6, -8)]);

        Widget score(
          String text,
          Color border, {
          Color bg = MosiColors.white,
          Color fg = _black,
        }) => _fade(
          scoreOpacity,
          Transform.scale(
            scale: scoreScale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: border, width: 2),
              ),
              child: Text(text, style: MosiFonts.grotesk(size: 13, color: fg)),
            ),
          ),
        );

        Widget bigCard(
          String n,
          String label,
          Color color, {
          double dy = 0,
          double opacity = 1,
        }) => _fade(
          opacity,
          Transform.translate(
            offset: Offset(0, dy),
            child: Container(
              width: 60,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(n, style: MosiFonts.playfair(size: 36, color: color)),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: MosiFonts.sans(
                      size: 9,
                      weight: FontWeight.w700,
                      color: const Color(0xFFB9B4A8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        return _SceneBackdrop(
          band: MosiColors.sky,
          stage: [
            _at(
              190,
              30,
              _TabletFrame(
                screen: ColoredBox(
                  color: const Color(0xFFEFEDE8),
                  child: Stack(
                    children: [
                      Center(
                        child: Container(
                          width: 156,
                          height: 156,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F6F2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2A2A2A),
                              width: 9,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _fade(
                          bannerOpacity,
                          Transform.translate(
                            offset: Offset(0, bannerY),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _yellow,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: MosiColors.ink,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                'CALL! 모두 공개',
                                style: MosiFonts.sans(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: _black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 카드 더미
            _at(
              296,
              114,
              Container(
                width: 30,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF2A2A2A), offset: Offset(2, 2)),
                  ],
                ),
                child: _rotated(
                  45,
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFB9B4A8),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _at(
              346,
              112,
              _fade(
                discardOpacity,
                Transform.translate(
                  offset: Offset(discardX, discardY),
                  child: _rotated(
                    discardRot,
                    Transform.scale(
                      scale: discardScale,
                      child: _miniCard(
                        width: 30,
                        height: 42,
                        background: const Color(0xFF111111),
                        border: _blue,
                        borderWidth: 1.5,
                        label: '2',
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _at(
              66,
              388,
              _fade(
                drawOpacity,
                Transform.translate(
                  offset: Offset(drawX, drawY),
                  child: Transform.scale(
                    scale: drawScale,
                    child: _miniCard(
                      width: 30,
                      height: 42,
                      background: const Color(0xFF111111),
                      border: _red,
                      borderWidth: 1.5,
                      label: '7',
                    ),
                  ),
                ),
              ),
            ),
            _at(232, 124, score('14', _red)),
            _at(418, 124, score('17', _blue)),
            _at(326, 56, score('12', _blue)),
            _at(
              329,
              196,
              score('9', MosiColors.ink, bg: _red, fg: MosiColors.white),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TeamLinePainter(
                    redOpacity: teamRed,
                    blueOpacity: teamBlue,
                  ),
                ),
              ),
            ),
            // 휴대폰 4: 지우
            _at(
              556,
              12,
              _rotated(
                6,
                _PhoneFrame(
                  width: 88,
                  height: 152,
                  small: true,
                  screenColor: _black,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _nameTag(
                            '지우',
                            _blue,
                            MosiColors.white,
                            size: 10,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 10,
                        child: handCard(_blue, -10, w: 17, h: 24),
                      ),
                      Positioned(
                        left: 25,
                        bottom: 12,
                        child: handCard(_blue, -3, w: 17, h: 24),
                      ),
                      Positioned(
                        left: 38,
                        bottom: 12,
                        child: handCard(_yellow, 4, w: 17, h: 24),
                      ),
                      Positioned(
                        left: 51,
                        bottom: 10,
                        child: handCard(_red, 11, w: 17, h: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 휴대폰 1: 사라
            _at(
              40,
              262,
              _rotated(
                -8,
                _PhoneFrame(
                  screenColor: _black,
                  glow: glowA,
                  glowColor: _yellow,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            children: [
                              _nameTag('사라', _red, MosiColors.white),
                              const SizedBox(height: 14),
                              Text(
                                '가져오기 · 교체',
                                style: MosiFonts.sans(
                                  size: 10,
                                  weight: FontWeight.w600,
                                  color: const Color(0xFFB9B4A8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        bottom: 12,
                        child: handCard(_red, -12),
                      ),
                      Positioned(
                        left: 26,
                        bottom: 15,
                        child: handCard(_red, -4),
                      ),
                      Positioned(
                        left: 42,
                        bottom: 15,
                        child: handCard(_blue, 4),
                      ),
                      Positioned(
                        left: 58,
                        bottom: 12,
                        child: handCard(_yellow, 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 휴대폰 2: 민준
            _at(
              530,
              262,
              _rotated(
                8,
                SizedBox(
                  width: 110,
                  height: 200,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _PhoneFrame(
                        screenColor: _black,
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Column(
                                  children: [
                                    _nameTag('민준', _blue, MosiColors.white),
                                    const SizedBox(height: 22),
                                    SizedBox(
                                      width: 70,
                                      height: 32,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: -6,
                                            top: -6,
                                            right: -6,
                                            bottom: -6,
                                            child: _fade(
                                              ringOpacity,
                                              Transform.scale(
                                                scale: ringScale,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: _yellow,
                                                      width: 3,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Transform.scale(
                                            scale: btnScale,
                                            child: Container(
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: _yellow,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: MosiColors.ink,
                                                  width: 2.5,
                                                ),
                                              ),
                                              child: Text(
                                                'CALL',
                                                style: MosiFonts.playfair(
                                                  size: 15,
                                                  color: _black,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 18,
                              bottom: 12,
                              child: handCard(_blue, -8),
                            ),
                            Positioned(
                              left: 34,
                              bottom: 14,
                              child: handCard(_blue, 0),
                            ),
                            Positioned(
                              left: 50,
                              bottom: 12,
                              child: handCard(_green, 8),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: -6,
                        top: -60,
                        child: _fade(
                          callOpacity,
                          Transform.scale(
                            scale: callScale,
                            alignment: const Alignment(0.8, 1),
                            child: _speech(
                              'CALL!',
                              background: _yellow,
                              foreground: _black,
                              fontSize: 20,
                              serif: true,
                              tailRight: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 휴대폰 3: 하린
            _at(
              285 + shakeC,
              300,
              _PhoneFrame(
                screenColor: _black,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          children: [
                            _nameTag('하린', _red, MosiColors.white),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _Heart(size: 16),
                                const SizedBox(width: 4),
                                const _Heart(size: 16),
                                const SizedBox(width: 4),
                                _fade(
                                  heartOpacity,
                                  Transform.translate(
                                    offset: Offset(0, heartY),
                                    child: Transform.scale(
                                      scale: heartScale,
                                      child: const _Heart(size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      bottom: 12,
                      child: handCard(_green, -8),
                    ),
                    Positioned(
                      left: 34,
                      bottom: 14,
                      child: handCard(_yellow, 0),
                    ),
                    Positioned(left: 50, bottom: 12, child: handCard(_red, 8)),
                  ],
                ),
              ),
            ),
            // 팀원끼리 숫자 확인
            _at(
              262,
              250,
              _fade(
                t1,
                _teamBubble(
                  '사라, 숫자 좀 됐어?',
                  tint: const Color(0xFFFFE3E1),
                  team: _red,
                ),
              ),
            ),
            _at(
              36,
              210,
              _fade(
                t2,
                _teamBubble(
                  '7 들어왔어! 지금 14',
                  tint: const Color(0xFFFFE3E1),
                  team: _red,
                ),
              ),
            ),
            _at(
              448,
              206,
              _fade(
                t3,
                _teamBubble(
                  '지우야, 우리 이 정도면 충분해?',
                  tint: const Color(0xFFE1E9FF),
                  team: _blue,
                ),
              ),
            ),
            _at(
              398,
              172,
              _fade(
                t4,
                _teamBubble(
                  '난 12! 꼴찌는 아냐, 콜 가자',
                  tint: const Color(0xFFE1E9FF),
                  team: _blue,
                ),
              ),
            ),
            // 사라 폰 확대
            Positioned(
              left: -60,
              top: -60,
              right: -60,
              bottom: -60,
              child: IgnorePointer(
                child: _fade(
                  zoomDim,
                  const ColoredBox(color: Color(0x9E05031F)),
                ),
              ),
            ),
            _at(
              70,
              140,
              _fade(
                zoomOpacity,
                Transform.translate(
                  offset: Offset(-245 * (1 - zoomT), 92 * (1 - zoomT)),
                  child: _rotated(
                    -98 * (1 - zoomT),
                    Transform.scale(
                      scale: 0.42 + 0.58 * zoomT,
                      child: Container(
                        width: 540,
                        height: 260,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: MosiColors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: MosiColors.ink, width: 3),
                          boxShadow: const [
                            BoxShadow(color: _deepest, offset: Offset(10, 10)),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                          decoration: BoxDecoration(
                            color: _black,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: -4,
                                top: -4,
                                child: _nameTag(
                                  '사라 · 레드팀',
                                  _red,
                                  MosiColors.white,
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 18),
                                    child: Row(
                                      children: [
                                        bigCard('7', '빨강', _red, dy: r7),
                                        const SizedBox(width: 8),
                                        bigCard(
                                          '3',
                                          '빨강',
                                          _red,
                                          dy: r3y,
                                          opacity: r3o,
                                        ),
                                        const SizedBox(width: 8),
                                        bigCard('7', '파랑', _blue, dy: b7),
                                        const SizedBox(width: 8),
                                        bigCard(
                                          '2',
                                          '노랑',
                                          _yellow,
                                          opacity: y2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 30),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          _fade(
                                            l1o,
                                            Transform.translate(
                                              offset: Offset(l1x, 0),
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF2A1A1A,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: _red,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      '같은 색 7 + 3 = 10',
                                                      style: MosiFonts.sans(
                                                        size: 13,
                                                        weight: FontWeight.w700,
                                                        color: MosiColors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    left: 6,
                                                    right: 6,
                                                    child: Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child:
                                                          FractionallySizedBox(
                                                            widthFactor: x1
                                                                .clamp(
                                                                  0.0,
                                                                  1.0,
                                                                ),
                                                            child: Container(
                                                              height: 3,
                                                              color: MosiColors
                                                                  .white,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          _fade(
                                            l2o,
                                            Transform.translate(
                                              offset: Offset(l2x, 0),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _yellow,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: MosiColors.ink,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Text(
                                                  '같은 숫자 7 + 7 = 14',
                                                  style: MosiFonts.sans(
                                                    size: 13,
                                                    weight: FontWeight.w700,
                                                    color: _black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: _fade(
                                  bigO,
                                  _rotated(
                                    bigR,
                                    Transform.scale(
                                      scale: bigS,
                                      child: Container(
                                        width: 84,
                                        height: 84,
                                        decoration: BoxDecoration(
                                          color: _yellow,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: MosiColors.ink,
                                            width: 3,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black,
                                              offset: Offset(4, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '14',
                                              style: MosiFonts.grotesk(
                                                size: 32,
                                                color: _black,
                                                height: 1,
                                              ),
                                            ),
                                            Text(
                                              '내 점수',
                                              style: MosiFonts.sans(
                                                size: 10,
                                                weight: FontWeight.w700,
                                                color: _black,
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
  }
}

class _TeamLinePainter extends CustomPainter {
  const _TeamLinePainter({required this.redOpacity, required this.blueOpacity});

  final double redOpacity;
  final double blueOpacity;

  void _dashed(Canvas canvas, Path path, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 12;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (redOpacity > 0) {
      _dashed(
        canvas,
        Path()
          ..moveTo(120, 330)
          ..quadraticBezierTo(220, 420, 300, 400),
        const Color(0xFFE0302E).withValues(alpha: redOpacity),
      );
    }
    if (blueOpacity > 0) {
      _dashed(
        canvas,
        Path()
          ..moveTo(600, 170)
          ..quadraticBezierTo(640, 220, 600, 262),
        const Color(0xFF2F5BEA).withValues(alpha: blueOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TeamLinePainter oldDelegate) =>
      oldDelegate.redOpacity != redOpacity ||
      oldDelegate.blueOpacity != blueOpacity;
}

class _Heart extends StatelessWidget {
  const _Heart({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size * 20 / 22),
    painter: const _HeartPainter(stroke: false),
  );
}

class _HeartPainter extends CustomPainter {
  const _HeartPainter({required this.stroke});

  final bool stroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 22, size.height / 20);
    final path = Path()
      ..moveTo(0, 5)
      ..cubicTo(0, -2, 9, -3, 11, 4)
      ..cubicTo(13, -3, 22, -2, 22, 5)
      ..cubicTo(22, 12, 11, 18, 11, 20)
      ..cubicTo(11, 18, 0, 12, 0, 5)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFE0302E));
    if (stroke) {
      canvas.drawPath(
        path,
        Paint()
          ..color = MosiColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeartPainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}

//=======================마피아 미리보기 (10초)==============================
class _MafiaPlayScene extends StatelessWidget {
  const _MafiaPlayScene();

  static const _night = Color(0xFF10131A);
  static const _street = Color(0xFF212730);

  @override
  Widget build(BuildContext context) {
    return _Loop(
      period: const Duration(seconds: 10),
      builder: (context, p) {
        final nightO = _kf(p, [(55, 1), (60, 0), (96, 0), (100, 1)]);
        final dayO = 1 - nightO;
        final aimO = _kf(p, [(12, 0), (16, 1), (55, 1), (58, 0)]);
        final aimS = _kf(p, [(12, 1.6), (16, 1)]);
        final tapMO = _kf(p, [(13, 0), (15, 1), (20, 0)]);
        final tapMS = _kf(p, [(13, 0.4), (15, 1), (20, 1.8)]);
        final doneO = _kf(p, [(20, 0), (23, 1), (55, 1), (58, 0)]);
        final healO = _kf(p, [(30, 0), (34, 1), (55, 1), (58, 0)]);
        final healS = _kf(p, [(30, 1.6), (34, 1)]);
        final tapDO = _kf(p, [(31, 0), (33, 1), (38, 0)]);
        final tapDS = _kf(p, [(31, 0.4), (33, 1), (38, 1.8)]);
        final sunO = _kf(p, [(56, 0), (64, 1), (96, 1), (100, 0)]);
        final sunY = _kf(p, [(56, 40), (64, 0)]);
        final msgO = _kf(p, [(62, 0), (66, 1), (94, 1), (97, 0)]);
        final msgY = _kf(p, [(62, 8), (66, 0)]);
        final aliveO = _kf(p, [(68, 0), (72, 1), (92, 1), (95, 0)]);
        final aliveS = _kf(p, [(68, 0.6), (72, 1)]);
        final talkO = _kf(p, [(74, 0), (78, 1), (94, 1), (97, 0)]);
        // z가 2초마다 위로 떠오릅니다.
        final zp = (p * 10 / 2) % 1 * 100;
        final zzO = _kf(zp, [(0, 0), (30, 1), (100, 0)]);
        final zzY = _kf(zp, [(0, 0), (100, -14)]);

        Widget choice(String name, {Widget? overlay}) => SizedBox(
          width: 74,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 74,
                padding: const EdgeInsets.symmetric(vertical: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _street,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  name,
                  style: MosiFonts.sans(
                    size: 10,
                    weight: FontWeight.w700,
                    color: MosiColors.white,
                  ),
                ),
              ),
              ?overlay,
            ],
          ),
        );

        Widget tapDot(double o, double s) => _fade(
          o,
          Transform.scale(
            scale: s,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0x99FFFFFF),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );

        return _SceneBackdrop(
          band: _street,
          overlay: Positioned.fill(
            child: _fade(nightO, const ColoredBox(color: Color(0x7305031F))),
          ),
          stage: [
            _at(
              190,
              30,
              _TabletFrame(
                screen: Stack(
                  children: [
                    Positioned.fill(
                      child: _fade(
                        nightO,
                        ColoredBox(
                          color: _night,
                          child: Stack(
                            children: [
                              Positioned(
                                right: 30,
                                top: 18,
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFFC400),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Positioned(
                                        left: -12,
                                        top: -6,
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: const BoxDecoration(
                                            color: _night,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              for (final (x, y, r) in const [
                                (30.0, 30.0, 3.0),
                                (90.0, 18.0, 3.0),
                                (150.0, 40.0, 2.0),
                              ])
                                Positioned(
                                  left: x,
                                  top: y,
                                  child: Container(
                                    width: r,
                                    height: r,
                                    decoration: const BoxDecoration(
                                      color: MosiColors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 72,
                                child: Text(
                                  '밤이 되었습니다',
                                  textAlign: TextAlign.center,
                                  style: MosiFonts.sans(
                                    size: 22,
                                    weight: FontWeight.w700,
                                    color: MosiColors.white,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 108,
                                child: Text(
                                  '각자 휴대폰에서 몰래 고르세요',
                                  textAlign: TextAlign.center,
                                  style: MosiFonts.sans(
                                    size: 11,
                                    color: const Color(0xFFB9BDC9),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 36,
                                child: ClipPath(
                                  clipper: const _SkylineClipper(),
                                  child: const ColoredBox(color: _street),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: _fade(
                        dayO,
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF8FD3FF), Color(0xFFFFF3C4)],
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 16,
                                child: Center(
                                  child: _fade(
                                    sunO,
                                    Transform.translate(
                                      offset: Offset(0, sunY),
                                      child: Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFC400),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: MosiColors.ink,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 70,
                                child: _fade(
                                  msgO,
                                  Transform.translate(
                                    offset: Offset(0, msgY),
                                    child: Column(
                                      children: [
                                        Text(
                                          '아침이 밝았습니다',
                                          style: MosiFonts.sans(
                                            size: 20,
                                            weight: FontWeight.w700,
                                            color: MosiColors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: MosiColors.white,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: MosiColors.ink,
                                              width: 2,
                                            ),
                                          ),
                                          child: Text(
                                            '아무도 죽지 않았어요',
                                            style: MosiFonts.sans(
                                              size: 12,
                                              weight: FontWeight.w700,
                                              color: MosiColors.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 36,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: MosiColors.lime,
                                    border: Border(
                                      top: BorderSide(
                                        color: MosiColors.ink,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 사라 · 시민
            _at(
              40,
              262,
              _rotated(
                -8,
                _PhoneFrame(
                  screenColor: _night,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            children: [
                              _nameTag('사라', MosiColors.sky, MosiColors.white),
                              const SizedBox(height: 6),
                              Text(
                                '시민',
                                style: MosiFonts.sans(
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF8FB6FF),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _fade(
                                nightO,
                                Text(
                                  '눈 감고\n아침을 기다려요',
                                  textAlign: TextAlign.center,
                                  style: MosiFonts.sans(
                                    size: 10,
                                    weight: FontWeight.w600,
                                    color: const Color(0xFFB9BDC9),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        top: 70 + zzY,
                        child: _fade(
                          zzO,
                          Text(
                            'z',
                            style: MosiFonts.grotesk(
                              size: 13,
                              color: const Color(0xFF8FB6FF),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 16,
                        child: _fade(
                          talkO,
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: MosiColors.sun,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '토론 시작',
                              style: MosiFonts.sans(
                                size: 10,
                                weight: FontWeight.w700,
                                color: MosiColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 민준 · 마피아
            _at(
              530,
              262,
              _rotated(
                8,
                _PhoneFrame(
                  screenColor: _night,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        _nameTag(
                          '민준',
                          const Color(0xFFFF0000),
                          MosiColors.white,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '마피아 · 나만 보여요',
                          style: MosiFonts.sans(
                            size: 10,
                            weight: FontWeight.w700,
                            color: const Color(0xFFFF8A8A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '오늘 밤 누구를?',
                          style: MosiFonts.sans(
                            size: 9,
                            color: const Color(0xFFB9BDC9),
                          ),
                        ),
                        const SizedBox(height: 6),
                        choice('사라'),
                        const SizedBox(height: 6),
                        choice(
                          '지우',
                          overlay: Positioned.fill(
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  left: -3,
                                  top: -3,
                                  right: -3,
                                  bottom: -3,
                                  child: _fade(
                                    aimO,
                                    Transform.scale(
                                      scale: aimS,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFF0000),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                tapDot(tapMO, tapMS),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        choice('하린'),
                        const SizedBox(height: 6),
                        _fade(
                          doneO,
                          Text(
                            '지목 완료',
                            style: MosiFonts.sans(
                              size: 9,
                              weight: FontWeight.w700,
                              color: const Color(0xFFFF8A8A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 하린 · 의사
            _at(
              285,
              300,
              _PhoneFrame(
                screenColor: _night,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      _nameTag('하린', MosiColors.sky, MosiColors.white),
                      const SizedBox(height: 6),
                      Text(
                        '의사 · 한 명 살리기',
                        style: MosiFonts.sans(
                          size: 10,
                          weight: FontWeight.w700,
                          color: const Color(0xFF8FB6FF),
                        ),
                      ),
                      const SizedBox(height: 6),
                      choice('사라'),
                      const SizedBox(height: 6),
                      choice(
                        '지우',
                        overlay: Positioned.fill(
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                left: -3,
                                top: -3,
                                right: -3,
                                bottom: -3,
                                child: _fade(
                                  healO,
                                  Transform.scale(
                                    scale: healS,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(
                                          color: const Color(0xFF2EB872),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -10,
                                top: -8,
                                child: _fade(
                                  healO,
                                  Transform.scale(
                                    scale: healS,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF2EB872),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '+',
                                        style: MosiFonts.sans(
                                          size: 13,
                                          weight: FontWeight.w700,
                                          color: MosiColors.white,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              tapDot(tapDO, tapDS),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      choice('민준'),
                    ],
                  ),
                ),
              ),
            ),
            // 지우 · 시민
            _at(
              556,
              12,
              _rotated(
                6,
                SizedBox(
                  width: 88,
                  height: 152,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _PhoneFrame(
                        width: 88,
                        height: 152,
                        small: true,
                        screenColor: _night,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            children: [
                              _nameTag('지우', MosiColors.sky, MosiColors.white),
                              const SizedBox(height: 6),
                              Text(
                                '시민',
                                style: MosiFonts.sans(
                                  size: 9,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF8FB6FF),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _fade(
                                zzO,
                                Transform.translate(
                                  offset: Offset(0, zzY),
                                  child: Text(
                                    'z z',
                                    style: MosiFonts.grotesk(
                                      size: 14,
                                      color: const Color(0xFF8FB6FF),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: -120,
                        top: 120,
                        child: _fade(
                          aliveO,
                          Transform.scale(
                            scale: aliveS,
                            alignment: const Alignment(-0.6, 1),
                            child: _teamBubble(
                              '휴, 살았다…!',
                              tint: const Color(0xFFEAF6DA),
                              team: const Color(0xFF2EB872),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _SkylineClipper extends CustomClipper<Path> {
  const _SkylineClipper();

  @override
  Path getClip(Size size) {
    const points = [
      (0.0, 0.40),
      (0.12, 0.40),
      (0.12, 0.10),
      (0.26, 0.10),
      (0.26, 0.50),
      (0.44, 0.50),
      (0.44, 0.0),
      (0.56, 0.0),
      (0.56, 0.40),
      (0.72, 0.40),
      (0.72, 0.20),
      (0.88, 0.20),
      (0.88, 0.45),
      (1.0, 0.45),
      (1.0, 1.0),
      (0.0, 1.0),
    ];
    final path = Path()
      ..moveTo(points.first.$1 * size.width, points.first.$2 * size.height);
    for (final (x, y) in points.skip(1)) {
      path.lineTo(x * size.width, y * size.height);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// 게임 화면과 같은 GameImage 경로 해석을 사용하고 원본 비율을 보존합니다.
Widget _partsImage(
  GameImage asset,
  String label, {
  double? width,
  double? height,
}) => asset.image(
  width: width,
  height: height,
  fit: BoxFit.contain,
  semanticLabel: label,
);

GameImage _liarCard(String face) {
  final cards = liar.Assets.games.liarsPoker.images.cards;
  return switch (face) {
    'A' => cards.whiteA.game,
    'K' => cards.whiteK.game,
    'Q' => cards.whiteQ.game,
    _ => cards.whiteJoker.game,
  };
}

GameImage _finalCard(String color, int value) => finalCallCardAsset(
  FinalCallCard(id: 'parts-$color-$value', color: color, value: value),
);

//=======================구성품 공통==============================
/// 구성품 카드가 아래에서 살짝 올라오며 나타납니다(mg-in).
class _EnterIn extends StatelessWidget {
  const _EnterIn({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 500);
    final total = duration + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      child: child,
      builder: (context, value, child) {
        final t = Curves.easeOutCubic.transform(
          ((value - start) / (1 - start)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

Widget _partsCard({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(18, 16, 18, 16),
  Duration delay = Duration.zero,
}) => _EnterIn(
  delay: delay,
  child: Container(
    padding: padding,
    decoration: BoxDecoration(
      color: MosiColors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: MosiColors.ink, width: 3),
      boxShadow: const [BoxShadow(color: _deepest, offset: Offset(5, 5))],
    ),
    child: DefaultTextStyle(
      style: MosiFonts.sans(size: 13, color: MosiColors.navy),
      child: child,
    ),
  ),
);

TextStyle _partsTitle() =>
    MosiFonts.sans(size: 15, weight: FontWeight.w700, color: MosiColors.navy);

TextStyle _partsMuted({double size = 12}) =>
    MosiFonts.sans(size: size, color: MosiColors.muted, height: 1.5);

/// 3초 주기로 위아래로 떠다닙니다(mg-float).
class _Float extends StatelessWidget {
  const _Float({required this.child, this.delay = 0});

  final Widget child;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return _Loop(
      period: const Duration(seconds: 3),
      builder: (context, p) {
        final shifted = (p + delay / 3 * 100) % 100;
        final y = -8 * math.sin(shifted / 100 * math.pi);
        return Transform.translate(offset: Offset(0, y), child: child);
      },
    );
  }
}

//=======================구성품 · 라이어스 포커==============================
class _LiarParts extends StatelessWidget {
  const _LiarParts();

  @override
  Widget build(BuildContext context) {
    const cards = [
      ('A', '에이스', 6, MosiColors.white, Color(0xFFE0302E), 34.0, 0.0),
      ('K', '킹', 6, MosiColors.white, MosiColors.ink, 34.0, 0.3),
      ('Q', '퀸', 6, MosiColors.white, Color(0xFFE0302E), 34.0, 0.6),
      ('JOKER', '조커', 2, MosiColors.sun, MosiColors.ink, 13.0, 0.9),
    ];
    const decks = [(2, 10), (3, 17), (4, 20), (5, 27), (6, 30)];
    const wheels = [(16, 4, '첫 번째'), (15, 5, '두 번째'), (12, 11, '세 번째')];

    Widget fanCard(
      String label,
      Color bg,
      Color fg,
      double size,
      double dy,
      double rot,
    ) => Transform.translate(
      offset: Offset(0, dy),
      child: _rotated(
        rot,
        _partsImage(_liarCard(label), '$label 카드', width: 34, height: 48),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 125,
            child: _partsCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('카드 덱', style: _partsTitle()),
                      const Spacer(),
                      Text(
                        '4명이면 20장',
                        style: MosiFonts.grotesk(
                          size: 13,
                          color: const Color(0xFF6E2A82),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final (face, name, n, _, _, _, delay) in cards)
                          Column(
                            children: [
                              _Float(
                                delay: delay,
                                child: SizedBox(
                                  width: 72,
                                  height: 98,
                                  child: Stack(
                                    children: [
                                      for (final (dx, dy, _) in const [
                                        (8.0, 0.0, Color(0xFF4A1A5E)),
                                        (4.0, 4.0, Color(0xFF6E2A82)),
                                      ])
                                        Positioned(
                                          left: dx,
                                          top: dy,
                                          child: _partsImage(
                                            liar
                                                .Assets
                                                .games
                                                .liarsPoker
                                                .images
                                                .cards
                                                .whiteBack
                                                .game,
                                            '카드 뒷면',
                                            width: 64,
                                            height: 90,
                                          ),
                                        ),
                                      Positioned(
                                        left: 0,
                                        top: 8,
                                        child: _partsImage(
                                          _liarCard(face),
                                          '$name 카드',
                                          width: 64,
                                          height: 90,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                name,
                                style: MosiFonts.sans(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: MosiColors.navy,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: MosiColors.cream,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: MosiColors.ink,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  '× $n',
                                  style: MosiFonts.grotesk(
                                    size: 13,
                                    color: MosiColors.navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: MosiColors.cream,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 150,
                          height: 88,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1022),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 34 * 5 - 8 * 4,
                              height: 56,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  for (final (i, (l, bg, fg, s, dy, r))
                                      in const [
                                        (
                                          'A',
                                          MosiColors.white,
                                          Color(0xFFE0302E),
                                          20.0,
                                          4.0,
                                          -14.0,
                                        ),
                                        (
                                          'K',
                                          MosiColors.white,
                                          MosiColors.ink,
                                          20.0,
                                          0.0,
                                          -7.0,
                                        ),
                                        (
                                          'JOKER',
                                          MosiColors.sun,
                                          MosiColors.ink,
                                          7.0,
                                          -3.0,
                                          0.0,
                                        ),
                                        (
                                          'Q',
                                          MosiColors.white,
                                          Color(0xFFE0302E),
                                          20.0,
                                          0.0,
                                          7.0,
                                        ),
                                        (
                                          'A',
                                          MosiColors.white,
                                          Color(0xFFE0302E),
                                          20.0,
                                          4.0,
                                          14.0,
                                        ),
                                      ].indexed)
                                    Positioned(
                                      left: i * 26.0,
                                      top: 4,
                                      child: fanCard(l, bg, fg, s, dy, r),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text.rich(
                            const TextSpan(
                              children: [
                                TextSpan(text: '시작할 때 '),
                                TextSpan(
                                  text: '각자 5장씩',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: MosiColors.navy,
                                  ),
                                ),
                                TextSpan(
                                  text: ' 받아요. 조커는 A·K·Q 어디에나 쓸 수 있는 만능 카드예요.',
                                ),
                              ],
                            ),
                            style: _partsMuted(size: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const MosiDashedDivider(color: Color(0xFFD4CFE6)),
                  const SizedBox(height: 12),
                  Text(
                    '인원에 따라 덱이 달라져요',
                    style: MosiFonts.sans(
                      size: 12,
                      weight: FontWeight.w700,
                      color: MosiColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final (i, (players, count)) in decks.indexed) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: players == 4
                                  ? MosiColors.sun
                                  : MosiColors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: MosiColors.ink,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$players명',
                                  style: MosiFonts.sans(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: MosiColors.navy,
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  '$count장',
                                  style: MosiFonts.grotesk(
                                    size: 15,
                                    color: MosiColors.navy,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _partsCard(
                    delay: const Duration(milliseconds: 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('벌칙 룰렛 · 갈수록 불리해요', style: _partsTitle()),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final (all, bad, label) in wheels)
                              Column(
                                children: [
                                  CustomPaint(
                                    size: const Size(68, 68),
                                    painter: _WheelPainter(all: all, bad: bad),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    label,
                                    style: MosiFonts.sans(
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: MosiColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$all칸 중 $bad칸',
                                    style: MosiFonts.sans(
                                      size: 11,
                                      weight: FontWeight.w700,
                                      color: const Color(0xFFA82E40),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _partsCard(
                  delay: const Duration(milliseconds: 160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('내 휴대폰 버튼', style: _partsTitle()),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Semantics(
                            image: true,
                            label: 'LIAR 버튼',
                            child: const LiarsPokerArcadeButtonSurface(
                              label: 'LIAR',
                              width: 78,
                              height: 58,
                              pressed: false,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1022),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _partsImage(
                              liar
                                  .Assets
                                  .games
                                  .liarsPoker
                                  .images
                                  .button
                                  .buttonFold
                                  .game,
                              'FOLD 버튼',
                              width: 90,
                              height: 48,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'FOLD는 카드가 남은 사람이 나 혼자일 때만 고를 수 있어요',
                        style: _partsMuted(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _partsCard(
                  delay: const Duration(milliseconds: 240),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 102,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A1A5E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _partsImage(
                              liar
                                  .Assets
                                  .games
                                  .liarsPoker
                                  .images
                                  .table
                                  .tableAceWhite
                                  .game,
                              '에이스 기준 카드',
                              width: 86,
                              height: 26,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '기준 카드 · A',
                              style: MosiFonts.sans(
                                size: 11,
                                color: MosiColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '라운드마다 태블릿이 A, K, Q 중 하나를 정해요',
                          style: MosiFonts.sans(
                            size: 13,
                            color: MosiColors.navy,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter({required this.all, required this.bad});

  final int all;
  final int bad;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    const center = Offset(50, 50);
    final rect = Rect.fromCircle(center: center, radius: 46);
    final sweep = 2 * math.pi / all;
    final stroke = Paint()
      ..color = MosiColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < all; i++) {
      final start = i * sweep - math.pi / 2;
      final path = Path()
        ..moveTo(50, 50)
        ..arcTo(rect, start, sweep, false)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = i < bad ? const Color(0xFFE0302E) : MosiColors.cream,
      );
      canvas.drawPath(path, stroke);
    }
    canvas.drawCircle(
      center,
      46,
      Paint()
        ..color = MosiColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(center, 9, Paint()..color = MosiColors.ink);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.all != all || oldDelegate.bad != bad;
}

//=======================구성품 · 파이널콜==============================
class _FinalParts extends StatelessWidget {
  const _FinalParts();

  static const _black = Color(0xFF141414);

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('빨강', 'red'),
      ('파랑', 'blue'),
      ('노랑', 'yellow'),
      ('초록', 'green'),
    ];
    const fan = [
      (7, 'red', -10.0),
      (3, 'red', -3.0),
      (7, 'blue', 4.0),
      (2, 'yellow', 10.0),
    ];

    Widget team(String label, Color bg, Color fg, {bool dashed = false}) =>
        Expanded(
          child: dashed
              ? MosiDashedBorder(
                  color: const Color(0xFF2EB872),
                  radius: 8,
                  strokeWidth: 2.5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: MosiFonts.sans(
                        size: 14,
                        weight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MosiColors.ink, width: 2.5),
                  ),
                  child: Text(
                    label,
                    style: MosiFonts.sans(
                      size: 14,
                      weight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
        );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 130,
            child: _partsCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('숫자 카드 40장', style: _partsTitle()),
                      const Spacer(),
                      Text(
                        '4색 × 1~10',
                        style: MosiFonts.grotesk(
                          size: 13,
                          color: MosiColors.navy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final (name, color) in rows) ...[
                    Row(
                      children: [
                        SizedBox(
                          width: 34,
                          child: Text(
                            name,
                            style: MosiFonts.sans(
                              size: 11,
                              weight: FontWeight.w700,
                              color: MosiColors.navy,
                            ),
                          ),
                        ),
                        for (var n = 1; n <= 10; n++) ...[
                          if (n > 1) const SizedBox(width: 4),
                          Expanded(
                            child: _partsImage(
                              _finalCard(color, n),
                              '$name $n 카드',
                              height: 40,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: MosiColors.cream,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 150,
                          height: 86,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _black,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final (i, (n, color, r)) in fan.indexed)
                                  Transform.translate(
                                    offset: Offset(-6.0 * i, 0),
                                    child: _rotated(
                                      r,
                                      _partsImage(
                                        _finalCard(color, n),
                                        '$color $n 카드',
                                        width: 32,
                                        height: 46,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text.rich(
                            const TextSpan(
                              children: [
                                TextSpan(text: '처음에 '),
                                TextSpan(
                                  text: '각자 4장씩',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: MosiColors.navy,
                                  ),
                                ),
                                TextSpan(
                                  text: ' 받고, 내 차례마다 더미나 버린 카드에서 한 장 가져와 바꿔요.',
                                ),
                              ],
                            ),
                            style: _partsMuted(size: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const MosiDashedDivider(color: Color(0xFFD4CFE6)),
                  const SizedBox(height: 12),
                  Text(
                    '점수 = 같은 색 합과 같은 숫자 합 중 큰 쪽',
                    style: MosiFonts.sans(
                      size: 12,
                      weight: FontWeight.w700,
                      color: MosiColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE3E1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFE0302E),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '7+3 = 10',
                          style: MosiFonts.grotesk(
                            size: 13,
                            color: MosiColors.navy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'vs',
                        style: MosiFonts.grotesk(
                          size: 13,
                          color: MosiColors.navy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5DB00),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: MosiColors.ink, width: 2),
                        ),
                        child: Text(
                          '7+7 = 14',
                          style: MosiFonts.grotesk(
                            size: 13,
                            color: MosiColors.navy,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text.rich(
                        const TextSpan(
                          children: [
                            TextSpan(text: '→ 내 점수 '),
                            TextSpan(
                              text: '14',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        style: MosiFonts.sans(
                          size: 13,
                          weight: FontWeight.w700,
                          color: MosiColors.navy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _partsCard(
                  delay: const Duration(milliseconds: 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('팀 · 마주 앉은 사람이 내 편', style: _partsTitle()),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          team(
                            '레드팀',
                            const Color(0xFFE0302E),
                            MosiColors.white,
                          ),
                          const SizedBox(width: 8),
                          team(
                            '블루팀',
                            const Color(0xFF2F5BEA),
                            MosiColors.white,
                          ),
                          const SizedBox(width: 8),
                          team(
                            '그린팀',
                            MosiColors.white,
                            const Color(0xFF2EB872),
                            dashed: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '4명은 2대2, 6명이면 그린팀이 더해져 2대2대2',
                        style: _partsMuted(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _partsCard(
                  delay: const Duration(milliseconds: 160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('팀마다 하트 3개', style: _partsTitle()),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _partsImage(
                            final_call
                                .Assets
                                .games
                                .finalCall
                                .images
                                .icons
                                .iconHeartRed
                                .game,
                            '팀 하트',
                            width: 30,
                            height: 30,
                          ),
                          const SizedBox(width: 8),
                          _partsImage(
                            final_call
                                .Assets
                                .games
                                .finalCall
                                .images
                                .icons
                                .iconHeartRed
                                .game,
                            '팀 하트',
                            width: 30,
                            height: 30,
                          ),
                          const SizedBox(width: 8),
                          _Float(
                            child: _partsImage(
                              final_call
                                  .Assets
                                  .games
                                  .finalCall
                                  .images
                                  .icons
                                  .iconHeartRed
                                  .game,
                              '팀 하트',
                              width: 30,
                              height: 30,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '꼴찌면 1개, CALL한 사람이 꼴찌면 2개를 잃어요',
                              style: _partsMuted(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _partsCard(
                    delay: const Duration(milliseconds: 240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _partsImage(
                          final_call
                              .Assets
                              .games
                              .finalCall
                              .images
                              .button
                              .buttonCall
                              .game,
                          'CALL 버튼',
                          width: 110,
                          height: 54,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '이길 것 같을 때 누르면, 나머지는 마지막으로 한 번 바꾸고 모두 공개해요. '
                          '같은 숫자 4장이면 상대 팀 전원이 하트를 잃어요.',
                          style: _partsMuted(size: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//=======================구성품 · 마피아==============================
class _MafiaParts extends StatelessWidget {
  const _MafiaParts();

  @override
  Widget build(BuildContext context) {
    const groups = [
      (
        '시민 팀',
        19,
        MosiColors.sky,
        ['citizen', 'police', 'doctor', 'bodyguard'],
        '외 15종',
      ),
      (
        '마피아 팀',
        15,
        Color(0xFFFF0000),
        ['mafia', 'mafia_boss', 'spy', 'madam'],
        '외 11종',
      ),
      (
        '중립',
        9,
        MosiColors.sun,
        ['jester', 'survivor', 'cult_leader', 'vampire'],
        '외 5종',
      ),
    ];
    const flow = [
      ('밤', Color(0xFF10131A), MosiColors.white),
      ('아침', Color(0xFFFFC400), MosiColors.ink),
      ('토론', MosiColors.white, MosiColors.ink),
      ('비밀 투표', MosiColors.white, MosiColors.ink),
      ('처형 발표', Color(0xFFFF0000), MosiColors.white),
    ];

    Widget roleCard(String id) {
      final role = MafiaRoles.find(id)!;
      return _partsImage(
        role.card!,
        '${role.displayName} 역할 카드',
        width: 58,
        height: 85,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 135,
            child: _partsCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('역할 카드 43종', style: _partsTitle()),
                      const Spacer(),
                      Text(
                        '방장이 골라 넣어요',
                        style: MosiFonts.grotesk(
                          size: 13,
                          color: const Color(0xFFA82E40),
                        ),
                      ),
                    ],
                  ),
                  for (final (title, count, color, roles, rest) in groups) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: MosiColors.ink, width: 2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: MosiFonts.sans(
                            size: 14,
                            weight: FontWeight.w700,
                            color: MosiColors.navy,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$count종',
                          style: MosiFonts.grotesk(
                            size: 13,
                            color: MosiColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final role in roles) ...[
                          roleCard(role),
                          const SizedBox(width: 6),
                        ],
                        const SizedBox(width: 4),
                        Text(
                          rest,
                          style: MosiFonts.sans(
                            size: 12,
                            weight: FontWeight.w700,
                            color: MosiColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '내 역할 카드는 내 휴대폰에만 보여요. 다른 사람 역할은 끝날 때까지 비밀이에요.',
                    style: _partsMuted(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _partsCard(
                  delay: const Duration(milliseconds: 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('하루의 흐름', style: _partsTitle()),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final (i, (label, bg, fg)) in flow.indexed) ...[
                            if (i > 0)
                              Text(
                                '→',
                                style: MosiFonts.sans(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF8C8AA8),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: MosiColors.ink,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                label,
                                style: MosiFonts.sans(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: fg,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '밤에는 휴대폰으로 몰래 능력을 쓰고, 낮에는 토론 뒤 비밀 투표로 한 명을 처형해요.',
                        style: _partsMuted(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _partsCard(
                  delay: const Duration(milliseconds: 160),
                  child: Row(
                    children: [
                      Container(
                        width: 90,
                        height: 62,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10131A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '밤이 되었습니다',
                            style: MosiFonts.sans(
                              size: 10,
                              weight: FontWeight.w700,
                              color: MosiColors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: '태블릿이 사회자예요.\n',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: '밤낮을 알리고, 결과를 발표하고, 시간을 재요.',
                                style: _partsMuted(size: 13),
                              ),
                            ],
                          ),
                          style: MosiFonts.sans(
                            size: 13,
                            color: MosiColors.navy,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _partsCard(
                    delay: const Duration(milliseconds: 240),
                    child: Row(
                      children: [
                        Text(
                          '4–12',
                          style: MosiFonts.grotesk(
                            size: 34,
                            color: MosiColors.navy,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: '명이 함께해요.\n',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text: '인원에 맞춰 역할 구성을 바꿀 수 있어요.',
                                  style: _partsMuted(size: 13),
                                ),
                              ],
                            ),
                            style: MosiFonts.sans(
                              size: 13,
                              color: MosiColors.navy,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
