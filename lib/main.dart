import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Google Sign-In SDK 패키지
import 'package:project00/core/app/app.dart';
import 'package:project00/core/sound/provider.dart/sound_provider.dart';
import 'package:project00/firebase/firebase_options.dart';
import 'package:provider/provider.dart';

void main() async {
  // 1. Flutter 프레임워크 코어와 네이티브 엔진 바인딩 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();

  //=======================플랫폼 기본 방향==============================
  // 게임이 직접 방향을 변경하기 전까지 모든 플랫폼 화면은 세로입니다.
  await AppOrientation.lockPlatformPortrait();

  // 2. Firebase 네이티브 SDK 인스턴스 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Google Sign-In SDK 초기화 및 Client ID 주입 (최신 API 필수 전제 조건)
  // firebase_options.dart에 구조화된 iOS Client ID를 메모리에 로드합니다.
  await GoogleSignIn.instance.initialize(
    clientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
  );

  final soundProvider = SoundProvider();
  runApp(
    ProviderScope(
      child: ChangeNotifierProvider.value(
        value: soundProvider,
        child: const App(),
      ),
    ),
  );

  // 네이티브 오디오 플러그인이 첫 화면 렌더링을 막지 않도록
  // 첫 프레임이 그려진 뒤 사운드를 초기화합니다.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(soundProvider.initialize());
  });
}
