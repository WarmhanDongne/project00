import 'package:flutter/material.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 모바일 브레이크포인트 설정 (일반적으로 600px 기준)
        if (constraints.maxWidth < 600) {
          return const HomeMobile();
        } else {
          return const HomeTablet(); // 기존 작성하신 home.dart의 내용
        }
      },
    );
  }
}
