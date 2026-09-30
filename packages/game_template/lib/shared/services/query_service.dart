// [query_service.dart] 는 새 게임을 같은 구조로 시작할 때 사용하는 서버의 게임 상태를 조회하고 해석하는 파일이다.
//
// - [Package] : 새 게임 템플릿
// - [Query] : 서버의 게임 상태를 조회하고 해석함
//
// 즉, 화면과 컨트롤러가 필요한 데이터만 안전하게 읽기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:firebase_database/firebase_database.dart';
import 'package:game_kit/services/game_query_service.dart';
// ============================================================

/// 게임 상태(읽기 스트림)를 담당하는 Query 서비스 뼈대입니다.
///
/// [GameQueryService]가 공개/개인 경계와 `watchPublicGame`,
/// `readPublicGame`, `watchStatus`, `watchPrivatePlayer`를 제공합니다.
/// 여기에는 **이 게임에만 있는 노드**만 추가하세요.
///
/// 경로 문자열을 직접 만들지 말고 `publicRef`/`privateRef`를 쓰세요.
class TemplateQueryService extends GameQueryService {
  TemplateQueryService({super.database});

  /// 이 게임에만 있는 공개 노드의 예시입니다. 필요 없으면 지우세요.
  Stream<DatabaseEvent> watchTurn(String roomCode) =>
      publicRef(roomCode, 'turnUid').onValue;
}
