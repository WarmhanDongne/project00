import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/widgets/phone_result_dialog.dart';

void main() {
  const dialog = PhoneResultDialog(nickname: '민수', profileImageUrl: '');

  /// 게임 화면 라우트를 하나 띄우고, 그 라우트의 context를 돌려줍니다.
  ///
  /// `Navigator.maybePop()`은 PopScope가 막아도 '처리했다'는 뜻으로 true를
  /// 돌려주므로 반환값으로는 판단할 수 없습니다. 화면에 무엇이 남아 있는지로만
  /// 확인합니다.
  Future<BuildContext> openGameScreen(WidgetTester tester, Widget body) async {
    late BuildContext gameContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (homeContext) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(homeContext).push(
                  MaterialPageRoute<void>(
                    builder: (routeContext) {
                      gameContext = routeContext;
                      return Scaffold(body: body);
                    },
                  ),
                ),
                child: const Text('방 대기 화면'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('방 대기 화면'));
    await tester.pumpAndSettle();
    return gameContext;
  }

  //=======================호스트 라우트를 잠그지 않는다==============================
  // 결과를 별도 라우트에 띄우는 게임(라이어스포커)과 게임 화면 안에 그대로
  // 그리는 게임(파이널콜)이 같은 위젯을 씁니다. 이 위젯이 PopScope를 직접 들고
  // 있으면 후자에서는 게임 라우트가 잠겨, 태블릿이 결과 화면에서 HOME을 눌러도
  // 휴대폰이 Navigator.maybePop()으로 나가지 못했습니다.
  testWidgets('화면에 직접 그려도 게임 화면을 나갈 수 있다', (tester) async {
    final gameContext = await openGameScreen(tester, dialog);
    expect(find.text('민수'), findsOneWidget);

    // 태블릿이 게임을 끝냈을 때 휴대폰이 하는 일과 같습니다.
    await Navigator.of(gameContext).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('민수'), findsNothing);
    expect(find.text('방 대기 화면'), findsOneWidget);
  });

  //=======================막는 책임은 띄우는 쪽에 있다==============================
  // 뒤로 가기 차단은 위젯이 아니라 호출부가 정합니다. 라이어스포커는
  // showDialog에서 PopScope로 감싸므로 우승자 발표가 그대로 유지되어야 합니다.
  testWidgets('PopScope로 감싸면 그 라우트만 뒤로 가기가 막힌다', (tester) async {
    final gameContext = await openGameScreen(
      tester,
      const PopScope(canPop: false, child: dialog),
    );
    expect(find.text('민수'), findsOneWidget);

    await Navigator.of(gameContext).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('민수'), findsOneWidget);
    expect(find.text('방 대기 화면'), findsNothing);
  });
}
