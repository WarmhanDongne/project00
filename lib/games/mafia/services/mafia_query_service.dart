import 'package:firebase_database/firebase_database.dart';
import 'package:project00/firebase/services/realtime_database_service.dart';

/// 마피아 Realtime Database 읽기·구독 전용 서비스입니다.
class MafiaQueryService {
  MafiaQueryService({FirebaseDatabase? database})
    : _database = database ?? RealtimeDatabaseService.instance;

  final FirebaseDatabase _database;

  /// 모든 기기가 공유하는 공개 게임 상태입니다.
  ///
  /// 여기에는 **신분을 유추할 수 있는 값이 없습니다.** 밤 행동은 제출 인원수만,
  /// 투표는 개표 결과만 들어 있습니다.
  Stream<DatabaseEvent> watchPublicGame(String roomCode) {
    return _database.ref('rooms/$roomCode/game/public').onValue;
  }

  /// 공개 게임 노드가 실제로 삭제됐는지 재확인합니다.
  ///
  /// 재연결 직후 스트림이 잠깐 null을 전달한 경우와 태블릿이 게임을 실제로
  /// 정리한 경우를 구분할 때 사용합니다.
  Future<DataSnapshot> readPublicGame(String roomCode) {
    return _database.ref('rooms/$roomCode/game/public').get();
  }

  /// 본인만 읽는 값입니다. 내 역할·동료·조사 결과·관전용 신분표.
  ///
  /// **태블릿은 이 구독을 열지 않습니다.** 태블릿 화면에 신분이 흘러들면 옆에서
  /// 보는 사람에게 다 드러납니다.
  Stream<DatabaseEvent> watchPrivatePlayer({
    required String roomCode,
    required String uid,
  }) {
    return _database.ref('rooms/$roomCode/game/private/$uid').onValue;
  }

  /// 플랫폼 대기 화면에서 게임 시작 여부만 확인합니다.
  Stream<DatabaseEvent> watchStatus(String roomCode) {
    return _database.ref('rooms/$roomCode/game/public/status').onValue;
  }
}
