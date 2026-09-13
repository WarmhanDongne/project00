library;

import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
//============================[ 기기 화면에 맞춰 픽셀 환산 ]=======================
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
    //============================[ 필요 변수 선언 ]==============================
    final view =
        PlatformDispatcher.instance.implicitView ??
        PlatformDispatcher.instance.views.firstOrNull;
    final size = view != null
        ? (view.physicalSize / view.devicePixelRatio)
        : const Size(390, 844);
    // 추후 수정 요망(9/13): 메인에서 계산한 것 중복.
    // 창 크기 변화에 유동적일지, 고정적일지 고민 후 처리할 것.
    // 예: 폴더블 폰.
    final isTablet = size.shortestSide >= DeviceLayout.tabletBreakpoint;
    final currentDesignSize = isTablet
        ? const Size(834, 1194)
        : const Size(390, 844);

    //===============================[ 앱 리턴 ]=================================
    return ScreenUtilInit(
      designSize: currentDesignSize,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // 추후 수정 요망(9/13): 타이틀 수정 필요
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
          // [진입 화면 판단] 유저의 인증, 가입 상태에 따라 진입 화면 결정
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
