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

  static String round(int value) => 'ROUND $value';
}
