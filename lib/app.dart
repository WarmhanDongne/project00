/// MaterialApp 배선입니다. 테마·인증 게이트·네트워크 가드·패치 게이트를 묶습니다.
///
/// `core/`가 아니라 앱 루트에 있는 이유: 이 파일은 platform(인증·테마)을 알아야
/// 하는데, `core`는 platform을 몰라야 합니다. 배선은 앱 셸의 일입니다
/// (`docs/engineering/PACKAGE_MIGRATION.md`).

library;

//=======================앱 셸==============================

import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:game_kit/core/diagnostics/dev_error_overlay.dart';
import 'package:game_kit/core/layout/device_layout.dart';
import 'package:game_kit/core/network/app_network_guard.dart';
import 'package:game_kit/core/update/shorebird_patch_gate.dart';
import 'package:project00/games/game_registry.dart';
import 'package:project00/platform/auth/widgets/auth_gate.dart';
import 'package:project00/platform/theme/platform_theme.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    this.userChanges,
    this.emailLinks,
    this.initialEmailLink,
  });

  final Stream<User?>? userChanges;
  final Stream<Uri>? emailLinks;
  final Uri? initialEmailLink;

  @override
  Widget build(BuildContext context) {
    final view =
        PlatformDispatcher.instance.implicitView ??
        PlatformDispatcher.instance.views.firstOrNull;
    final size = view != null
        ? (view.physicalSize / view.devicePixelRatio)
        : const Size(390, 844);

    final isTablet = size.shortestSide >= DeviceLayout.tabletBreakpoint;
    final currentDesignSize = isTablet
        ? const Size(834, 1194)
        : const Size(390, 844);

    return ScreenUtilInit(
      designSize: currentDesignSize,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Project 00',
        theme: PlatformTheme.light(),
        darkTheme: PlatformTheme.dark(),
        themeMode: ThemeMode.light,
        // 개발용 게임 통신 진단을 가장 바깥에 둡니다. 휴대폰·태블릿
        // 어떤 화면에서든 오른쪽 아래에서 같은 타임라인을 열 수 있으며,
        // 릴리스 빌드에서는 child를 그대로 통과시킵니다.
        builder: (context, child) => DevErrorOverlay(
          child: AppNetworkGuard(child: child ?? const SizedBox.shrink()),
        ),
        // 새 패치가 있으면 받는 동안만 패치 화면을 덮습니다. 확인 중에는
        // 화면을 막지 않고, 패치가 없거나 실패하면 그대로 통과합니다.
        home: ShorebirdPatchGate(
          child: AuthGate(
            gameCatalog: const GameRegistry(),
            userChanges: userChanges,
            emailLinks: emailLinks,
            initialEmailLink: initialEmailLink,
          ),
        ),
      ),
    );
  }
}
