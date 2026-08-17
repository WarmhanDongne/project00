import 'dart:math' as math;

import 'package:flutter/material.dart';

Alignment finalCallSeatAlignment(int index, int count) {
  if (count == 2) {
    return index == 0 ? Alignment.bottomCenter : Alignment.topCenter;
  }
  if (count == 3) {
    return const [
      Alignment.bottomCenter,
      Alignment.centerLeft,
      Alignment.centerRight,
    ][index];
  }
  return const [
    Alignment.bottomCenter,
    Alignment.centerRight,
    Alignment.topCenter,
    Alignment.centerLeft,
  ][index];
}

double finalCallSeatRotation(int index, int count) {
  final alignment = finalCallSeatAlignment(index, count);
  if (alignment == Alignment.topCenter) return math.pi;
  if (alignment == Alignment.centerLeft) return math.pi / 2;
  if (alignment == Alignment.centerRight) return -math.pi / 2;
  return 0;
}

/// 실제 원형 레이아웃 좌표에서 플레이어가 보드 중심을 바라보는 각도입니다.
double finalCallSeatRotationForCenter({
  required Offset center,
  required Size boardSize,
}) {
  final boardCenter = boardSize.center(Offset.zero);
  final direction = center - boardCenter;
  if (direction.distanceSquared == 0) return 0;
  return math.atan2(direction.dy, direction.dx) - math.pi / 2;
}
