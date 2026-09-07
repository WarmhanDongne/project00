/// 모든 게임의 휴대폰 화면이 공유하는 진행 단계입니다.
///
/// 서버의 `phase` 문자열은 게임마다 다르지만(라이어스 포커 5개, 파이널 콜 7개),
/// **화면이 무엇을 보여줄지**는 어느 게임이나 아래 6단계로 같습니다. 각 게임은
/// 자기 서버 상태를 이 단계로 번역하기만 하면 공용 셸([PhoneGameShell])이
/// 진입 연출·상단바·퇴장·결과를 동일하게 처리합니다.
///
/// 새 게임을 추가할 때 화면 분기를 직접 짜지 말고, 이 단계를 계산하는 함수
/// 하나만 만드세요.
enum GameScreenPhase {
  /// 서버의 첫 상태나 내 손패가 아직 도착하지 않았습니다.
  ///
  /// 배경만 보여 주고 상단바·퇴장 버튼도 감춥니다. 아직 게임에 들어오지 않은
  /// 것과 같으므로 나갈 대상도 없습니다.
  connecting,

  /// `GAME START` 연출 중입니다. 문구 외의 모든 UI를 감춥니다.
  intro,

  /// `ROUND N` 연출 중입니다. 문구 외의 모든 UI를 감춥니다.
  roundIntro,

  /// 실제 게임 진행 중입니다. 상단바(퇴장 포함)와 게임 화면을 함께 보여 줍니다.
  ///
  /// 손패를 모두 제출해 화면이 비는 순간도 여기에 포함됩니다. 그때 상단바를
  /// 감추면 퇴장할 방법이 사라지므로 반드시 이 단계로 유지하세요.
  playing,

  /// 승자가 확정되어 결과를 보여 줍니다.
  result,

  /// 인원 부족 등으로 게임이 정리되는 중입니다. 안내만 보여 줍니다.
  closing,
}

extension GameScreenPhaseX on GameScreenPhase {
  /// 문구만 보여 주는 연출 단계인지 여부입니다.
  bool get isIntro =>
      this == GameScreenPhase.intro || this == GameScreenPhase.roundIntro;

  /// 상단바와 퇴장 버튼을 노출해야 하는 단계인지 여부입니다.
  ///
  /// 연출 중이거나 아직 접속 중일 때만 감춥니다. 그 외에는 어떤 상태에서도
  /// 사용자가 게임에서 나갈 수 있어야 합니다.
  bool get showsTopBar =>
      this == GameScreenPhase.playing || this == GameScreenPhase.result;
}
