/// Final Call 태블릿이 실제로 그릴 화면 단계입니다.
///
/// 서버 phase 문자열과 결과 공개 애니메이션 완료 여부를 화면 진입점에서 이
/// enum으로 번역하고, 하위 레이어는 문자열을 다시 해석하지 않습니다.
enum FinalCallTabletStage {
  connecting,
  dealing,
  playing,
  roundResult,
  result,
  closing,
}
