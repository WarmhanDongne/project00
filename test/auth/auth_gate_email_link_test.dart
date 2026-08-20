import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/widgets/auth_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('실행 중 이메일 링크는 push된 화면을 닫고 인증 로딩을 보여준다', (
    tester,
  ) async {
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
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('cover'))),
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

    expect(find.text('cover'), findsNothing);
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

class _PendingEmailLinkService implements OnboardingService {
  final Completer<void> _completion = Completer<void>();

  @override
  bool isEmailSignInLink(String link) => true;

  @override
  Future<void> completeEmailLink({
    required String email,
    required String link,
  }) => _completion.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
