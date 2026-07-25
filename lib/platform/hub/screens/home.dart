import 'package:flutter/material.dart';
import 'package:project00/platform/hub/screens/home_mobile.dart';
import 'package:project00/platform/hub/screens/home_tablet.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 모바일 브레이크포인트 설정 (일반적으로 600px 기준)
        if (constraints.maxWidth < 600) {
          return const HomeMobile(); // 600보다 작으면 모바일 화면 리턴
        } else {
          return const HomeTablet(); // 기존 작성하신 home.dart의 내용
        }
      },
    );
  }
}
