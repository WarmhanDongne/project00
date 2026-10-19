import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:game_yut/src/theme.dart';

/// 디자인의 한지 배경(`tradbg`)을 코드로 그립니다.
///
/// 미색 바탕(#F3EBDC) 위에 놀이 소품 무늬(윷가락·구름·팔각 말·엽전·연·
/// 복주머니·제기·매화) 300×288 한 칸을 80% 불투명도로 반복하고, 세로로 가는
/// 한지 결을 옅게 얹습니다. 한 칸은 한 번만 기록해 두고 반복해 그립니다.
class YutHanjiPainter extends CustomPainter {
  const YutHanjiPainter();

  static const tile = Size(300, 288);
  static ui.Picture? _tile;

  static ui.Picture _record() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & tile);
    canvas.saveLayer(
      Offset.zero & tile,
      Paint()..color = const Color(0xCC000000),
    );
    _paintHanjiMotifs(canvas);
    for (final (text, dx, dy, degrees) in const [
      ('청', 250.0, 40.0, 8.0),
      ('백', 196.0, 262.0, -8.0),
    ]) {
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(degrees * math.pi / 180);
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontFamily: YutFonts.brush,
            fontFamilyFallback: [YutFonts.body],
            fontSize: 11,
            color: Color(0xFFC9B48E),
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final ascent = painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      painter.paint(canvas, Offset(-painter.width / 2, 4.1 - ascent));
      canvas.restore();
    }
    canvas.restore();
    // 디자인의 노이즈는 바탕 전체를 아주 옅은 갈색으로 물들입니다.
    canvas.drawRect(
      Offset.zero & tile,
      Paint()..color = const Color(0xFF73542E).withValues(alpha: .012),
    );
    // 한지 결: 1px 열마다 옅은 세로 섬유가 이어집니다(디자인의 노이즈 필터).
    final random = math.Random(5);
    final fiber = Paint()..strokeWidth = 1;
    for (var x = .5; x < tile.width; x += 1) {
      var y = -random.nextDouble() * 20;
      while (y < tile.height) {
        final length = 8 + random.nextDouble() * 30;
        fiber.color = const Color(
          0xFF73542E,
        ).withValues(alpha: random.nextDouble() * .028);
        canvas.drawLine(Offset(x, y), Offset(x, y + length), fiber);
        y += length;
      }
    }
    return recorder.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = YutColors.paper);
    final picture = _tile ??= _record();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var y = 0.0; y < size.height; y += tile.height) {
      for (var x = 0.0; x < size.width; x += tile.width) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawPicture(picture);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(YutHanjiPainter oldDelegate) => false;
}

// 아래는 디자인 SVG의 무늬 한 칸을 옮긴 그리기 코드입니다.
// ignore_for_file: prefer_const_constructors

void _paintHanjiMotifs(Canvas canvas) {
  canvas.save();
  canvas.translate(40, 30);
  canvas.rotate(-0.489);
  canvas.scale(1, 1);
  final p1 = Path()..addRRect(RRect.fromLTRBXY(-23, -5.5, 23, 5.5, 5.5, 5.5));
  canvas.drawPath(
    p1,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p2 = Path()
    ..moveTo(-14, -3)
    ..lineTo(-8, 3)
    ..moveTo(-8, -3)
    ..lineTo(-14, 3);
  canvas.drawPath(
    p2,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p3 = Path()
    ..moveTo(-3, -3)
    ..lineTo(3, 3)
    ..moveTo(3, -3)
    ..lineTo(-3, 3);
  canvas.drawPath(
    p3,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p4 = Path()
    ..moveTo(8, -3)
    ..lineTo(14, 3)
    ..moveTo(14, -3)
    ..lineTo(8, 3);
  canvas.drawPath(
    p4,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  canvas.restore();
  canvas.save();
  canvas.translate(150, 22);
  canvas.rotate(0);
  canvas.scale(0.75, 0.75);
  final p5 = Path()
    ..moveTo(-20, 4)
    ..cubicTo(-22, -5, -11, -10, -5, -4)
    ..cubicTo(-2, -11, 10, -11, 12, -3)
    ..cubicTo(20, -5, 24, 3, 19, 8)
    ..cubicTo(24, 12, 20, 19, 13, 17)
    ..cubicTo(11, 23, 1, 24, -2, 18)
    ..cubicTo(-8, 22, -17, 19, -16, 12)
    ..cubicTo(-23, 11, -24, 4, -20, 4)
    ..close();
  canvas.drawPath(
    p5,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p6 = Path()
    ..moveTo(-10, 6)
    ..arcToPoint(
      Offset(-4, 9),
      radius: Radius.elliptical(4, 4),
      rotation: 0,
      largeArc: true,
      clockwise: true,
    )
    ..moveTo(6, 4)
    ..arcToPoint(
      Offset(11, 7),
      radius: Radius.elliptical(3.5, 3.5),
      rotation: 0,
      largeArc: true,
      clockwise: true,
    );
  canvas.drawPath(
    p6,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  canvas.restore();
  canvas.save();
  canvas.translate(250, 40);
  canvas.rotate(0.14);
  final p7 = Path()
    ..addPolygon([
      Offset(11.1, 4.6),
      Offset(4.6, 11.1),
      Offset(-4.6, 11.1),
      Offset(-11.1, 4.6),
      Offset(-11.1, -4.6),
      Offset(-4.6, -11.1),
      Offset(4.6, -11.1),
      Offset(11.1, -4.6),
    ], true);
  canvas.drawPath(
    p7,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  canvas.restore();
  canvas.save();
  canvas.translate(96, 86);
  final p8 = Path()
    ..addOval(Rect.fromCircle(center: Offset(0, -6), radius: 4.5));
  canvas.drawPath(
    p8,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p9 = Path()
    ..addOval(Rect.fromCircle(center: Offset(5.7, -1.9), radius: 4.5));
  canvas.drawPath(
    p9,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p10 = Path()
    ..addOval(Rect.fromCircle(center: Offset(3.5, 4.9), radius: 4.5));
  canvas.drawPath(
    p10,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p11 = Path()
    ..addOval(Rect.fromCircle(center: Offset(-3.5, 4.9), radius: 4.5));
  canvas.drawPath(
    p11,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p12 = Path()
    ..addOval(Rect.fromCircle(center: Offset(-5.7, -1.9), radius: 4.5));
  canvas.drawPath(
    p12,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p13 = Path()
    ..addOval(Rect.fromCircle(center: Offset(0, 0), radius: 2.1));
  canvas.drawPath(p13, Paint()..color = const Color(0xFFC9B48E));
  canvas.restore();
  canvas.save();
  canvas.translate(200, 96);
  canvas.rotate(0.262);
  final p14 = Path()
    ..addOval(Rect.fromCircle(center: Offset(0, 0), radius: 11));
  canvas.drawPath(
    p14,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p15 = Path()
    ..addOval(Rect.fromCircle(center: Offset(0, 0), radius: 8.58));
  canvas.drawPath(
    p15,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p16 = Path()..addRect(Rect.fromLTWH(-3.08, -3.08, 6.16, 6.16));
  canvas.drawPath(
    p16,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  canvas.restore();
  canvas.save();
  canvas.translate(268, 128);
  canvas.rotate(-0.209);
  canvas.scale(0.8, 0.8);
  final p17 = Path()..addRect(Rect.fromLTWH(-13, -16, 26, 32));
  canvas.drawPath(
    p17,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p18 = Path()..addOval(Rect.fromCircle(center: Offset(0, 0), radius: 6));
  canvas.drawPath(
    p18,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p19 = Path()
    ..moveTo(-13, -16)
    ..lineTo(13, 16)
    ..moveTo(13, -16)
    ..lineTo(-13, 16);
  canvas.drawPath(
    p19,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p20 = Path()
    ..moveTo(0, 16)
    ..quadraticBezierTo(4, 26, -2, 34)
    ..quadraticBezierTo(-8, 42, 0, 50);
  canvas.drawPath(
    p20,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  canvas.restore();
  canvas.save();
  canvas.translate(34, 150);
  canvas.rotate(0.105);
  final p21 = Path()..addRect(Rect.fromLTWH(-12, -12, 24, 24));
  canvas.drawPath(
    p21,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p22 = Path()
    ..moveTo(-12, -12)
    ..lineTo(12, 12)
    ..moveTo(12, -12)
    ..lineTo(-12, 12);
  canvas.drawPath(
    p22,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p23 = Path()
    ..addOval(Rect.fromCircle(center: Offset(-12, -12), radius: 1.6));
  canvas.drawPath(p23, Paint()..color = const Color(0xFFC9B48E));
  final p24 = Path()
    ..addOval(Rect.fromCircle(center: Offset(-12, 12), radius: 1.6));
  canvas.drawPath(p24, Paint()..color = const Color(0xFFC9B48E));
  final p25 = Path()
    ..addOval(Rect.fromCircle(center: Offset(12, -12), radius: 1.6));
  canvas.drawPath(p25, Paint()..color = const Color(0xFFC9B48E));
  final p26 = Path()
    ..addOval(Rect.fromCircle(center: Offset(12, 12), radius: 1.6));
  canvas.drawPath(p26, Paint()..color = const Color(0xFFC9B48E));
  final p27 = Path()
    ..addOval(Rect.fromCircle(center: Offset(0, 0), radius: 2.6));
  canvas.drawPath(p27, Paint()..color = const Color(0xFFC9B48E));
  canvas.restore();
  canvas.save();
  canvas.translate(140, 150);
  canvas.rotate(0.419);
  canvas.scale(1, 1);
  final p28 = Path()..addRRect(RRect.fromLTRBXY(-23, -5.5, 23, 5.5, 5.5, 5.5));
  canvas.drawPath(
    p28,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p29 = Path()
    ..moveTo(-15, 0)
    ..lineTo(15, 0);
  canvas.drawPath(
    _dashed(p29, const [4, 3]),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  canvas.restore();
  canvas.save();
  canvas.translate(222, 190);
  canvas.rotate(-0.14);
  canvas.scale(0.85, 0.85);
  final p30 = Path()
    ..moveTo(-12, -8)
    ..quadraticBezierTo(-22, 6, -12, 17)
    ..quadraticBezierTo(0, 24, 12, 17)
    ..quadraticBezierTo(22, 6, 12, -8)
    ..close();
  canvas.drawPath(
    p30,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p31 = Path()
    ..moveTo(-12, -8)
    ..lineTo(-15, -17)
    ..lineTo(-8, -13)
    ..lineTo(-5, -20)
    ..lineTo(-2, -13)
    ..lineTo(1, -20)
    ..lineTo(4, -13)
    ..lineTo(11, -17)
    ..lineTo(8, -8);
  canvas.drawPath(
    p31,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p32 = Path()
    ..moveTo(-12, -8)
    ..lineTo(12, -8);
  canvas.drawPath(
    p32,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p33 = Path()
    ..moveTo(-4, 4)
    ..lineTo(4, 4)
    ..moveTo(0, 0)
    ..lineTo(0, 8);
  canvas.drawPath(
    p33,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  canvas.restore();
  canvas.save();
  canvas.translate(56, 232);
  canvas.rotate(0);
  canvas.scale(0.7, 0.7);
  final p34 = Path()
    ..moveTo(-20, 4)
    ..cubicTo(-22, -5, -11, -10, -5, -4)
    ..cubicTo(-2, -11, 10, -11, 12, -3)
    ..cubicTo(20, -5, 24, 3, 19, 8)
    ..cubicTo(24, 12, 20, 19, 13, 17)
    ..cubicTo(11, 23, 1, 24, -2, 18)
    ..cubicTo(-8, 22, -17, 19, -16, 12)
    ..cubicTo(-23, 11, -24, 4, -20, 4)
    ..close();
  canvas.drawPath(
    p34,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p35 = Path()
    ..moveTo(-10, 6)
    ..arcToPoint(
      Offset(-4, 9),
      radius: Radius.elliptical(4, 4),
      rotation: 0,
      largeArc: true,
      clockwise: true,
    )
    ..moveTo(6, 4)
    ..arcToPoint(
      Offset(11, 7),
      radius: Radius.elliptical(3.5, 3.5),
      rotation: 0,
      largeArc: true,
      clockwise: true,
    );
  canvas.drawPath(
    p35,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  canvas.restore();
  canvas.save();
  canvas.translate(132, 232);
  canvas.rotate(0.175);
  canvas.scale(0.85, 0.85);
  final p36 = Path()
    ..moveTo(0, 6)
    ..lineTo(-10.7, -11.6);
  canvas.drawPath(
    p36,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p37 = Path()
    ..moveTo(0, 6)
    ..lineTo(-7, -15.6);
  canvas.drawPath(
    p37,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p38 = Path()
    ..moveTo(0, 6)
    ..lineTo(-2.4, -17.7);
  canvas.drawPath(
    p38,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p39 = Path()
    ..moveTo(0, 6)
    ..lineTo(2.4, -17.7);
  canvas.drawPath(
    p39,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p40 = Path()
    ..moveTo(0, 6)
    ..lineTo(7, -15.6);
  canvas.drawPath(
    p40,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p41 = Path()
    ..moveTo(0, 6)
    ..lineTo(10.7, -11.6);
  canvas.drawPath(
    p41,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p42 = Path()
    ..addOval(Rect.fromCenter(center: Offset(0, 8), width: 14, height: 8));
  canvas.drawPath(
    p42,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  canvas.restore();
  canvas.save();
  canvas.translate(196, 262);
  canvas.rotate(-0.14);
  final p43 = Path()
    ..addPolygon([
      Offset(11.1, 4.6),
      Offset(4.6, 11.1),
      Offset(-4.6, 11.1),
      Offset(-11.1, 4.6),
      Offset(-11.1, -4.6),
      Offset(-4.6, -11.1),
      Offset(4.6, -11.1),
      Offset(11.1, -4.6),
    ], true);
  canvas.drawPath(
    p43,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  canvas.restore();
  canvas.save();
  canvas.translate(270, 250);
  final p44 = Path()
    ..addOval(Rect.fromCircle(center: Offset(0, -6), radius: 4.5));
  canvas.drawPath(
    p44,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p45 = Path()
    ..addOval(Rect.fromCircle(center: Offset(5.7, -1.9), radius: 4.5));
  canvas.drawPath(
    p45,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p46 = Path()
    ..addOval(Rect.fromCircle(center: Offset(3.5, 4.9), radius: 4.5));
  canvas.drawPath(
    p46,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p47 = Path()
    ..addOval(Rect.fromCircle(center: Offset(-3.5, 4.9), radius: 4.5));
  canvas.drawPath(
    p47,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p48 = Path()
    ..addOval(Rect.fromCircle(center: Offset(-5.7, -1.9), radius: 4.5));
  canvas.drawPath(
    p48,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p49 = Path()
    ..addOval(Rect.fromCircle(center: Offset(0, 0), radius: 2.1));
  canvas.drawPath(p49, Paint()..color = const Color(0xFFC9B48E));
  canvas.restore();
  canvas.save();
  canvas.translate(250, 288);
  canvas.rotate(-1.047);
  canvas.scale(0.9, 0.9);
  final p50 = Path()..addRRect(RRect.fromLTRBXY(-23, -5.5, 23, 5.5, 5.5, 5.5));
  canvas.drawPath(
    p50,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p51 = Path()
    ..moveTo(-14, -3)
    ..lineTo(-8, 3)
    ..moveTo(-8, -3)
    ..lineTo(-14, 3);
  canvas.drawPath(
    p51,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p52 = Path()
    ..moveTo(-3, -3)
    ..lineTo(3, 3)
    ..moveTo(3, -3)
    ..lineTo(-3, 3);
  canvas.drawPath(
    p52,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  final p53 = Path()
    ..moveTo(8, -3)
    ..lineTo(14, 3)
    ..moveTo(14, -3)
    ..lineTo(8, 3);
  canvas.drawPath(
    p53,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFFC9B48E),
  );
  canvas.restore();
}

/// SVG `stroke-dasharray`를 경로 길이를 따라 잘라 그립니다.
Path _dashed(Path source, List<double> pattern) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var index = 0;
    while (distance < metric.length) {
      final length = pattern[index % pattern.length];
      if (index.isEven) {
        out.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
      }
      distance += length;
      index++;
    }
  }
  return out;
}
