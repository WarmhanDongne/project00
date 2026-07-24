import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Google Sign-In SDK 패키지
import 'firebase_options.dart';

// UI 바인딩을 위해 LoginScreen 경로를 Import 합니다. (패키지명 확인 요망)
import 'package:project00/platform/auth/screens/login_screen.dart';

void main() async {
  // 1. Flutter 프레임워크 코어와 네이티브 엔진 바인딩 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Firebase 네이티브 SDK 인스턴스 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Google Sign-In SDK 초기화 및 Client ID 주입 (최신 API 필수 전제 조건)
  // firebase_options.dart에 구조화된 iOS Client ID를 메모리에 로드합니다.
  await GoogleSignIn.instance.initialize(
    clientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Google Login Auth',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // AuthProvider와 바인딩된 LoginScreen 위젯을 초기 뷰로 마운트합니다.
      home: const LoginScreen(),
    );
  }
}
