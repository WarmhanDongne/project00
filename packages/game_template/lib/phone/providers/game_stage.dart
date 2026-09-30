// 새 게임의 서버 상태와 로컬 안내 완료값을 휴대폰 화면 단계로 번역합니다.
// 게임별 phase가 늘어나면 이 enum과 phone_board.dart의 FlowConfig를 함께 늘립니다.

import 'package:game_kit/game_flow/phone_game_shell.dart';

enum TemplatePhoneStage {
  connecting,
  gameStart,
  roundIntro,
  playing,
  result,
  closing,
}

extension TemplatePhoneStageShellRole on TemplatePhoneStage {
  PhoneGameShellStageRole get shellRole => switch (this) {
    TemplatePhoneStage.connecting => PhoneGameShellStageRole.connecting,
    TemplatePhoneStage.gameStart => PhoneGameShellStageRole.intro,
    TemplatePhoneStage.roundIntro => PhoneGameShellStageRole.roundIntro,
    TemplatePhoneStage.result => PhoneGameShellStageRole.result,
    TemplatePhoneStage.closing => PhoneGameShellStageRole.closing,
    TemplatePhoneStage.playing => PhoneGameShellStageRole.playing,
  };
}

TemplatePhoneStage resolveTemplatePhoneStage({
  required bool isLoading,
  required bool isClosing,
  required bool introDone,
  required bool roundIntroDone,
  required bool isFinished,
}) {
  if (isLoading) return TemplatePhoneStage.connecting;
  if (isClosing) return TemplatePhoneStage.closing;
  if (!introDone) return TemplatePhoneStage.gameStart;
  if (!roundIntroDone) return TemplatePhoneStage.roundIntro;
  if (isFinished) return TemplatePhoneStage.result;
  return TemplatePhoneStage.playing;
}
