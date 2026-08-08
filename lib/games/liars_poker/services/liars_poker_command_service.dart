import 'package:cloud_functions/cloud_functions.dart';

class LiarsPokerCommandService {
  LiarsPokerCommandService({
    FirebaseFunctions? functions,
  }) : _functions =
            functions ??
            FirebaseFunctions.instanceFor(
              region: 'asia-northeast3',
            );

  final FirebaseFunctions _functions;

  // 게임 시작
  Future<Map<String, dynamic>> startGame({
    required String roomCode,
  }) {
    return _call(
      'startLiarsPokerGame',
      {
        'roomCode': roomCode,
      },
    );
  }

  // 카드 제출
  Future<Map<String, dynamic>> submitCards({
    required String roomCode,
    required List<String> cardIds,
  }) {
    return _call(
      'submitLiarsPokerCards',
      {
        'roomCode': roomCode,
        'commandId': _commandId('cards'),
        'cardIds': cardIds,
      },
    );
  }

  // 라이어 선언
  Future<Map<String, dynamic>> callLiar({
    required String roomCode,
  }) {
    return _call(
      'callLiarsPoker',
      {
        'roomCode': roomCode,
        'commandId': _commandId('liar'),
      },
    );
  }

  // 마지막 카드 도전 포기
  Future<Map<String, dynamic>> passLastCardChallenge({
    required String roomCode,
  }) {
    return _call(
      'passLiarsPokerChallenge',
      {
        'roomCode': roomCode,
        'commandId': _commandId('pass'),
      },
    );
  }

  // 벌칙 결과 전달
  Future<Map<String, dynamic>> resolvePenalty({
    required String roomCode,
    required String result,
  }) {
    return _call(
      'resolveLiarsPokerPenalty',
      {
        'roomCode': roomCode,
        'commandId': _commandId('roulette'),
        'result': result,
      },
    );
  }

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    try {
      final result =
          await _functions.httpsCallable(functionName).call(data);

      if (result.data is! Map) {
        return const {};
      }

      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw LiarsPokerCommandException(
        code: e.code,
        message: e.message ?? '게임 요청을 처리하지 못했습니다.',
      );
    }
  }

  String _commandId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }
}

class LiarsPokerCommandException implements Exception {
  const LiarsPokerCommandException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => message;
}