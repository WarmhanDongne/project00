import 'package:project00/games/shared/game_flow/game_announcement.dart';

/// Liar's Poker 화면에서 사용하는 사용자 문구입니다.
abstract final class LiarsPokerCopy {
  static const waitingForOpponent = '상대의 선택을 기다리는 중...';
  static const waitingForNextRound = '다음 라운드를 기다려주세요';
  static const eliminated = '탈락했습니다';
  static const dealingOnTablet = '태블릿에서 카드를 배분하는 중입니다';
  static const myPenaltyInProgress = '내 벌칙을 진행 중입니다';
  static const penaltyInProgress = '벌칙을 진행 중입니다';
  static const decideLastCard = '마지막 카드가 라이어인지 결정하세요';
  static const truthProven = '진실이 증명되었습니다.';
  static const lieRevealed = '거짓이 밝혀졌습니다.';
  static const challengeSucceeded = '간파 성공!';
  static const challengeFailed = '간파 실패!';
  static const noCards = '내 손패 없음';
  static const penaltyTitle = '벌칙 진행 중';

  static String winner(String nickname) => '$nickname님이 승리했습니다';
  static String waitingForDecision(String nickname) => '$nickname님의 결정을 기다리는 중';
  static String selectionLimit(int count) => '최대 $count장만 선택할 수 있습니다';

  static String table(String rank) => switch (rank.toUpperCase()) {
    'A' => 'ACE',
    'Q' => 'QUEEN',
    _ => 'KING',
  };

  static GameAnnouncementTone verdictTone(String message) {
    return switch (message) {
      truthProven || challengeSucceeded => GameAnnouncementTone.positive,
      lieRevealed || challengeFailed => GameAnnouncementTone.negative,
      _ => GameAnnouncementTone.neutral,
    };
  }
}
