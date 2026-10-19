import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/generated/l10n/app_localizations.dart';
import 'package:project00/platform/auth/screens/login_screen.dart';
import 'package:project00/platform/auth/services/auth_service.dart';

void main() {
  test('재설정 메일은 Firebase Auth를 사용하고 계정 존재 여부를 노출하지 않는다', () async {
    final auth = _ResetAuth();
    final service = FirebaseAuthService(
      auth: auth,
      functions: _Functions(),
      storage: _Storage(),
    );

    await service.sendPasswordResetEmail(email: 'member@example.com');
    expect(auth.emails, ['member@example.com']);

    auth.failure = FirebaseAuthException(code: 'user-not-found');
    await service.sendPasswordResetEmail(email: 'unknown@example.com');
    expect(auth.emails, ['member@example.com', 'unknown@example.com']);

    auth.failure = FirebaseAuthException(code: 'network-request-failed');
    await expectLater(
      service.sendPasswordResetEmail(email: 'member@example.com'),
      throwsA(
        isA<AuthServiceException>().having(
          (error) => error.code,
          'code',
          'network-request-failed',
        ),
      ),
    );
  });

  for (final (locale, forgot, title) in [
    (const Locale('ko'), '비밀번호를 잊으셨나요?', '비밀번호 재설정'),
    (const Locale('en'), 'Forgot your password?', 'Reset password'),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      '忘记密码？',
      '重置密码',
    ),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      '忘記密碼？',
      '重設密碼',
    ),
  ]) {
    testWidgets('$locale 로그인 카드에서 재설정 요소로 교체된다', (tester) async {
      final service = _ResetService();
      await _pumpLogin(tester, service: service, locale: locale);

      expect(find.text(forgot), findsOneWidget);
      await tester.tap(find.byKey(const Key('forgot-password-button')));
      await _finishAuthTransition(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(
        find.byKey(const Key('send-password-reset-button')),
        findsOneWidget,
      );
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(390, 844), const Size(1194, 834)]) {
    testWidgets('메일 발송·중복 방지·재전송·로그인 복귀가 작동한다 ($size)', (tester) async {
      final service = _ResetService();
      await _pumpLogin(tester, service: service, size: size);
      await tester.enterText(
        find.byKey(const Key('email-local-field')),
        'member',
      );
      await tester.tap(find.byKey(const Key('forgot-password-button')));
      await _finishAuthTransition(tester);

      final send = find.byKey(const Key('send-password-reset-button'));
      await tester.tap(send);
      await tester.pump();
      await tester.tap(send, warnIfMissed: false);
      expect(service.emails, ['member@gmail.com']);
      expect(tester.widget<MosiButton>(send).onPressed, isNull);

      service.completeCurrent();
      await tester.pump();
      await _finishAuthTransition(tester);
      expect(find.text('메일을 보냈습니다'), findsOneWidget);
      expect(find.text('member@gmail.com'), findsOneWidget);

      await tester.tap(send);
      await tester.pump();
      expect(service.emails, ['member@gmail.com', 'member@gmail.com']);
      service.completeCurrent();
      await _finishAuthTransition(tester);

      await tester.tap(find.byKey(const Key('back-to-login-button')));
      await _finishAuthTransition(tester);
      expect(find.text('로그인'), findsNWidgets(2));
      final emailField = tester.widget<TextField>(
        find.byKey(const Key('email-local-field')),
      );
      expect(emailField.controller?.text, 'member');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('잘못된 이메일과 Firebase 오류를 같은 카드에서 안내한다', (tester) async {
    final service = _ResetService();
    await _pumpLogin(tester, service: service);
    await tester.tap(find.byKey(const Key('forgot-password-button')));
    await _finishAuthTransition(tester);

    final send = find.byKey(const Key('send-password-reset-button'));
    await tester.tap(send);
    await tester.pump();
    expect(find.text('이메일 형식이 올바르지 않습니다.'), findsOneWidget);
    expect(service.emails, isEmpty);

    await tester.enterText(
      find.byKey(const Key('email-local-field')),
      'member',
    );
    service.nextError = const AuthServiceException(
      'too-many-requests',
      'raw firebase message',
    );
    await tester.tap(send);
    await tester.pump();
    expect(find.text('요청이 많습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('raw firebase message'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _finishAuthTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  required _ResetService service,
  Locale locale = const Locale('ko'),
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginScreen(authService: service),
    ),
  );
  await tester.pump();
}

class _ResetService extends FirebaseAuthService {
  _ResetService()
    : super(auth: _ResetAuth(), functions: _Functions(), storage: _Storage());

  final emails = <String>[];
  Completer<void>? _pending;
  AuthServiceException? nextError;

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    emails.add(email);
    final error = nextError;
    nextError = null;
    if (error != null) return Future<void>.error(error);
    _pending = Completer<void>();
    return _pending!.future;
  }

  void completeCurrent() => _pending!.complete();
}

class _ResetAuth implements FirebaseAuth {
  final emails = <String>[];
  FirebaseAuthException? failure;

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    emails.add(email);
    final currentFailure = failure;
    failure = null;
    if (currentFailure != null) throw currentFailure;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Functions implements FirebaseFunctions {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements FirebaseStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
