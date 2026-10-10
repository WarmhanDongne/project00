// [game_command_service.dart] 는 여러 게임이 함께 사용하는 서버의 게임 상태를 변경하는 명령을 모아둔 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Command] : 서버의 게임 상태를 변경하는 명령을 모아둔
//
// 즉, 화면에서 발생한 행동을 정해진 서버 쓰기 경계로 전달하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:game_kit/core/diagnostics/game_communication_log.dart';
import 'package:game_kit/recovery/services/callable_retry_policy.dart';
import 'package:game_kit/recovery/services/controller_room_session_store.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'package:game_kit/recovery/models/room_session_identity.dart';
import 'package:game_kit/recovery/services/game_command_batch.dart';
import 'package:game_kit/recovery/services/room_recovery_batch.dart';

// ============================================================

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
  final Map<String, Map<String, dynamic>> _unresolved = {};
  static int _traceSequence = 0;

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
    Map<String, dynamic>? capturedPayload,
    String? capturedUid,
  }) async {
    if (GameCommandBatch.current == null &&
        RoomRecoveryBatch.current == null &&
        data['roomCode'] is String &&
        data['warmup'] != true) {
      return GameCommandBatch(ownsAttempts: false).run(
        () => invoke(
          functionName,
          data,
          retryTransientFailure: retryTransientFailure,
          capturedPayload: capturedPayload,
          capturedUid: capturedUid,
        ),
      );
    }
    final roomOwner = RoomRecoveryBatch.current,
        gameOwner = GameCommandBatch.current;
    Duration? remainingBudget() {
      final game = gameOwner?.remaining, room = roomOwner?.remaining;
      if (game == null) return room;
      if (room == null) return game;
      return game < room ? game : room;
    }

    final roomCode = data['roomCode'];
    final owner = GameCommandBatch.current?.commands ?? _unresolved;
    var payload = roomCode is String
        ? controllerCommandData(roomCode, data)
        : Map<String, dynamic>.from(data);
    GameRecoverySession? session;
    String? boundUid;
    String? logicalKey;
    RoomSessionIdentity? startIdentity;
    String? retainedCommandId;
    Future<Map<String, dynamic>> Function()? retryCommand;
    var replayApplied = false;
    var startPreviouslyPending = false;
    final isStart = functionName.endsWith('_start_game');
    Map<String, dynamic> refreshEnvelope(Map<String, dynamic> retained) {
      if (boundUid == null) return retained;
      final latest = RoomSessionIdentityStore.instance.current(
        boundUid,
        retained['role'] as String,
        roomCode as String,
      );
      if (FirebaseAuth.instance.currentUser?.uid != boundUid ||
          latest == null ||
          latest.roomInstanceId != retained['roomInstanceId'] ||
          latest.membershipId != retained['membershipId']) {
        throw StateError('방 연결이 변경되었습니다.');
      }
      return {...retained, ...latest.envelope};
    }

    Future<void> releaseRetained() async {
      if (startIdentity != null && retainedCommandId != null) {
        await RoomSessionIdentityStore.instance.completeGameStart(
          startIdentity,
          retainedCommandId,
        );
      }
      if (_unresolved[logicalKey]?['commandId'] == retainedCommandId) {
        _unresolved.remove(logicalKey);
      }
      if (identical(session?.retryCommand, retryCommand)) {
        session?.retryCommand = null;
      }
    }

    if (roomCode is String && data['warmup'] != true) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || (capturedUid != null && capturedUid != uid)) {
        throw StateError('로그인 상태를 확인해주세요.');
      }
      boundUid = uid;
      final store = RoomSessionIdentityStore.instance;
      await store.load();
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        throw StateError('로그인 상태가 변경되었습니다.');
      }
      final identity =
          store.current(uid, 'controller', roomCode) ??
          store.current(uid, 'player', roomCode);
      if (identity?.role == 'player') payload.remove('controllerSessionId');
      if (identity == null) throw StateError('방 연결을 복원해주세요.');
      if (functionName == 'game_common_recovery_report' &&
          data['connectionId'] != null &&
          (data['connectionId'] != identity.connectionId ||
              data['connectionSeq'] != identity.connectionSeq)) {
        throw StateError('이전 접속의 준비 보고입니다.');
      }
      session = GameRecoverySession.forRoom(roomCode, uid);
      final isRecovery = functionName.startsWith('game_common_');
      final allowedPaused =
          isRecovery ||
          isStart ||
          functionName.endsWith('_end_game') ||
          functionName.endsWith('_leave_game') ||
          functionName.endsWith('_clear_game');

      // A known request ID must keep its original context when live data has
      // advanced after a lost response (e.g. roulette has already resolved).
      if (capturedPayload == null && data['commandId'] != null) {
        for (final entry in _unresolved.entries) {
          if (entry.key.startsWith('$uid/$functionName/') &&
              entry.value['commandId'] == data['commandId']) {
            capturedPayload = entry.value;
            break;
          }
        }
      }
      payload =
          capturedPayload ??
          {
            if (session.context != null) ...session.context!.envelope,
            ...payload,
            ...identity.envelope,
          };
      if (payload['roomInstanceId'] != identity.roomInstanceId ||
          payload['membershipId'] != identity.membershipId) {
        throw StateError('이전 참가 세션의 요청입니다.');
      }
      var retainedStart = false;
      if (isStart) {
        final input = {...data, 'roomCode': payload['roomCode']}
          ..remove('commandId')
          ..remove('operationId')
          ..remove('controllerSessionId');
        retainedStart =
            store.pendingGameStart(uid, identity.role, roomCode) != null;
        final candidateId =
            payload['commandId'] ??
            payload['operationId'] ??
            newRecoveryOperationId('start');
        payload = await store.retainGameStart(identity, functionName, input, {
          ...payload,
          'commandId': candidateId,
        });
        retainedStart = retainedStart || payload['commandId'] != candidateId;
        startPreviouslyPending = retainedStart;
        startIdentity = identity;
      }
      if (payload['roomInstanceId'] != identity.roomInstanceId ||
          payload['membershipId'] != identity.membershipId) {
        throw StateError('이전 참가 세션의 요청입니다.');
      }
      final domain = Map<String, dynamic>.from(payload)
        ..remove('commandId')
        ..remove('operationId')
        ..remove('connectionId')
        ..remove('connectionSeq')
        ..remove('controllerSessionId');
      logicalKey = '$uid/$functionName/${jsonEncode(domain)}';

      if (!isStart) {
        payload = owner.putIfAbsent(
          logicalKey,
          () =>
              _unresolved[logicalKey!] ??
              {
                ...payload,
                'commandId':
                    payload['commandId'] ??
                    payload['operationId'] ??
                    newRecoveryOperationId('command'),
              },
        );
      }
      final retained = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(payload)) as Map,
      );
      retainedCommandId = retained['commandId'] as String;
      if (retainedStart ||
          capturedPayload != null ||
          _unresolved.containsKey(logicalKey)) {
        final status = await retryPolicy.run(
          () => functions.httpsCallable('game_common_operation_status').call({
            ...refreshEnvelope(retained),
            'operationId': retained['commandId'],
          }),
          enabled: false,
          remainingBudget: remainingBudget(),
        );
        final outcome = status.data is Map
            ? (status.data as Map)['status']
            : null;
        if (outcome == 'applied') {
          // The status endpoint deliberately omits private command results.
          // Replay the exact callable to retrieve its saved response instead.
          replayApplied = true;
        }
        if (outcome == 'stale') {
          await releaseRetained();
          throw StateError('이전 게임의 요청입니다.');
        }
        if (outcome != 'applied' && outcome != 'notApplied') {
          throw StateError('요청 처리 여부를 확인하지 못했습니다. 다시 시도해주세요.');
        }
        if (!replayApplied &&
            session.context?.gameInstanceId != retained['gameInstanceId'] &&
            !isStart) {
          throw StateError('이전 게임의 요청입니다.');
        }
      }
      if (!replayApplied && !allowedPaused && !session.canSend) {
        throw StateError('게임 준비를 기다리고 있습니다.');
      }
      payload = {...retained, ...identity.envelope};
      retryCommand = () => GameCommandBatch(ownsAttempts: false).run(
        () => invoke(
          functionName,
          data,
          retryTransientFailure: true,
          capturedPayload: retained,
          capturedUid: uid,
        ),
      );
      session.retryCommand = retryCommand;
      _unresolved[logicalKey] = retained;
    }
    final traceId = 'local_${++_traceSequence}';
    final operation = _commandLabel(functionName);
    final totalElapsed = Stopwatch()..start();
    var attempt = 0;

    GameCommunicationLog.instance.add(
      level: GameCommunicationLevel.info,
      title: '$operation 요청 시작',
      detail: !isStart && retryTransientFailure ? '일시 오류 시 자동 재시도' : '단일 요청',
      operation: functionName,
      traceId: traceId,
    );

    try {
      final result = await retryPolicy.run(
        () async {
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
            payload = refreshEnvelope(payload);
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
        },
        enabled:
            !isStart &&
            retryTransientFailure &&
            GameCommandBatch.current?.ownsAttempts != true &&
            RoomRecoveryBatch.current == null,
        remainingBudget: remainingBudget(),
        isCurrent: () =>
            (boundUid == null ||
                FirebaseAuth.instance.currentUser?.uid == boundUid) &&
            (session == null ||
                !session.leaving ||
                functionName.endsWith('_leave_game')),
      );

      totalElapsed.stop();
      final success = result['success'];
      final reason = result['reason'];
      final safeReason = reason is String && _safeReasonPattern.hasMatch(reason)
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
      await releaseRetained();
      return result;
    } catch (error, stackTrace) {
      if (error is FirebaseFunctionsException &&
          (!isStart || !startPreviouslyPending) &&
          (!CallableRetryPolicy.retryableCodes.contains(error.code) ||
              (isStart && error.code == 'aborted')) &&
          error.code != 'internal' &&
          error.code != 'unknown') {
        await releaseRetained();
      }
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
  String commandId(String prefix) => newRecoveryOperationId(prefix);

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
  'game_holdem_act' => '홀덤 행동',
  'game_holdem_complete_dealing' => '홀덤 카드 배분 완료',
  'game_holdem_timeout_turn' => '홀덤 턴 시간 초과',
  'game_holdem_complete_result' => '홀덤 핸드 결과 완료',
  _ => functionName,
};

final RegExp _safeReasonPattern = RegExp(r'^[A-Za-z][A-Za-z0-9_-]{0,63}$');

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
    final details = error.details;
    final reason = details is Map ? details['reason'] : null;
    final safeReason =
        const {
          'staleConnection',
          'roomInstanceMismatch',
          'membershipMismatch',
          'staleContext',
        }.contains(reason)
        ? ' reason=$reason'
        : '';
    return '$base (${error.code})$safeReason';
  }
  return '클라이언트 ${error.runtimeType}';
}
