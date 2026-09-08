import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/screens/login_screen.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('로고와 문구를 함께 보여주고 탭하면 콜백이 실행된다', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      host(
        SocialLoginButton(
          label: 'Google 로그인',
          icon: const Icon(Icons.abc),
          enabled: true,
          onPressed: () => taps += 1,
        ),
      ),
    );

    expect(find.text('Google 로그인'), findsOneWidget);
    expect(find.byIcon(Icons.abc), findsOneWidget);

    await tester.tap(find.byType(SocialLoginButton));
    expect(taps, 1);
  });

  //=======================로그인 중에는 눌리지 않아야 합니다==============================
  // 두 번 눌러 인증이 두 번 시작되면 계정 연결이 꼬입니다. 화면은 isLoading으로
  // enabled를 내리는데, 그때 실제로 탭이 막히는지 확인합니다.
  testWidgets('비활성일 때는 탭해도 콜백이 실행되지 않는다', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      host(
        SocialLoginButton(
          label: 'Apple로 로그인',
          icon: const Icon(Icons.apple),
          enabled: false,
          onPressed: () => taps += 1,
        ),
      ),
    );

    await tester.tap(find.byType(SocialLoginButton), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('두 버튼의 높이와 모서리가 같다', (tester) async {
    await tester.pumpWidget(
      host(
        Column(
          children: [
            SocialLoginButton(
              label: 'Google 로그인',
              icon: const Icon(Icons.abc),
              enabled: true,
              onPressed: () {},
            ),
            SocialLoginButton(
              label: 'Apple로 로그인',
              icon: const Icon(Icons.apple),
              enabled: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    final sizes = tester
        .widgetList<SocialLoginButton>(find.byType(SocialLoginButton))
        .map((button) => tester.getSize(find.byWidget(button)))
        .toList();

    expect(sizes[0].height, 64);
    expect(sizes[0].height, sizes[1].height);
  });
}
