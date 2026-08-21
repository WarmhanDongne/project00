import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:project00/core/layout/device_layout.dart';
import 'package:project00/games/mafia/dev/mafia_practice_screen.dart';
import 'package:project00/platform/home/phone/screens/phone_home.dart';
import 'package:project00/platform/home/tablet/screens/tablet_home.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = DeviceLayout.isTablet(constraints);
        final home = isTablet ? const TabletHome() : const PhoneHome();
        // 디버그 빌드에서만: 마피아 연습장(로컬 가짜 서버) 진입 버튼.
        // 릴리스 빌드에는 코드 자체가 들어가지 않습니다(tree shaking).
        if (!kDebugMode) return home;
        return Stack(
          children: [
            home,
            Positioned(
              left: 8,
              bottom: 8,
              child: SafeArea(
                child: IconButton(
                  tooltip: '마피아 연습장 (개발 전용)',
                  icon: const Icon(Icons.bug_report, color: Colors.black26),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MafiaPracticeScreen(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
