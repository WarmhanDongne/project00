import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore 추가
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/auth/screens/login_screen.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/core/layout/device_layout.dart';
import 'package:project00/platform/home/home.dart';

class App extends StatelessWidget {
  const App({super.key, this.userChanges});
  final Stream<User?>? userChanges;

  @override
  Widget build(BuildContext context) {
    // 화면 크기 구하기
    final view = View.of(context);
    final size = view.physicalSize / view.devicePixelRatio;

    // 테블릿, 폰 분기
    final isTablet = size.shortestSide >= DeviceLayout.tabletBreakpoint;
    final Size currentDesignSize = isTablet
        ? const Size(834, 1194) // 테블릿 기본 사이즈
        : const Size(390, 844); // 핸드폰 기본 사이즈

    return ScreenUtilInit(
      ensureScreenSize: true, // android 환경 등에서 프레임 사이즈가 초기에 0이 되는 걸 방지
      designSize: currentDesignSize,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Project 00',
        home: StreamBuilder<User?>(
          stream: userChanges ?? FirebaseAuth.instance.userChanges(),
          builder: (context, snapshot) {
            // 1. Firebase Auth 상태 로딩 중
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // 2. Auth에 로그인된 유저 정보가 있는 경우
            if (snapshot.hasData && snapshot.data != null) {
              final user = snapshot.data!;

              // 🔥 핵심 변경 부분: Firebase Auth 대신 Firestore의 users 컬렉션 확인
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get(),
                builder: (context, userDocSnapshot) {
                  // Firestore 데이터 로딩 중
                  if (userDocSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  // Firestore에 문서가 없거나, 닉네임 데이터가 없으면 닉네임 설정 화면으로 연결
                  final userData =
                      userDocSnapshot.data?.data() as Map<String, dynamic>?;

                  if (!userDocSnapshot.hasData ||
                      !userDocSnapshot.data!.exists ||
                      userData == null ||
                      userData['nickname'] == null ||
                      userData['nickname'].toString().trim().isEmpty) {
                    return const RegisterScreen(isGoogleSignIn: true);
                  }

                  // DB에 유저 문서와 닉네임이 모두 존재하면 홈 화면으로 이동
                  return const Home();
                },
              );
            }

            // 3. 로그인되지 않은 상태
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
