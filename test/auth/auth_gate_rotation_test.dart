import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/models/onboarding_state.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/widgets/auth_gate.dart';

//=======================회전 크래시 회귀 방지==============================
// 실기기에서 잡은 버그입니다. 로그인 뒤 화면을 회전하면
// `Bad state: Stream has already been listened to.`로 앱이 터졌습니다.
//
// 원인은 두 겹이었습니다.
//   1. 온보딩 스트림(async*)은 **한 번만** 들을 수 있는데 AuthGate가 캐시함
//   2. 로그인 스트림을 빌드마다 새로 만들어, 회전 리빌드 때 구독이 갈리며
//      화면이 스피너로 접혔다 펴짐 → 그 과정에서 캐시된 스트림을 두 번째 listen
//
// 이 테스트는 그 회전 상황을 그대로 흉내 냅니다: 부모가 리빌드마다 **새 로그인
// 스트림 인스턴스**를 넘기고(수정 전 fallback과 같은 동작), 화면 크기도
// 세로↔가로로 바꿉니다. 온보딩 스트림은 실제와 같은 단일 구독이며, 두 번째
// listen이 일어나면 그 자리에서 터져 테스트가 실패합니다.

class _FakeUser implements User {
  @override
  String get uid => 'tester';

  @override
  String? get email => 'tester@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 실제 서비스처럼 **단일 구독** 스트림을 돌려줍니다. listen 횟수를 셉니다.
class _SingleSubscriptionOnboardingService implements OnboardingService {
  int watchCallCount = 0;
  int listenCount = 0;

  @override
  Stream<UserOnboarding?> watch(String uid) {
    watchCallCount += 1;
    final controller = StreamController<UserOnboarding?>(); // 단일 구독
    controller.onListen = () {
      listenCount += 1;
      // 실제 흐름처럼 값은 이벤트 루프 다음 순번에 도착합니다.
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          // null → 복구 화면으로 이어지는 가장 가벼운 경로를 씁니다.
          controller.add(null);
        }
      });
    };
    return controller.stream;
  }

  @override
  Future<OnboardingStatus> recoverLegacy() {
    // 복구가 끝나지 않은 상태로 두어 가벼운 대기 화면에 머무릅니다.
    return Completer<OnboardingStatus>().future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 리빌드할 때마다 **새 로그인 스트림 인스턴스**를 AuthGate에 넘기는 부모입니다.
/// 수정 전 코드의 `FirebaseAuth...userChanges()` fallback이 정확히 이렇게
/// 동작했습니다.
class _RotatingHost extends StatefulWidget {
  const _RotatingHost({super.key, required this.service});

  final OnboardingService service;

  @override
  State<_RotatingHost> createState() => _RotatingHostState();
}

class _RotatingHostState extends State<_RotatingHost> {
  final List<StreamController<User?>> _controllers = [];

  Stream<User?> _newUserStream() {
    final controller = StreamController<User?>.broadcast();
    _controllers.add(controller);
    return controller.stream;
  }

  /// 모든 스트림에 로그인 상태를 흘립니다. AuthGate가 어느 것을 듣고 있든
  /// 로그인 사용자를 받게 됩니다.
  void emitUser() {
    for (final controller in _controllers) {
      controller.add(_FakeUser());
    }
  }

  void rebuildWithNewStream() => setState(() {});

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthGate(
        // 리빌드마다 다른 인스턴스가 넘어옵니다(회전 리빌드 흉내).
        userChanges: _newUserStream(),
        onboardingService: widget.service,
      ),
    );
  }
}

void main() {
  testWidgets('로그인 뒤 회전을 반복해도 온보딩 스트림을 두 번 듣지 않는다', (tester) async {
    final service = _SingleSubscriptionOnboardingService();
    final hostKey = GlobalKey<_RotatingHostState>();

    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_RotatingHost(key: hostKey, service: service));
    hostKey.currentState!.emitUser();
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '로그인 직후 예외');
    expect(service.listenCount, 1);

    // 회전을 다섯 번 반복합니다. 매번 부모가 새 로그인 스트림으로 리빌드하고
    // (수정 전 fallback과 동일), 화면 크기도 세로↔가로로 바뀝니다.
    for (var round = 0; round < 5; round += 1) {
      final landscape = round.isEven;
      tester.view.physicalSize = landscape
          ? const Size(844 * 3, 390 * 3)
          : const Size(390 * 3, 844 * 3);
      hostKey.currentState!.rebuildWithNewStream();
      await tester.pump();
      hostKey.currentState!.emitUser();
      await tester.pump();
      await tester.pump();

      final thrown = tester.takeException();
      expect(thrown, isNull, reason: '회전 ${round + 1}번째에서 터졌습니다: $thrown');
    }

    // 온보딩 구독은 처음 것 하나로 충분해야 합니다. 회전마다 다시 듣는다면
    // 단일 구독 스트림에서 즉시 터지거나 이 숫자가 늘어납니다.
    expect(service.watchCallCount, 1, reason: '회전마다 온보딩을 다시 구독했습니다');
    expect(service.listenCount, 1);
  });
}
