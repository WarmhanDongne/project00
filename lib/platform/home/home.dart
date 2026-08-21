import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:project00/core/layout/device_layout.dart';
import 'package:project00/games/mafia/dev/mafia_practice_screen.dart';
import 'package:project00/games/shared/widgets/game_reconnect_screen.dart';
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
        // 디버그 빌드에서만 보이는 개발용 진입 버튼입니다.
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
                  tooltip: '개발 도구',
                  icon: const Icon(Icons.bug_report, color: Colors.black26),
                  onPressed: () => _openDevMenu(context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 개발용 화면 목록입니다(디버그 빌드 전용).
  ///
  /// 아직 배선하지 않은 화면을 눈으로 확인하는 자리이기도 합니다.
  void _openDevMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videogame_asset),
              title: const Text('마피아 연습장'),
              subtitle: const Text('Firebase 없이 흐름 전체를 돌려 봅니다'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MafiaPracticeScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.wifi_tethering),
              title: const Text('게임 재접속 화면'),
              subtitle: const Text('디자인 확인용 — 아직 배선하지 않았습니다'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GameReconnectScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
