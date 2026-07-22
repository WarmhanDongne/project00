import 'package:flutter/material.dart';
// Firebase 연동을 위한 코어 패키지
import 'package:firebase_core/firebase_core.dart';
// flutterfire configure로 생성된 플랫폼별 설정 파일
import 'firebase_options.dart';

void main() async {
  // 1. Flutter 프레임워크 코어와 네이티브 엔진 바인딩 초기화 보장
  // 네이티브 채널(MethodChannel)을 사용하기 위한 필수 전제 조건입니다.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 플랫폼별 환경 설정(firebase_options.dart)을 주입하여 Firebase 네이티브 SDK 인스턴스 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Login Auth',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Scaffold(
        body: Center(child: Text('Firebase SDK Initialized')),
      ),
    );
  }
}
