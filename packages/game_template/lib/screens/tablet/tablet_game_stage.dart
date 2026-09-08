/// 새 태블릿 게임이 서버 상태를 번역할 때 사용하는 화면 단계 예시입니다.
///
/// 게임에 없는 단계는 삭제하고 필요한 단계는 추가해도 됩니다. 단, 서버 phase
/// 문자열을 하위 Widget에서 직접 비교하지 말고 진입점의 `_resolveStage`에서만
/// 이 enum으로 번역하세요.
enum TemplateTabletStage {
  connecting,
  dealing,
  playing,
  roundResult,
  penalty,
  result,
  closing,
}
