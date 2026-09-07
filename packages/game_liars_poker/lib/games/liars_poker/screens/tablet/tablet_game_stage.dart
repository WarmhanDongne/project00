/// 태블릿에서 표현하는 Liar's Poker 화면 상태입니다.
///
/// 서버의 `status`와 `phase`를 그대로 사용하지 않는 이유는 카드 배분과
/// 카드 이동처럼 태블릿에서만 필요한 애니메이션 상태가 있기 때문입니다.
enum LiarsPokerTabletStage {
  /// 첫 서버 상태를 기다립니다.
  waiting,

  /// 생존 좌석에 카드를 분배합니다.
  dealing,

  /// 테이블·잔여 카드·턴 조명을 등장시킵니다.
  roundStarting,

  /// 휴대폰 플레이어의 행동을 기다립니다.
  playing,

  /// 제출 카드를 좌석에서 중앙 더미로 이동합니다.
  cardsPlaying,

  /// LIAR 판정 카드를 뒤집어 공개합니다.
  cardsRevealing,

  /// 패널티 대상자의 벌칙 룰렛을 표시합니다.
  penalty,

  /// 최종 우승자와 결과 버튼을 표시합니다.
  result,

  /// 결과 이외의 게임 종료 안내를 표시합니다.
  finished,
}

extension LiarsPokerTabletStageLabel on LiarsPokerTabletStage {
  String get label {
    return switch (this) {
      LiarsPokerTabletStage.waiting => '게임 대기',
      LiarsPokerTabletStage.dealing => '카드 배분',
      LiarsPokerTabletStage.roundStarting => '라운드 시작',
      LiarsPokerTabletStage.playing => '게임 진행',
      LiarsPokerTabletStage.cardsPlaying => '카드 제출 애니메이션',
      LiarsPokerTabletStage.cardsRevealing => '카드 공개 애니메이션',
      LiarsPokerTabletStage.penalty => '벌칙 룰렛',
      LiarsPokerTabletStage.result => '결과',
      LiarsPokerTabletStage.finished => '게임 종료',
    };
  }
}
