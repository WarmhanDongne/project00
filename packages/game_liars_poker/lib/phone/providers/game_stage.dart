// Liar's Poker 휴대폰의 서버 상태와 로컬 연출 상태를 화면 단계로 번역합니다.
// 표시 문구·시간·영역은 phone_board.dart의 FlowConfig에서 수정합니다.

import 'package:game_liars_poker/shared/providers/game_controller.dart';

enum LiarsPokerPhoneStage {
  connecting,
  gameStart,
  dealing,
  roundIntro,
  tableIntro,
  handReveal,
  playing,
  lastCardChallenge,
  verdict,
  penalty,
  spectator,
  result,
  closing,
}

/// 현재 진행 화면에서 보여 줄 단계를 계산합니다.
LiarsPokerPhoneStage resolveLiarsPokerPhoneStage({
  required LiarsPokerController? game,
  required bool gameStartCompleted,
  required bool revealInProgress,
  required bool showSpectatorTopBar,
}) {
  if (game == null || game.isInitialLoading) {
    return LiarsPokerPhoneStage.connecting;
  }
  if (game.isFinished && !game.isNaturalResult) {
    return LiarsPokerPhoneStage.closing;
  }
  if (game.isNaturalResult && !game.isPenaltyResultVisible) {
    return LiarsPokerPhoneStage.result;
  }
  if (showSpectatorTopBar && !game.showPenaltyHandOverlay) {
    return LiarsPokerPhoneStage.spectator;
  }
  final gameStartReady = game.phase != 'dealing' && game.handCards.isNotEmpty;
  if (!gameStartCompleted && gameStartReady) {
    return LiarsPokerPhoneStage.gameStart;
  }
  if (game.phase == 'dealing') return LiarsPokerPhoneStage.dealing;
  if (revealInProgress || !game.hasRevealedHand) {
    return LiarsPokerPhoneStage.handReveal;
  }
  if (game.showPenaltyHandOverlay) {
    return game.liarVerdictMessage != null || game.isLiarVerdictPending
        ? LiarsPokerPhoneStage.verdict
        : LiarsPokerPhoneStage.penalty;
  }
  if (game.showFoldPrompt) {
    return LiarsPokerPhoneStage.lastCardChallenge;
  }
  return LiarsPokerPhoneStage.playing;
}
