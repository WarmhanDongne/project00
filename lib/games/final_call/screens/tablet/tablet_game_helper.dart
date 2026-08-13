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
