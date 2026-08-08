/// 태블릿에서 표현하는 Liar's Poker 화면 상태입니다.
///
/// 서버의 `status`와 `phase`를 그대로 사용하지 않는 이유는 카드 배분과
/// 카드 이동처럼 태블릿에서만 필요한 애니메이션 상태가 있기 때문입니다.
enum GameStatus {
  waiting,
  dealing,
  roundStarting,
  playing,
  cardsPlaying,
  cardsRevealing,
  penalty,
  result,
  finished,
}

extension GameStatusLabel on GameStatus {
  String get label {
    return switch (this) {
      GameStatus.waiting => '게임 대기',
      GameStatus.dealing => '카드 배분',
      GameStatus.roundStarting => '라운드 시작',
      GameStatus.playing => '게임 진행',
      GameStatus.cardsPlaying => '카드 제출 애니메이션',
      GameStatus.cardsRevealing => '카드 공개 애니메이션',
      GameStatus.penalty => '벌칙 룰렛',
      GameStatus.result => '결과',
      GameStatus.finished => '게임 종료',
    };
  }
}
