import 'package:flutter/widgets.dart';

abstract final class DeviceLayout {
  static const double tabletBreakpoint = 600;

  static bool isTablet(BoxConstraints constraints) {
    return constraints.biggest.shortestSide >= tabletBreakpoint;
  }
}
