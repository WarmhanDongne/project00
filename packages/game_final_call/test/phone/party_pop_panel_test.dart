import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/game_copy.dart';
import 'package:game_final_call/phone/widgets/game_actions.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';

FinalCallCard _card(String color, int value) =>
    FinalCallCard(id: '${color}_$value', color: color, value: value);

FinalCallPlayer _player(String uid, int seat, FinalCallTeam team) =>
    FinalCallPlayer(
      uid: uid,
      nickname: uid,
      characterId: 'frog',
      seatIndex: seat,
      team: team,
      status: 'alive',
      lives: 3,
    );

class _Game extends Fake implements FinalCallController {
  @override
  String get uid => 'me';
  @override
  String turnUid = 'me';
  @override
  bool get isMyTurn => turnUid == uid;
  @override
  String phase = 'playing';
  @override
  bool canDraw = true;
  @override
  bool canCall = true;
  @override
  int get deckRemainingCount => 20;
  @override
  FinalCallCard? get discardCard => _card('blue', 4);
  @override
  FinalCallCard? pendingDraw;
  @override
  String? pendingDrawSource;
  @override
  List<String> get finalTurnPendingUids => const [];
  @override
  List<FinalCallCard> get hand => [
    _card('blue', 7),
    _card('red', 7),
    _card('red', 3),
    _card('green', 9),
  ];
  @override
  final Map<String, FinalCallPlayer> players = {
    'me': _player('me', 0, FinalCallTeam.red),
    'b': _player('b', 1, FinalCallTeam.blue),
    'partner': _player('partner', 2, FinalCallTeam.red),
    'd': _player('d', 3, FinalCallTeam.blue),
  };
  @override
  FinalCallTeam? get myTeam => FinalCallTeam.red;
}

Widget _panel(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        height: 318,
        child: FinalCallPhonePanel(child: child),
      ),
    ),
  ),
);

void main() {
  test('최고 점수를 만든 카드를 점수 규칙과 같게 고르고 계산식을 만든다', () {
    final pair = finalCallBestCombination([
      _card('blue', 7),
      _card('red', 7),
      _card('red', 3),
      _card('green', 9),
    ]);
    expect(pair.score, 14);
    expect(pair.cardIds, {'blue_7', 'red_7'});
    expect(FinalCallCopy.combinationEquation(pair), '7 + 7 = 14점');

    final triple = finalCallBestCombination([
      _card('blue', 7),
      _card('red', 7),
      _card('yellow', 7),
      _card('red', 3),
    ]);
    expect(triple.score, 21);
    expect(FinalCallCopy.combinationEquation(triple), '7 × 3 = 21점');
    expect(
      FinalCallCopy.combinationName(triple, (_) => ''),
      '같은 숫자 7 × 3',
    );

    final color = finalCallBestCombination([
      _card('red', 9),
      _card('red', 6),
      _card('blue', 2),
      _card('green', 4),
    ]);
    expect(color.score, calculateFinalCallScore(color.cards));
    expect(color.cardIds, {'red_9', 'red_6'});
    expect(FinalCallCopy.combinationEquation(color), '9 + 6 = 15점');
    expect(FinalCallCopy.replaceWith('초록', 9), '초록 9랑 바꾸기');
    expect(FinalCallCopy.replaceWith('파랑', 7), '파랑 7이랑 바꾸기');
  });

  testWidgets('턴 시작 패널은 덱·공개 카드를 바로 가져오고 CALL은 꾹 눌러야 선언된다', (
    tester,
  ) async {
    final sources = <String>[];
    var calls = 0;
    await tester.pumpWidget(
      _panel(
        FinalCallPhoneActions(
          controller: _Game(),
          selectedCardId: null,
          onDraw: sources.add,
          onCall: () => calls++,
          onCompleteTurn: (_) async {},
          replacementInProgress: false,
        ),
      ),
    );
    expect(find.text(FinalCallCopy.whereToDraw), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('덱에서 새 카드 가져오기'));
    await tester.tap(find.bySemanticsLabel('공개 카드 가져오기'));
    expect(sources, ['deck', 'discard']);

    // 짧게 누르면 선언되지 않습니다.
    await tester.tap(find.bySemanticsLabel('CALL 선언'));
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('CALL 선언')),
    );
    // 버튼 안이 차오르는 동안 프레임을 계속 돌립니다.
    for (var elapsed = 0; elapsed < 900; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pump();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('새 카드를 받으면 고른 카드로 바꾸기와 버리기를 구분한다', (tester) async {
    final game = _Game()
      ..canDraw = false
      ..canCall = false
      ..pendingDraw = _card('yellow', 7)
      ..pendingDrawSource = 'discard';
    final completed = <String?>[];
    Widget panel(String? selected) => _panel(
      FinalCallPhoneActions(
        controller: game,
        selectedCardId: selected,
        onDraw: (_) {},
        onCall: () {},
        onCompleteTurn: (id) async => completed.add(id),
        replacementInProgress: false,
      ),
    );

    await tester.pumpWidget(panel(null));
    await tester.pumpAndSettle();
    expect(find.text(FinalCallCopy.pickCardToReplace), findsOneWidget);
    await tester.tap(find.text(FinalCallCopy.pickCardToReplace));
    expect(completed, isEmpty);

    await tester.pumpWidget(panel('green_9'));
    await tester.pumpAndSettle();
    // 초록 9 대신 노랑 7을 넣으면 7이 세 장(21점)이 됩니다.
    expect(find.text('21'), findsOneWidget);
    expect(find.text('같은 숫자 7 × 3'), findsOneWidget);
    await tester.tap(find.text('초록 9랑 바꾸기'));
    await tester.tap(find.text(FinalCallCopy.discardNewCard));
    expect(completed, ['green_9', null]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('다른 사람 차례에는 내 점수와 좌석 순서대로 차례를 보여 준다', (tester) async {
    final game = _Game()..turnUid = 'b';
    await tester.pumpWidget(_panel(FinalCallWaitingPanel(controller: game)));
    expect(find.text('14'), findsOneWidget);
    expect(find.text(FinalCallCopy.now), findsOneWidget);
    expect(find.text(FinalCallCopy.partner), findsOneWidget);
    // b(지금) → partner → d → 나: 나는 3번째 뒤입니다.
    expect(find.text('3번째 뒤'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
