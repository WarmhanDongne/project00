import 'package:firebase_database/firebase_database.dart';
import 'package:game_kit/games/shared/services/game_query_service.dart';

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
