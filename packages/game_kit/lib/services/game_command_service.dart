import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:game_kit/core/diagnostics/game_communication_log.dart';
import 'package:game_kit/services/callable_retry_policy.dart';
import 'package:game_kit/session/controller_room_session_store.dart';

//=======================게임 명령 서비스 공통 베이스==============================
/// 모든 게임의 `<game>_command_service.dart`가 상속하는 쓰기 전용 베이스입니다.
///
/// 게임마다 똑같이 복사되던 것들을 여기 한곳으로 모읍니다.
/// - callable 리전 (게임별로 문자열을 각자 들고 있으면 한 곳만 고쳤을 때 그
///   게임만 다른 리전을 호출하게 됩니다)
/// - `controllerCommandData`로 roomCode 정규화와 controllerSessionId 첨부
/// - [CallableRetryPolicy]를 통한 일시 오류 재전송
/// - 응답 Map 변환과 비-Map 응답 방어
/// - 멱등 재전송용 `commandId` 생성
/// - 콜드스타트 예열 호출
///
/// **오류는 감싸지 않고 그대로 올려보냅니다.** `userErrorMessage`와 마피아
/// 컨트롤러가 `FirebaseFunctionsException`의 `code`와 서버가 내려준 한국어
/// `message`를 직접 읽기 때문입니다. 자체 예외로 포장하면 그 두 값이 가려져
/// 사용자에게 일반 문구만 보이게 됩니다.
abstract class GameCommandService {
  GameCommandService({
    FirebaseFunctions? functions,
    this.retryPolicy = const CallableRetryPolicy(),
  }) : functions =
           functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  /// 게임 callable이 배포된 리전입니다.
  static const String functionsRegion = 'asia-northeast3';

  @protected
  final FirebaseFunctions functions;

  final CallableRetryPolicy retryPolicy;

  /// callable 한 번을 호출하고 응답을 `Map`으로 돌려줍니다.
  ///
  /// 이름이 `call`이 아닌 이유: 파이널콜의 CALL 선언 메서드가 이미 `call`이고,
  /// Dart에서 `call`이라는 이름의 메서드는 객체 자체를 함수처럼 호출 가능하게
  /// 만드는 특별한 이름이기도 합니다. 게임별 서비스와 부딪히지 않는 이름을 씁니다.
  ///
  /// [data]에 `roomCode`가 있으면 [controllerCommandData]가 대문자 정규화와
  /// controllerSessionId 첨부를 처리합니다.
  ///
  /// [retryTransientFailure]는 같은 안정적인 멱등 키(`commandId` 또는
  /// `interruptionId`)로 재전송해도 서버가 한 번만 처리하는 명령에만 true를
  /// 주세요. 멱등 키 없이 재전송하면 게임이 두 번 진행될 수 있습니다.
  @protected
  Future<Map<String, dynamic>> invoke(
    String functionName,
    Map<String, dynamic> data, {
    bool retryTransientFailure = false,
  }) async {
    final roomCode = data['roomCode'];
    final payload = roomCode is String
        ? controllerCommandData(roomCode, data)
        : data;
    final traceId =
        payload['commandId']?.toString() ??
        'request_${DateTime.now().microsecondsSinceEpoch}';
    final operation = _commandLabel(functionName);
    final totalElapsed = Stopwatch()..start();
    var attempt = 0;

    GameCommunicationLog.instance.add(
      level: GameCommunicationLevel.info,
      title: '$operation 요청 시작',
      detail: retryTransientFailure ? '일시 오류 시 자동 재시도' : '단일 요청',
      operation: functionName,
      traceId: traceId,
    );

    try {
      final result = await retryPolicy.run(() async {
        attempt += 1;
        GameCommunicationLog.instance.add(
          level: attempt == 1
              ? GameCommunicationLevel.info
              : GameCommunicationLevel.warning,
          title: attempt == 1 ? '서버로 전송' : '서버로 재전송',
          detail: '$attempt회차 시도',
          operation: functionName,
          traceId: traceId,
        );
        try {
          final response = await functions
              .httpsCallable(functionName)
              .call(payload);
          return response.data is Map
              ? Map<String, dynamic>.from(response.data as Map)
              : const <String, dynamic>{};
        } catch (error) {
          GameCommunicationLog.instance.add(
            level: GameCommunicationLevel.warning,
            title: '서버 시도 실패',
            detail: '$attempt회차 · ${_communicationErrorDescription(error)}',
            operation: functionName,
            traceId: traceId,
          );
          rethrow;
        }
      }, enabled: retryTransientFailure);

      totalElapsed.stop();
      final success = result['success'];
      final reason = result['reason'];
      final safeReason =
          reason is String &&
              RegExp(r'^[A-Za-z][A-Za-z0-9_-]{0,63}$').hasMatch(reason)
          ? reason
          : null;
      final responseSummary = <String>[
        '${totalElapsed.elapsedMilliseconds}ms',
        '$attempt회 시도',
        if (result['type'] is String) 'type=${result['type']}',
        if (result['revision'] is num)
          'revision=${(result['revision'] as num).toInt()}',
        if (safeReason != null) 'reason=$safeReason',
      ].join(' · ');
      GameCommunicationLog.instance.add(
        level: success == false
            ? GameCommunicationLevel.warning
            : GameCommunicationLevel.success,
        title: success == false ? '$operation 서버 보류' : '$operation 서버 응답',
        detail: responseSummary,
        operation: functionName,
        traceId: traceId,
      );
      return result;
    } catch (error, stackTrace) {
      totalElapsed.stop();
      GameCommunicationLog.instance.add(
        level: GameCommunicationLevel.failure,
        title: '$operation 요청 실패',
        detail:
            '${totalElapsed.elapsedMilliseconds}ms · $attempt회 시도 · '
            '${_communicationErrorDescription(error)}',
        operation: functionName,
        traceId: traceId,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// 재전송해도 서버가 한 번만 처리하도록 명령을 식별합니다.
  ///
  /// 재전송 전체에서 **같은 값을 유지해야** 하므로, 호출 시점에 한 번만 만들어
  /// payload에 담습니다. 재시도 루프 안에서 다시 만들면 안 됩니다.
  @protected
  String commandId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  /// 첫 조작이 콜드스타트를 그대로 맞지 않도록 함수를 미리 깨웁니다.
  ///
  /// 서버는 `warmup: true`를 받으면 아무 일도 하지 않고 즉시 돌아옵니다.
  /// 예열 실패는 호출자가 삼킵니다 — 실제 명령이 어차피 다시 호출합니다.
  @protected
  Future<void> warmUpCommands(List<String> functionNames) async {
    await Future.wait(
      functionNames.map((name) => invoke(name, const {'warmup': true})),
    );
  }
}

String _commandLabel(String functionName) => switch (functionName) {
  'game_liars_poker_submit_cards' => '라이어스포커 카드 제출',
  'game_liars_poker_call_liar' => '라이어스포커 LIAR 선언',
  'game_liars_poker_prepare_penalty' => '라이어스포커 룰렛 결과 추첨',
  'game_liars_poker_resolve_penalty' => '라이어스포커 룰렛 결과 반영',
  'game_liars_poker_ready_turn' => '라이어스포커 첫 턴 시작',
  'game_final_call_draw_card' => '파이널콜 카드 뽑기',
  'game_final_call_complete_turn' => '파이널콜 카드 교체',
  'game_final_call_declare' => '파이널콜 CALL 선언',
  'game_final_call_submit_hand' => '파이널콜 최종 카드 제출',
  _ => functionName,
};

String _communicationErrorDescription(Object error) {
  if (error is TimeoutException) return '서버 응답 시간초과';
  if (error is FirebaseFunctionsException) {
    final base = switch (error.code) {
      'unavailable' => '서버에 연결할 수 없음',
      'deadline-exceeded' => '서버 처리 시간초과',
      'unauthenticated' => '로그인 인증 만료',
      'permission-denied' => '요청 권한 없음',
      'failed-precondition' => '현재 게임 단계와 요청이 맞지 않음',
      'invalid-argument' => '요청 데이터가 올바르지 않음',
      'data-loss' => '서버 게임 데이터 누락',
      'aborted' => '서버 트랜잭션 중단',
      'internal' => '서버 내부 오류',
      _ => '서버 오류',
    };
    final message = error.message?.trim();
    final safeKoreanMessage =
        message != null &&
        message.isNotEmpty &&
        message.length <= 120 &&
        RegExp(r'^[ㄱ-ㆎ가-힣\s.,!?()\-]+$').hasMatch(message);
    return safeKoreanMessage
        ? '$base (${error.code}) · $message'
        : '$base (${error.code})';
  }
  return '클라이언트 ${error.runtimeType}';
}
