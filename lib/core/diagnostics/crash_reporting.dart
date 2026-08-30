import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:project00/core/diagnostics/dev_error_log.dart';

//=======================오류 수집==============================
/// 앱에서 나는 오류를 한곳에서 받습니다.
///
/// | 빌드 | 하는 일 |
/// |---|---|
/// | 디버그(개발) | 개인정보 없는 구조화 로그를 콘솔·ADB에 남기고 [DevErrorLog]에 쌓습니다. 화면·Crashlytics에는 보내지 않습니다 |
/// | 릴리스 | Crashlytics로 보냅니다 |
///
/// 받는 경로는 세 가지입니다.
///
/// 1. [FlutterError.onError] — 위젯 빌드·레이아웃·그리기 중 오류
/// 2. [PlatformDispatcher.onError] — `await` 없이 흘린 비동기 오류
/// 3. [recordError] — 직접 잡아서 알리고 싶은 오류
///
/// 개발 중에 Crashlytics로 보내지 않는 이유는, 개발 오류가 실제 사용자 오류와
/// 섞이면 정작 출시 뒤 문제를 찾기 어려워지기 때문입니다.
abstract final class CrashReporting {
  /// 앱 시작 때 한 번 부릅니다. Firebase 초기화 **뒤**에 불러야 합니다.
  static Future<void> initialize() async {
    final crashlytics = FirebaseCrashlytics.instance;
    // 개발 중 오류는 보내지 않습니다.
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    // 1. 위젯·프레임워크 오류
    FlutterError.onError = (details) {
      DevErrorLog.instance.add(
        error: details.exceptionAsString(),
        stack: details.stack,
        context: details.library ?? '프레임워크',
        time: DateTime.now(),
      );
      if (!kDebugMode) crashlytics.recordFlutterFatalError(details);
    };

    // 2. 놓친 비동기 오류(`unawaited`로 흘린 Future 등)
    PlatformDispatcher.instance.onError = (error, stack) {
      DevErrorLog.instance.add(
        error: error,
        stack: stack,
        context: '비동기',
        time: DateTime.now(),
      );
      if (kDebugMode) {
        // DevErrorLog.add가 원문 없이 구조화된 한 줄을 출력합니다.
      } else {
        unawaited(crashlytics.recordError(error, stack, fatal: true));
      }
      // true를 돌려주면 앱이 죽지 않고 계속 돕니다.
      return true;
    };

    // 누가 겪은 오류인지 알면 재현이 쉬워집니다(닉네임·이메일은 보내지 않습니다).
    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) {
      unawaited(crashlytics.setUserIdentifier(user?.uid ?? ''));
    });
  }

  static StreamSubscription<User?>? _authSubscription;

  /// 직접 잡은 오류를 알립니다.
  ///
  /// [fatal]이 false면 앱은 계속 돌지만 기록은 남습니다(예: 서버 호출 실패).
  static void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    DevErrorLog.instance.add(
      error: error,
      stack: stack,
      context: reason ?? '직접 기록',
      time: DateTime.now(),
    );
    if (kDebugMode) {
      // DevErrorLog.add가 원문 없이 구조화된 한 줄을 출력합니다.
      return;
    }
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      ),
    );
  }

  /// 오류가 났을 때 함께 보고 싶은 진행 기록을 남깁니다.
  ///
  /// 예: `CrashReporting.log('마피아 밤 제출: 방 ABCD')`. 크래시 리포트에
  /// 마지막 동작들이 함께 붙어 재현 경로를 알 수 있습니다.
  static void log(String message) {
    if (kDebugMode) {
      debugPrint('기록: $message');
      return;
    }
    unawaited(FirebaseCrashlytics.instance.log(message));
  }
}
