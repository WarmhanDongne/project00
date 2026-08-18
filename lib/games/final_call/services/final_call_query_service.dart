import 'package:firebase_database/firebase_database.dart';
import 'package:project00/firebase/services/realtime_database_service.dart';

/// Final Call Realtime Database 읽기·구독 전용 서비스입니다.
class FinalCallQueryService {
  FinalCallQueryService({FirebaseDatabase? database})
    : _database = database ?? RealtimeDatabaseService.instance;

  final FirebaseDatabase _database;

  /// 모든 기기가 공유하는 공개 게임 상태입니다.
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

  /// 한 플레이어만 읽는 손패와 현재 가져온 카드입니다.
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
