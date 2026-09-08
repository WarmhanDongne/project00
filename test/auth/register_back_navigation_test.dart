import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/services/pending_email_store.dart';

void main() {
  testWidgets('email input app back asks before leaving registration', (
    tester,
  ) async {
    var cancelled = 0;
    await _pumpRegisterRoute(tester, onCancel: () => cancelled += 1);
    await tester.enterText(find.byType(TextField).first, 'tester');

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('회원가입을 중단할까요?'), findsOneWidget);
    expect(find.text('입력한 내용은 저장되지 않습니다.'), findsOneWidget);

    await tester.tap(find.text('계속하기'));
    await tester.pumpAndSettle();
    expect(find.text('회원가입'), findsOneWidget);
    expect(find.text('tester'), findsOneWidget);
    expect(cancelled, 0);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('중단하기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-root')), findsOneWidget);
    expect(find.text('회원가입'), findsNothing);
    expect(cancelled, 1);
  });

  testWidgets('Android system back uses the same registration confirmation', (
    tester,
  ) async {
    var cancelled = 0;
    await _pumpRegisterRoute(tester, onCancel: () => cancelled += 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('회원가입을 중단할까요?'), findsOneWidget);
    expect(find.text('회원가입'), findsOneWidget);

    await tester.tap(find.text('중단하기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-root')), findsOneWidget);
    expect(find.text('회원가입'), findsNothing);
    expect(cancelled, 1);
  });
}

Future<void> _pumpRegisterRoute(
  WidgetTester tester, {
  required VoidCallback onCancel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          key: const Key('login-root'),
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => RegisterScreen(
                  onboardingService: _NoopOnboardingService(),
                  pendingEmailStore: _NoopPendingEmailStore(),
                  onCancel: onCancel,
                ),
              ),
            ),
            child: const Text('회원가입 열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('회원가입 열기'));
  await tester.pumpAndSettle();
  expect(find.text('회원가입'), findsOneWidget);
}

class _NoopOnboardingService implements OnboardingService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopPendingEmailStore implements PendingEmailStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
