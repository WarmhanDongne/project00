import 'package:game_kit/services/game_command_service.dart';

/// 마피아 Cloud Functions 명령 전용 서비스입니다.
///
/// 함수 이름은 서버(`functions/src/mafia/`)와 정확히 같아야 합니다. 배포된
/// 이름을 바꾸면 구버전 앱이 함수를 찾지 못합니다.
class MafiaCommandService extends GameCommandService {
  MafiaCommandService({super.functions, super.retryPolicy});

  //=======================게임 수명주기==============================
  /// 게임을 시작합니다.
  ///
  /// [composition]은 역할 배치 화면에서 고른 구성(`역할 id → 인원수`)입니다.
  /// 넘기지 않으면 서버가 인원별 추천 표를 씁니다.
  Future<Map<String, dynamic>> startGame({
    required String roomCode,
    Map<String, int>? composition,
  }) {
    return invoke('game_mafia_start_game', {
      'roomCode': roomCode,
      if (composition != null && composition.isNotEmpty)
        'composition': composition,
    });
  }

  Future<Map<String, dynamic>> restartGame({required String roomCode}) {
    return invoke('game_mafia_start_game', {
      'roomCode': roomCode,
      'restart': true,
    });
  }

  /// 첫 조작의 콜드스타트를 없애기 위해 게임 진입 때 미리 한 번 부릅니다.
  ///
  /// 서버는 아무 일도 하지 않고 즉시 돌아옵니다. 실패해도 무시합니다.
  Future<Map<String, dynamic>> warmUp({required String roomCode}) {
    return invoke('game_mafia_start_game', {
      'roomCode': roomCode,
      'warmup': true,
    });
  }

  Future<Map<String, dynamic>> endGame({required String roomCode}) {
    return invoke('game_mafia_end_game', {'roomCode': roomCode});
  }

  //=======================역할 확인==============================
  Future<Map<String, dynamic>> confirmRole({required String roomCode}) {
    return invoke('game_mafia_confirm_role', {
      'roomCode': roomCode,
      'commandId': commandId('confirm_role'),
    }, retryTransientFailure: true);
  }

  Future<Map<String, dynamic>> completeRoleReveal({required String roomCode}) {
    return invoke('game_mafia_complete_role_reveal', {'roomCode': roomCode});
  }

  //=======================밤==============================
  Future<Map<String, dynamic>> submitNightAction({
    required String roomCode,
    required String targetUid,
  }) {
    return invoke('game_mafia_submit_night_action', {
      'roomCode': roomCode,
      'targetUid': targetUid,
      // 대상을 바꿀 수 있어야 하므로 호출마다 새 id를 씁니다.
      'commandId': commandId('night'),
    }, retryTransientFailure: true);
  }

  Future<Map<String, dynamic>> timeoutNight({required String roomCode}) {
    return invoke('game_mafia_timeout_night', {'roomCode': roomCode});
  }

  //=======================아침·낮==============================
  Future<Map<String, dynamic>> completeMorning({required String roomCode}) {
    return invoke('game_mafia_complete_morning', {'roomCode': roomCode});
  }

  Future<Map<String, dynamic>> endDiscussion({required String roomCode}) {
    return invoke('game_mafia_end_discussion', {
      'roomCode': roomCode,
      'commandId': commandId('end_discussion'),
    }, retryTransientFailure: true);
  }

  Future<Map<String, dynamic>> timeoutDay({required String roomCode}) {
    return invoke('game_mafia_timeout_day', {'roomCode': roomCode});
  }

  //=======================투표==============================
  Future<Map<String, dynamic>> submitVote({
    required String roomCode,
    required String targetUid,
  }) {
    return invoke('game_mafia_submit_vote', {
      'roomCode': roomCode,
      'targetUid': targetUid,
      'commandId': commandId('vote'),
    }, retryTransientFailure: true);
  }

  Future<Map<String, dynamic>> timeoutVote({required String roomCode}) {
    return invoke('game_mafia_timeout_vote', {'roomCode': roomCode});
  }

  Future<Map<String, dynamic>> completeVoteResult({required String roomCode}) {
    return invoke('game_mafia_complete_vote_result', {'roomCode': roomCode});
  }
}
