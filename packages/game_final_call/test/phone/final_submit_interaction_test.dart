import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/game_copy.dart';
import 'package:game_final_call/phone/providers/final_selection.dart';
import 'package:game_final_call/phone/screens/game_screen.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';

FinalCallCard _card(String color, int value) =>
    FinalCallCard(id: '${color}_$value', color: color, value: value);

class _SubmitGame extends Fake implements FinalCallController {
  final List<FinalCallCard> cards = [
    _card('red', 7),
    _card('red', 3),
    _card('blue', 7),
    _card('yellow', 2),
  ];
  List<String>? submittedIds;

  @override
  List<FinalCallCard> get hand => cards;
  @override
  String get phase => 'callerSubmit';
  @override
  int get round => 2;
  @override
  int get revision => 5;
  @override
  bool get isFinalSubmitPhase => true;
  @override
  bool get canSubmitFinalHand => true;
  @override
  bool get canCompleteTurn => false;
  @override
  FinalCallCard? get pendingDraw => null;
  @override
  void reorderHand(String draggedCardId, String targetCardId) {}
  @override
  Future<bool> submitFinalHand(List<String> cardIds) async {
    submittedIds = cardIds;
    return true;
  }
}

void main() {
  testWidgets('CALL 이후 다른 조합을 골라 제출하면 그 카드만 전송한다', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = _SubmitGame();
    final selected = <String>{'red_7', 'blue_7'};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => FinalCallPhoneGameScreen(
              controller: game,
              handRevealed: true,
              selectedCardId: null,
              selectedFinalCardIds: selected,
              visibleCallerUid: null,
              onRevealStarted: () {},
              onRevealCompleted: () {},
              onSelectedCardChanged: (_) {},
              onFinalCardSelected: (id) => update(() {
                toggleFinalCallSelection(
                  selected: selected,
                  hand: game.hand,
                  cardId: id,
                );
              }),
              onCompleteTurn: (_) async {},
              replacingCardId: null,
              replacementInProgress: false,
              onExitRoom: () {},
              regions: const PhoneGameRegions(
                showHand: true,
                showActions: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('red_3')));
    await tester.pump();
    expect(selected, {'red_3', 'red_7'});
    expect(find.text('10'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(FinalCallCopy.submit));
    await tester.pump();
    expect(game.submittedIds, unorderedEquals(['red_7', 'red_3']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('같은 색 자동 선택에서 같은 숫자로 바꿔 제출한다', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = _SubmitGame();
    final selected = <String>{'red_7', 'red_3'};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => FinalCallPhoneGameScreen(
              controller: game,
              handRevealed: true,
              selectedCardId: null,
              selectedFinalCardIds: selected,
              visibleCallerUid: null,
              onRevealStarted: () {},
              onRevealCompleted: () {},
              onSelectedCardChanged: (_) {},
              onFinalCardSelected: (id) => update(() {
                toggleFinalCallSelection(
                  selected: selected,
                  hand: game.hand,
                  cardId: id,
                );
              }),
              onCompleteTurn: (_) async {},
              replacingCardId: null,
              replacementInProgress: false,
              onExitRoom: () {},
              regions: const PhoneGameRegions(
                showHand: true,
                showActions: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('blue_7')));
    await tester.pump();
    expect(selected, {'red_7', 'blue_7'});
    expect(find.text('14'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(FinalCallCopy.submit));
    await tester.pump();
    expect(game.submittedIds, unorderedEquals(['red_7', 'blue_7']));
    expect(tester.takeException(), isNull);
  });
}
