import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mosigame_core/core/layout/device_layout.dart';
import 'package:mosigame_core/games/shared/widgets/game_reconnect_screen.dart';
import 'package:game_contract/games/template_game.dart';
import 'package:mosigame_platform/platform/home/phone/screens/phone_home.dart';
import 'package:mosigame_platform/platform/home/tablet/screens/tablet_home.dart';

class Home extends StatelessWidget {
  const Home({super.key, this.gameCatalog = const EmptyGameCatalog()});

  final GameCatalog gameCatalog;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = DeviceLayout.isTablet(constraints);
        final home = isTablet
            ? TabletHome(gameCatalog: gameCatalog)
            : PhoneHome(gameCatalog: gameCatalog);
        // 개발용 진입 지점입니다. 디버그 빌드에서만 살아 있고, 릴리스 빌드에는
        // 코드 자체가 들어가지 않습니다(tree shaking).
        if (!kDebugMode) return home;
        return Stack(
          children: [
            home,
            // 확정(2026-08): **아이콘을 그리지 않습니다.** 벌레 모양이 홈 디자인
            // 위에 늘 떠 있어 화면을 어지럽혔습니다. 대신 왼쪽 아래 모서리를
            // **길게 누르면** 개발 도구 목록이 열립니다.
            Positioned(
              left: 0,
              bottom: 0,
              child: SafeArea(
                child: GestureDetector(
                  onLongPress: () => _openDevMenu(context),
                  // 아무것도 그리지 않지만 누름은 받습니다.
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox(width: 56, height: 56),
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
