import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/widgets/platform_components.dart';

void main() {
  testWidgets('Google 로그인 버튼에 로고 에셋을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformButton(
            label: 'Google 로그인',
            style: PlatformButtonStyle.secondary,
            leading: SvgPicture.asset(
              'assets/images/button/google_g_logo.svg',
              width: 20,
              height: 20,
            ),
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Google 로그인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
