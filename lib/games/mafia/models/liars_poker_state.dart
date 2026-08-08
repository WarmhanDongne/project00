enum LiarsPokerPhase { waiting, playing, finished }

class LiarsPokerState {
  const LiarsPokerState({
    this.phase = LiarsPokerPhase.waiting,
    this.currentPlayerIndex = 0,
  });
  final LiarsPokerPhase phase;
  final int currentPlayerIndex;
}
