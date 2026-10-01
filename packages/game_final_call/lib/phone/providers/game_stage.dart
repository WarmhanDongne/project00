// Final Call 휴대폰의 서버 상태를 화면 단계로 번역합니다.
// 표시 문구·시간·영역은 phone_board.dart의 FlowConfig에서 수정합니다.

import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_kit/game_flow/phone_game_shell.dart';

/// Final Call 휴대폰이 실제로 보여 주는 화면 단계입니다.
enum FinalCallPhoneStage {
  connecting,
  dealing,
  gameStart,
  roundIntro,
  handReveal,
  playing,
  finalSelection,
  roundResultWaiting,
  result,
  closing,
}

extension FinalCallPhoneStageShellRole on FinalCallPhoneStage {
  PhoneGameShellStageRole get shellRole => switch (this) {
    FinalCallPhoneStage.connecting ||
    FinalCallPhoneStage.dealing => PhoneGameShellStageRole.connecting,
    FinalCallPhoneStage.gameStart => PhoneGameShellStageRole.intro,
    FinalCallPhoneStage.roundIntro => PhoneGameShellStageRole.roundIntro,
    FinalCallPhoneStage.result => PhoneGameShellStageRole.result,
    FinalCallPhoneStage.closing => PhoneGameShellStageRole.closing,
    _ => PhoneGameShellStageRole.playing,
  };
}

/// 서버 상태와 로컬 연출 완료값을 한 곳에서 화면 단계로 번역합니다.
///
/// 이 함수는 상태를 변경하지 않습니다. 조건 순서는 기존 화면의 안전장치를
/// 보존하므로, 표시 순서를 바꿀 때도 서버 종료·분배 검사를 앞쪽에 유지하세요.
FinalCallPhoneStage resolveFinalCallPhoneStage({
  required FinalCallController game,
  required bool gameStartCompleted,
  required int? announcedRound,
  required bool handRevealed,
}) {
  if (game.loading) return FinalCallPhoneStage.connecting;
  if (game.isFinished && !game.isNaturalResult) {
    return FinalCallPhoneStage.closing;
  }
  if (game.phase == 'dealing') return FinalCallPhoneStage.dealing;
  if (announcedRound != game.round && game.hand.isEmpty) {
    return FinalCallPhoneStage.dealing;
  }
  if (!gameStartCompleted) return FinalCallPhoneStage.gameStart;
  if (announcedRound != game.round) return FinalCallPhoneStage.roundIntro;
  if (game.isFinished && game.resultRevealCompletedAt == null) {
    return FinalCallPhoneStage.roundResultWaiting;
  }
  if (game.isFinished) return FinalCallPhoneStage.result;
  if (!handRevealed) return FinalCallPhoneStage.handReveal;
  if (game.isFinalSubmitPhase) return FinalCallPhoneStage.finalSelection;
  return FinalCallPhoneStage.playing;
}
