// [query_service.dart] 는 마피아에서 사용하는 서버의 게임 상태를 조회하고 해석하는 파일이다.
//
// - [Package] : 마피아
// - [Query] : 서버의 게임 상태를 조회하고 해석함
//
// 즉, 화면과 컨트롤러가 필요한 데이터만 안전하게 읽기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:game_kit/services/game_query_service.dart';
// ============================================================

/// 마피아 Realtime Database 읽기·구독 전용 서비스입니다.
///
/// 이 게임에서 공개/개인 경계는 곧 게임 규칙입니다.
/// - `watchPublicGame`에는 **신분을 유추할 수 있는 값이 없습니다.** 밤 행동은
///   제출 인원수만, 투표는 개표 결과만 들어 있습니다.
/// - `watchPrivatePlayer`에 내 역할·동료·조사 결과·관전용 신분표가 있습니다.
///   **태블릿은 이 구독을 열지 않습니다.**
///
/// 구독 경로가 모두 [GameQueryService]의 공용 경계와 같아서 이 게임만의 추가
/// 노드는 없습니다.
class MafiaQueryService extends GameQueryService {
  MafiaQueryService({super.database});
}
