import 'dart:async';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/core/layout/device_layout.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Google Sign-In SDK 패키지
import 'package:project00/core/app/app.dart';
import 'package:project00/core/diagnostics/crash_reporting.dart';
import 'package:project00/core/diagnostics/dev_error_overlay.dart';
import 'package:project00/core/sound/providers/sound_provider.dart';
import 'package:project00/firebase/firebase_options.dart';
import 'package:provider/provider.dart';

void main() async {
  // 1. Flutter 프레임워크 코어와 네이티브 엔진 바인딩 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();
  // 첫 프레임보다 먼저 만들어 콜드 스타트 이메일 링크를 놓치지 않습니다.
  final appLinks = AppLinks();

  //=======================플랫폼 기본 방향==============================
  // 게임이 직접 방향을 변경하기 전까지 플랫폼 화면은 휴대폰에서 세로,
  // 태블릿에서 가로입니다.
  //
  // 중요: runApp 전이나 첫 화면 initState에서 적용하면 안 됩니다. iOS scene이
  final view =
      PlatformDispatcher.instance.implicitView ??
      PlatformDispatcher.instance.views.firstOrNull;
  final physicalSize = view != null
      ? (view.physicalSize / view.devicePixelRatio)
      : const Size(390, 844);
  final isTablet = physicalSize.shortestSide >= DeviceLayout.tabletBreakpoint;
  // 2. Firebase 네이티브 SDK 인스턴스 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  //=======================오류 수집 시작==============================
  // Firebase 초기화 바로 뒤에 붙입니다. 이 뒤에 나는 위젯·비동기 오류는
  // 개발 중에는 화면(오른쪽 아래 빨간 표시)에서 보고, 릴리스에서는
  // Crashlytics로 올라갑니다.
  installDevErrorWidgetBuilder();
  await CrashReporting.initialize();
  Uri? initialEmailLink;
  try {
    initialEmailLink = await appLinks.getInitialLink();
  } catch (error, stack) {
    CrashReporting.recordError(error, stack, reason: '초기 이메일 링크 읽기');
  }

  //=======================서버 시각 보정 시작==============================
  // 턴 마감은 서버 시각 기준이므로, 기기 시계 오차·수동 변경·백그라운드 복귀에
  // 영향받지 않도록 서버와의 차이를 계속 추적합니다.
  ServerClock.start();

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
        child: App(
          emailLinks: appLinks.uriLinkStream,
          initialEmailLink: initialEmailLink,
        ),
      ),
    ),
  );

  //=======================iOS scene 연결 이후 초기 방향==============================
  _InitialOrientationApplier(isTablet: isTablet).start();

  //=======================첫 프레임 이후 네이티브 초기화==============================
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // 네이티브 오디오 플러그인이 첫 화면 렌더링을 막지 않도록 첫 프레임이
    // 그려진 뒤 사운드를 초기화합니다.
    unawaited(soundProvider.initialize());
  });
}

/// 앱 최초 화면 방향을 iOS scene이 활성화된 뒤 한 번만 적용합니다.
///
/// Flutter 첫 프레임은 `UIWindowScene`이 아직 unattached인 시점에도 만들어질 수
/// 있으므로 `addPostFrameCallback`만으로는 충분하지 않습니다. lifecycle의
/// `resumed`를 기준으로 해야 실제 창에 방향 요청이 전달됩니다.
class _InitialOrientationApplier with WidgetsBindingObserver {
  _InitialOrientationApplier({required this.isTablet});

  final bool isTablet;
  bool _completed = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _applyIfReady(WidgetsBinding.instance.lifecycleState);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _applyIfReady(state);
  }

  void _applyIfReady(AppLifecycleState? state) {
    if (_completed || state != AppLifecycleState.resumed) return;
    _completed = true;
    WidgetsBinding.instance.removeObserver(this);

    // scene 연결 전 요청이 남아 있어도 활성 scene에는 반드시 다시 전달합니다.
    AppOrientation.invalidate();
    unawaited(
      isTablet
          ? AppOrientation.lockPlatformLandscape()
          : AppOrientation.lockPlatformPortrait(),
    );
  }
}
