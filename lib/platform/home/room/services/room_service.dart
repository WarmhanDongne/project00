import 'package:game_kit/recovery/services/durable_room_operation_store.dart';
import 'package:game_kit/recovery/services/room_recovery_batch.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:game_kit/core/error/user_error_message.dart';
import 'package:game_kit/firebase/services/realtime_database_service.dart';
import 'package:game_kit/core/network/realtime_connection_monitor.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/room_action_timing.dart';
import 'package:project00/platform/home/room/services/controller_presence.dart';
import 'package:game_kit/session/controller_room_session_store.dart';
import 'package:game_kit/recovery/models/room_session_identity.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';

class RoomService {
  static const int _databaseOperationAttempts = 4;
  RoomService({
    FirebaseDatabase? database,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : realtime = database ?? RealtimeDatabaseService.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseDatabase realtime;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final _identities = RoomSessionIdentityStore.instance;
  final _operations = DurableRoomOperationStore.instance;
  Future<RoomSessionIdentity> roomIdentity(String code) => _sessionIdentity(
    code,
    ControllerRoomSessionStore.instance.sessionIdForRoom(code) != null
        ? 'controller'
        : 'player',
  );
  Future<Map<String, dynamic>> _controllerEnvelope(String code) async {
    final identity = await _sessionIdentity(code, 'controller');
    var context = GameRecoverySession.forRoom(code, identity.uid).context;
    if (context == null) {
      final snapshot = await realtime.ref('rooms/$code/game/public').get();
      if (snapshot.value is Map) {
        context = GameRecoveryContext.fromMap(snapshot.value as Map);
      }
    }
    return controllerCommandData(code, {
      ...identity.envelope,
      if (context != null) ...context.envelope,
      'operationId': newRecoveryOperationId('room'),
    });
  }

  Future<RoomSessionIdentity> _sessionIdentity(String code, String role) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const RoomCommandException('인증 정보가 없습니다.');
    await _identities.load();
    final cached = _identities.current(uid, role, code);
    if (_auth.currentUser?.uid != uid) {
      throw const RoomCommandException("로그인 상태가 변경되었습니다.");
    }
    if (cached != null) return cached;
    final response = await _call(
      'fetchRealtimeRoomSession',
      controllerCommandData(code),
    );
    if (_auth.currentUser?.uid != uid) {
      throw const RoomCommandException('로그인 상태가 변경되었습니다.');
    }
    final identity = RoomSessionIdentity.fromJson({
      ...Map<String, dynamic>.from(response.data as Map),
      'uid': uid,
      'role': role,
      'roomCode': code,
      if (role == 'controller')
        'controllerSessionId': ControllerRoomSessionStore.instance
            .sessionIdForRoom(code),
    });
    await _identities.save(identity);
    return identity;
  }

  Future<HttpsCallableResult<dynamic>> _call(String name, dynamic payload) {
    final owner = RoomRecoveryBatch.inherited;
    Future<HttpsCallableResult<dynamic>> send() =>
        _functions.httpsCallable(name).call(payload);
    return RoomActionTiming.measure(
      'callable:$name',
      () => owner != null
          ? owner.request(send)
          : send().timeout(const Duration(seconds: 8)),
    );
  }

  Future<T> _withRoomBatch<T>(Future<T> Function() action) {
    if (RoomRecoveryBatch.inherited != null &&
        RoomRecoveryBatch.current == null) {
      return Future.error(TimeoutException('이전 복구 요청이 종료되었습니다.'));
    }
    final uid = _auth.currentUser?.uid;
    return RoomRecoveryBatch().run(
      action,
      isCurrent: () => _auth.currentUser?.uid == uid,
      retryable: (error) =>
          error is TimeoutException ||
          (error is FirebaseFunctionsException &&
              const {
                'aborted',
                'unavailable',
                'deadline-exceeded',
              }.contains(error.code)),
    );
  }

  DatabaseReference _connectionReference(
    RoomSessionIdentity identity,
  ) => realtime.ref(
    'rooms/${identity.roomCode}/connections/${identity.uid}/${identity.connectionId}',
  );

  Future<User> ensureAuthenticated() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      return currentUser;
    }
    final credential = await FirebaseAuth.instance.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw const RoomCommandException('사용자 인증에 실패했습니다.');
    }
    return user;
  }

  //===================================[방 생성]=================================
  // 방 코드를 반환
  Future<String> createRoom({String? operationId}) async {
    if (RoomRecoveryBatch.current == null) {
      return _withRoomBatch(() => createRoom(operationId: operationId));
    }
    final user = _auth.currentUser;

    // 가드 조건문: 로그인 상태 확인
    if (user == null) {
      throw const RoomCommandException('방을 만들려면 로그인이 필요합니다.');
    }

    try {
      final operation = await RoomActionTiming.measure(
        'local:create_intent',
        () async {
          final operation = await _operations.begin(
            uid: user.uid,
            kind: 'create',
            scope: 'active',
            payload: {'operationId': ?operationId},
          );
          await _operations.mark(operation, 'awaitingResult');
          return operation;
        },
      );
      // cloud function 호출: 방 생성 작업 요청
      final response = await _call('createRealtimeRoom', operation['payload']);

      if (_auth.currentUser?.uid != user.uid) {
        throw const RoomCommandException('로그인 상태가 변경되었습니다.');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['status'] == 'terminal') {
        await _operations.mark(operation, 'confirmed');
        throw const RoomCommandException('이전 방은 종료되었습니다. 새 방을 만들어주세요.');
      }

      final roomCode = data['roomCode'] as String?;
      final controllerSessionId = data['controllerSessionId'] as String?;

      if (roomCode == null ||
          roomCode.isEmpty ||
          controllerSessionId == null ||
          controllerSessionId.isEmpty) {
        throw const RoomCommandException('생성된 방 코드를 확인할 수 없습니다.');
      }
      // 태블릿 기기에 roomCode와 controllerSessionId을 저장.
      await RoomActionTiming.measure('local:created_identity', () async {
        await ControllerRoomSessionStore.instance.save(
          roomCode: roomCode,
          sessionId: controllerSessionId,
        );
        await _identities.save(
          RoomSessionIdentity.fromJson({
            ...data,
            'uid': user.uid,
            'role': 'controller',
            'roomCode': roomCode,
          }),
        );
      });
      // A first, confirmed creation already owns the server's initial connection.
      // Replayed/unknown results still allocate a fresh connection through resume,
      // so an old onDisconnect reservation cannot tear down the current session.
      if (operation['state'] == 'requested' && data['connectionSeq'] == 1) {
        await markControllerConnected(roomCode);
      } else if (await restoreControllerRoom() != roomCode) {
        throw const RoomCommandException('방 연결을 확인하지 못했습니다. 다시 시도해주세요.');
      }
      if (_auth.currentUser?.uid != user.uid) {
        throw const RoomCommandException('로그인 상태가 변경되었습니다.');
      }
      await RoomActionTiming.measure(
        'local:create_confirmed',
        () => _operations.mark(operation, 'confirmed'),
      );
      // 호출한 함수에 방 코드 리턴
      return roomCode;
    } on FirebaseFunctionsException catch (error) {
      if (const {
        'aborted',
        'unavailable',
        'deadline-exceeded',
      }.contains(error.code)) {
        rethrow;
      }
      throw RoomCommandException(error.message ?? '방을 생성하지 못했습니다.');
    } catch (error) {
      if (error is RoomCommandException) {
        rethrow;
      }
      throw RoomCommandException(
        userErrorMessage(error, context: UserErrorContext.roomCommand) ??
            '방을 생성하지 못했습니다.',
      );
    }
  }

  Future<List<RoomPlayer>> getRoomPlayers(String roomCode) async {
    final snapshot = await _readWithRetry(
      realtime.ref('rooms/$roomCode/players'),
    );
    return _playersFromSnapshot(snapshot);
  }

  Stream<DatabaseEvent> watchRoom(String roomCode) {
    return realtime.ref('rooms/$roomCode/selectedGame').onValue;
  }

  /// 게임 종류와 관계없이 플랫폼 대기실이 확인하는 공통 시작 상태입니다.
  ///
  /// 게임 선택 알림보다 게임 노드가 먼저 생성되어도 현재 값을 다시 받을 수 있도록
  /// `onValue`를 사용합니다.
  Stream<String?> watchGameStatus(String roomCode) {
    return realtime
        .ref('rooms/$roomCode/game/public/status')
        .onValue
        .map((event) => event.snapshot.value?.toString());
  }

  //=======================태블릿(진행 기기) 방 수명 주기==============================
  // 방 전체를 삭제하지 않고 presence만 false로 예약합니다. 실제 삭제는
  // controller lastSeen 유예시간을 확인하는 scheduled cleanup이 담당합니다.
  Future<void> markControllerConnected(String roomCode) async {
    final identity = await _sessionIdentity(roomCode, 'controller');
    final presenceRef = _connectionReference(identity);
    await RoomActionTiming.measure(
      'rtdb:presence_write',
      () => _writeWithRetry(
        () => presenceRef.update({
          'connected': true,
          'lastSeen': ServerValue.timestamp,
        }),
      ),
    );
    // 현재 연결 상태 갱신이 복구의 성공 기준입니다. 다음 단절 예약은 Android/iOS
    // native plugin에서 일시적인 `unknown`을 낼 수 있는 보조 기능이므로, 성공한
    // 복구와 네트워크 팝업 종료를 지연하거나 실패시키지 않습니다.
    unawaited(_registerControllerDisconnectPresence(presenceRef));
  }

  Future<void> heartbeatController(String roomCode) async {
    final identity = await _sessionIdentity(roomCode, 'controller');
    await _writeWithRetry(
      () => _connectionReference(
        identity,
      ).update({'connected': true, 'lastSeen': ServerValue.timestamp}),
    );
  }

  /// 백그라운드·dispose에서는 presence만 멈추며 방을 삭제하지 않습니다.
  Future<void> markControllerDisconnected(String roomCode) async {
    final uid = _auth.currentUser?.uid;
    final identity = uid == null
        ? null
        : _identities.current(uid, 'controller', roomCode);
    if (identity == null) return;
    await _writeWithRetry(
      () => _connectionReference(
        identity,
      ).update({'connected': false, 'lastSeen': ServerValue.timestamp}),
    );
  }

  /// 사용자가 명시적으로 방을 종료했을 때만 callable로 close 상태를 만듭니다.
  Future<void> closeControllerRoom(String roomCode) async {
    if (RoomRecoveryBatch.current == null) {
      return _withRoomBatch(() => closeControllerRoom(roomCode));
    }
    final identity = await RoomActionTiming.measure(
      'local:close_identity',
      () => _sessionIdentity(roomCode, 'controller'),
    );
    try {
      await RoomActionTiming.measure(
        'rtdb:disconnect_cancel',
        () => _connectionReference(identity).onDisconnect().cancel(),
      );
    } catch (_) {
      // 서버 close가 방 종료의 권위이므로 예약 취소 실패는 계속 진행합니다.
    }
    final session = GameRecoverySession.forRoom(roomCode, identity.uid);
    session.leaving = true;
    session.invalidate();
    await _operations.load();
    final confirmed = _operations
        .recordsFor(identity.uid)
        .where(
          (entry) =>
              entry['kind'] == 'close' &&
              entry['scope'] == identity.roomInstanceId &&
              entry['state'] == 'confirmed',
        )
        .firstOrNull;
    if (confirmed != null) {
      await _identities.clear(
        identity.uid,
        "controller",
        roomCode,
        onlyRoomInstanceId: identity.roomInstanceId,
      );
      await ControllerRoomSessionStore.instance.clear(
        onlyRoomCode: roomCode,
        onlySessionId: identity.controllerSessionId,
      );
      return;
    }
    final operation = await _operations.begin(
      uid: identity.uid,
      kind: 'close',
      scope: identity.roomInstanceId,
      payload: controllerCommandData(roomCode, {
        'roomInstanceId': identity.roomInstanceId,
      }),
    );
    final needsResultLookup = operation['state'] != 'requested';
    await _operations.mark(operation, 'awaitingResult');
    final payload = Map<String, dynamic>.from(operation['payload'] as Map);
    var alreadyApplied = false;
    if (needsResultLookup) {
      final status = await _call('game_common_operation_status', payload);
      alreadyApplied = const {
        'applied',
        'stale',
      }.contains(status.data['status']);
    }
    if (!alreadyApplied) {
      await _call('closeRoom', payload);
    }
    await _operations.mark(operation, 'confirmed');
    await _identities.clear(
      identity.uid,
      "controller",
      roomCode,
      onlyRoomInstanceId: identity.roomInstanceId,
    );
    await ControllerRoomSessionStore.instance.clear(
      onlyRoomCode: roomCode,
      onlySessionId: identity.controllerSessionId,
    );
  }

  /// 앱 재실행 뒤 로컬에 보존된 controller 세션으로 방을 복원합니다.
  Future<String?> restoreControllerRoom() async {
    if (RoomRecoveryBatch.current == null) {
      return _withRoomBatch(restoreControllerRoom);
    }
    final owner = RoomRecoveryBatch.current!;
    final store = ControllerRoomSessionStore.instance;
    await store.load();
    await _identities.load();
    await _operations.load();
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final storedIdentity = _identities.latestFor(uid, 'controller');
    final roomCode = storedIdentity?.roomCode ?? store.roomCode;
    final observedToken =
        storedIdentity?.controllerSessionId ??
        (roomCode == null ? null : store.sessionIdForRoom(roomCode));
    if (storedIdentity?.controllerSessionId != null) {
      await store.save(
        roomCode: storedIdentity!.roomCode,
        sessionId: storedIdentity.controllerSessionId!,
      );
      if (_auth.currentUser?.uid != uid) return null;
    }
    final pendingClose = _operations
        .pendingFor(uid)
        .where(
          (entry) =>
              entry['kind'] == 'close' &&
              (entry['payload'] as Map)['roomCode'] == roomCode,
        )
        .firstOrNull;
    if (pendingClose != null && roomCode != null) {
      await closeControllerRoom(roomCode);
      return null;
    }
    final sessionId = roomCode == null
        ? null
        : store.sessionIdForRoom(roomCode);
    if (roomCode == null || sessionId == null) return null;
    try {
      final identity = await _sessionIdentity(roomCode, 'controller');
      bool current() {
        final saved = _identities.current(uid, 'controller', roomCode);
        return _auth.currentUser?.uid == uid &&
            owner.remaining > Duration.zero &&
            identical(RoomRecoveryBatch.current, owner) &&
            store.sessionIdForRoom(roomCode) == sessionId &&
            saved?.roomInstanceId == identity.roomInstanceId &&
            saved?.connectionId == identity.connectionId &&
            saved?.connectionSeq == identity.connectionSeq;
      }

      void requireCurrent() {
        if (!current()) throw StateError('이전 방 복구 요청입니다.');
      }

      requireCurrent();
      final pending = _identities.pending(identity.uid, 'controller', roomCode);
      final expectedSequence = identity.connectionSeq;
      if (pending != null) {
        // A timed-out resume may already have replaced the server connection.
        // Recover that current connection before replaying a delayed request.
        Future<RoomSessionIdentity> readCurrentIdentity() async {
          final latest = await _call(
            'fetchRealtimeRoomSession',
            controllerCommandData(roomCode),
          );
          requireCurrent();
          final data = Map<String, dynamic>.from(latest.data as Map);
          if (data['roomInstanceId'] != identity.roomInstanceId ||
              data['roomStatus'] == 'closed' ||
              data['roomStatus'] == 'terminal') {
            throw FirebaseFunctionsException(
              code: 'failed-precondition',
              message: '이미 종료된 방입니다.',
            );
          }
          return RoomSessionIdentity.fromJson({
            ...data,
            'uid': identity.uid,
            'controllerSessionId': sessionId,
            'role': 'controller',
            'roomCode': roomCode,
          });
        }

        var latestIdentity = await readCurrentIdentity();
        if (latestIdentity.connectionSeq <= expectedSequence) {
          try {
            await _call('resumeRealtimeControllerRoom', pending);
          } on FirebaseFunctionsException catch (error) {
            if (error.code != 'aborted' ||
                error.details is! Map ||
                (error.details as Map)['reason'] != 'staleConnection') {
              rethrow;
            }
          }
          requireCurrent();
          latestIdentity = await readCurrentIdentity();
        }
        if (latestIdentity.connectionSeq <= expectedSequence) {
          throw StateError('현재 방 접속을 확인하지 못했습니다.');
        }
        await _identities.save(
          latestIdentity,
          completedOperationId: pending['operationId'] as String,
          isCurrent: current,
        );
        await markControllerConnected(roomCode);
        return roomCode;
      }
      final payload = {
        'roomCode': roomCode,
        'controllerSessionId': sessionId,
        'roomInstanceId': identity.roomInstanceId,
        'expectedConnectionSeq': expectedSequence,
        'operationId': newRecoveryOperationId('resume'),
      };
      await _identities.savePending(
        identity.uid,
        'controller',
        roomCode,
        payload,
        isCurrent: current,
      );
      final resumed = await _call('resumeRealtimeControllerRoom', payload);
      requireCurrent();
      await _identities.save(
        RoomSessionIdentity.fromJson({
          ...Map<String, dynamic>.from(resumed.data as Map),
          'uid': identity.uid,
          'controllerSessionId':
              identity.controllerSessionId ?? store.sessionIdForRoom(roomCode),
          'role': 'controller',
          'roomCode': roomCode,
        }),
        completedOperationId: payload['operationId'] as String,
        isCurrent: current,
      );
      await markControllerConnected(roomCode);
      return roomCode;
    } on FirebaseFunctionsException catch (error) {
      if (_auth.currentUser?.uid != uid) rethrow;
      if (error.code == 'not-found' ||
          error.code == 'permission-denied' ||
          error.code == 'failed-precondition') {
        await store.clear(onlyRoomCode: roomCode, onlySessionId: observedToken);
        await _identities.clear(
          uid,
          "controller",
          roomCode,
          onlyRoomInstanceId: storedIdentity?.roomInstanceId,
        );
        return null;
      }
      rethrow;
    }
  }

  /// 태블릿의 현재 접속 표시입니다.
  ///
  /// `false`는 백그라운드·강제 종료·순간적인 네트워크 단절을 뜻할 수 있으므로
  /// 방 종료 신호로 사용하지 않습니다. 값이 없으면 방 삭제와 초기 캐시 미수신을
  /// 구분할 수 없으므로 `null`을 유지하고 별도의 방 생존 마커로 확인합니다.
  /// 태블릿의 접속 표시와 마지막 heartbeat 시각을 **함께** 구독합니다.
  ///
  /// `connected`만 보면 태블릿이 강제 종료·크래시·전원 차단으로
  /// `markControllerDisconnected`를 보낼 기회조차 없었던 경우를 영원히 알 수
  /// 없습니다. 그 값이 `true`로 굳어 참가자에게 아무 안내도 뜨지 않습니다.
  ///
  /// `lastSeen`은 `ServerValue.timestamp`로 기록되므로 서버 시각입니다.
  /// 판정에는 반드시 `ServerClock.nowMillis()`를 쓰세요.
  Stream<ControllerPresence> watchControllerPresence(String roomCode) {
    return realtime
        .ref('rooms/${roomCode.trim().toUpperCase()}/controllerPresence')
        .onValue
        .map((event) => ControllerPresence.fromValue(event.snapshot.value));
  }

  //[observe] 특정 방의 현재 상태를 파베에서 실시간으로 감시
  Stream<String?> watchRoomStatus(String roomCode) => realtime
      .ref('rooms/$roomCode/status')
      .onValue
      .map((event) => event.snapshot.value?.toString());

  /// 방 전체를 읽지 않고 생성 시부터 삭제까지 유지되는 공개 roomCode 마커를
  /// 구독합니다. `false` 이벤트는 서버 재조회로 한 번 더 확인한 뒤 사용합니다.
  Stream<bool> watchRoomExists(String roomCode) => realtime
      .ref('rooms/${roomCode.trim().toUpperCase()}/roomCode')
      .onValue
      .map((event) => event.snapshot.exists);

  /// 캐시의 일시적인 null이 아니라 서버에서도 방 마커가 사라졌는지 확인합니다.
  Future<bool> roomExists(String roomCode) async {
    final snapshot = await _readWithRetry(
      realtime.ref('rooms/${roomCode.trim().toUpperCase()}/roomCode'),
    );
    return snapshot.exists;
  }

  Stream<List<RoomPlayer>> watchRoomPlayers(String roomCode) {
    return realtime
        .ref('rooms/$roomCode/players')
        .onValue
        .map((event) => _playersFromSnapshot(event.snapshot));
  }

  //[method] Firebase 서버와 이 앱 인스턴스의 실제 연결 상태 파악하는 메서드.
  Stream<bool> watchServerConnection() =>
      RealtimeConnectionMonitor.instance.watch(realtime);

  Future<Map<String, dynamic>> gameTarget(String roomCode) async {
    final identity = await _sessionIdentity(roomCode, 'controller');
    final snapshot = await realtime.ref('rooms/$roomCode/game/public').get();
    if (snapshot.value is! Map) throw StateError('게임 정보를 확인할 수 없습니다.');
    final context = GameRecoveryContext.fromMap(snapshot.value as Map);
    return {'roomCode': roomCode, ...identity.envelope, ...context.envelope};
  }

  Future<void> clearCapturedGame(Map<String, dynamic> target) async {
    final identity = await _sessionIdentity(
      target['roomCode'] as String,
      'controller',
    );
    if (identity.roomInstanceId != target['roomInstanceId']) return;
    await _call(
      'selectRealtimeRoomGame',
      controllerCommandData(identity.roomCode, {
        ...target,
        'gameId': null,
        'operationId': newRecoveryOperationId('cleanup'),
      }),
    );
  }

  //게임 선택
  Future<void> selectGame({
    required String roomCode,
    required String? gameId,
  }) async {
    await _call('selectRealtimeRoomGame', {
      ...await _controllerEnvelope(roomCode),
      'gameId': gameId,
    });
  }

  /// 서버에서 `waiting → seating`을 확정한 뒤 잠긴 최신 참가자 명단을 반환합니다.
  Future<List<RoomPlayer>> beginPlayerSeating(String roomCode) async {
    await _call(
      'beginRealtimeRoomSeating',
      await _controllerEnvelope(roomCode),
    );
    return getRoomPlayers(roomCode);
  }

  List<RoomPlayer> _playersFromSnapshot(DataSnapshot snapshot) {
    final value = snapshot.value;
    if (!snapshot.exists || value is! Map) {
      return const [];
    }

    return value.entries
        .where((entry) => entry.value is Map)
        .map(
          (entry) => RoomPlayer.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
            key: entry.key.toString(),
          ),
        )
        .where((player) => player.isPlayer && player.isActive)
        .toList(growable: false);
  }

  Future<void> savePlayerSeatIndexes({
    required String roomCode,
    required Map<String, int> seatIndexesByUid,
  }) async {
    await _call('saveRealtimePlayerSeatIndexes', {
      ...await _controllerEnvelope(roomCode),
      'seatIndexesByUid': seatIndexesByUid,
    });
  }

  Future<void> removePlayer(String roomCode, String userUid) async {
    await _call('removeRealtimeRoomPlayer', {
      ...await _controllerEnvelope(roomCode),
      'playerUid': userUid,
    });
  }

  /// 태블릿이 발견한 stale 후보를 서버가 최신 heartbeat와 함께 재검증합니다.
  /// 정상 heartbeat에서는 호출하지 않으며, 실제 후보 한 건에만 호출합니다.
  Future<void> reportStalePlayer({
    required String roomCode,
    required String playerUid,
    required int observedLastSeen,
  }) async {
    final player =
        (await realtime.ref('rooms/$roomCode/players/$playerUid').get()).value;
    if (player is! Map) return;
    final payload = {
      ...await _controllerEnvelope(roomCode),
      'commandId': newRecoveryOperationId('stale'),
      'role': 'controller',
      'playerUid': playerUid,
      'observedLastSeen': observedLastSeen,
      'playerConnectionId': player['currentConnectionId'],
      'playerConnectionSeq': player['connectionSeq'],
    };
    await _call(
      'game_common_interruption_report_stale_player',
      payload,
    ).timeout(const Duration(seconds: 8));
  }

  /// 휴대폰이 본 진행 기기 heartbeat 정체를 서버가 현재 접속과 다시 대조합니다.
  Future<void> reportStaleController({
    required String roomCode,
    required int observedLastSeen,
  }) async {
    final identity = await _sessionIdentity(roomCode, 'player');
    var context = GameRecoverySession.forRoom(roomCode, identity.uid).context;
    if (context == null) {
      final snapshot = await realtime.ref('rooms/$roomCode/game/public').get();
      if (snapshot.value is Map) {
        context = GameRecoveryContext.fromMap(snapshot.value as Map);
      }
    }
    if (context == null) return;
    final payload = {
      ...identity.envelope,
      ...context.envelope,
      'commandId': newRecoveryOperationId('stale_controller'),
      'observedLastSeen': observedLastSeen,
    };
    await _call(
      'game_common_interruption_report_stale_controller',
      payload,
    ).timeout(const Duration(seconds: 8));
  }

  // ========================================================== phone ==================================================================

  /// 실제 플레이어 노드를 만들기 전에 방 코드와 현재 입장 가능 상태만 검증합니다.
  Future<void> validateRoomJoin(String roomCode) async {
    final code = roomCode.trim().toUpperCase();
    try {
      await _call('validateRealtimeRoom', {'roomCode': code});
    } on FirebaseFunctionsException catch (error) {
      throw RoomCommandException(
        error.message ?? '방 정보를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<void> joinRoom(
    String roomCode,
    String nickname, {
    required String characterId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const RoomCommandException('인증 정보가 없습니다.');
    }

    final code = roomCode.trim().toUpperCase();
    await _joinRoomWithRetry(
      roomCode: code,
      nickname: nickname,
      characterId: characterId,
      // 설정 화면에서 확정한 값을 사용합니다. 앱 재시작·네트워크 복구 경로만
      // preserveProfile=true로 기존 방 프로필을 유지합니다.
      preserveProfile: false,
    );

    // 참가 저장은 Cloud Function에서 완료됩니다. 접속 종료 표시는 보조
    // 기능이므로 클라이언트에서 한 번만 예약하고 실패해도 입장은 유지합니다.
    final playerRef = _connectionReference(
      await _sessionIdentity(code, 'player'),
    );
    await _registerDisconnectPresence(playerRef);
  }

  /// 네트워크가 돌아온 플레이어의 presence와 onDisconnect 예약을 복원합니다.
  ///
  /// 서버에서 기존 UID를 먼저 merge하므로 seat와 game/private 상태는 그대로
  /// 유지되고 `isConnected`만 true가 됩니다. 다음 단절 예약은 보조 기능으로
  /// 비동기 등록해 native `unknown`이 실제 복구를 실패시키지 않게 합니다.
  Future<void> restorePlayerConnection({
    required String roomCode,
    required String nickname,
    required String characterId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const RoomCommandException('인증 정보가 없습니다.');
    }
    final code = roomCode.trim().toUpperCase();
    await _joinRoomWithRetry(
      roomCode: code,
      nickname: nickname,
      characterId: characterId,
      preserveProfile: true,
    );
    final playerRef = _connectionReference(
      await _sessionIdentity(code, 'player'),
    );
    unawaited(_registerDisconnectPresence(playerRef));
  }

  /// 저장된 세션으로 무엇을 복원할 수 있는지 확인합니다.
  ///
  /// 대기실과 진행 중 게임을 구분해 돌려줍니다. 화면이 `그룹 다시 참여`와
  /// `게임 다시 참여` 중 무엇을 보여 줄지 정하는 근거입니다(P-01).
  ///
  /// 이 확인 없이 join callable을 호출하면 대기 중인 방에서 강퇴된 사용자를 새
  /// 참가자로 다시 만들 수 있으므로, 자동 재접속 경로에서는 반드시 선행합니다.
  Future<RestorableSession> restorableSession(String roomCode) async {
    final user = _auth.currentUser;
    if (user == null) return RestorableSession.none;
    final code = roomCode.trim().toUpperCase();
    // players는 인증 사용자에게 독립적으로 읽기가 허용됩니다. 먼저 참가자 노드를
    // 확인해야, 이미 제거된 사용자가 status/game을 읽다가 permission-denied가 나
    // 로컬 유령 세션을 계속 보존하는 일을 막을 수 있습니다.
    final playerSnapshot = await _readWithRetry(
      realtime.ref('rooms/$code/players/${user.uid}'),
    );
    final playerValue = playerSnapshot.value;
    final playerStatus = playerValue is Map
        ? playerValue['status']?.toString()
        : null;
    if (!playerSnapshot.exists || playerStatus != 'active') {
      return RestorableSession.none;
    }

    final snapshots = await Future.wait([
      _readWithRetry(realtime.ref('rooms/$code/status')),
      _readWithRetry(realtime.ref('rooms/$code/selectedGame')),
      _readWithRetry(realtime.ref('rooms/$code/game/public/status')),
    ]);
    return restorablePlayerSession(
      playerExists: true,
      playerStatus: playerStatus,
      roomStatus: snapshots[0].value?.toString(),
      selectedGameId: snapshots[1].value?.toString(),
      gameStatus: snapshots[2].value?.toString(),
      privateGameDataExists: true,
    );
  }

  Future<void> markPlayerDisconnected(String roomCode) async {
    final uid = _auth.currentUser?.uid;
    final identity = uid == null
        ? null
        : _identities.current(uid, 'player', roomCode);
    if (identity == null) return;
    await _connectionReference(
      identity,
    ).update({'connected': false, 'lastSeen': ServerValue.timestamp});
  }

  Future<void> heartbeatPlayer(String roomCode) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final identity = await _sessionIdentity(roomCode, 'player');
    await _writeWithRetry(
      () => _connectionReference(
        identity,
      ).update({'connected': true, 'lastSeen': ServerValue.timestamp}),
    );
  }

  /// 이미 참가한 플레이어의 닉네임과 방 캐릭터를 갱신합니다.
  Future<void> updateRoomPlayerProfile(
    String roomCode,
    String nickname, {
    required String characterId,
  }) => _joinRoomWithRetry(
    roomCode: roomCode.trim().toUpperCase(),
    nickname: nickname,
    characterId: characterId,
    preserveProfile: false,
  );

  Future<void> _joinRoomWithRetry({
    required String roomCode,
    required String nickname,
    required String characterId,
    required bool preserveProfile,
  }) async {
    if (RoomRecoveryBatch.current == null) {
      return _withRoomBatch(
        () => _joinRoomWithRetry(
          roomCode: roomCode,
          nickname: nickname,
          characterId: characterId,
          preserveProfile: preserveProfile,
        ),
      );
    }
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const RoomCommandException('인증 정보가 없습니다.');
    await _identities.load();
    await _operations.load();
    if (_operations
        .pendingFor(uid)
        .any(
          (entry) =>
              entry['kind'] == 'leave' &&
              (entry['payload'] as Map)['roomCode'] == roomCode,
        )) {
      throw const RoomCommandException('퇴장 결과를 먼저 확인해주세요.');
    }
    final pending = _identities.pending(uid, 'player', roomCode);
    final owner = RoomRecoveryBatch.current!;
    final capturedIdentity = _identities.current(uid, 'player', roomCode);
    bool current() =>
        _auth.currentUser?.uid == uid &&
        owner.remaining > Duration.zero &&
        identical(RoomRecoveryBatch.current, owner) &&
        (_identities.current(uid, 'player', roomCode)?.roomInstanceId ==
            capturedIdentity?.roomInstanceId) &&
        (_identities.current(uid, 'player', roomCode)?.membershipId ==
            capturedIdentity?.membershipId);
    void requireCurrent() {
      if (!current()) throw StateError('이전 방 복구 요청입니다.');
    }

    if (pending != null) {
      try {
        await _call('joinRealtimeRoom', pending);
        requireCurrent();
        // A saved allocation result may describe a connection since replaced.
        // Adopt the server's current membership instead of allocating again.
        final confirmed = await _call('fetchRealtimeRoomSession', {
          'roomCode': roomCode,
        });
        requireCurrent();
        final identity = RoomSessionIdentity.fromJson({
          ...Map<String, dynamic>.from(confirmed.data as Map),
          'uid': uid,
          'role': 'player',
          'roomCode': roomCode,
        });
        if (identity.roomInstanceId != pending['roomInstanceId'] ||
            (pending['membershipId'] != null &&
                identity.membershipId != pending['membershipId'])) {
          throw const RoomCommandException('이 방에는 다시 참가할 수 없습니다.');
        }
        await _identities.save(
          identity,
          completedOperationId: pending['operationId'] as String,
          isCurrent: current,
        );
        if (!preserveProfile &&
            (pending['nickname'] != nickname ||
                pending['characterId'] != characterId)) {
          // A different explicit profile edit is a new logical request.
          return await _joinRoomWithRetry(
            roomCode: roomCode,
            nickname: nickname,
            characterId: characterId,
            preserveProfile: false,
          );
        }
        return;
      } on FirebaseFunctionsException catch (error) {
        if (error.code != 'aborted' ||
            error.details is! Map ||
            (error.details as Map)['reason'] != 'staleConnection') {
          rethrow;
        }
      }
    }
    // Independent reads; the join transaction still checks both generations.
    final snapshots = await Future.wait([
      _readWithRetry(realtime.ref('rooms/$roomCode/roomInstanceId')),
      _readWithRetry(realtime.ref('rooms/$roomCode/players/$uid')),
    ]);
    final roomId = snapshots[0].value;
    final player = snapshots[1].value;
    final membership = player is Map ? player['membershipId'] : null;
    final sequence = player is Map ? player['connectionSeq'] : null;
    requireCurrent();
    final previousIdentity = _identities.current(uid, 'player', roomCode);
    if (preserveProfile &&
        (player is! Map ||
            player['status'] != 'active' ||
            (previousIdentity != null &&
                (previousIdentity.roomInstanceId != roomId ||
                    previousIdentity.membershipId != membership)))) {
      throw const RoomCommandException('이 방에는 다시 참가할 수 없습니다.');
    }
    final payload = {
      'roomCode': roomCode,
      'roomInstanceId': roomId,
      'nickname': nickname,
      'characterId': characterId,
      'preserveProfile': preserveProfile,
      'operationId': newRecoveryOperationId('join'),
      'membershipId': ?membership,
      'expectedConnectionSeq': sequence ?? 0,
    };
    await _identities.savePending(
      uid,
      'player',
      roomCode,
      payload,
      isCurrent: current,
    );
    requireCurrent();
    final response = await _call('joinRealtimeRoom', payload);
    requireCurrent();
    await _identities.save(
      RoomSessionIdentity.fromJson({
        ...Map<String, dynamic>.from(response.data as Map),
        'uid': uid,
        'role': 'player',
        'roomCode': roomCode,
      }),
      completedOperationId: payload['operationId'] as String,
      isCurrent: current,
    );
  }

  /// 내 참가자 노드가 아직 방에 살아 있는지만 확인합니다.
  ///
  /// [hasExistingPlayer]는 방 상태와 게임 상태까지 함께 요구해 정상 참가자에게도
  /// false를 줄 수 있으므로 퇴장 완료 판정에는 쓰지 않습니다.
  Future<bool> hasActivePlayerNode(String roomCode) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final code = roomCode.trim().toUpperCase();
    final snapshot = await _readWithRetry(
      realtime.ref('rooms/$code/players/${user.uid}'),
    );
    if (!snapshot.exists) return false;
    final value = snapshot.value;
    return value is Map && value['status']?.toString() == 'active';
  }

  Future<void> leaveRoom(String roomCode) =>
      _callLeave(cloudFunctionName: 'leaveRealtimeRoom', roomCode: roomCode);

  /// 진행 중인 게임에서 퇴장합니다.
  ///
  /// 플레이어 삭제와 다음 턴 결정은 [cloudFunctionName]으로 지정한 게임별 Cloud
  /// Function 트랜잭션이 함께 처리하며, 클라이언트는 기존 연결 종료 예약만 먼저
  /// 취소합니다.
  Future<void> leaveGame({
    required String cloudFunctionName,
    required String roomCode,
  }) => _callLeave(cloudFunctionName: cloudFunctionName, roomCode: roomCode);

  /// 대기실 퇴장과 게임 중 퇴장이 재시도 정책과 연결 예약 취소를 공유합니다.
  ///
  /// 예전에는 대기실 퇴장에만 재시도가 없어 일시적인 네트워크 오류로 곧바로
  /// 실패했고, 게임 중 퇴장의 인라인 재시도는 시도별 타임아웃이 없어 최악의 경우
  /// callable 기본 70초 × 4회를 기다렸습니다. 두 퇴장 callable 모두 이미 나간
  /// 사용자에게 성공으로 답하는 멱등 함수라 같은 정책을 공유해도 안전합니다.
  ///
  /// 원본 예외는 감싸지 않고 그대로 올려보냅니다. 호출자가 오류 코드를 보고
  /// 사용자 문구를 결정하므로, 여기서 문자열로 바꾸면 그 판단 근거가 사라집니다.
  Future<void> _callLeave({
    required String cloudFunctionName,
    required String roomCode,
  }) async {
    if (RoomRecoveryBatch.current == null) {
      return _withRoomBatch(
        () => _callLeave(
          cloudFunctionName: cloudFunctionName,
          roomCode: roomCode,
        ),
      );
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw const RoomCommandException('인증 정보가 없습니다.');
    }

    final code = roomCode.trim().toUpperCase();
    await _operations.load();
    await _identities.load();
    final identity = _identities.current(user.uid, 'player', code);
    final previous = _operations
        .recordsFor(user.uid)
        .where(
          (entry) =>
              entry['kind'] == 'leave' &&
              (entry['payload'] as Map)['roomCode'] == code &&
              (identity == null ||
                  (entry['payload'] as Map)['membershipId'] ==
                      identity.membershipId),
        )
        .firstOrNull;
    if (previous?['state'] == 'confirmed') return;
    final target = previous == null
        ? identity ?? await _sessionIdentity(code, 'player')
        : identity;
    final session = GameRecoverySession.forRoom(code, user.uid);
    session.leaving = true;
    session.invalidate();
    final operation =
        previous ??
        await _operations.begin(
          uid: user.uid,
          kind: 'leave',
          scope: '${target!.roomInstanceId}/${target.membershipId}',
          payload: {
            'roomCode': code,
            'roomInstanceId': target.roomInstanceId,
            'membershipId': target.membershipId,
          },
        );
    final payload = Map<String, dynamic>.from(operation['payload'] as Map);
    final needsResultLookup = operation['state'] != 'requested';
    await _operations.mark(operation, 'awaitingResult');
    try {
      if (identity != null) {
        await _connectionReference(identity).onDisconnect().cancel();
      }
    } catch (_) {}
    var alreadyApplied = false;
    if (needsResultLookup) {
      final status = await _call('game_common_operation_status', payload);
      alreadyApplied = const {
        'applied',
        'stale',
      }.contains(status.data['status']);
    }
    if (!alreadyApplied) {
      final response = await _call(cloudFunctionName, payload);
      final leaveResult = Map<String, dynamic>.from(response.data as Map);
      if (!const {'applied', 'stale'}.contains(leaveResult['status'])) {
        throw const RoomCommandException('퇴장 결과를 확인하고 있습니다. 다시 확인해주세요.');
      }
    }
    await _operations.mark(operation, 'confirmed');
    await _identities.clear(
      user.uid,
      'player',
      code,
      onlyRoomInstanceId: payload['roomInstanceId'] as String,
    );
  }

  /// iOS에서 일시적인 native `unknown` 오류가 발생해도 같은 읽기를 재시도합니다.
  Future<DataSnapshot> _readWithRetry(DatabaseReference reference) async {
    if (RoomRecoveryBatch.inherited != null) {
      return RoomRecoveryBatch.inherited!.request(reference.get);
    }
    Object? lastError;

    for (var attempt = 0; attempt < _databaseOperationAttempts; attempt += 1) {
      try {
        return await reference.get();
      } catch (error) {
        lastError = error;
        if (!_isTransientDatabaseError(error) ||
            attempt == _databaseOperationAttempts - 1) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 180 * (attempt + 1)));
      }
    }

    throw RoomCommandException(_databaseErrorMessage(lastError));
  }

  /// set/update/remove는 같은 값을 다시 적용해도 안전한 작업만 전달받습니다.
  Future<void> _writeWithRetry(Future<void> Function() operation) async {
    if (RoomRecoveryBatch.inherited != null) {
      return RoomRecoveryBatch.inherited!.request(operation);
    }
    Object? lastError;

    for (var attempt = 0; attempt < _databaseOperationAttempts; attempt += 1) {
      try {
        await operation();
        return;
      } catch (error) {
        lastError = error;
        if (!_isTransientDatabaseError(error) ||
            attempt == _databaseOperationAttempts - 1) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 180 * (attempt + 1)));
      }
    }

    if (lastError != null && isPermissionDenied(lastError)) throw lastError;
    throw RoomCommandException(_databaseErrorMessage(lastError));
  }

  /// 접속 여부 표시는 보조 기능이므로 예약 실패가 방 입장을 중단시키지 않습니다.
  Future<void> _registerDisconnectPresence(DatabaseReference playerRef) async {
    try {
      await playerRef.onDisconnect().update({'connected': false});
    } catch (_) {
      // 실시간 게임 데이터와 재접속은 UID 기준이므로 presence 예약 없이도 안전합니다.
    }
  }

  Future<void> _registerControllerDisconnectPresence(
    DatabaseReference presenceRef,
  ) async {
    try {
      await presenceRef.onDisconnect().update({'connected': false});
    } catch (_) {
      // controller heartbeat와 scheduled cleanup이 최종 상태를 정리합니다.
    }
  }

  bool _isTransientDatabaseError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('firebase_database/unknown') ||
        message.contains('stacktrace:') ||
        message.contains('network') ||
        message.contains('disconnected') ||
        message.contains('unavailable') ||
        message.contains('timeout');
  }

  String _databaseErrorMessage(Object? error) {
    if (error != null && isPermissionDenied(error)) {
      return '방에 접근할 권한이 없습니다.';
    }
    return '서버 연결이 불안정합니다. 잠시 후 다시 시도해주세요.';
  }
}
