// [game_copy.dart] 는 새 게임 템플릿에서만 쓰는 화면 문구를 모아 두는 파일이다.
//
// - [Package] : 새 게임 템플릿
// - [Copy] : 이 게임에만 있는 문구
//
// 즉, 문구를 화면 코드 곳곳에 흩어 두지 않고 한곳에서 고치기 위해 필요한 파일이다.

/// 이 게임에서만 쓰는 문구입니다.
///
/// GAME START · ROUND N · 연결 중 · 인원 부족처럼 모든 게임이 같은 문구는
/// game_kit의 `GameFlowCopy`를 씁니다. 여기에는 그 밖의 것만 둡니다.
abstract final class TemplateCopy {
  static const playing = '게임 진행 중';
  static const playFailed = '선택을 보내지 못했습니다.';
}
