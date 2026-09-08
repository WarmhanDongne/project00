import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/models/onboarding_state.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/widgets/auth_gate.dart';

//=======================끝나지 않는 로딩 막기==============================
// 2026-08-22 실기기에서 앱이 스피너에서 멈춰 아무것도 못 하는 일이 있었습니다.
// 애플로 로그인한 계정의 온보딩 값을 앱이 읽지 못해, 복구 화면과 스피너를
// 오가며 갇혔습니다.
//
// 값을 못 읽던 원인은 따로 고쳤지만(`onboarding_parity_test.dart`), **어떤
// 이유로든 스피너가 영원히 돌지 않아야** 합니다. 8초가 지나면 다시 시도할
// 화면으로 넘어갑니다.
void main() {
  testWidgets('회원가입 상태가 오지 않으면 다시 시도 화면으로 넘어간다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          userChanges: Stream<User?>.value(_FakeUser()),
          onboardingService: _SilentOnboardingService(),
          onAuthRestoreTimeout: () {},
        ),
      ),
    );
    await tester.pump();

    // 처음에는 스피너입니다.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 3초가 지나면 무엇을 기다리는지 알려 줍니다.
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('회원가입 상태 확인'), findsOneWidget);

    // 8초가 지나면 다시 시도할 수 있는 화면으로 바뀝니다.
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.textContaining('회원가입 상태를 불러오지 못했습니다'), findsOneWidget);
  });

  testWidgets('회원가입 상태가 제때 오면 스피너가 지나간다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          userChanges: Stream<User?>.value(_FakeUser()),
          onboardingService: _SilentOnboardingService(
            state: const UserOnboarding(
              uid: 'u1',
              // 프로필 설정 화면은 Firebase 앱이 필요해 시험에서 못 그립니다.
              // 여기서 확인할 것은 목적지가 아니라 **스피너를 벗어나는지**입니다.
              status: OnboardingStatus.settingPassword,
              // 애플 로그인이 쓰는 값입니다. 앱이 이 값을 읽지 못해 갇혔습니다.
              provider: OnboardingProvider.apple,
            ),
          ),
          onAuthRestoreTimeout: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);

    // 시간이 더 흘러도 다시 시도 화면으로 떨어지지 않습니다.
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('로그인 복원이 멈추면 저장된 세션을 비운다', (tester) async {
    // 앱 번들 id·서명 팀이 바뀐 뒤 키체인 세션을 못 읽으면 스트림이 아무 값도
    // 주지 않습니다. 그때는 세션을 비워 로그인 화면으로 되돌립니다.
    var clearedSession = 0;
    // 값도 끝도 주지 않는 스트림 — 복원이 멈춘 기기와 같은 상태입니다.
    final stalled = StreamController<User?>();
    addTearDown(stalled.close);
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          userChanges: stalled.stream,
          onboardingService: _SilentOnboardingService(),
          onAuthRestoreTimeout: () => clearedSession += 1,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('로그인 상태 확인'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    expect(clearedSession, 1);
  });
}

/// 값을 주지 않거나(기본) 하나만 주는 가짜 온보딩 서비스입니다.
class _SilentOnboardingService implements OnboardingService {
  _SilentOnboardingService({this.state});

  final UserOnboarding? state;

  @override
  Stream<UserOnboarding?> watch(String uid) {
    final controller = StreamController<UserOnboarding?>();
    if (state != null) controller.add(state);
    return controller.stream;
  }

  @override
  bool isEmailSignInLink(String link) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeUser implements User {
  @override
  String get uid => 'u1';

  @override
  String? get email => 'kim@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
