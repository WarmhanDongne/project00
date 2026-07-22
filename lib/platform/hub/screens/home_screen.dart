import 'package:flutter/material.dart';
import 'package:project00/platform/router/route_names.dart';
import 'package:project00/platform/widgets/navigation/bottom_nav_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Project 00')),
    body: Center(
      child: FilledButton(
        onPressed: () => Navigator.pushNamed(context, RouteNames.store),
        child: const Text('게임 스토어'),
      ),
    ),
    bottomNavigationBar: const BottomNavBar(currentIndex: 0),
  );
}
