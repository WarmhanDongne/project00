import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project00/platform/auth/screens/login_screen.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Project 00',
      // Firebase Auth의 세션 상태 변경 이벤트 스트림 구독
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 비동기 파이프라인의 데이터 수신 대기 상태
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 검증된 유저 객체가 메모리에 할당된 경우 (인가 완료)
          if (snapshot.hasData && snapshot.data != null) {
            // 스트림에서 넘어온 유저 객체 할당
            final user = snapshot.data!;

            // 필수 정보 누락 여부 검증
            if (user.phoneNumber == null || user.displayName == null) {
              // 누락된 정보가 있다면 step2로 이동
              return const RegisterScreen(isGoogleSignIn: true);
            }
            return Scaffold(
              appBar: AppBar(
                title: const Text('Main Workspace'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    // 로그아웃 트리거 시 authStateChanges 스트림에 null이 push되어 LoginScreen으로 리다이렉트됨
                    onPressed: () => FirebaseAuth.instance.signOut(),
                  ),
                ],
              ),
              body: Center(
                child: Text('Authenticated UID: ${snapshot.data!.uid}'),
              ),
            );
          }

          // 유저 객체가 null인 경우 (미인증 상태)
          return const LoginScreen();
        },
      ),
    );
  }
}
