import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/models/password_policy.dart';
import 'package:project00/platform/auth/widgets/register_step_one.dart';
import 'package:project00/platform/auth/widgets/register_step_two.dart';
import 'package:project00/platform/theme/platform_theme.dart';

void main() {
  testWidgets('최초 메일 발송 중에는 인증 버튼에 로더 하나만 표시한다', (tester) async {
    await _pumpStep(
      tester,
      step: RegisterStep.emailInput,
      action: RegisterAction.sendEmail,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('인증 대기 중에는 안내 배너에 로더 하나만 표시한다', (tester) async {
    await _pumpStep(
      tester,
      step: RegisterStep.awaitingEmailLink,
      action: RegisterAction.completeLink,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('5분 재전송 안내 시간 중에도 즉시 재전송을 허용한다', (tester) async {
    var resendCalls = 0;
    await _pumpStep(
      tester,
      step: RegisterStep.awaitingEmailLink,
      action: null,
      cooldownSeconds: 300,
      onResendEmail: () => resendCalls++,
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('재전송'), findsOneWidget);
    expect(find.textContaining('재전송 가능'), findsOneWidget);

    await tester.tap(find.text('재전송'));
    expect(resendCalls, 1);
  });

  testWidgets('비밀번호 정책과 재입력 일치를 모두 충족해야 다음 버튼이 활성화된다', (tester) async {
    var setPasswordCalls = 0;
    await _pumpStep(
      tester,
      step: RegisterStep.settingPassword,
      action: null,
      onSetPassword: () => setPasswordCalls++,
    );

    FilledButton nextButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음'));

    expect(nextButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(1), 'Abcdef1');
    await tester.enterText(find.byType(TextField).at(2), 'Abcdef1');
    await tester.pump();
    expect(PasswordPolicy.isValid('Abcdef1'), isFalse);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(nextButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(1), 'Abcdef1!');
    await tester.enterText(find.byType(TextField).at(2), 'Abcdef1?');
    await tester.pump();
    expect(nextButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(2), 'Abcdef1!');
    await tester.pump();
    expect(PasswordPolicy.isValid('Abcdef1!'), isTrue);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(5));
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(nextButton().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    expect(setPasswordCalls, 1);
  });

  testWidgets('비밀번호와 비밀번호 확인의 눈 아이콘으로 표시 상태를 토글한다', (tester) async {
    await _pumpStep(tester, step: RegisterStep.settingPassword, action: null);
    await tester.enterText(find.byType(TextField).at(1), 'Abcdef1!');
    await tester.enterText(find.byType(TextField).at(2), 'Abcdef1!');

    TextField passwordField() =>
        tester.widget<TextField>(find.byType(TextField).at(1));
    TextField confirmationField() =>
        tester.widget<TextField>(find.byType(TextField).at(2));

    expect(passwordField().obscureText, isTrue);
    expect(confirmationField().obscureText, isTrue);

    await tester.tap(find.byTooltip('비밀번호 보기'));
    await tester.tap(find.byTooltip('비밀번호 확인 보기'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
    expect(confirmationField().obscureText, isFalse);

    await tester.tap(find.byTooltip('비밀번호 숨기기'));
    await tester.tap(find.byTooltip('비밀번호 확인 숨기기'));
    await tester.pump();
    expect(passwordField().obscureText, isTrue);
    expect(confirmationField().obscureText, isTrue);
  });

  testWidgets('프로필 작업 중에는 앨범과 키보드 완료 동작이 비활성화된다', (tester) async {
    final nickname = TextEditingController(text: '테스트');
    addTearDown(nickname.dispose);
    var albumCalls = 0;
    var completeCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: PlatformTheme.light(),
        home: Scaffold(
          body: RegisterStepTwo(
            nicknameController: nickname,
            isLoading: true,
            googlePhotoURL: null,
            profileImageBytes: null,
            onPickProfileImage: () => albumCalls++,
            onCheckNickname: () => completeCalls++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('사진 설정'));
    await tester.tap(find.byType(CircleAvatar));
    await tester.tap(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.done);

    expect(albumCalls, 0);
    expect(completeCalls, 0);
  });
}

Future<void> _pumpStep(
  WidgetTester tester, {
  required RegisterStep step,
  required RegisterAction? action,
  int cooldownSeconds = 300,
  VoidCallback? onResendEmail,
  VoidCallback? onSetPassword,
}) async {
  final email = TextEditingController(text: 'msg@gmail.com');
  final customDomain = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final focusNode = FocusNode();
  addTearDown(() {
    email.dispose();
    customDomain.dispose();
    password.dispose();
    confirmPassword.dispose();
    focusNode.dispose();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: PlatformTheme.light(),
      home: Scaffold(
        body: RegisterStepOne(
          emailController: email,
          customDomainController: customDomain,
          customDomainFocusNode: focusNode,
          passwordController: password,
          confirmPasswordController: confirmPassword,
          emailDomain: 'gmail.com',
          isCustomDomain: false,
          step: step,
          action: action,
          cooldownSeconds: cooldownSeconds,
          onDomainChanged: (_) {},
          onSendEmail: () {},
          onResendEmail: onResendEmail ?? () {},
          onSetPassword: onSetPassword ?? () {},
        ),
      ),
    ),
  );
}
