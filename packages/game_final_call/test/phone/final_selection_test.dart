import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/phone/providers/final_selection.dart';
import 'package:game_final_call/shared/models/game_models.dart';

FinalCallCard _card(String color, int value) =>
    FinalCallCard(id: '$color-$value', color: color, value: value);

void main() {
  test('같은 숫자 자동 선택에서 같은 색을 누르면 겹치는 카드를 남긴다', () {
    final hand = [
      _card('red', 7),
      _card('red', 3),
      _card('blue', 7),
      _card('yellow', 2),
    ];
    final selected = {'red-7', 'blue-7'};

    toggleFinalCallSelection(selected: selected, hand: hand, cardId: 'red-3');
    expect(selected, {'red-3', 'red-7'});
    expect(
      finalCallBestCombination(
        hand.where((card) => selected.contains(card.id)),
      ).cardIds,
      selected,
    );
  });

  test('같은 색 선택에서 같은 숫자를 누르면 겹치는 카드를 남긴다', () {
    final hand = [
      _card('red', 7),
      _card('red', 3),
      _card('blue', 7),
      _card('yellow', 2),
    ];
    final selected = {'red-7', 'red-3'};
    toggleFinalCallSelection(selected: selected, hand: hand, cardId: 'blue-7');
    expect(selected, {'blue-7', 'red-7'});
    toggleFinalCallSelection(selected: selected, hand: hand, cardId: 'blue-7');
    expect(selected, {'red-7'});
    toggleFinalCallSelection(
      selected: selected,
      hand: hand,
      cardId: 'green-10',
    );
    expect(selected, {'red-7'});
  });

  test('최종 제출이 열리면 가장 높은 조합을 한 번만 미리 고른다', () {
    final hand = [
      _card('red', 7),
      _card('red', 3),
      _card('blue', 7),
      _card('yellow', 2),
    ];
    final selected = <String>{};
    var preset = syncFinalCallSelection(
      selected: selected,
      hand: hand,
      submitPhase: true,
      round: 2,
      presetRound: null,
    );
    expect(selected, {'red-7', 'blue-7'});
    expect(preset, 2);

    // 사용자가 모두 해제하면 같은 라운드에서는 다시 채우지 않습니다.
    selected.clear();
    preset = syncFinalCallSelection(
      selected: selected,
      hand: hand,
      submitPhase: true,
      round: 2,
      presetRound: preset,
    );
    expect(selected, isEmpty);
  });

  test('제출 단계가 바뀐 손패보다 먼저 와도 버린 카드를 제출하지 않는다', () {
    final oldHand = [
      _card('red', 7),
      _card('red', 3),
      _card('blue', 7),
      _card('yellow', 2),
    ];
    final selected = <String>{};
    // 마지막 교체로 파랑 7을 버렸지만 손패 갱신이 아직 오지 않았습니다.
    var preset = syncFinalCallSelection(
      selected: selected,
      hand: oldHand,
      submitPhase: true,
      round: 4,
      presetRound: null,
    );
    expect(selected, contains('blue-7'));

    final newHand = [
      _card('red', 7),
      _card('red', 3),
      _card('red', 9),
      _card('yellow', 2),
    ];
    preset = syncFinalCallSelection(
      selected: selected,
      hand: newHand,
      submitPhase: true,
      round: 4,
      presetRound: preset,
    );
    final handIds = {for (final card in newHand) card.id};
    expect(selected.every(handIds.contains), isTrue);
    expect(selected, {'red-7', 'red-3', 'red-9'});
    expect(preset, 4);
  });

  test('제출 단계가 아니면 선택을 비운다', () {
    final selected = {'red-7'};
    syncFinalCallSelection(
      selected: selected,
      hand: [_card('red', 7)],
      submitPhase: false,
      round: 1,
      presetRound: 1,
    );
    expect(selected, isEmpty);
  });
}
