enum LiarsBarPhase { waiting, playing, finished }

class LiarsBarState {
  const LiarsBarState({
    this.phase = LiarsBarPhase.waiting,
    this.currentPlayerIndex = 0,
  });
  final LiarsBarPhase phase;
  final int currentPlayerIndex;
}
