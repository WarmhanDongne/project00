import 'package:flutter/material.dart';
import 'package:project00/platform/hub/screens/home_mobile.dart';
import 'package:project00/platform/hub/screens/home_tablet.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.biggest.shortestSide >= 600;
        return isTablet ? const HomeTablet() : const HomeMobile();
      },
    );
  }
}
