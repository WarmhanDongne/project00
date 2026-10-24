import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_yut/src/hanji.dart';
import 'package:game_yut/src/rules.dart';
import 'package:game_yut/src/theme.dart';
import 'package:game_yut/src/view.dart';

/// 패키지에 들어 있는 윷놀이 그림입니다.
abstract final class YutImages {
  static AssetImage of(String name) =>
      AssetImage('assets/images/$name.webp', package: 'game_yut');
  static final boardHolo = of('board_holo');

  /// 일반 윷놀이 판(E안)의 옅은 오크 나무결입니다. 선과 점은 코드로 그립니다.
  static final boardOak = of('board_oak');
  static final holoTablet = of('bg_holo_tablet');
  static final holoPhone = of('bg_holo_phone');
  /// 둥근 앞면(× 세 개)입니다.
  static final stickFront = of('stick_front');

  /// 평평한 뒷면(배)입니다.
  static final stickBack = of('stick_back');

  /// 일반 윷놀이 빽도 윷의 뒷면: 평평한 면에 모시겜 로고가 찍혀 있습니다.
  static final stickBackBackDo = of('stick_back_backdo');
  static final book = of('button_book');
  static final coin = of('button_coin');

  static Future<void> precache(BuildContext context, {required bool edition}) =>
      Future.wait([
        for (final image in [
          edition ? boardHolo : boardOak,
          if (edition) holoTablet,
          if (edition) holoPhone,
          stickFront,
          stickBack,
          stickBackBackDo,
          book,
          coin,
          for (final piece in [
            'piece_blue',
            'piece_white',
            'piece_red',
            'piece_green',
          ])
            of(piece),
        ])
          precacheImage(image, context).catchError((_) {}),
      ]);
}

/// 한지 무늬(일반판) 또는 홀로그램 민화(에디션) 배경입니다.
class YutBackground extends StatelessWidget {
  const YutBackground({
    super.key,
    required this.edition,
    required this.tablet,
    required this.child,
  });
  final bool edition;
  final bool tablet;
  final Widget child;

  @override
  Widget build(BuildContext context) => edition
      ? DecoratedBox(
          decoration: BoxDecoration(
            color: YutColors.night,
            image: DecorationImage(
              image: tablet ? YutImages.holoTablet : YutImages.holoPhone,
              fit: BoxFit.cover,
            ),
          ),
          child: child,
        )
      // 한지 배경은 그림 파일 없이 디자인 SVG를 옮긴 코드로 그립니다.
      : CustomPaint(
          painter: const YutHanjiPainter(),
          isComplex: true,
          child: child,
        );
}

/// 일반 윷놀이 판(디자인 `윷판 E안 · 오크 목재 + 검정 점과 선`)입니다.
///
/// 옅은 오크 나무결 위에 바깥 네모와 두 대각선을 먹선으로 긋고, 모서리·
/// 가운데는 큰 점, 나머지 칸은 작은 점을 찍습니다. 출발 모서리는 붉은 원에
/// `출발`을 씁니다. 디자인 좌표(620×620)를 판 크기에 맞춰 그립니다.
class YutOakBoard extends StatelessWidget {
  const YutOakBoard({super.key, required this.side});
  final double side;

  @override
  Widget build(BuildContext context) {
    final k = side / 620;
    final radius = BorderRadius.circular(22 * k);
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: const Color(0xFFE3C69E),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: const Color(0xFFB48A5C), offset: Offset(0, 9 * k)),
          const BoxShadow(
            color: Color(0x4D3C2612),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(image: YutImages.boardOak, fit: BoxFit.cover),
            // 안쪽 테두리 세 겹(진한 선 · 밝은 띠 · 가장자리 그늘)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: const Color(0x736E461E),
                  width: 3 * k,
                ),
                gradient: RadialGradient(
                  radius: .95,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF784F28).withValues(alpha: .18),
                  ],
                  stops: const [.72, 1],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(3 * k),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19 * k),
                  border: Border.all(
                    color: const Color(0x2EFFF0D7),
                    width: 9 * k,
                  ),
                ),
              ),
            ),
            CustomPaint(painter: _OakLinesPainter(k)),
          ],
        ),
      ),
    );
  }
}

class _OakLinesPainter extends CustomPainter {
  const _OakLinesPainter(this.k);
  final double k;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(k);
    const ink = Color(0xFF1E1A16);
    const lo = 76.7, hi = 543.3, mid = 310.0;
    final line = Paint()
      ..color = ink.withValues(alpha: .9)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in const [
      (Offset(lo, lo), Offset(hi, lo)),
      (Offset(hi, lo), Offset(hi, hi)),
      (Offset(hi, hi), Offset(lo, hi)),
      (Offset(lo, hi), Offset(lo, lo)),
      (Offset(lo, lo), Offset(hi, hi)),
      (Offset(hi, lo), Offset(lo, hi)),
    ]) {
      canvas.drawLine(a, b, line);
    }
    final dot = Paint()..color = ink;
    const step = (hi - lo) / 5;
    for (var i = 1; i <= 4; i++) {
      final t = lo + step * i;
      for (final c in [
        Offset(t, lo),
        Offset(t, hi),
        Offset(lo, t),
        Offset(hi, t),
      ]) {
        canvas.drawCircle(c, 10, dot);
      }
    }
    for (final t in const [1 / 3, 2 / 3]) {
      final d = (mid - lo) * t;
      for (final c in [
        Offset(lo + d, lo + d),
        Offset(hi - d, lo + d),
        Offset(lo + d, hi - d),
        Offset(hi - d, hi - d),
      ]) {
        canvas.drawCircle(c, 10, dot);
      }
    }
    for (final c in const [
      Offset(lo, lo),
      Offset(hi, lo),
      Offset(lo, hi),
      Offset(mid, mid),
      Offset(hi, hi),
    ]) {
      canvas.drawCircle(c, 17, dot);
    }
    // 출발: 붉은 원과 흰 글자
    canvas.drawCircle(
      const Offset(hi, hi),
      30,
      Paint()..color = YutColors.vermilion,
    );
    final label = TextPainter(
      text: TextSpan(
        text: YutCopy.start,
        style: YutFonts.stamp(19, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(hi - label.width / 2, hi - label.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OakLinesPainter old) => old.k != k;
}

/// 판 위의 말입니다. 일반판은 둥근 장기알 그림, 에디션은 팔각 홀로그램 알입니다.
class YutPieceToken extends StatelessWidget {
  const YutPieceToken({
    super.key,
    required this.team,
    required this.label,
    required this.size,
    required this.edition,
    this.count = 1,
    this.glow = false,
    this.characterId,
  });
  final YutTeam? team;
  final String label;

  /// 일반 윷놀이는 말에 이름 대신 주인 얼굴을 넣습니다(자리 색 원판).
  final String? characterId;

  /// 말의 지름입니다. 일반판 그림은 세로가 조금 더 깁니다(그림자 포함).
  final double size;
  final bool edition;
  final int count;
  final bool glow;

  bool get _faceDisc =>
      characterId != null &&
      !edition &&
      (team == YutTeam.east ||
          team == YutTeam.south ||
          team == YutTeam.west ||
          team == YutTeam.north);

  @override
  Widget build(BuildContext context) {
    final style = YutTeamStyle.of(team);
    final white = style.piece == 'piece_white';
    final token = _faceDisc
        ? _FaceDisc(
            style: style,
            characterId: characterId!,
            size: size,
            glow: glow,
          )
        : edition
        ? CustomPaint(
            size: Size.square(size),
            painter: _HoloPiecePainter(blue: !white, glow: glow),
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: Text(
                  label,
                  style: YutFonts.title(
                    size * .5,
                    color: white ? const Color(0xFF14121C) : Colors.white,
                  ),
                ),
              ),
            ),
          )
        : SizedBox(
            width: size,
            height: size * 67 / 60,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image(
                    image: YutImages.of(style.piece),
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: size * 58 / 60,
                  child: Center(
                    child: Text(
                      label,
                      style: YutFonts.stamp(
                        size * .5,
                        color: white ? YutColors.ink : Colors.white,
                        shadows: [
                          Shadow(
                            color: white
                                ? Colors.white.withValues(alpha: .9)
                                : const Color(0x73280808),
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
    if (count <= 1) return token;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        token,
        Positioned(
          right: -size * .14,
          top: -size * .1,
          child: Container(
            width: size * .42,
            height: size * .42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: edition
                  ? YutColors.moon
                  : _faceDisc
                  ? YutColors.ink
                  : YutColors.red,
              border: Border.all(
                color: edition
                    ? YutColors.night
                    : _faceDisc
                    ? YutColors.paper
                    : Colors.white,
                width: 2,
              ),
            ),
            child: Text(
              '×$count',
              style: YutFonts.title(
                size * .2,
                color: edition ? YutColors.night : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 자리 색 원판 안에 주인 얼굴이 들어간 일반 윷놀이 말입니다.
class _FaceDisc extends StatelessWidget {
  const _FaceDisc({
    required this.style,
    required this.characterId,
    required this.size,
    required this.glow,
  });
  final YutTeamStyle style;
  final String characterId;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * 5 / 56),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: style.fill,
      boxShadow: [
        BoxShadow(color: style.shadow, offset: Offset(0, size * 4 / 56)),
        BoxShadow(
          color: const Color(0x59281406),
          offset: Offset(1, size * 6 / 56),
          blurRadius: 4,
        ),
        if (glow) ...[
          BoxShadow(
            color: style.fill.withValues(alpha: .33),
            spreadRadius: size * 6 / 74,
          ),
          BoxShadow(color: style.fill, blurRadius: size * 22 / 74),
        ],
      ],
    ),
    child: ClipOval(
      child: ColoredBox(
        color: Colors.white,
        child: MosiFace(characterId: characterId, size: size),
      ),
    ),
  );
}

class _HoloPiecePainter extends CustomPainter {
  const _HoloPiecePainter({required this.blue, required this.glow});
  final bool blue;
  final bool glow;

  Path _octagon(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = math.pi / 8 + i * math.pi / 4;
      final point = c + Offset(math.cos(angle), math.sin(angle)) * r;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final unit = size.width / 74;
    final rect = Offset.zero & size;
    final holo = Paint()..shader = YutColors.holoGradient.createShader(rect);
    canvas.drawCircle(
      c,
      size.width * .62,
      Paint()
        ..color = (blue ? const Color(0xFF7FA2FF) : Colors.white).withValues(
          alpha: glow ? .3 : .16,
        ),
    );
    canvas.drawPath(
      _octagon(c + Offset(2.4 * unit, 6.4 * unit), 40 * unit),
      Paint()..color = Colors.black.withValues(alpha: .7),
    );
    final body = _octagon(c, 40 * unit);
    canvas.drawPath(
      body,
      Paint()..color = blue ? YutColors.holoBlue : const Color(0xFFFFFDF7),
    );
    canvas.drawPath(
      body,
      holo
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * unit
        ..strokeJoin = StrokeJoin.round,
    );
    final inner = _octagon(c, 24.5 * unit);
    canvas.drawPath(
      inner,
      Paint()..color = blue ? YutColors.holoBlueLight : const Color(0xFFF1ECFF),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * unit
        ..color = blue ? const Color(0xFFAFC3FF) : const Color(0xFF2A2340),
    );
  }

  @override
  bool shouldRepaint(_HoloPiecePainter old) =>
      old.blue != blue || old.glow != glow;
}

/// 윷가락 하나입니다. 위쪽 구멍에 주인 얼굴이 보입니다.
///
/// [front]가 true면 둥근 앞면(× 세 개), false면 평평한 뒷면(배)입니다.
/// 결과는 평평한 뒷면이 위로 나온 개수로 셉니다(배 1 = 도 … 4 = 윷, 0 = 모).
class YutStick extends StatelessWidget {
  const YutStick({
    super.key,
    required this.front,
    required this.width,
    required this.edition,
    this.characterId,
    this.marked = false,
    this.dim = false,
  });
  final bool front;
  final double width;
  final bool edition;
  final String? characterId;

  /// 일반 윷놀이의 빽도 판정용 표시 윷입니다. 평평한 뒷면에 로고가 보입니다.
  final bool marked;
  final bool dim;

  static const aspect = 850 / 316;

  @override
  Widget build(BuildContext context) {
    final height = width * aspect;
    // 일반판 윷은 몸통 폭(240/316)에 맞춰 구멍이 작습니다.
    final hole = width * (edition ? 87 : 70) / 316;
    final face = Positioned(
      left: width * 157.5 / 316 - hole,
      top: height * 172.5 / 850 - hole,
      width: hole * 2,
      height: hole * 2,
      child: ClipOval(
        child: ColoredBox(
          color: edition ? YutColors.nightRaised : const Color(0xFF3F8EE0),
          child: characterId == null || characterId!.isEmpty
              ? const SizedBox.expand()
              : MosiFace(characterId: characterId, size: hole * 2),
        ),
      ),
    );
    final body = edition
        ? CustomPaint(
            size: Size(width, height),
            painter: _HoloStickPainter(front: front, marked: marked),
          )
        : Image(
            image: front
                ? YutImages.stickFront
                : (marked ? YutImages.stickBackBackDo : YutImages.stickBack),
            width: width,
            height: height,
            fit: BoxFit.fill,
            gaplessPlayback: true,
          );
    return Opacity(
      opacity: dim ? .4 : 1,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            face,
            Positioned.fill(child: body),
          ],
        ),
      ),
    );
  }
}

class _HoloStickPainter extends CustomPainter {
  const _HoloStickPainter({required this.front, required this.marked});
  final bool front;
  final bool marked;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .12, w * .06, w * .76, size.height - w * .16),
      Radius.circular(w * .38),
    );
    final hole = Offset(w * 157.5 / 316, size.height * 172.5 / 850);
    final holeR = w * 87 / 316;
    final shape = Path.combine(
      PathOperation.difference,
      Path()..addRRect(body),
      Path()..addOval(Rect.fromCircle(center: hole, radius: holeR)),
    );
    canvas.drawShadow(shape, Colors.black, 6, false);
    canvas.drawPath(
      shape,
      Paint()
        ..shader =
            (front
                    ? YutColors.holoGradient
                    : const LinearGradient(
                        colors: [Color(0xFF242036), Color(0xFF14121F)],
                      ))
                .createShader(body.outerRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .035
        ..color = front ? const Color(0xFF14121C) : YutColors.lilac,
    );
    canvas.drawCircle(
      hole,
      holeR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .035
        ..color = front ? const Color(0xFF14121C) : YutColors.lilac,
    );
    final mark = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * .07
      ..color = front ? const Color(0xFF14121C) : YutColors.haze;
    if (front) {
      for (final y in [.47, .62, .77]) {
        final c = Offset(w / 2, size.height * y);
        final r = w * .18;
        // 빽도 표시 윷은 가운데 ×만 붉게 칠합니다.
        final paint = marked && y == .62
            ? (Paint()
                ..strokeCap = StrokeCap.round
                ..strokeWidth = w * .07
                ..color = const Color(0xFFE0465A))
            : mark;
        canvas.drawLine(c + Offset(-r, -r), c + Offset(r, r), paint);
        canvas.drawLine(c + Offset(r, -r), c + Offset(-r, r), paint);
      }
    } else {
      for (final y in [.45, .55, .65, .75]) {
        canvas.drawLine(
          Offset(w / 2, size.height * y - w * .05),
          Offset(w / 2, size.height * y + w * .05),
          mark..strokeWidth = w * .04,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HoloStickPainter old) =>
      old.front != front || old.marked != marked;
}

/// 팀 색 리본입니다. 태블릿 양옆에서는 세로로 돌려 씁니다.
class YutRibbon extends StatelessWidget {
  const YutRibbon({
    super.key,
    required this.text,
    required this.team,
    required this.edition,
    this.alert = false,
    this.fontSize = 27,
  });
  final String text;
  final YutTeam? team;
  final bool edition;

  /// 잡기·한 번 더 같은 강조(붉은 띠)입니다.
  final bool alert;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = YutTeamStyle.of(team);
    final Color fill;
    final Color ink;
    final Border? border;
    final Color shadow;
    Gradient? gradient;
    if (edition) {
      final blue = team == YutTeam.blue;
      fill = alert
          ? YutColors.moon
          : blue
          ? YutColors.holoBlue
          : YutColors.nightRaised;
      ink = alert ? YutColors.night : YutColors.moon;
      border = Border.all(
        color: alert ? Colors.transparent : YutColors.lilac,
        width: 2,
      );
      shadow = Colors.black.withValues(alpha: .5);
      if (alert) gradient = YutColors.holoGradient;
    } else {
      fill = alert ? YutColors.red : style.fill;
      ink = alert ? Colors.white : style.ink;
      border = !alert && style.edge != null
          ? Border.all(color: style.edge!, width: 2)
          : null;
      shadow = alert ? YutColors.redDeep : style.shadow;
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * .8,
        vertical: fontSize * .42,
      ),
      decoration: BoxDecoration(
        color: fill,
        gradient: gradient,
        borderRadius: BorderRadius.circular(6),
        border: border,
        boxShadow: [
          BoxShadow(color: shadow, offset: const Offset(0, 5)),
          BoxShadow(
            color: const Color(0x40281410),
            offset: const Offset(8, 14),
            blurRadius: 16,
          ),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: YutFonts.title(fontSize, color: ink),
      ),
    );
  }
}

/// 붉은 인주 도장으로 찍는 윷 결과입니다.
class YutResultStamp extends StatelessWidget {
  const YutResultStamp({
    super.key,
    required this.result,
    required this.size,
    required this.edition,
    this.caption,
  });
  final YutResult result;
  final double size;
  final bool edition;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final ink = edition ? YutColors.night : const Color(0xFFF7EFE6);
    return Transform.rotate(
      angle: -.08,
      child: Container(
        width: size,
        height: size * 136 / 140,
        decoration: BoxDecoration(
          color: edition ? null : const Color(0xFFC21F2E),
          gradient: edition ? YutColors.holoGradient : null,
          borderRadius: BorderRadius.circular(size * .16),
          border: Border.all(
            color: edition ? YutColors.night : const Color(0xFF8E141F),
            width: size * .03,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x47501414),
              offset: Offset(6, 10),
              blurRadius: 6,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(size * .07),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * .11),
              border: Border.all(
                color: ink.withValues(alpha: .8),
                width: size * .015,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  YutCopy.result(result),
                  style: YutFonts.stamp(
                    size * (result == YutResult.backDo ? .34 : .47),
                    color: ink,
                  ),
                ),
                SizedBox(height: size * .04),
                Text(
                  caption ?? YutCopy.stepsForward(result),
                  style: YutFonts.text(
                    size * .093,
                    color: ink,
                    weight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 나온 윷 칩입니다. 태블릿에서 눌러 말에 쓸 결과를 고릅니다.
class YutChipButton extends StatelessWidget {
  const YutChipButton({
    super.key,
    required this.result,
    required this.team,
    required this.edition,
    this.selected = false,
    this.onTap,
    this.scale = 1,
  });
  final YutResult result;
  final YutTeam? team;
  final bool edition;
  final bool selected;
  final VoidCallback? onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final blue = team == YutTeam.blue || team == YutTeam.east;
    final style = YutTeamStyle.of(team);
    late final Color bg, fg, edge, shadow;
    if (edition) {
      bg = selected ? YutColors.moon : YutColors.nightRaised;
      fg = selected ? YutColors.night : YutColors.moon;
      edge = selected ? YutColors.moon : YutColors.lilac;
      shadow = Colors.black;
    } else if (blue || style.piece != 'piece_white') {
      bg = selected ? style.fill : style.soft;
      fg = selected ? const Color(0xFFF4F1EA) : style.fill;
      edge = selected ? style.shadow : style.fill;
      shadow = selected ? style.shadow : YutColors.blueLine;
    } else {
      bg = selected ? YutColors.muted : YutColors.paperLight;
      fg = selected ? YutColors.paperLight : YutColors.muted;
      edge = selected ? const Color(0xFF4A463F) : YutColors.edge;
      shadow = selected ? const Color(0xFF4A463F) : YutColors.edgeShadow;
    }
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${YutCopy.result(result)} ${YutCopy.steps(result)}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 58 * scale,
          height: 62 * scale,
          decoration: BoxDecoration(
            color: bg,
            gradient: edition && selected ? YutColors.holoGradient : null,
            borderRadius: BorderRadius.circular(10 * scale),
            border: Border.all(color: edge, width: 2),
            boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 3))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                YutCopy.result(result),
                style: YutFonts.stamp(
                  (result == YutResult.backDo ? 19 : 27) * scale,
                  color: fg,
                ),
              ),
              SizedBox(height: 3 * scale),
              Text(
                YutCopy.steps(result),
                style: YutFonts.text(
                  11 * scale,
                  color: fg,
                  weight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 남은 시간을 보여 주는 원형 시계입니다.
class YutTimerRing extends StatefulWidget {
  const YutTimerRing({
    super.key,
    required this.deadlineAt,
    required this.total,
    required this.color,
    required this.track,
    required this.fill,
    this.size = 50,
  });
  final int deadlineAt;
  final Duration total;
  final Color color;
  final Color track;
  final Color fill;
  final double size;

  @override
  State<YutTimerRing> createState() => _YutTimerRingState();
}

class _YutTimerRingState extends State<YutTimerRing> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.deadlineAt <= 0
        ? 0
        : (widget.deadlineAt - DateTime.now().millisecondsSinceEpoch).clamp(
            0,
            widget.total.inMilliseconds,
          );
    final seconds = (left / 1000).ceil();
    final progress = left / widget.total.inMilliseconds;
    return Semantics(
      label: yutText(
        '남은 시간 $seconds초',
        '$seconds seconds left',
        '剩余$seconds秒',
        '剩餘$seconds秒',
      ),
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: progress,
            color: widget.color,
            track: widget.track,
            fill: widget.fill,
          ),
          child: Center(
            child: Text(
              '$seconds',
              style: YutFonts.title(widget.size * .48, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.fill,
  });
  final double progress;
  final Color color;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    canvas.drawCircle(c, r + 2, Paint()..color = fill);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, stroke..color = track);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      stroke..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// 휴대폰 위쪽의 44px 네모 아이콘 버튼입니다.
class YutIconButton extends StatelessWidget {
  const YutIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.edition,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final bool edition;
  final ValueChanged<Offset> onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTapUp: (details) => onPressed(details.globalPosition),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: edition
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [YutColors.paperLight, YutColors.paperDeep],
                ),
          color: edition ? YutColors.nightPanel : null,
          border: Border.all(
            color: edition ? YutColors.lilac : YutColors.edge,
            width: 2,
          ),
          boxShadow: edition
              ? const [BoxShadow(color: Color(0x80000000), blurRadius: 10)]
              : const [
                  BoxShadow(color: YutColors.edgeShadow, offset: Offset(0, 4)),
                  BoxShadow(
                    color: Color(0x2E28282E),
                    offset: Offset(5, 9),
                    blurRadius: 10,
                  ),
                ],
        ),
        child: Icon(
          icon,
          size: 21,
          color: edition ? YutColors.moon : YutColors.ink,
        ),
      ),
    ),
  );
}

/// 에디션의 무지개빛 글자입니다.
class YutHoloText extends StatelessWidget {
  const YutHoloText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: YutColors.holoGradient.createShader,
    child: Text(text, style: style.copyWith(color: Colors.white)),
  );
}

/// 흩날리는 색종이입니다(승리 화면).
class YutConfetti extends StatefulWidget {
  const YutConfetti({super.key, required this.colors, this.count = 22});
  final List<Color> colors;
  final int count;

  @override
  State<YutConfetti> createState() => _YutConfettiState();
}

class _YutConfettiState extends State<YutConfetti>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();
  final _random = math.Random(7);
  late final _pieces = List.generate(
    widget.count,
    (i) => (
      x: _random.nextDouble(),
      speed: .7 + _random.nextDouble() * .5,
      offset: _random.nextDouble(),
      color: widget.colors[i % widget.colors.length],
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_pieces, _controller.value),
      ),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<({double x, double speed, double offset, Color color})> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final p = (t * piece.speed + piece.offset) % 1;
      canvas.save();
      canvas.translate(piece.x * size.width, -40 + p * (size.height + 80));
      canvas.rotate(p * math.pi * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4, -7, 8, 14),
          const Radius.circular(2),
        ),
        Paint()..color = piece.color.withValues(alpha: .9),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
