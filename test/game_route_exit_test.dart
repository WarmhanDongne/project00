import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/widgets/game_route_exit.dart';

//=======================게임 화면 이탈==============================
// 서버가 게임을 비정상 종료했을 때 게임 화면을 확실히 닫는지 확인합니다.
// maybePop을 쓰던 시절에는 다이얼로그가 열려 있으면 그 다이얼로그만 닫히고
// 게임 화면에 갇혔습니다(호출부가 '한 번만 나간다' 플래그로 잠겨 재시도도
// 하지 않았습니다).

void main() {
  /// 홈 → 게임 화면 순으로 쌓은 앱을 띄우고, 게임 화면의 context를 돌려줍니다.
  Future<BuildContext> pumpGameRoute(WidgetTester tester) async {
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
                      return const Scaffold(body: Text('게임 화면'));
                    },
                  ),
                ),
                child: const Text('게임 시작'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('게임 시작'));
    await tester.pumpAndSettle();
    expect(find.text('게임 화면'), findsOneWidget);
    return gameContext;
  }

  testWidgets('다이얼로그가 없으면 게임 화면을 닫는다', (tester) async {
    final gameContext = await pumpGameRoute(tester);

    exitGameRoute(gameContext);
    await tester.pumpAndSettle();

    expect(find.text('게임 화면'), findsNothing);
    expect(find.text('게임 시작'), findsOneWidget);
  });

  testWidgets('같은 프레임의 두 종료 신호가 대기실을 제거하지 않는다', (tester) async {
    final gameContext = await pumpGameRoute(tester);
    exitGameRoute(gameContext);
    // pop 이후 퇴장 애니메이션 동안 context는 아직 mounted입니다.
    expect(gameContext.mounted, isTrue);
    exitGameRoute(gameContext);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('게임 시작'), findsOneWidget);
  });

  testWidgets('다른 종료 경로가 먼저 pop해도 늦은 종료가 홈을 닫지 않는다', (tester) async {
    final gameContext = await pumpGameRoute(tester);
    Navigator.of(gameContext).pop();
    exitGameRoute(gameContext);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('게임 시작'), findsOneWidget);
  });

  testWidgets('다이얼로그가 열려 있어도 다이얼로그와 게임 화면을 함께 닫는다', (tester) async {
    final gameContext = await pumpGameRoute(tester);

    // 설정·룰북처럼 게임 화면 위에 쌓이는 다이얼로그입니다.
    showDialog<void>(
      context: gameContext,
      builder: (_) => const AlertDialog(content: Text('설정')),
    );
    await tester.pumpAndSettle();
    expect(find.text('설정'), findsOneWidget);

    exitGameRoute(gameContext);
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsNothing);
    expect(find.text('게임 화면'), findsNothing);
    expect(find.text('게임 시작'), findsOneWidget);
  });

  testWidgets('다이얼로그가 여러 겹 쌓여 있어도 모두 걷어내고 나간다', (tester) async {
    final gameContext = await pumpGameRoute(tester);

    showDialog<void>(
      context: gameContext,
      builder: (_) => const AlertDialog(content: Text('룰북')),
    );
    await tester.pumpAndSettle();
    showDialog<void>(
      context: gameContext,
      builder: (_) => const AlertDialog(content: Text('나가기 확인')),
    );
    await tester.pumpAndSettle();

    exitGameRoute(gameContext);
    await tester.pumpAndSettle();

    expect(find.text('나가기 확인'), findsNothing);
    expect(find.text('룰북'), findsNothing);
    expect(find.text('게임 화면'), findsNothing);
    expect(find.text('게임 시작'), findsOneWidget);
  });
}
