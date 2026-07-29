import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:project00/platform/auth/screens/login_screen.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/hub/screens/home.dart';

class App extends StatelessWidget {
  const App({super.key, this.authStateChanges});

  final Stream<User?>? authStateChanges;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;

        final Size currentDesignSize = isTablet
            ? const Size(834, 1194) // 테블릿
            : const Size(390, 844); // 핸드폰

        return ScreenUtilInit(
          designSize: currentDesignSize,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Project 00',

            home: StreamBuilder<User?>(
              stream:
                  authStateChanges ?? FirebaseAuth.instance.authStateChanges(),
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
                  if (user.phoneNumber == null || user.displayName == null) {
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
      },
    );
  }
}
