import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/widgets/register_step_one.dart';
import 'package:project00/platform/auth/widgets/register_step_two.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

//=======================태블릿 회원가입·로그인 동등성 (T-03)==============================
// 인증 화면에는 기기 분기가 없습니다. home.dart의 DeviceLayout.isTablet만
// 태블릿·휴대폰을 가르고, login/register/profile_setup은 세 기기가 같은 위젯을
// 씁니다. 그래서 "태블릿에 기능이 빠졌다"는 코드 수준에서는 일어날 수 없습니다.
//
// 실제 위험은 **레이아웃**입니다. 태블릿은 가로가 훨씬 넓고 세로도 깁니다.
// 폼이 화면 폭을 따라 늘어나면 입력란이 한 줄로 길게 퍼져 쓰기 어려워지고,
// 가로 모드에서는 세로 공간이 좁아 넘칠 수 있습니다. 이 시험이 그 두 가지를
// 고정합니다. 실기기 검증은 work-items/13-t-03-manual-test.md가 담당합니다.

void main() {
  /// 태블릿 가로·세로와 휴대폰을 모두 돌립니다.
  const sizes = <String, Size>{
    '휴대폰 세로': Size(390, 844),
    '태블릿 세로': Size(834, 1194),
    '태블릿 가로': Size(1194, 834),
    '큰 태블릿 가로': Size(1366, 1024),
  };

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    Widget child, {
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: PlatformTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
    await tester.pump();
  }

  Widget stepOne({
    required RegisterStep step,
    required List<TextEditingController> controllers,
    required FocusNode focusNode,
  }) {
    return PlatformAuthShell(
      maxWidth: 390,
      child: RegisterStepOne(
        emailController: controllers[0],
        customDomainController: controllers[1],
        customDomainFocusNode: focusNode,
        passwordController: controllers[2],
        confirmPasswordController: controllers[3],
        emailDomain: 'gmail.com',
        isCustomDomain: false,
        step: step,
        action: null,
        cooldownSeconds: 0,
        onDomainChanged: (_) {},
        onSendEmail: () {},
        onResendEmail: () {},
        onSetPassword: () {},
      ),
    );
  }

  (List<TextEditingController>, FocusNode) makeControllers() {
    final controllers = List.generate(4, (_) => TextEditingController());
    final focusNode = FocusNode();
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
      focusNode.dispose();
    });
    controllers[0].text = 'msg@gmail.com';
    return (controllers, focusNode);
  }

  for (final entry in sizes.entries) {
    testWidgets('${entry.key}에서 이메일 입력 단계가 넘치지 않는다', (tester) async {
      final (controllers, focusNode) = makeControllers();
      await pumpAt(
        tester,
        entry.value,
        stepOne(
          step: RegisterStep.emailInput,
          controllers: controllers,
          focusNode: focusNode,
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('${entry.key}에서 비밀번호 단계가 넘치지 않는다', (tester) async {
      final (controllers, focusNode) = makeControllers();
      await pumpAt(
        tester,
        entry.value,
        stepOne(
          step: RegisterStep.settingPassword,
          controllers: controllers,
          focusNode: focusNode,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('태블릿에서도 비밀번호 정책 안내가 그대로 나온다', (tester) async {
    // 휴대폰과 같은 위젯이므로 항목 수가 같아야 합니다. 하나라도 기기 분기가
    // 생기면 여기서 걸립니다.
    final (controllers, focusNode) = makeControllers();
    await pumpAt(
      tester,
      const Size(1194, 834),
      stepOne(
        step: RegisterStep.settingPassword,
        controllers: controllers,
        focusNode: focusNode,
      ),
    );

    await tester.enterText(find.byType(TextField).at(1), 'Abcdef1!');
    await tester.enterText(find.byType(TextField).at(2), 'Abcdef1!');
    await tester.pump();

    expect(find.byIcon(Icons.check_rounded), findsNWidgets(5));
    expect(find.widgetWithText(FilledButton, '다음'), findsOneWidget);
  });

  testWidgets('넓은 화면에서도 폼이 가로로 늘어나지 않는다', (tester) async {
    // 입력란이 1366px를 가득 채우면 한 줄이 지나치게 길어 쓰기 어렵습니다.
    // PlatformAuthShell의 maxWidth가 그것을 막습니다.
    final (controllers, focusNode) = makeControllers();
    await pumpAt(
      tester,
      const Size(1366, 1024),
      stepOne(
        step: RegisterStep.emailInput,
        controllers: controllers,
        focusNode: focusNode,
      ),
    );

    final field = tester.getRect(find.byType(TextField).first);
    expect(field.width, lessThanOrEqualTo(390));
  });

  testWidgets('태블릿 가로에서 프로필 단계가 넘치지 않는다', (tester) async {
    final nickname = TextEditingController(text: '테스트');
    addTearDown(nickname.dispose);

    await pumpAt(
      tester,
      const Size(1194, 834),
      PlatformAuthShell(
        maxWidth: 390,
        child: RegisterStepTwo(
          nicknameController: nickname,
          isLoading: false,
          googlePhotoURL: null,
          profileImageBytes: null,
          onPickProfileImage: () {},
          onCheckNickname: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('사진 설정'), findsOneWidget);
  });

  testWidgets('태블릿 가로 + 큰 글자에서도 넘치지 않는다', (tester) async {
    // 세로 공간이 가장 좁은 조합입니다. 넘치면 스크롤로 흡수해야 합니다.
    final (controllers, focusNode) = makeControllers();
    await pumpAt(
      tester,
      const Size(1194, 834),
      stepOne(
        step: RegisterStep.settingPassword,
        controllers: controllers,
        focusNode: focusNode,
      ),
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
  });
}
