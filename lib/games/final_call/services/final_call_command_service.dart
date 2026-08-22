import 'package:cloud_functions/cloud_functions.dart';
import 'package:project00/games/shared/services/callable_retry_policy.dart';
import 'package:project00/platform/home/room/services/controller_room_session_store.dart';

/// Final Call Cloud Functions 명령 전용 서비스입니다.
class FinalCallCommandService {
  FinalCallCommandService({
    FirebaseFunctions? functions,
    this.retryPolicy = const CallableRetryPolicy(),
  }) : _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;
  final CallableRetryPolicy retryPolicy;

  //=======================콜드스타트 예열==============================
  /// 게임에 들어갈 때 첫 조작 함수들을 미리 깨웁니다.
  ///
  /// 서버는 `warmup: true`를 받으면 아무 일도 하지 않고 즉시 돌아옵니다. 이걸
  /// 하지 않으면 그 판의 **첫 카드 뽑기와 첫 CALL**이 콜드스타트를 그대로
  /// 맞습니다(라이어스 포커·마피아와 같은 방식).
  Future<void> warmUpGameplayCommands() async {
    await Future.wait([
      _call('game_final_call_draw_card', const {'warmup': true}),
      _call('game_final_call_declare', const {'warmup': true}),
    ]);
  }

  //=======================게임 수명주기==============================
  Future<Map<String, dynamic>> startGame({required String roomCode}) {
    return _call('game_final_call_start_game', {'roomCode': roomCode});
  }

  Future<Map<String, dynamic>> restartGame({required String roomCode}) {
    return _call('game_final_call_start_game', {
      'roomCode': roomCode,
      'restart': true,
    });
  }

  /// 먼저 finished 상태를 전달해 모든 휴대폰이 종료를 인식하게 합니다.
  Future<Map<String, dynamic>> endGame({required String roomCode}) {
    return _call('game_final_call_end_game', {
      'roomCode': roomCode,
    }, retryTransientFailure: true);
  }

  /// 방과 참가자는 유지하고 `rooms/{code}/game`만 삭제합니다.
  Future<Map<String, dynamic>> clearGame({required String roomCode}) {
    return _call('game_final_call_clear_game', {
      'roomCode': roomCode,
    }, retryTransientFailure: true);
  }

  //=======================라운드 진행==============================
  Future<Map<String, dynamic>> completeDealing({required String roomCode}) {
    return _call('game_final_call_complete_dealing', {
      'roomCode': roomCode,
    }, retryTransientFailure: true);
  }

  Future<Map<String, dynamic>> drawCard({
    required String roomCode,
    required String source,
  }) {
    return _call('game_final_call_draw_card', {
      'roomCode': roomCode,
      'source': source,
      'commandId': _commandId('draw'),
    }, retryTransientFailure: true);
  }

  Future<Map<String, dynamic>> completeTurn({
    required String roomCode,
    String? replaceCardId,
  }) {
    return _call('game_final_call_complete_turn', {
      'roomCode': roomCode,
      'replaceCardId': replaceCardId,
      'commandId': _commandId('turn'),
    }, retryTransientFailure: true);
  }

  Future<Map<String, dynamic>> call({required String roomCode}) {
    return _call('game_final_call_declare', {
      'roomCode': roomCode,
      'commandId': _commandId('call'),
    }, retryTransientFailure: true);
  }

  Future<Map<String, dynamic>> submitFinalHand({
    required String roomCode,
    required List<String> cardIds,
  }) {
    return _call('game_final_call_submit_hand', {
      'roomCode': roomCode,
      'cardIds': cardIds,
      'commandId': _commandId('final_hand'),
    }, retryTransientFailure: true);
  }

  Future<Map<String, dynamic>> startNextRound({required String roomCode}) {
    return _call('game_final_call_start_next_round', {
      'roomCode': roomCode,
    }, retryTransientFailure: true);
  }

  Future<Map<String, dynamic>> timeoutTurn({required String roomCode}) {
    return _call('game_final_call_timeout_turn', {
      'roomCode': roomCode,
    }, retryTransientFailure: true);
  }

  /// 태블릿의 최종 카드 공개가 끝난 뒤 휴대폰 결과 화면을 엽니다.
  Future<Map<String, dynamic>> completeResultReveal({
    required String roomCode,
  }) {
    return _call('game_final_call_complete_result_reveal', {
      'roomCode': roomCode,
    }, retryTransientFailure: true);
  }

  //=======================Callable 공통 처리==============================
  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, dynamic> data, {
    bool retryTransientFailure = false,
  }) async {
    final roomCode = data['roomCode'];
    final payload = roomCode is String
        ? controllerCommandData(roomCode, data)
        : data;
    return retryPolicy.run(() async {
      final response = await _functions
          .httpsCallable(functionName)
          .call(payload);
      return response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const {};
    }, enabled: retryTransientFailure);
  }

  String _commandId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }
}
