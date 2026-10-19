part of 'mosi_game_art.dart';

/// 홀덤 빨간 카드 상자 표지입니다. 기존 그림(749×1050)과 같은 배치를 코드로
/// 그립니다: Washable·스페이드·No. 52, 겹친 카드 뒷면, POKER와 두 줄 문구.
class _HoldemCardboxPainter extends CustomPainter {
  const _HoldemCardboxPainter();

  static const _navy = Color(0xFF1B1E2C);
  static const _ink = Color(0xFFE4E6F0);
  static const _red = Color(0xFFC42632);
  static const _serif = ['Times New Roman', 'Times', 'Georgia', 'serif'];
  static const _sans = ['Helvetica Neue', 'Arial', 'Roboto', 'sans-serif'];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 749, size.height / 1050);
    const box = Rect.fromLTWH(0, 0, 749, 1050);
    final shape = RRect.fromRectAndRadius(box, const Radius.circular(12));
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.1),
          radius: .85,
          colors: [Color(0xFFCA2B36), Color(0xFFC2252F), Color(0xFFA51E28)],
          stops: [0, .62, 1],
        ).createShader(box),
    );
    canvas.drawRRect(
      shape.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF6E1018),
    );

    _text(
      canvas,
      'Washable',
      const Offset(66, 84),
      TextStyle(
        fontFamily: 'Times New Roman',
        fontFamilyFallback: _serif,
        fontSize: 60,
        color: Colors.white,
        height: 1,
      ),
      angle: -.075,
    );
    _spade(canvas, const Offset(607, 112), 104);
    _text(
      canvas,
      'No. 52',
      const Offset(607, 188),
      const TextStyle(
        fontFamily: 'Times New Roman',
        fontFamilyFallback: _serif,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 5,
        height: 1,
      ),
      center: true,
    );

    _cards(canvas);

    _text(
      canvas,
      'POKER',
      const Offset(374.5, 640),
      const TextStyle(
        fontFamily: 'Times New Roman',
        fontFamilyFallback: _serif,
        fontSize: 172,
        color: Colors.white,
        letterSpacing: 4,
        height: 1,
      ),
      center: true,
    );
    _text(
      canvas,
      '100% ALL PLASTIC PLAYING CARDS',
      const Offset(374.5, 838),
      const TextStyle(
        fontFamily: 'Arial',
        fontFamilyFallback: _sans,
        fontSize: 31,
        color: Colors.white,
        height: 1,
      ),
      center: true,
    );
    _text(
      canvas,
      'MADE BY MOSIGAME',
      const Offset(374.5, 900),
      const TextStyle(
        fontFamily: 'Arial',
        fontFamilyFallback: _sans,
        fontSize: 25,
        color: Colors.white,
        height: 1,
      ),
      center: true,
    );
    canvas.restore();
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    bool center = false,
    double angle = 0,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (angle != 0) canvas.rotate(angle);
    painter.paint(canvas, Offset(center ? -painter.width / 2 : 0, 0));
    canvas.restore();
  }

  void _spade(Canvas canvas, Offset c, double s) {
    final u = s / 100;
    final path = Path()
      ..moveTo(c.dx, c.dy - 50 * u)
      ..cubicTo(
        c.dx + 18 * u,
        c.dy - 22 * u,
        c.dx + 50 * u,
        c.dy - 4 * u,
        c.dx + 46 * u,
        c.dy + 22 * u,
      )
      ..cubicTo(
        c.dx + 42 * u,
        c.dy + 44 * u,
        c.dx + 14 * u,
        c.dy + 44 * u,
        c.dx + 4 * u,
        c.dy + 30 * u,
      )
      ..quadraticBezierTo(
        c.dx + 8 * u,
        c.dy + 48 * u,
        c.dx + 20 * u,
        c.dy + 58 * u,
      )
      ..lineTo(c.dx - 20 * u, c.dy + 58 * u)
      ..quadraticBezierTo(
        c.dx - 8 * u,
        c.dy + 48 * u,
        c.dx - 4 * u,
        c.dy + 30 * u,
      )
      ..cubicTo(
        c.dx - 14 * u,
        c.dy + 44 * u,
        c.dx - 42 * u,
        c.dy + 44 * u,
        c.dx - 46 * u,
        c.dy + 22 * u,
      )
      ..cubicTo(
        c.dx - 50 * u,
        c.dy - 4 * u,
        c.dx - 18 * u,
        c.dy - 22 * u,
        c.dx,
        c.dy - 50 * u,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  /// 흰 테두리 안에 카드 두 장(뒤: 마름모 띠, 앞: 별 무늬)이 겹쳐 있습니다.
  void _cards(Canvas canvas) {
    final back = RRect.fromLTRBR(150, 205, 547, 504, const Radius.circular(22));
    final front = RRect.fromLTRBR(
      203,
      257,
      622,
      545,
      const Radius.circular(22),
    );
    Path union(double inset) => Path.combine(
      PathOperation.union,
      Path()..addRRect(back.deflate(inset)),
      Path()..addRRect(front.deflate(inset)),
    );
    canvas.drawPath(union(0), Paint()..color = Colors.white);
    canvas.drawPath(union(9), Paint()..color = _red);
    canvas.drawPath(
      union(16),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.white,
    );

    // 카드는 테두리 모양을 그대로 따라갑니다. 왼쪽 띠는 뒤 카드(마름모),
    // 나머지는 앞 카드(별과 점)입니다.
    final card = union(24);
    canvas.drawPath(card, Paint()..color = _navy);
    canvas.save();
    canvas.clipPath(card);
    const split = 225.0;
    final diamond = Paint()..color = _ink;
    for (var row = 0; row < 14; row++) {
      for (var col = 0; col < 3; col++) {
        final cx = 183 + col * 15.0 + (row.isOdd ? 7.5 : 0);
        final cy = 236 + row * 21.0;
        if (cx > split - 6) continue;
        canvas.drawPath(
          Path()
            ..moveTo(cx, cy - 7)
            ..lineTo(cx + 4.5, cy)
            ..lineTo(cx, cy + 7)
            ..lineTo(cx - 4.5, cy)
            ..close(),
          diamond,
        );
      }
    }
    final ring = Paint()..color = const Color(0xFF262A3C);
    final dot = Paint()..color = _ink;
    for (var row = 0; row < 12; row++) {
      for (var col = 0; col < 14; col++) {
        final c = Offset(split + 17 + col * 29.0, 240 + row * 28.0);
        if ((row + col).isEven) {
          _star(canvas, c, 12, dot);
        } else {
          canvas.drawCircle(c, 12, ring);
          canvas.drawCircle(c, 3.6, dot);
        }
      }
    }
    // 앞 카드 왼쪽 가장자리와 비스듬한 광택
    canvas.drawRect(
      const Rect.fromLTWH(split - 4, 0, 6, 1050),
      Paint()..color = _navy,
    );
    canvas.drawLine(
      const Offset(split, 0),
      const Offset(split, 1050),
      Paint()
        ..strokeWidth = 2.5
        ..color = _ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(300, 190)
        ..lineTo(380, 190)
        ..lineTo(250, 540)
        ..lineTo(170, 540)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: .07),
    );
    canvas.restore();

    const emblem = Offset(425, 470);
    canvas.drawRect(
      Rect.fromCenter(center: emblem, width: 96, height: 96),
      Paint()..color = _navy,
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = _ink;
    canvas.drawRect(
      Rect.fromCenter(center: emblem, width: 82, height: 82),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(emblem.dx, emblem.dy - 58)
        ..lineTo(emblem.dx + 58, emblem.dy)
        ..lineTo(emblem.dx, emblem.dy + 58)
        ..lineTo(emblem.dx - 58, emblem.dy)
        ..close(),
      line,
    );
    _star(canvas, emblem, 26, Paint()..color = _ink);
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final w = r * .3;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + w * .4, c.dy - w * .4, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + w * .4, c.dy + w * .4, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - w * .4, c.dy + w * .4, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - w * .4, c.dy - w * .4, c.dx, c.dy - r)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_HoldemCardboxPainter oldDelegate) => false;
}
