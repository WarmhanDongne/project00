// [game_stage.dart] 는 새 게임을 같은 구조로 시작할 때 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
//
// - [Package] : 새 게임 템플릿
// - [TabletScreen] : 태블릿에서 보이는 공용 게임 진행 화면을 구성함
//
// 즉, 모든 플레이어가 함께 보는 진행 상태와 연출을 표시하기 위해 필요한 파일이다.

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
