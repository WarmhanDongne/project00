/// 여러 게임에서 같은 의미로 사용하는 기본 화면 문구입니다.
abstract final class GameFlowCopy {
  static const gameStart = 'GAME START';
  static const preparingGame = '';
  static const insufficientPlayers = '인원 부족으로 게임을 종료합니다';
  static const interruptionVoteExpired = '계속 진행 동의를 얻지 못해 게임을 종료합니다';
  static const gameFinished = '게임이 종료되었습니다.';
  static const authenticationRequired = '게임에 참여하려면 사용자 인증이 필요합니다.';
  static const gameOpenFailed = '게임을 열 수 없습니다.';
  static const leaveFailed = '게임에서 퇴장하지 못했습니다.';
  static const waitingForGameData = '게임 준비를 기다리는 중...';
  static const leaveGame = '나가기';

  //=======================인원 부족 즉시 종료 (C-11)==============================
  /// 남은 인원이 부족할 때 60초 카운트다운을 기다리지 않고 끝내는 버튼입니다.
  /// 휴대폰과 태블릿이 같은 문구를 씁니다.
  static const interruptionFinishNow = '게임 종료하기';
  static const interruptionFinishNowCancel = '취소';
  static const interruptionFinishNowAccept = '종료';
  static const interruptionFinishNowFailed = '게임을 종료하지 못했습니다.';

  static String round(int value) => 'ROUND $value';

  /// 즉시 종료 확인 문구입니다.
  ///
  /// 이탈자가 60초 안에 돌아오면 서버가 중단을 취소하고 게임이 그대로
  /// 이어집니다(직접 나간 경우도 마찬가지입니다). 그 기회를 없애는 조작이므로
  /// 남은 시간을 알려 주고 사람이 판단하게 합니다.
  static String interruptionFinishNowConfirm(String nickname, int seconds) =>
      '지금 종료하면 $nickname가 돌아올 수 있는 $seconds초가 사라집니다. 종료할까요?';
}
