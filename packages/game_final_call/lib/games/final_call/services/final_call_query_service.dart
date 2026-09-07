import 'package:game_kit/games/shared/services/game_query_service.dart';

/// Final Call Realtime Database 읽기·구독 전용 서비스입니다.
///
/// 구독 경로가 모두 [GameQueryService]의 공용 경계와 같아서 이 게임만의
/// 추가 노드는 없습니다. 그래도 클래스를 두는 이유는, 게임별 서비스가 주입과
/// 테스트 대역의 이름 있는 자리이기 때문입니다.
class FinalCallQueryService extends GameQueryService {
  FinalCallQueryService({super.database});
}
