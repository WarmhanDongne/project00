import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Google Sign-In SDK 패키지
import 'package:project00/platform/app/app.dart';
import 'firebase_options.dart';

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

  runApp(const App());
}
