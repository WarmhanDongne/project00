// Mafia 휴대폰의 서버 상태를 화면 단계로 번역합니다.
// 표시 문구·시간·영역은 phone_board.dart의 FlowConfig에서 수정합니다.

import 'package:game_kit/game_flow/phone_game_shell.dart';
import 'package:game_mafia/shared/providers/game_controller.dart';

/// Mafia 휴대폰이 실제로 보여 주는 화면 단계입니다.
enum MafiaPhoneStage {
  connecting,
  roleReveal,
  night,
  morning,
  day,
  voting,
  voteResult,
  spectator,
  result,
  closing,
}

extension MafiaPhoneStageShellRole on MafiaPhoneStage {
  PhoneGameShellStageRole get shellRole => switch (this) {
    MafiaPhoneStage.connecting => PhoneGameShellStageRole.connecting,
    MafiaPhoneStage.result => PhoneGameShellStageRole.result,
    MafiaPhoneStage.closing => PhoneGameShellStageRole.closing,
    _ => PhoneGameShellStageRole.playing,
  };
}

/// 서버 phase를 화면에서 사용하는 typed Stage로 변환합니다.
MafiaPhoneStage resolveMafiaPhoneStage(MafiaController game) {
  if (game.loading) return MafiaPhoneStage.connecting;
  if (game.isFinished && !game.isNaturalResult) {
    return MafiaPhoneStage.closing;
  }
  if (game.isFinished) return MafiaPhoneStage.result;
  if (!game.privateDataReady) return MafiaPhoneStage.connecting;
  // 처형 직후에는 사망자도 발표를 먼저 봐야 하므로 관전보다 우선합니다.
  if (game.isVoteResult) return MafiaPhoneStage.voteResult;
  // 오늘 밤 사망한 당사자도 아침 발표를 본 뒤 관전으로 이동합니다.
  if (game.isMorning &&
      (game.morningResult?.deadUids.contains(game.uid) ?? false)) {
    return MafiaPhoneStage.morning;
  }
  if (game.isSpectating) return MafiaPhoneStage.spectator;
  return switch (game.phase) {
    'roleReveal' => MafiaPhoneStage.roleReveal,
    'night' => MafiaPhoneStage.night,
    'morning' => MafiaPhoneStage.morning,
    'day' => MafiaPhoneStage.day,
    'voting' => MafiaPhoneStage.voting,
    _ => MafiaPhoneStage.connecting,
  };
}
