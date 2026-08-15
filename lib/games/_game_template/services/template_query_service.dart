import 'package:firebase_database/firebase_database.dart';
import 'package:project00/firebase/services/realtime_database_service.dart';

/// 게임 상태(읽기 스트림)를 담당하는 Query 서비스 뼈대입니다.
///
/// `LiarsPokerQueryService`/`FinalCallQueryService`처럼 Realtime Database
/// 경로별 스트림을 여기에 추가하세요.
class TemplateQueryService {
  TemplateQueryService({FirebaseDatabase? database})
    : _database = database ?? RealtimeDatabaseService.instance;

  final FirebaseDatabase _database;

  /// 게임 상태('waiting'|'playing'|...). [TemplateGame.watchStatus]가 사용합니다.
  Stream<DatabaseEvent> watchStatus(String roomCode) {
    return _database.ref('rooms/$roomCode/game/public/status').onValue;
  }
}
