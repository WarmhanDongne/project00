import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/widgets/auth_design.dart';
import 'package:project00/platform/home/tablet/widgets/detail/game_detail_previews.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, files) in const [
      ('IBMPlexSansKR', ['IBMPlexSansKR-Regular', 'IBMPlexSansKR-Bold']),
      ('SpaceGrotesk', ['SpaceGrotesk-Bold']),
      ('PlayfairDisplay', ['PlayfairDisplay-Black']),
    ]) {
      final loader = FontLoader('packages/game_kit/$family');
      for (final file in files) {
        loader.addFont(
          rootBundle.load('packages/game_kit/assets/fonts/$file.ttf'),
        );
      }
      await loader.load();
    }
  });
  for (final width in [280.0, 390.0, 520.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('이메일 $width / $scale에서 선택·직접입력 블록 높이와 팝업 위치가 맞는다', (
        tester,
      ) async {
        final email = TextEditingController();
        final custom = TextEditingController();
        final focus = FocusNode();
        addTearDown(email.dispose);
        addTearDown(custom.dispose);
        addTearDown(focus.dispose);
        var domain = 'gmail.com';
        var customMode = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SizedBox(
                    width: width,
                    child: StatefulBuilder(
                      builder: (context, update) => MosiEmailField(
                        emailController: email,
                        customDomainController: custom,
                        customDomainFocusNode: focus,
                        emailDomain: domain,
                        isCustomDomain: customMode,
                        onDomainChanged: (value) => update(() {
                          customMode = value == 'custom';
                          if (!customMode) domain = value!;
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        void aligned() {
          final left = tester.getRect(
            find.byKey(const Key('email-local-field')),
          );
          final right = tester.getRect(
            find.byKey(const Key('email-domain-block')),
          );
          expect(left.top, right.top);
          expect(left.bottom, right.bottom);
          expect(right.left - left.right, 8);
        }

        aligned();
        final before = tester.getRect(
          find.byKey(const Key('email-domain-block')),
        );
        await tester.tap(find.byKey(const Key('email-domain-menu')));
        await tester.pumpAndSettle();
        final item = find.widgetWithText(PopupMenuItem<String>, '@naver.com');
        final popupRect = tester.getRect(item);
        expect(popupRect.width, closeTo(before.width, .1));
        expect(popupRect.left, closeTo(before.left, .1));
        expect(popupRect.top, greaterThan(before.bottom));
        await tester.tap(item);
        await tester.pumpAndSettle();
        expect(domain, 'naver.com');
        expect(find.text('@naver.com'), findsOneWidget);
        aligned();
        await tester.tap(find.byKey(const Key('email-domain-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(PopupMenuItem<String>, '직접 입력'));
        await tester.pumpAndSettle();
        aligned();
        await tester.enterText(
          find.byKey(const Key('email-custom-domain-field')),
          'example.org',
        );
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        // 목록을 여는 것만으로 저장된 도메인이 Gmail로 바뀌면 안 됩니다.
        expect(domain, 'naver.com');
        expect(custom.text, 'example.org');
        expect(customMode, isTrue);
        await tester.tap(
          find.widgetWithText(PopupMenuItem<String>, '@daum.net'),
        );
        await tester.pumpAndSettle();
        expect(domain, 'daum.net');
        expect(customMode, isFalse);
        aligned();
        await tester.enterText(
          find.byKey(const Key('email-local-field')),
          'name@other.org',
        );
        await tester.pump();
        expect(find.byKey(const Key('email-domain-block')), findsNothing);
        await tester.enterText(
          find.byKey(const Key('email-local-field')),
          'name',
        );
        await tester.pump();
        expect(find.text('@daum.net'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('비활성 직접 입력 도메인은 목록을 열거나 값을 바꾸지 않는다', (tester) async {
    final email = TextEditingController();
    final domain = TextEditingController(text: 'example.org');
    final focus = FocusNode();
    addTearDown(email.dispose);
    addTearDown(domain.dispose);
    addTearDown(focus.dispose);
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: MosiEmailField(
              emailController: email,
              customDomainController: domain,
              customDomainFocusNode: focus,
              emailDomain: 'naver.com',
              isCustomDomain: true,
              enabled: false,
              onDomainChanged: (_) => calls++,
            ),
          ),
        ),
      ),
    );
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    expect(calls, 0);
  });

  for (final game in ['liars_poker', 'final_call', 'mafia', 'holdem']) {
    testWidgets('$game 구성품이 패키지 원본 에셋을 표시하고 배치를 유지한다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 694,
                height: 560,
                child: GameDetailStage(child: buildGameParts(game)!),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      // 홀덤은 다운로드형 게임이라 로비 구성품을 에셋 없이 코드로 그립니다.
      expect(images, game == 'holdem' ? isEmpty : isNotEmpty);
      final names = <String>{};
      for (final image in images) {
        final asset = image.image as AssetImage;
        expect(asset.package, 'game_$game');
        expect(
          File('packages/${asset.package}/${asset.assetName}').existsSync(),
          isTrue,
          reason: asset.assetName,
        );
        expect(image.fit, BoxFit.contain);
        names.add(asset.assetName);
      }
      if (game == 'liars_poker') {
        for (final face in ['A', 'K', 'Q', 'Joker', 'back']) {
          expect(names.any((p) => p.endsWith('white $face.webp')), isTrue);
        }
        expect(names.any((p) => p.endsWith('button_fold.png')), isTrue);
      } else if (game == 'final_call') {
        for (final color in ['red', 'blue', 'yellow', 'green']) {
          for (var n = 1; n <= 10; n++) {
            expect(
              names.any((p) => p.endsWith('card_${color}_$n.webp')),
              isTrue,
            );
          }
        }
        expect(names.any((p) => p.endsWith('button_call.webp')), isTrue);
        expect(names.any((p) => p.endsWith('icon_heart_red.webp')), isTrue);
      } else if (game == 'holdem') {
        expect(find.bySemanticsLabel('카드 뒷면'), findsNWidgets(4));
        for (final suit in ['스페이드', '하트', '다이아', '클로버']) {
          expect(find.text(suit), findsOneWidget);
        }
        expect(find.bySemanticsLabel('스페이드 A'), findsWidgets);
        expect(find.bySemanticsLabel('Fold, Call, Raise 버튼'), findsOneWidget);
      } else {
        expect(names.where((p) => p.contains('/cards/role_')).length, 12);
        expect(names.any((p) => p.endsWith('role_mafia_boss.webp')), isTrue);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('홀덤 플레이 미리보기는 한 판을 반복하며 쇼다운까지 보여 준다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 694,
              height: 560,
              child: buildGamePlayPreview('holdem')!,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2400));
    expect(find.text('400 레이즈!'), findsOneWidget);
    expect(find.bySemanticsLabel('스페이드 K'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 5000));
    expect(find.text('WIN'), findsOneWidget);
    expect(find.text('POT 830'), findsOneWidget);
    // 10초 주기로 처음 장면으로 돌아옵니다.
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.text('POT 30'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
