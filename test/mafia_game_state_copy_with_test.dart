import 'package:flutter_test/flutter_test.dart';
import 'package:game_mafia/games/mafia/models/mafia_state_models.dart';
import 'package:game_mafia/games/mafia/providers/mafia_game_state.dart';

void main() {
  test('unrelated copyWith preserves nullable night progress', () {
    const cue = MafiaNightActionCue(id: 7, action: 'eliminate');
    final state = MafiaGameState.initial().copyWith(
      nightStage: 'attack',
      nightStageActorCount: 3,
      nightStageSubmittedCount: 2,
      dayEndReason: 'vote',
      nightActionCue: cue,
    );

    final updated = state.copyWith(commandInFlight: true);

    expect(updated.nightStage, 'attack');
    expect(updated.nightStageActorCount, 3);
    expect(updated.nightStageSubmittedCount, 2);
    expect(updated.dayEndReason, 'vote');
    expect(updated.nightActionCue, same(cue));
  });

  test('explicit null clears server-resettable night progress', () {
    const cue = MafiaNightActionCue(id: 7, action: 'eliminate');
    final state = MafiaGameState.initial().copyWith(
      nightStage: 'attack',
      dayEndReason: 'vote',
      nightActionCue: cue,
    );

    final cleared = state.copyWith(
      nightStage: null,
      dayEndReason: null,
      nightActionCue: null,
    );

    expect(cleared.nightStage, isNull);
    expect(cleared.dayEndReason, isNull);
    expect(cleared.nightActionCue, isNull);
  });
}
