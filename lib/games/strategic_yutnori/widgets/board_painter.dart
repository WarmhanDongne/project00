import 'package:flutter/material.dart';

class BoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // 1. 외곽선 정사각형 그리기
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    // 2. 내부 대각선 (X자) 그리기
    canvas.drawLine(const Offset(0, 0), Offset(w, h), paint);
    canvas.drawLine(Offset(w, 0), Offset(0, h), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false; // 정적인 선이므로 상태가 변해도 다시 그릴 필요가 없습니다.
  }
}
