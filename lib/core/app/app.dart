import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/core/layout/device_layout.dart';
import 'package:project00/core/network/app_network_guard.dart';
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
        builder: (context, child) =>
            AppNetworkGuard(child: child ?? const SizedBox.shrink()),
        home: AuthGate(
          userChanges: userChanges,
          emailLinks: emailLinks,
          initialEmailLink: initialEmailLink,
        ),
      ),
    );
  }
}
