import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/auth/widgets/auth_gate.dart';
import 'package:project00/core/layout/device_layout.dart';
import 'package:project00/core/network/app_network_guard.dart';
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
    // 화면 크기 구하기
    final view =
        PlatformDispatcher.instance.implicitView ??
        PlatformDispatcher.instance.views.firstOrNull;
    final size = view != null
        ? (view.physicalSize / view.devicePixelRatio)
        : const Size(390, 844);

    // 테블릿, 폰 분기
    final bool isTablet = size.shortestSide >= DeviceLayout.tabletBreakpoint;
    final Size currentDesignSize = isTablet
        ? const Size(834, 1194) // 테블릿 기본 사이즈
        : const Size(390, 844); // 핸드폰 기본 사이즈

    return ScreenUtilInit(
      designSize: currentDesignSize,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Project 00',
        theme: PlatformTheme.light(),
        darkTheme: PlatformTheme.dark(),
        themeMode: ThemeMode.light,
        //=======================앱 전체 네트워크 모달==============================
        // Navigator보다 바깥에서 한 번만 연결 상태를 구독하므로 로그인·플랫폼·
        // 모든 게임과 그 위에 열린 dialog까지 같은 반응형 모달이 덮습니다.
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
