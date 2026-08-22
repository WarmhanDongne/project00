import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/widgets/game_reconnect_screen.dart';

//=======================게임 재접속 화면==============================
// 아직 배선하지 않은 화면입니다(디자인 확인 단계). 그림 파일이 저장소에
// 들어오기 전에도 화면이 깨지지 않아야 하고, 휴대폰 세로·태블릿 가로 모두에서
// 문구가 잘리지 않아야 합니다.
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: GameReconnectScreen()));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('휴대폰 세로에서 문구가 보인다', (tester) async {
    await pumpAt(tester, const Size(402, 874));

    expect(find.text('게임에 다시 접속하는 중'), findsOneWidget);
    expect(find.text('잠시만 기다려 주세요'), findsOneWidget);
    // 그림 파일이 아직 없어도 오류 없이 그려집니다.
    expect(tester.takeException(), isNull);
  });

  testWidgets('태블릿 가로에서도 문구가 한 줄로 들어간다', (tester) async {
    await pumpAt(tester, const Size(1194, 834));

    final title = tester.getRect(find.text('게임에 다시 접속하는 중'));
    expect(title.width, lessThan(1194));
    expect(tester.takeException(), isNull);
  });

  testWidgets('문구를 바꿔 넣을 수 있다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: GameReconnectScreen(
          title: '다시 연결하는 중이에요',
          message: '조금만 기다려 주세요',
        ),
      ),
    );

    expect(find.text('다시 연결하는 중이에요'), findsOneWidget);
    expect(find.text('조금만 기다려 주세요'), findsOneWidget);
  });

  testWidgets('시간이 흘러도(별이 생겼다 사라져도) 오류가 없다', (tester) async {
    await pumpAt(tester, const Size(402, 874));

    // 별은 무작위로 태어나고 사라집니다. 여러 주기를 돌려 봅니다.
    for (var i = 0; i < 12; i += 1) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('잠시만 기다려 주세요'), findsOneWidget);
  });

  group('시간이 지나면 홈으로 버튼', () {
    testWidgets('처음에는 기다림 표시만 있고 버튼이 없다', (tester) async {
      await pumpAt(tester, const Size(402, 874));

      expect(find.text('홈으로'), findsNothing);
    });

    testWidgets('정해진 시간이 지나면 기다림 표시가 버튼으로 바뀐다', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var homeTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: GameReconnectScreen(
            // 시험에서는 짧게 잡습니다(실제 기본값은 20초).
            homeButtonDelay: const Duration(seconds: 2),
            onHome: () => homeTaps += 1,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('홈으로'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('홈으로'), findsOneWidget);

      // 눌러야 나갈 수 있습니다.
      await tester.tap(find.text('홈으로'));
      expect(homeTaps, 1);

      // 문구는 그대로 남습니다(왜 이 화면인지 알 수 있어야 합니다).
      expect(find.text('게임에 다시 접속하는 중'), findsOneWidget);
    });

    testWidgets('버튼으로 바뀔 때 그림과 문구가 움직이지 않는다', (tester) async {
      for (final size in [const Size(402, 874), const Size(1194, 834)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          const MaterialApp(
            home: GameReconnectScreen(homeButtonDelay: Duration(seconds: 2)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final titleBefore = tester.getRect(find.text('게임에 다시 접속하는 중'));
        final messageBefore = tester.getRect(find.text('잠시만 기다려 주세요'));

        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('홈으로'), findsOneWidget);

        // 점이 버튼으로 바뀌어도 위쪽 내용은 제자리에 있어야 합니다.
        expect(
          tester.getRect(find.text('게임에 다시 접속하는 중')).top,
          moreOrLessEquals(titleBefore.top, epsilon: 0.5),
        );
        expect(
          tester.getRect(find.text('잠시만 기다려 주세요')).top,
          moreOrLessEquals(messageBefore.top, epsilon: 0.5),
        );
      }
    });

    test('기본 대기 시간은 공용 연결 화면과 같은 20초다', () {
      expect(
        GameReconnectScreen.defaultHomeButtonDelay,
        const Duration(seconds: 20),
      );
    });
  });
}
