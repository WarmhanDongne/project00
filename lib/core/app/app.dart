import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore 추가
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/auth/screens/login_screen.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/core/layout/device_layout.dart';
import 'package:project00/core/network/app_network_guard.dart';
import 'package:project00/platform/home/home.dart';
import 'package:project00/platform/theme/platform_theme.dart';

class App extends StatelessWidget {
  const App({super.key, this.userChanges});
  final Stream<User?>? userChanges;

  @override
  Widget build(BuildContext context) {
    // 화면 크기 구하기
    final view = View.of(context);
    final size = view.physicalSize / view.devicePixelRatio;

    // shortestSide를 기준으로 태블릿 여부를 판단합니다.
    final isTablet = size.shortestSide >= DeviceLayout.tabletBreakpoint;

    // 테블릿, 폰 분기
    final Size currentDesignSize = isTablet
        ? const Size(834, 1194) // 테블릿 기본 사이즈
        : const Size(390, 844); // 핸드폰 기본 사이즈

    return ScreenUtilInit(
      ensureScreenSize:
          true, // 추가: Android 환경 등에서 첫 프레임 렌더링 시 크기가 0으로 잡혀 검은 화면이 되는 현상 방지
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

        home: StreamBuilder<User?>(
          stream: userChanges ?? FirebaseAuth.instance.userChanges(),
          builder: (context, snapshot) {
            // Firebase 로그인 상태 확인 중
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // 로그인된 사용자
            if (snapshot.hasData && snapshot.data != null) {
              final user = snapshot.data!;

              // Google 로그인 후 필수 정보가 없다면 회원가입 계속 진행
              if (user.displayName == null) {
                return const RegisterScreen(isGoogleSignIn: true);
              }

              // 로그인 완료 → 홈 화면
              return const Home();
            }

            // 로그인 안 된 경우
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
