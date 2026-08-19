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

  /// 휴대폰 상단 팁 아이콘으로 여는 규칙 문구입니다.
  ///
  /// 플레이 화면과 관전 화면이 같은 문구를 씁니다. 마크다운을 지원하지 않는
  /// 일반 텍스트로 표시되므로 기호 없이 문장으로만 씁니다. 태블릿 룰북
  /// (`widgets/tablet/rolebook.dart`)과 내용이 어긋나지 않게 함께 고치세요.
  static const phoneRules =
      '라운드마다 기준 카드가 A, K, Q 중 하나로 정해집니다.\n\n'
      '내 차례에는 손패에서 1~3장을 뒷면으로 냅니다. 낸 카드가 모두 기준 '
      '카드라고 주장하는 것이며, 다른 카드를 섞어 속여도 됩니다. 조커는 어떤 '
      '기준 카드로든 인정됩니다.\n\n'
      '다음 차례 사람은 카드를 내는 대신 LIAR를 외칠 수 있습니다. 직전에 낸 '
      '카드가 공개되어, 속인 것이 맞으면 카드를 낸 사람이, 진실이었으면 LIAR를 '
      '외친 사람이 벌칙 룰렛을 돌립니다.\n\n'
      '카드가 남은 사람이 나 혼자라면 LIAR 대신 FOLD를 골라, 의심을 접고 내가 '
      '룰렛을 돌릴 수 있습니다.\n\n'
      '룰렛에서 살아남아도 다음 룰렛은 더 불리해집니다. 세 번째 룰렛은 12칸 중 '
      '11칸이 탈락입니다.\n\n'
      '손패를 먼저 비우는 것은 승리가 아닙니다. 마지막까지 살아남은 한 명이 '
      '승리합니다.';

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
