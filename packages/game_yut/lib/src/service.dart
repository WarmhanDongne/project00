import 'package:game_kit/services/game_command_service.dart';
import 'package:game_kit/services/game_query_service.dart';

class YutCommandService extends GameCommandService {
  Future<Map<String, dynamic>> startGame(
    String roomCode,
    String gameId, {
    bool restart = false,
  }) => invoke('game_yut_start_game', {
    'roomCode': roomCode,
    'gameId': gameId,
    if (restart) 'restart': true,
  });
  Future<Map<String, dynamic>> roll(String roomCode) => invoke(
    'game_yut_roll',
    {'roomCode': roomCode, 'commandId': commandId('roll')},
    retryTransientFailure: true,
  );
  Future<Map<String, dynamic>> choose(String roomCode, bool front) => invoke(
    'game_yut_submit_choice',
    {'roomCode': roomCode, 'front': front, 'commandId': commandId('choice')},
    retryTransientFailure: true,
  );

  /// 태블릿(B안)에서 [pieceId] 말에 나온 윷 [poolIndex]번을 씁니다.
  Future<Map<String, dynamic>> move(
    String roomCode,
    int pieceId,
    int poolIndex,
  ) => invoke('game_yut_move_piece', {
    'roomCode': roomCode,
    'pieceId': pieceId,
    'poolIndex': poolIndex,
    'commandId': commandId('move'),
  }, retryTransientFailure: true);
  Future<Map<String, dynamic>> timeout(String roomCode) =>
      invoke('game_yut_timeout_turn', {'roomCode': roomCode});
  Future<Map<String, dynamic>> endGame(String roomCode) =>
      invoke('game_yut_end_game', {'roomCode': roomCode});
}

class YutQueryService extends GameQueryService {}

class YutService {
  YutService({YutCommandService? command, YutQueryService? query})
    : command = command ?? YutCommandService(),
      query = query ?? YutQueryService();
  final YutCommandService command;
  final YutQueryService query;
}
