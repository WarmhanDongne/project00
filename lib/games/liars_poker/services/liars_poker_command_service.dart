import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:project00/games/shared/services/callable_retry_policy.dart';
import 'package:project00/platform/home/room/services/controller_room_session_store.dart';

class LiarsPokerCommandService {
  LiarsPokerCommandService({
    FirebaseFunctions? functions,
    this.retryPolicy = const CallableRetryPolicy(),
  }) : _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;
  final CallableRetryPolicy retryPolicy;

  /// 태블릿 딜링 중 첫 카드 제출과 라이어 함수의 콜드 스타트를 미리 끝냅니다.
  Future<void> warmUpGameplayCommands() async {
    await Future.wait([
      _call('game_liars_poker_submit_cards', const {'warmup': true}),
      warmUpLiarCommand(),
    ]);
  }

  /// 카드가 제출된 직후 라이어 선언 함수가 바로 응답하도록 준비합니다.
  Future<void> warmUpLiarCommand() async {
    await _call('game_liars_poker_call_liar', const {'warmup': true});
  }

  // 게임 시작
  Future<Map<String, dynamic>> startGame({required String roomCode}) {
    return _call('game_liars_poker_start_game', {'roomCode': roomCode});
  }

  // 방과 플레이어는 유지하고 게임만 처음부터 다시 시작
  Future<Map<String, dynamic>> restartGame({required String roomCode}) {
    return _call('game_liars_poker_start_game', {
      'roomCode': roomCode,
      'restart': true,
    });
  }

  // 방은 유지하고 현재 게임만 종료
  Future<Map<String, dynamic>> endGame({required String roomCode}) {
    return _call('game_liars_poker_end_game', {
      'roomCode': roomCode,
    }, retryTransientFailure: true);
  }

  // 태블릿의 카드 배분 애니메이션 완료
  Future<Map<String, dynamic>> completeDealing({required String roomCode}) {
    return _call('game_liars_poker_complete_dealing', {
      'roomCode': roomCode,
    }, retryTransientFailure: true);
  }

  // 카드 제출
  Future<Map<String, dynamic>> submitCards({
    required String roomCode,
    required List<String> cardIds,
  }) {
    return _call('game_liars_poker_submit_cards', {
      'roomCode': roomCode,
      'commandId': _commandId('cards'),
      'cardIds': cardIds,
    }, retryTransientFailure: true);
  }

  // 라이어 선언
  Future<Map<String, dynamic>> callLiar({required String roomCode}) {
    return _call('game_liars_poker_call_liar', {
      'roomCode': roomCode,
      'commandId': _commandId('liar'),
    }, retryTransientFailure: true);
  }

  // 마감이 지난 턴을 태블릿(컨트롤러)이 강제로 해결합니다.
  //
  // 평소 타임아웃은 턴 플레이어 휴대폰이 처리하지만, 그 기기가 화면 잠금·
  // 백그라운드로 멈추면 아무도 턴을 넘기지 못합니다. 이 명령이 그 백스톱입니다.
  // 마감 전 호출은 서버가 {success: false, reason: notExpired}로 거절합니다.
  Future<Map<String, dynamic>> forceTimeout({required String roomCode}) {
    return _call('game_liars_poker_force_timeout', {
      'roomCode': roomCode,
    }, retryTransientFailure: true);
  }

  // 카드를 펼쳐 최초 턴 타이머 시작
  Future<Map<String, dynamic>> readyTurn({required String roomCode}) {
    return _call('game_liars_poker_ready_turn', {
      'roomCode': roomCode,
      'commandId': _commandId('ready'),
    }, retryTransientFailure: true);
  }

  // 마지막 카드 도전 포기(FOLD)
  //
  // 서버 함수는 `game_liars_poker_pass_challenge`입니다. 배포된 callable 이름을
  // 바꿀 때는 이 호출부를 같은 커밋에서 함께 고치고 함께 배포해야 구버전 앱이
  // 함수를 찾지 못하는 일을 막을 수 있습니다.
  Future<Map<String, dynamic>> foldLastCardChallenge({
    required String roomCode,
  }) {
    return _call('game_liars_poker_pass_challenge', {
      'roomCode': roomCode,
      'commandId': _commandId('fold'),
    }, retryTransientFailure: true);
  }

  // 벌칙 결과 전달
  Future<Map<String, dynamic>> resolvePenalty({
    required String roomCode,
    required String result,
  }) {
    return _call('game_liars_poker_resolve_penalty', {
      'roomCode': roomCode,
      'commandId': _commandId('roulette'),
      'result': result,
    }, retryTransientFailure: true);
  }

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, dynamic> data, {
    bool retryTransientFailure = false,
  }) async {
    final roomCode = data['roomCode'];
    final payload = roomCode is String
        ? controllerCommandData(roomCode, data)
        : data;
    try {
      return await retryPolicy.run(() async {
        final result = await _functions
            .httpsCallable(functionName)
            .call(payload);

        if (result.data is! Map) {
          return const {};
        }

        return Map<String, dynamic>.from(result.data as Map);
      }, enabled: retryTransientFailure);
    } on FirebaseFunctionsException catch (error) {
      throw LiarsPokerCommandException(
        code: error.code,
        message: error.message ?? '게임 요청을 처리하지 못했습니다.',
      );
    } on TimeoutException {
      // 재전송 예산을 다 썼습니다. 여기서 실패로 끝내야 화면이 잠금에서 풀립니다.
      throw const LiarsPokerCommandException(
        code: 'deadline-exceeded',
        message: '서버 응답이 늦어 요청을 취소했습니다. 다시 시도해주세요.',
      );
    }
  }

  String _commandId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }
}

class LiarsPokerCommandException implements Exception {
  const LiarsPokerCommandException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}
