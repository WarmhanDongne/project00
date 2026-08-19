import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
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

    await tester.tap(find.text('앨범열기'));
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
          cooldownSeconds: 300,
          onDomainChanged: (_) {},
          onSendEmail: () {},
          onResendEmail: () {},
          onSetPassword: () {},
        ),
      ),
    ),
  );
}
