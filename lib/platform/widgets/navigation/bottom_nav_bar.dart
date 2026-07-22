import 'package:flutter/material.dart';
import 'package:project00/platform/router/route_names.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({required this.currentIndex, super.key});
  final int currentIndex;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: currentIndex,
    onDestinationSelected: (index) {
      if (index == 1) Navigator.pushNamed(context, RouteNames.store);
      if (index == 2) Navigator.pushNamed(context, RouteNames.settings);
    },
    destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
      NavigationDestination(
        icon: Icon(Icons.sports_esports_outlined),
        label: '게임',
      ),
      NavigationDestination(icon: Icon(Icons.settings_outlined), label: '설정'),
    ],
  );
}
