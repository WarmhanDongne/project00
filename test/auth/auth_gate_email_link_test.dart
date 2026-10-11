import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/models/onboarding_state.dart';
import 'package:project00/platform/auth/services/pending_email_store.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/widgets/auth_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final coldStart in [true, false]) {
    testWidgets('이메일 링크 coldStart=$coldStart: 인증 중 로그인 이벤트가 와도 비밀번호로 진행한다', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'auth.pendingEmail': 'tester@example.com',
        'auth.emailLinkCooldownUntil': DateTime.now().millisecondsSinceEpoch,
      });
      final links = StreamController<Uri>.broadcast(sync: true);
      final users = StreamController<User?>.broadcast(sync: true);
      final service = _PendingEmailLinkService();
      final link = Uri.parse(
        'https://project0000-ec01e.firebaseapp.com/__/auth/links?mode=signIn&oobCode=test',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            userChanges: users.stream,
            emailLinks: links.stream,
            initialEmailLink: coldStart ? link : null,
            onboardingService: service,
          ),
        ),
      );
      // 링크 수신과 로그인 스트림의 초기 복원 순서 모두 지원합니다.
      if (!coldStart) links.add(link);
      users.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(service.calls, 1);
      expect(service.email, 'tester@example.com');
      links.add(link); // 처리 중 같은 링크가 다시 전달돼도 인증 한 번만.
      users.add(_User());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // signInWithEmailLink가 먼저 auth 이벤트를 보내고, callable이 늦게 완료됩니다.
      service._completion.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('비밀번호 재입력'), findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(service.calls, 1);
      expect(await PendingEmailStore().read(), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await links.close();
      await users.close();
    });
  }

  testWidgets('실행 중 이메일 링크는 push된 화면을 닫고 인증 로딩을 보여준다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.pendingEmail': 'tester@example.com',
      'auth.emailLinkCooldownUntil': DateTime.now()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
    });
    final emailLinks = StreamController<Uri>.broadcast(sync: true);
    final userChanges = StreamController<User?>.broadcast(sync: true);
    addTearDown(emailLinks.close);
    addTearDown(userChanges.close);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          userChanges: userChanges.stream,
          emailLinks: emailLinks.stream,
          onboardingService: _PendingEmailLinkService(),
        ),
      ),
    );
    await tester.pump();

    Navigator.of(tester.element(find.byType(AuthGate))).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('cover')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('cover'), findsOneWidget);

    emailLinks.add(
      Uri.parse(
        'https://project0000-ec01e.firebaseapp.com/__/auth/links'
        '?mode=signIn&oobCode=test-code',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    userChanges.add(null);
    await tester.pump();
    // The outgoing AuthGate view remains mounted for the 240ms card transition.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('cover'), findsNothing);
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

class _PendingEmailLinkService implements OnboardingService {
  final Completer<void> _completion = Completer<void>();
  int calls = 0;
  String? email;

  @override
  Stream<UserOnboarding?> watch(String uid) => Stream.value(
    UserOnboarding(
      uid: uid,
      status: OnboardingStatus.settingPassword,
      provider: OnboardingProvider.emailLink,
    ),
  );

  @override
  bool isEmailSignInLink(String link) => true;

  @override
  Future<void> completeEmailLink({
    required String email,
    required String link,
  }) {
    calls++;
    this.email = email;
    return _completion.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  @override
  String get uid => 'test';
  @override
  String? get email => 'tester@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
