import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/widgets/phone/card_change_dialog.dart';

void main() {
  testWidgets('카드 교환 모달은 바깥 탭으로 닫고 새 카드 버튼으로 다시 연다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const discardCard = FinalCallCard(id: 'red_7', color: 'red', value: 7);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const Key('new-card-button'),
              onPressed: () => FinalCallCardChangeDialog.show(
                context,
                discardCard: discardCard,
                canSelectDeck: true,
              ),
              child: const Text('새 카드'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('new-card-button')));
    await tester.pumpAndSettle();
    expect(find.byType(FinalCallCardChangeDialog), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(FinalCallCardChangeDialog), findsNothing);

    await tester.tap(find.byKey(const Key('new-card-button')));
    await tester.pumpAndSettle();
    expect(find.byType(FinalCallCardChangeDialog), findsOneWidget);
  });
}
