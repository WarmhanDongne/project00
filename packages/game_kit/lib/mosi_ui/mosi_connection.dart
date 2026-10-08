// [mosi_connection.dart] 는 연결이 끊겼을 때 보여 주는 화면의 공통 틀과 장면 그림을 담은 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Design] : 시안 '연결 끊김 화면 — 위는 장면, 아래는 시트'
//
// 휴대폰(세로)에서는 위에 장면, 아래에 흰 시트를 두고, 태블릿(가로)에서는 왼쪽에
// 장면, 오른쪽에 결정 패널을 둡니다. 장면은 390×390 시안 좌표로 그린 뒤 자리에
// 맞춰 줄이거나 키웁니다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/core/constants/room_character.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

// ============================================================

/// 장면 배경으로 쓰는 연보라입니다(대기실 단절).
const mosiConnectionLavender = Color(0xFFD9D1EE);

/// 참가자 단절 꼬리표의 분홍입니다.
const mosiConnectionPink = Color(0xFFF3C6CC);

//=======================화면 틀==============================
/// 연결 끊김 화면의 공통 틀입니다.
class MosiConnectionLayout extends StatelessWidget {
  const MosiConnectionLayout({
    super.key,
    required this.background,
    required this.scene,
    required this.tag,
    required this.title,
    required this.body,
    this.tagColor = MosiColors.sun,
    this.status,
    this.extra,
    this.actions = const [],
    this.actionFlex,
    this.footnote,
    this.semanticLabel,
  });

  final Color background;

  /// 390×390 좌표로 그린 장면입니다.
  final Widget scene;
  final String tag;
  final Color tagColor;
  final String title;
  final String body;

  /// 기다림 상태 줄입니다([MosiConnectionStatus]).
  final Widget? status;

  /// 상태 줄 아래 추가 안내(실패 문구 등)입니다.
  final Widget? extra;

  /// 아래 버튼들입니다. 여러 개면 한 줄에 나란히 놓습니다.
  final List<Widget> actions;

  /// [actions]를 나란히 놓을 때의 너비 비율입니다.
  final List<int>? actionFlex;
  final String? footnote;
  final String? semanticLabel;

  static const double sceneSize = 390;

  @override
  Widget build(BuildContext context) {
    final dark = background.computeLuminance() < .4;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Semantics(
        container: true,
        label: semanticLabel,
        child: Material(
          color: background,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth > constraints.maxHeight &&
                  constraints.maxWidth >= 700;
              return wide
                  ? _buildWide(context, constraints)
                  : _buildTall(context, constraints);
            },
          ),
        ),
      ),
    );
  }

  Widget _scene() => FittedBox(
    fit: BoxFit.contain,
    child: SizedBox.square(dimension: sceneSize, child: scene),
  );

  Widget _buildTall(BuildContext context, BoxConstraints constraints) {
    final sceneHeight = constraints.maxHeight * 0.46;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      children: [
        SizedBox(
          height: sceneHeight,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(child: _scene()),
            ),
          ),
        ),
        Expanded(
          // 위쪽 테두리만 검은 선으로 보이도록 검은 판 위에 흰 판을 3px 내려 겹칩니다.
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: MosiColors.ink,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: MosiColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: LayoutBuilder(
                  builder: (context, sheet) {
                    final padding = EdgeInsets.fromLTRB(
                      24,
                      28,
                      24,
                      math.max(34, bottomInset + 16),
                    );
                    return SingleChildScrollView(
                      padding: padding,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(
                            0,
                            sheet.maxHeight - padding.vertical,
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _sheet(wide: false),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWide(BuildContext context, BoxConstraints constraints) {
    final panelPadding = constraints.maxWidth >= 1000 ? 72.0 : 40.0;
    return Row(
      children: [
        Expanded(
          flex: 580,
          child: SafeArea(
            right: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: _scene()),
            ),
          ),
        ),
        Expanded(
          flex: 614,
          child: Container(
            decoration: const BoxDecoration(
              color: MosiColors.white,
              border: Border(left: BorderSide(color: MosiColors.ink, width: 4)),
            ),
            child: SafeArea(
              left: false,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: panelPadding,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 470),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _sheet(wide: true),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _sheet({required bool wide}) {
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: MosiConnectionTag(label: tag, color: tagColor, large: wide),
      ),
      SizedBox(height: wide ? 20 : 14),
      Text(
        title,
        style: MosiFonts.sans(
          size: wide ? 38 : 24,
          weight: FontWeight.w700,
          color: MosiColors.navy,
          height: wide ? 1.25 : 1.3,
        ),
      ),
      SizedBox(height: wide ? 14 : 8),
      Text(
        body,
        style: MosiFonts.sans(
          size: wide ? 18 : 15,
          color: MosiColors.ink2,
          height: 1.55,
        ),
      ),
      if (status != null) ...[SizedBox(height: wide ? 28 : 20), status!],
      if (extra != null) ...[const SizedBox(height: 14), extra!],
      if (wide)
        const SizedBox(height: 36)
      else ...[
        const Spacer(),
        const SizedBox(height: 20),
      ],
      if (actions.length == 1)
        actions.single
      else if (actions.isNotEmpty)
        Row(
          children: [
            for (final (i, action) in actions.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(flex: actionFlex?[i] ?? 1, child: action),
            ],
          ],
        ),
      if (footnote != null) ...[
        const SizedBox(height: 12),
        Text(
          footnote!,
          textAlign: TextAlign.center,
          style: MosiFonts.sans(size: wide ? 14 : 12, color: MosiColors.muted),
        ),
      ],
    ];
  }
}

//=======================시트 부품==============================
/// 시트 맨 위의 둥근 꼬리표입니다.
class MosiConnectionTag extends StatelessWidget {
  const MosiConnectionTag({
    super.key,
    required this.label,
    this.color = MosiColors.sun,
    this.large = false,
  });

  final String label;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: large ? 12 : 10,
      vertical: large ? 5 : 4,
    ),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: MosiColors.ink, width: 2),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: MosiFonts.sans(
        size: large ? 14 : 12,
        weight: FontWeight.w700,
        color: MosiColors.ink,
        height: 1.2,
      ),
    ),
  );
}

/// 기다리는 중임을 알리는 크림색 상태 줄입니다.
class MosiConnectionStatus extends StatelessWidget {
  const MosiConnectionStatus({
    super.key,
    required this.text,
    this.trailing,
    this.dots = true,
    this.icon,
    this.color = MosiColors.violetDeep,
  });

  final String text;

  /// 오른쪽 끝에 붙는 작은 글자나 위젯입니다.
  final Widget? trailing;

  /// 깜빡이는 점 세 개를 앞에 둘지입니다.
  final bool dots;

  /// 점 대신 놓을 아이콘입니다.
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: MosiColors.paper,
        border: Border.all(color: MosiColors.ink, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (icon != null)
            Icon(icon, size: 22, color: color)
          else if (dots)
            const _BlinkingDots(),
          if (icon != null || dots) const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: MosiFonts.sans(
                size: 14,
                weight: FontWeight.w700,
                color: color,
                height: 1.35,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class _BlinkingDots extends StatefulWidget {
  const _BlinkingDots();

  @override
  State<_BlinkingDots> createState() => _BlinkingDotsState();
}

class _BlinkingDotsState extends State<_BlinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _blink.stop();
    } else if (!_blink.isAnimating) {
      _blink.repeat();
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _blink,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Opacity(
                opacity: _opacity(i),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: MosiColors.violet,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _opacity(int index) {
    if (!_blink.isAnimating) return 1;
    // 시안: 1.2초 주기로 .25↔1, 점마다 .2초씩 늦게 깜빡입니다.
    final t = (_blink.value - index * (200 / 1200)) % 1;
    return .25 + .75 * (1 - (2 * t - 1).abs());
  }
}

/// 시트 아래 버튼입니다. 시안의 흰 버튼(나가기)과 연두 버튼(진행)입니다.
class MosiConnectionButton extends StatelessWidget {
  const MosiConnectionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.loading = false,
    this.large = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool loading;
  final bool large;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => MosiButton(
    label: label,
    onPressed: onPressed,
    loading: loading,
    background: primary ? MosiColors.lime : MosiColors.white,
    foreground: MosiColors.ink,
    shadowColor: MosiColors.ink,
    borderWidth: 3,
    radius: 12,
    height: large ? 64 : 52,
    shadowOffset: large ? 6 : 4,
    fontSize: large ? 21 : 17,
    expand: true,
    semanticLabel: semanticLabel,
  );
}

//=======================장면 부품==============================
/// 테두리를 두른 둥근 캐릭터 얼굴입니다.
class MosiConnectionFace extends StatelessWidget {
  const MosiConnectionFace({
    super.key,
    required this.characterId,
    required this.size,
    this.border = 3,
    this.background,
    this.dimmed = false,
  });

  final String? characterId;
  final double size;
  final double border;
  final Color? background;

  /// 연결이 끊긴 사람처럼 흐리고 회색으로 보입니다.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      roomCharacterAssetPath(characterId),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    if (dimmed) {
      image = Opacity(
        opacity: .7,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(_grayscale70),
          child: image,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: Border.all(color: MosiColors.ink, width: border),
      ),
      child: image,
    );
  }
}

/// 채도를 30%만 남기는 색 행렬입니다(CSS grayscale(0.7)).
const _grayscale70 = <double>[
  0.5114, 0.5007, 0.0504, 0, 0, //
  0.1491, 0.8629, 0.0504, 0, 0, //
  0.1491, 0.5007, 0.4126, 0, 0, //
  0, 0, 0, 1, 0, //
];

Widget _at(double left, double top, Widget child) =>
    Positioned(left: left, top: top, child: child);

Widget _dot(double left, double top, double size, Color color) => _at(
  left,
  top,
  Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  ),
);

Widget _badge(Widget child, {double size = 36}) => Container(
  width: size,
  height: size,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: MosiColors.red,
    shape: BoxShape.circle,
    border: Border.all(color: MosiColors.ink, width: 3),
  ),
  child: child,
);

Widget _bubble(String text, {double size = 18, bool grotesk = false}) =>
    Container(
      padding: EdgeInsets.fromLTRB(12, grotesk ? 4 : 6, 12, 6),
      decoration: BoxDecoration(
        color: MosiColors.white,
        border: Border.all(color: MosiColors.ink, width: 3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Text(
        text,
        style: grotesk
            ? MosiFonts.grotesk(
                size: size,
                weight: FontWeight.w700,
                letterSpacing: 2,
                height: 1,
                color: MosiColors.ink,
              )
            : MosiFonts.sans(
                size: size,
                weight: FontWeight.w700,
                height: 1.1,
                color: MosiColors.ink,
              ),
      ),
    );

//=======================장면: 내 인터넷 끊김==============================
/// 신호가 약해진 와이파이와 갸웃하는 내 캐릭터입니다.
class MosiWifiLostScene extends StatelessWidget {
  const MosiWifiLostScene({super.key, this.characterId});

  final String? characterId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _dot(44, 70, 5, MosiColors.lilac),
        _dot(330, 112, 4, MosiColors.sun),
        _dot(300, 300, 5, MosiColors.lilac),
        _dot(70, 250, 4, MosiColors.white),
        const Positioned(
          left: 125,
          top: 56,
          width: 140,
          height: 104,
          child: CustomPaint(painter: _WeakWifiPainter()),
        ),
        _at(
          226,
          52,
          _badge(
            Text(
              '!',
              style: MosiFonts.sans(
                size: 20,
                weight: FontWeight.w700,
                color: MosiColors.white,
                height: 1,
              ),
            ),
          ),
        ),
        _at(
          115,
          186,
          Transform.rotate(
            angle: -5 * math.pi / 180,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: MosiColors.navyDeepest,
                    offset: Offset(8, 8),
                  ),
                ],
              ),
              child: MosiConnectionFace(
                characterId: characterId,
                size: 160,
                border: 4,
                background: MosiColors.sun,
              ),
            ),
          ),
        ),
        _at(252, 168, _bubble('?')),
      ],
    );
  }
}

/// 바깥 두 줄은 점선으로 희미하고 안쪽 한 줄만 남은 와이파이입니다.
class _WeakWifiPainter extends CustomPainter {
  const _WeakWifiPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 시안 SVG(140×104): 가운데 x=70, 각 호는 양 끝 점과 반지름으로 정해집니다.
    final weak = Paint()..color = MosiColors.muted;
    for (final (y, r) in [(42.0, 85.0), (62.0, 56.0)]) {
      final half = r == 85 ? 60.0 : 40.0;
      final cy = y + math.sqrt(r * r - half * half);
      final start = math.atan2(y - cy, -half);
      final sweep = math.atan2(y - cy, half) - start;
      // 점선(2 · 16, 둥근 끝 10px)은 5px 점이 18px마다 찍힌 모양입니다.
      final count = (r * sweep.abs() / 18).floor();
      for (var i = 0; i <= count; i++) {
        final a = start + sweep * i / count;
        canvas.drawCircle(
          Offset(70 + r * math.cos(a), cy + r * math.sin(a)),
          5,
          weak,
        );
      }
    }
    final strong = Paint()
      ..color = MosiColors.lilac
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    const r = 28.0;
    final cy = 82 + math.sqrt(r * r - 20 * 20);
    final start = math.atan2(82 - cy, -20);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(70, cy), radius: r),
      start,
      math.atan2(82 - cy, 20) - start,
      false,
      strong,
    );
    canvas.drawCircle(
      const Offset(70, 96),
      7,
      Paint()..color = MosiColors.lilac,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//=======================장면: 태블릿 끊김==============================
/// 꺼진 와이파이 표시가 뜬 태블릿 화면입니다.
class _OfflineTablet extends StatelessWidget {
  const _OfflineTablet({required this.label, required this.shadow});

  final String label;
  final Color shadow;

  @override
  Widget build(BuildContext context) => Container(
    width: 240,
    height: 156,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: MosiColors.ink,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: shadow, offset: const Offset(8, 8))],
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: MosiColors.ink2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 54,
            height: 40,
            child: CustomPaint(painter: _WifiOffPainter()),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: MosiFonts.grotesk(
              size: 11,
              weight: FontWeight.w700,
              letterSpacing: 3,
              color: MosiColors.lilac,
            ),
          ),
        ],
      ),
    ),
  );
}

class _WifiOffPainter extends CustomPainter {
  const _WifiOffPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final arc = Paint()
      ..color = MosiColors.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    // 시안 SVG(54×40): M4 16a33 33 … 50 16, M13 25a20 20 … 41 25.
    for (final (y, r, half) in [(16.0, 33.0, 23.0), (25.0, 20.0, 14.0)]) {
      final cy = y + math.sqrt(r * r - half * half);
      final start = math.atan2(y - cy, -half);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(27, cy), radius: r),
        start,
        math.atan2(y - cy, half) - start,
        false,
        arc,
      );
    }
    canvas.drawCircle(
      const Offset(27, 34),
      4,
      Paint()..color = MosiColors.muted,
    );
    canvas.drawLine(
      const Offset(8, 4),
      const Offset(46, 38),
      arc..color = MosiColors.red,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 4,
    height: height,
    child: Column(
      children: [
        for (var y = 0.0; y < height; y += 11)
          Container(
            width: 4,
            height: math.min(6, height - y),
            margin: EdgeInsets.only(bottom: y + 11 < height ? 5 : 0),
            color: MosiColors.white,
          ),
      ],
    ),
  );
}

/// 게임 중 태블릿과 내 휴대폰 사이 연결이 끊긴 장면입니다.
class MosiTabletLostScene extends StatelessWidget {
  const MosiTabletLostScene({super.key, this.characterId});

  final String? characterId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _at(
          75,
          48,
          const _OfflineTablet(label: 'OFFLINE', shadow: MosiColors.violetDeep),
        ),
        _at(193, 206, const _DashedLine(height: 22)),
        _at(
          177,
          226,
          _badge(
            const Icon(Icons.close_rounded, size: 18, color: MosiColors.white),
          ),
        ),
        _at(193, 262, const _DashedLine(height: 20)),
        _at(
          146,
          282,
          Container(
            width: 98,
            height: 108,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            decoration: const BoxDecoration(
              color: MosiColors.ink,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Container(
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                color: MosiColors.lime,
                borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
              ),
              child: MosiConnectionFace(characterId: characterId, size: 58),
            ),
          ),
        ),
      ],
    );
  }
}

/// 대기실에서 태블릿이 꺼지고 친구들이 의자에 앉아 기다리는 장면입니다.
class MosiLobbyLostScene extends StatelessWidget {
  const MosiLobbyLostScene({super.key, this.characterIds = const []});

  /// 의자에 앉힐 캐릭터입니다. 앞에서 네 명까지 보여 줍니다.
  final List<String> characterIds;

  @override
  Widget build(BuildContext context) {
    final faces = characterIds.take(4).toList();
    const tilts = [(-6.0, 0.0), (0.0, -6.0), (5.0, 0.0), (-3.0, -4.0)];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _at(
          75,
          44,
          const _OfflineTablet(
            label: 'LOBBY · OFFLINE',
            shadow: MosiColors.lilac,
          ),
        ),
        _at(96, 222, _bubble('···', grotesk: true)),
        Positioned(
          left: 41,
          top: 262,
          width: 308,
          child: Row(
            mainAxisAlignment: faces.length > 2
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.spaceEvenly,
            children: [
              for (final (i, id) in faces.indexed)
                Transform.translate(
                  offset: Offset(0, tilts[i].$2),
                  child: Transform.rotate(
                    angle: tilts[i].$1 * math.pi / 180,
                    child: MosiConnectionFace(characterId: id, size: 68),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          top: 334,
          height: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFC99A5B),
              border: Border.all(color: MosiColors.ink, width: 3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const Positioned(
          left: 52,
          top: 350,
          width: 12,
          height: 26,
          child: ColoredBox(color: MosiColors.ink),
        ),
        const Positioned(
          right: 52,
          top: 350,
          width: 12,
          height: 26,
          child: ColoredBox(color: MosiColors.ink),
        ),
      ],
    );
  }
}

//=======================장면: 다시 돌아오기==============================
/// 둥근 테이블과 비워 둔 내 자리입니다. 앱을 다시 켰을 때 보여 줍니다.
class MosiReturnTableScene extends StatelessWidget {
  const MosiReturnTableScene({
    super.key,
    this.characterId,
    this.seatLabel = '내 자리',
  });

  final String? characterId;
  final String seatLabel;

  /// 테이블에 둘러앉은 다른 자리의 장식용 얼굴입니다.
  static const _guests = ['cat', 'whale', 'owl', 'penguin'];

  @override
  Widget build(BuildContext context) {
    Widget card(double left, double top, double angle) => _at(
      left,
      top,
      Transform.rotate(
        angle: angle * math.pi / 180,
        child: Container(
          width: 30,
          height: 42,
          decoration: BoxDecoration(
            color: MosiColors.navy,
            border: Border.all(color: MosiColors.ink, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _at(
          100,
          115,
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              color: const Color(0xFFC99A5B),
              shape: BoxShape.circle,
              border: Border.all(color: MosiColors.ink, width: 4),
              boxShadow: const [
                BoxShadow(color: MosiColors.ink, offset: Offset(8, 8)),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 116,
          top: 131,
          width: 158,
          height: 158,
          child: CustomPaint(painter: _DashedCirclePainter()),
        ),
        card(128, 196, 18),
        card(230, 186, -14),
        _at(
          167,
          168,
          Transform.rotate(
            angle: -6 * math.pi / 180,
            child: Container(
              width: 56,
              height: 76,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF16141F),
                border: Border.all(color: MosiColors.ink, width: 3),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(3),
                  right: Radius.circular(6),
                ),
              ),
              child: Stack(
                children: [
                  // 초승달
                  Positioned(
                    left: 26,
                    top: 8,
                    child: ClipPath(
                      clipper: const _CrescentClipper(),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF2B632),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 22,
                    child: ColoredBox(color: Color(0xFFE2402F)),
                  ),
                ],
              ),
            ),
          ),
        ),
        _at(163, 43, MosiConnectionFace(characterId: _guests[0], size: 64)),
        _at(291, 136, MosiConnectionFace(characterId: _guests[1], size: 64)),
        _at(35, 136, MosiConnectionFace(characterId: _guests[2], size: 64)),
        _at(84, 287, MosiConnectionFace(characterId: _guests[3], size: 64)),
        _at(
          230,
          276,
          Container(
            width: 86,
            height: 86,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: MosiColors.sun,
              shape: BoxShape.circle,
              border: Border.all(color: MosiColors.violet, width: 4),
            ),
            child: characterId == null
                ? Container(
                    decoration: BoxDecoration(
                      color: MosiColors.cream,
                      shape: BoxShape.circle,
                      border: Border.all(color: MosiColors.ink, width: 3),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: MosiColors.violet,
                    ),
                  )
                : MosiConnectionFace(characterId: characterId, size: 74),
          ),
        ),
        Positioned(
          left: 238,
          top: 352,
          width: 70,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: MosiColors.violet,
              border: Border.all(color: MosiColors.ink, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              seatLabel,
              textAlign: TextAlign.center,
              style: MosiFonts.sans(
                size: 12,
                weight: FontWeight.w700,
                color: MosiColors.white,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CrescentClipper extends CustomClipper<Path> {
  const _CrescentClipper();

  @override
  Path getClip(Size size) {
    final full = Path()..addOval(Offset.zero & size);
    final bite = Path()
      ..addOval(
        Rect.fromLTWH(
          -size.width * .35,
          -size.height * .15,
          size.width,
          size.height,
        ),
      );
    return Path.combine(PathOperation.difference, full, bite);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MosiColors.ink.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = (Offset.zero & size).deflate(1);
    const dashes = 48;
    const sweep = math.pi * 2 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * .55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//=======================장면: 다른 참가자 끊김==============================
/// 끊긴 참가자 얼굴을 남은 시간 고리로 감싼 장면입니다.
class MosiPlayerWaitScene extends StatelessWidget {
  const MosiPlayerWaitScene({
    super.key,
    required this.characterId,
    required this.seconds,
    required this.progress,
    this.badge = '연결 끊김',
    this.caption = '돌아오기를 기다리는 중',
  });

  final String? characterId;
  final int seconds;

  /// 남은 시간 비율(1 → 0)입니다.
  final double progress;
  final String badge;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 77,
          top: 36,
          width: 236,
          height: 236,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress.clamp(0, 1)),
            duration: const Duration(milliseconds: 600),
            builder: (context, value, _) =>
                CustomPaint(painter: _TimeRingPainter(value)),
          ),
        ),
        _at(
          115,
          74,
          MosiConnectionFace(
            characterId: characterId,
            size: 160,
            border: 4,
            background: MosiColors.sky,
            dimmed: true,
          ),
        ),
        Positioned(
          left: 135,
          top: 222,
          width: 120,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: MosiColors.red,
              border: Border.all(color: MosiColors.ink, width: 3),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              textAlign: TextAlign.center,
              style: MosiFonts.sans(
                size: 13,
                weight: FontWeight.w700,
                color: MosiColors.white,
                height: 1.3,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 290,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$seconds',
                style: MosiFonts.grotesk(
                  size: 44,
                  weight: FontWeight.w700,
                  color: MosiColors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '초',
                style: MosiFonts.sans(
                  size: 18,
                  weight: FontWeight.w700,
                  color: MosiColors.white,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 342,
          child: Text(
            caption,
            textAlign: TextAlign.center,
            style: MosiFonts.sans(size: 13, color: MosiColors.lilac),
          ),
        ),
      ],
    );
  }
}

class _TimeRingPainter extends CustomPainter {
  const _TimeRingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 106);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = MosiColors.ink2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = MosiColors.sun
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TimeRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
