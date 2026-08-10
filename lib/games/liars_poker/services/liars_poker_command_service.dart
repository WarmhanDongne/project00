import 'package:cloud_functions/cloud_functions.dart';

class LiarsPokerCommandService {
  static const int _maxTransientAttempts = 4;

  LiarsPokerCommandService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  /// 태블릿 딜링 중 첫 카드 제출과 라이어 함수의 콜드 스타트를 미리 끝냅니다.
  Future<void> warmUpGameplayCommands() async {
    await Future.wait([
      _call('submitLiarsPokerCards', const {'warmup': true}),
      warmUpLiarCommand(),
    ]);
  }

  /// 카드가 제출된 직후 라이어 선언 함수가 바로 응답하도록 준비합니다.
  Future<void> warmUpLiarCommand() async {
    await _call('callLiarsPoker', const {'warmup': true});
  }

  // 게임 시작
  Future<Map<String, dynamic>> startGame({required String roomCode}) {
    return _call('startLiarsPokerGame', {'roomCode': roomCode});
  }

  // 방과 플레이어는 유지하고 게임만 처음부터 다시 시작
  Future<Map<String, dynamic>> restartGame({required String roomCode}) {
    return _call('startLiarsPokerGame', {
      'roomCode': roomCode,
      'restart': true,
    });
  }

  // 방은 유지하고 현재 게임만 종료
  Future<Map<String, dynamic>> endGame({required String roomCode}) {
    return _call('endLiarsPokerGame', {
      'roomCode': roomCode,
    }, retryTransientFailure: true);
  }

  // 태블릿의 카드 배분 애니메이션 완료
  Future<Map<String, dynamic>> completeDealing({required String roomCode}) {
    return _call('completeLiarsPokerDealing', {
      'roomCode': roomCode,
    }, retryTransientFailure: true);
  }

  // 카드 제출
  Future<Map<String, dynamic>> submitCards({
    required String roomCode,
    required List<String> cardIds,
  }) {
    return _call('submitLiarsPokerCards', {
      'roomCode': roomCode,
      'commandId': _commandId('cards'),
      'cardIds': cardIds,
    }, retryTransientFailure: true);
  }

  // 라이어 선언
  Future<Map<String, dynamic>> callLiar({required String roomCode}) {
    return _call('callLiarsPoker', {
      'roomCode': roomCode,
      'commandId': _commandId('liar'),
    }, retryTransientFailure: true);
  }

  // 카드를 펼쳐 최초 턴 타이머 시작
  Future<Map<String, dynamic>> readyTurn({required String roomCode}) {
    return _call('readyLiarsPokerTurn', {
      'roomCode': roomCode,
      'commandId': _commandId('ready'),
    }, retryTransientFailure: true);
  }

  // 마지막 카드 도전 포기
  Future<Map<String, dynamic>> passLastCardChallenge({
    required String roomCode,
  }) {
    return _call('passLiarsPokerChallenge', {
      'roomCode': roomCode,
      'commandId': _commandId('pass'),
    }, retryTransientFailure: true);
  }

  // 벌칙 결과 전달
  Future<Map<String, dynamic>> resolvePenalty({
    required String roomCode,
    required String result,
  }) {
    return _call('resolveLiarsPokerPenalty', {
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
    for (var attempt = 0; attempt < _maxTransientAttempts; attempt += 1) {
      try {
        final result = await _functions.httpsCallable(functionName).call(data);

        if (result.data is! Map) {
          return const {};
        }

        return Map<String, dynamic>.from(result.data as Map);
      } on FirebaseFunctionsException catch (error) {
        final shouldRetry =
            retryTransientFailure &&
            attempt < _maxTransientAttempts - 1 &&
            _isTransientCode(error.code);
        if (shouldRetry) {
          // 같은 commandId를 유지해 서버의 멱등 처리 결과를 안전하게 재사용합니다.
          await Future<void>.delayed(
            Duration(milliseconds: 220 * (attempt + 1)),
          );
          continue;
        }

        throw LiarsPokerCommandException(
          code: error.code,
          message: error.message ?? '게임 요청을 처리하지 못했습니다.',
        );
      }
    }

    throw const LiarsPokerCommandException(
      code: 'aborted',
      message: '게임 요청을 처리하지 못했습니다.',
    );
  }

  bool _isTransientCode(String code) =>
      code == 'not-found' ||
      code == 'aborted' ||
      code == 'unavailable' ||
      code == 'deadline-exceeded';

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
