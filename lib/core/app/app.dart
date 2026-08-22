import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/core/diagnostics/dev_error_overlay.dart';
import 'package:project00/core/layout/device_layout.dart';
import 'package:project00/core/network/app_network_guard.dart';
import 'package:project00/core/update/shorebird_patch_gate.dart';
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
        // 개발 중 오류 표시는 가장 바깥에 둡니다. 어떤 화면에서 오류가 나도
        // 같은 자리에서 볼 수 있습니다(릴리스에서는 통과만 합니다).
        builder: (context, child) => DevErrorOverlay(
          child: AppNetworkGuard(child: child ?? const SizedBox.shrink()),
        ),
        // 새 패치가 있으면 받는 동안만 패치 화면을 덮습니다. 확인 중에는
        // 화면을 막지 않고, 패치가 없거나 실패하면 그대로 통과합니다.
        home: ShorebirdPatchGate(
          child: AuthGate(
            userChanges: userChanges,
            emailLinks: emailLinks,
            initialEmailLink: initialEmailLink,
          ),
        ),
      ),
    );
  }
}
