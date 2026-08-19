import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/liars_poker/widgets/phone/hand_card_stack.dart';
import 'package:project00/gen/assets.gen.dart';

void main() {
  //=======================새 라운드 손패 교체==============================
  // 새 라운드가 시작되면 손패 위젯의 key가 바뀌어 State가 새로 만들어집니다.
  // 선택이 남아 있는 상태로 교체될 때 예외 없이 선택이 정리되고, 컨트롤러를
  // 듣는 버튼 쪽에도 반영되는지 확인합니다.
  //
  // 주의: 이 테스트는 실제로 보고된
  // `setState() or markNeedsBuild() called during build`를 재현하지 못했습니다.
  // 컨트롤러 쪽 방어 코드(`_notifySelectionListeners`)를 넣거나 빼도 통과합니다.
  // 그 오류의 정확한 발생 경로는 아직 확인되지 않았습니다.
  testWidgets('선택한 카드가 있는 상태로 새 라운드 손패로 교체해도 오류가 나지 않는다', (tester) async {
    final controller = PhoneHandCardStackController();
    addTearDown(controller.dispose);

    final cards = <AssetGenImage>[
      Assets.games.liarsPoker.images.cards.whiteA,
      Assets.games.liarsPoker.images.cards.whiteK,
      Assets.games.liarsPoker.images.cards.whiteQ,
    ];

    // 실제 화면과 같은 구조입니다. 버튼 자리가 컨트롤러를 듣고 있어야 이 오류가
    // 재현됩니다.
    Widget build(int dealVersion) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) =>
                  Text('선택 ${controller.selectedIndexes.length}장'),
            ),
            SizedBox(
              height: 320,
              child: PhoneHandCardStack(
                key: ValueKey('portrait-deal-$dealVersion'),
                isLandscape: false,
                controller: controller,
                cards: cards,
                initiallyRevealed: true,
              ),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(build(1));
    await tester.pumpAndSettle();

    // 카드를 한 장 눌러 컨트롤러에 선택 상태를 남깁니다.
    await tester.tap(find.byType(Image).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(controller.hasSelection, isTrue);
    expect(find.text('선택 1장'), findsOneWidget);

    // 새 라운드: key가 바뀌어 dispose와 initState가 같은 빌드에서 일어납니다.
    await tester.pumpWidget(build(2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // 선택은 새 손패 기준으로 비워지고, 버튼 쪽에도 반영돼야 합니다.
    expect(controller.hasSelection, isFalse);
    expect(find.text('선택 0장'), findsOneWidget);
  });
}
