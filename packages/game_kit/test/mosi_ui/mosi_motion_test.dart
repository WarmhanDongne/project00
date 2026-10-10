import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

Widget _items(List<String> names) => _host(
  MosiAnimatedItems<String>(
    items: names,
    keyOf: (name) => name,
    itemBuilder: (_, name) => SizedBox(height: 40, child: Text(name)),
  ),
);

void main() {
  testWidgets('빠지는 참가자는 사라지는 동안 남아 있다가 애니메이션 뒤에 지워진다', (tester) async {
    await tester.pumpWidget(_items(['사라', '민준', '하린']));
    expect(find.text('민준'), findsOneWidget);

    await tester.pumpWidget(_items(['사라', '하린']));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('민준'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('민준'), findsNothing);
    expect(find.text('사라'), findsOneWidget);
    expect(find.text('하린'), findsOneWidget);
  });

  testWidgets('새 참가자는 바로 목록에 들어오고 끝난 뒤 제 크기가 된다', (tester) async {
    await tester.pumpWidget(_items(['사라']));
    await tester.pumpWidget(_items(['사라', '도윤']));
    expect(find.text('도윤'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(tester.getSize(find.text('도윤')).height, greaterThan(0));
  });

  testWidgets('성공 상태 버튼은 체크 문구를 보이고 눌리지 않는다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        MosiButton(
          label: '저장',
          onPressed: () => taps++,
          success: true,
          successLabel: '저장됐어요',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('저장됐어요'), findsOneWidget);
    expect(find.byType(MosiDrawnCheck), findsOneWidget);
    await tester.tap(find.text('저장됐어요'));
    expect(taps, 0);
  });

  testWidgets('점 로딩 버튼은 원형 표시 대신 점을 보인다', (tester) async {
    await tester.pumpWidget(
      _host(
        MosiButton(
          label: '입장',
          onPressed: () {},
          loading: true,
          loadingDots: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MosiLoadingDots), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('방 코드는 글자가 차례로 나타나도 전체 문자열로 찾을 수 있다', (tester) async {
    await tester.pumpWidget(
      _host(
        const MosiStaggeredText(text: 'AB12', style: TextStyle(fontSize: 20)),
      ),
    );
    expect(find.text('AB12'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('AB12'), findsOneWidget);
  });
}
