import 'package:flutter/material.dart';
import 'package:project00/core/layout/device_layout.dart';
import 'package:project00/platform/home/phone/screens/phone_home.dart';
import 'package:project00/platform/home/tablet/screens/tablet_home.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = DeviceLayout.isTablet(constraints);
        return isTablet ? const TabletHome() : const PhoneHome();
      },
    );
  }
}
