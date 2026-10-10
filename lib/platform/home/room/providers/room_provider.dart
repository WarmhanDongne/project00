import 'package:game_kit/recovery/services/room_recovery_batch.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'package:game_kit/core/diagnostics/recovery_metrics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kDebugMode, listEquals;
import 'package:flutter/material.dart';
import 'package:game_kit/core/diagnostics/dev_error_log.dart';
import 'package:game_kit/core/error/user_error_message.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/template_game.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/room_leave_intent.dart';
import 'package:project00/platform/home/room/services/controller_presence.dart';
import 'package:game_kit/session/controller_room_session_store.dart';
import 'package:project00/platform/home/room/services/player_room_session_store.dart';
import 'package:project00/platform/home/room/services/player_presence.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/home/room/services/room_action_timing.dart';
import 'package:project00/platform/home/room/providers/room_command_executor.dart';

//==============================================================================
//
//==============================================================================
//

// listenRoom 등의 메서드에서 사용되는 enum 정의
enum RoomDataLoadStatus { idle, loading, loaded, failure }

enum ControllerPresenceState { unknown, connected, reconnecting }

enum RoomTerminationReason { closed, deleted }

class RoomProvider extends GameRoomContext with WidgetsBindingObserver {
  RoomProvider({
    RoomService? service,
    GameService? gameService,
    this.gameCatalog = const EmptyGameCatalog(),
    RoomCommandExecutor? commandExecutor,
    @visibleForTesting String? Function()? currentUidReader,
  }) : //서비스 객체 전달
       _service = service ?? RoomService(),
       _gameService = gameService ?? GameService(),
       _commandExecutor = commandExecutor ?? const RoomCommandExecutor(),
       _currentUid = currentUidReader ?? _firebaseUid {
    try {
      _lifecycleBinding = WidgetsBinding.instance;
      _lifecycleBinding!.addObserver(this);
    } catch (_) {
      /* pure Dart callers have no binding */
    }
  }

  WidgetsBinding? _lifecycleBinding;

  /// Firebase를 초기화하지 않는 순수 위젯·단위 테스트에서도 참가자 판정 코드가
  /// 그대로 실행되도록, 현재 UID 조회를 한곳으로 모읍니다.
  static String? _firebaseUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  // 룸 서비스 객체 보관
  final RoomService _service;
  final GameService _gameService;
  // 익스큐터 객체 보관
  final RoomCommandExecutor _commandExecutor;
  final GameCatalog gameCatalog;
  final String? Function() _currentUid;

  @override
  String? roomCode;
  StreamSubscription<DatabaseEvent>? roomSubscription;
  StreamSubscription<List<RoomPlayer>>? playerSubscription;
  StreamSubscription<bool>? connectionSubscription;
  StreamSubscription<String?>? statusSubscription;
  StreamSubscription<ControllerPresence>? controllerPresenceSubscription;
  StreamSubscription<bool>? roomExistenceSubscription;

  @override
  List<RoomPlayer> players = [];
  List<GameInfo> groupGames = [];
  RoomDataLoadStatus groupGamesLoadStatus = RoomDataLoadStatus.idle;
  String? groupGamesError;
  bool isLoading = false;
  final Set<String> _removingPlayerUids = <String>{};
  bool get isRemovingAnyPlayer => _removingPlayerUids.isNotEmpty;
  bool isRemovingPlayer(String uid) => _removingPlayerUids.contains(uid);
  bool get isInRoom => roomCode != null; // 사용자가 Room 안인지 판단하는 기준 변수.

  /// 이 앱 인스턴스가 RTDB 서버에 연결된 상태인지입니다.
  ///
  /// controller heartbeat가 오래됐다는 판정은 로컬 연결이 살아 있을 때만
  /// 사용자에게 보여야 합니다. 휴대폰 자체가 오프라인이면 캐시된 lastSeen도
  /// 함께 늙으므로, 그 값을 태블릿 장애로 표시하면 원인을 거꾸로 안내합니다.
  bool get isServerConnected => _isServerConnected;

  /// 이 기기 참가자의 캐릭터 ID입니다. 연결 끊김 장면에 내 얼굴을 그릴 때 씁니다.
  String? get currentCharacterId {
    final uid = _currentUid();
    for (final player in players) {
      if (player.uid == uid) return player.characterId;
    }
    return _joinedCharacterId;
  }

  /// 퇴장 요청이 진행 중입니다. 나가기 버튼 비활성화와 중복 탭 판정에 씁니다.
  @override
  bool get isLeaving => _isLeaving;

  bool wasKicked = false;
  bool wasRoomClosed = false;

  /// 서버가 관리하는 방 상태입니다(`waiting`/`seating`/`playing`/`finished`/`closed`).
  ///
  /// 화면이 `selectedGame`만 보고 판단하면 게임이 끝난 뒤에도 룰북과
  /// `곧 시작합니다`가 남습니다. 종료 경로 어디에서도 `selectedGame`을 지우지
  /// 않기 때문입니다(P-02). 아직 아무 값도 받지 못했으면 null입니다.
  String? roomStatus;

  /// 이 방의 게임이 끝나 대기실로 돌아가야 하는 상태입니다.
  bool get isRoomFinished => roomStatus == 'finished';
  ControllerPresenceState controllerPresenceState =
      ControllerPresenceState.unknown;
  RoomTerminationReason? roomTerminationReason;
  bool _hasJoined = false;
  bool _isLeaving = false;
  bool _leaveRequestInFlight = false;
  bool _pendingControllerRestore = false, _controllerRestoreInFlight = false;

  /// 방 세션 세대입니다. 저장 세션 복원처럼 여러 await를 거치는 작업이 그동안
  /// 방이 바뀌었는지 판정하는 데 씁니다.
  int _sessionEpoch = 0;
  int _connectionEpoch = 0;
  int _roomExistenceRevision = 0;
  bool _wasServerDisconnected = false;
  bool _isServerConnected = false;
  bool _roomMissingCandidate = false;
  Future<void>? _roomDeletionConfirmation;
  int _playerRemovalCheckId = 0;
  Future<void>? _connectionRecoveryFuture;
  (String?, String?, int, int, String?)? _confirmedRecovery;
  bool _heartbeatPermissionRecoveryAttempted = false;
  RoomRecoveryBatch? _requestedRecoveryOwner;
  GameRecoverySession? _reconnectSession;
  Future<void> Function()? _reconnectCallback;
  Timer? _controllerHeartbeatTimer;
  Timer? _playerHeartbeatTimer;
  bool _controllerHeartbeatInFlight = false;
  int _controllerHeartbeatFailures = 0;
  bool _controllerHeartbeatRecoveryStarted = false;

  /// 태블릿 heartbeat가 유예를 넘겼는지 다시 판정하는 타이머입니다.
  ///
  /// heartbeat가 끊기면 RTDB 이벤트도 함께 끊기므로, 구독만으로는 "값이 오지
  /// 않는 상태"를 알 수 없습니다. 마지막으로 받은 lastSeen을 들고 시계를
  /// 직접 돌려야 합니다.
  Timer? _controllerPresenceTimer;
  Timer? _playerPresenceTimer;
  bool _ownsControllerSession = false;
  final PlayerStaleReportTracker _staleReportTracker =
      PlayerStaleReportTracker();
  final Set<String> _staleReportInFlight = <String>{};
  int? _controllerStaleReportLastSeen;
  int _controllerStaleReportAttempts = 0;
  bool _controllerStaleReportInFlight = false;
  ControllerPresence _controllerPresence = ControllerPresence.unknown;
  String? _joinedNickname;
  String? _joinedCharacterId;
  List<String>? _lastGroupGameUids;
  int _groupGamesRequestId = 0;
  int _selectedGameRequestId = 0;
  String? _pendingCreateRoomOperationId;

  String? errorMessage;
  String? selectedGameId;
  @override
  GameInfo? selectedGame;
  RoomDataLoadStatus selectedGameLoadStatus = RoomDataLoadStatus.idle;
  String? selectedGameError;

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  //======================[ 방 명령의 상태 관리용 공통 실행 함수]====================
  // 화면 상태 관리 및 _commandExecutor에게 함수 전달
  Future<T?> _runCommand<T>(Future<T> Function() command) async {
    // 버튼이 비활성화되기 전 연타 입력이 이미 큐에 들어온
    // 경우에도 동일한 방 명령이 중복 실행되지 않게 합니다.
    if (isLoading) return null;

    // 로딩 시작 및 이전 에러 초기화
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final outcome = await _commandExecutor.run(command);
      errorMessage = outcome.errorMessage;
      return outcome.succeeded ? outcome.value : null;
    } finally {
      // 로딩 종료 및 UI 갱신
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<RoomPlayer>> getRoomPlayers(String roomCode) async {
    players = await _service.getRoomPlayers(roomCode);
    notifyListeners();
    return players;
  }

  //===================================[방 생성]=================================
  Future<void> createRoom() async {
    // Figma 상태 계약에서 방 생성은 `구성원 없음`에서만 가능합니다.
    // 기존 방의 `초기화`는 closeRoom이 담당하며 새 코드를 만들지 않습니다.

    // 룸 코드가 없거나 로딩 중이면 리턴
    if (roomCode != null || isLoading) return;

    await RoomActionTiming.run(RoomTimedAction.create, () async {
      // room_service에 전달
      final operationId = _pendingCreateRoomOperationId ??=
          'create_room_${DateTime.now().microsecondsSinceEpoch}';
      // 코드 반환 받기 위한 메서드 실행
      // _runCommand -> RoomCommandExecutor ->
      final code = await _runCommand<String>(
        () => _service.createRoom(operationId: operationId),
      );

      //코드 반환 후 과정
      if (code != null) {
        // 재시도용 요청 id 정리
        _pendingCreateRoomOperationId = null;
        // 현재 방 코드 설정
        roomCode = code;
        // 이 태블릿이 방을 관리 중이라고 표시
        _ownsControllerSession = true;
        // 구독: 방 데이터 구독
        listenRoom();
        // 하트 비트: 태블릿 접속 정보 주기적 갱신
        _startControllerHeartbeat(code);
        // 화면에 상태 변경 알림
        notifyListeners();
      }
      return code != null;
    });
  }

  // [방 종료] 서버에서 방 종료 후, 방 상태를 초기화하는 비동기 메서드
  Future<void> closeRoom() async {
    final currentCode = roomCode;
    if (currentCode == null || isLoading) return;

    await RoomActionTiming.run(RoomTimedAction.close, () async {
      _isLeaving = true;
      _controllerHeartbeatTimer?.cancel();
      _playerHeartbeatTimer?.cancel();
      // 방 종료 요청
      final success = await _runCommand<bool>(() async {
        await _service.closeControllerRoom(currentCode);
        return true;
      });

      //앱 내부 상태 초기화
      if (success == true) {
        clearRoom(expectedRoomCode: currentCode);
      }
      return success == true;
    });
  }

  Future<bool> selectGame(String gameId) async {
    if (roomCode == null) return false;

    final result = await _runCommand<bool>(() async {
      await _service.selectGame(roomCode: roomCode!, gameId: gameId);
      return true;
    });

    return result ?? false;
  }

  Future<Map<String, dynamic>?> captureGameTarget() async {
    final code = roomCode;
    if (code == null) return null;
    try {
      return await _service.gameTarget(code);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCapturedGame(Map<String, dynamic> target) async {
    if (roomCode != target['roomCode'] || !isRoomFinished) return;
    await _runCommand<void>(() => _service.clearCapturedGame(target));
  }

  Future<bool> clearSelectedGame() async {
    if (roomCode == null) return false;

    final result = await _runCommand<bool>(() async {
      await _service.selectGame(roomCode: roomCode!, gameId: null);
      return true;
    });

    return result ?? false;
  }

  /// 휴대폰 대기실에서 게임 종류와 무관하게 시작 상태를 한 번만 구독합니다.
  Stream<String?> watchGameStatus(String code) =>
      _service.watchGameStatus(code.trim().toUpperCase());

  Stream<String?> watchRoomStatus(String code) =>
      _service.watchRoomStatus(code.trim().toUpperCase());

  Stream<List<RoomPlayer>> watchRoomPlayers(String code) =>
      _service.watchRoomPlayers(code.trim().toUpperCase());

  /// 입장 전 캐릭터 선택 화면에서 참가자와 점유 캐릭터만 구독합니다.
  void listenRoomPreview(String rawRoomCode) {
    if (roomCode != null) return;
    final code = rawRoomCode.trim().toUpperCase();
    playerSubscription?.cancel();
    playerSubscription = _service.watchRoomPlayers(code).listen((value) {
      if (roomCode != null) return;
      players = value;
      notifyListeners();
    }, onError: (Object error) => _handleSubscriptionError(error));
  }

  void stopRoomPreview() {
    if (roomCode != null) return;
    playerSubscription?.cancel();
    playerSubscription = null;
    players = [];
    notifyListeners();
  }

  @override
  Stream<bool> watchServerConnection() => _service.watchServerConnection();

  /// 태블릿이 방 화면을 열고 있는 동안 접속 표시를 유지합니다.
  Future<void> markControllerConnected() async {
    final code = roomCode;
    if (code == null) return;
    final epoch = _sessionEpoch;
    try {
      await _service.markControllerConnected(code);
      if (_isDisposed || roomCode != code || _sessionEpoch != epoch) return;
      _startControllerHeartbeat(code);
    } catch (_) {
      // 접속 표시 실패가 방 진행을 막지 않습니다.
    }
  }

  Future<void> restoreControllerRoom() async {
    if (roomCode != null || _controllerRestoreInFlight) return;
    _controllerRestoreInFlight = true;
    _pendingControllerRestore = true;
    connectionSubscription ??= _service.watchServerConnection().listen(
      _handleServerConnection,
    );
    final uid = _currentUid();
    if (uid != null) await RoomLeaveIntent.load(uid);
    try {
      final owner = RoomRecoveryBatch.current ?? RoomRecoveryBatch();
      final restoredCode = RoomRecoveryBatch.current != null
          ? await _service.restoreControllerRoom()
          : await owner.run(
              _service.restoreControllerRoom,
              isCurrent: () =>
                  !_isDisposed && _currentUid() == uid && roomCode == null,
              retryable: (error) =>
                  error is TimeoutException ||
                  (error is FirebaseFunctionsException &&
                      const {
                        'aborted',
                        'unavailable',
                        'deadline-exceeded',
                      }.contains(error.code)),
            );
      if (_isDisposed || _currentUid() != uid) return;
      _pendingControllerRestore = false;
      if (restoredCode == null) return;
      roomCode = restoredCode;
      if (uid != null) {
        GameRecoverySession.forRoom(restoredCode, uid).preparationBatch = owner;
      }
      _ownsControllerSession = true;
      listenRoom();
      _startControllerHeartbeat(restoredCode);
      notifyListeners();
    } on RoomCommandException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    } catch (_) {
      errorMessage = "기존 방 연결을 확인하고 있습니다.";
      notifyListeners();
    } finally {
      _controllerRestoreInFlight = false;
    }
  }

  void _startControllerHeartbeat(String code) {
    _controllerHeartbeatTimer?.cancel();
    _controllerHeartbeatTimer = Timer.periodic(const Duration(seconds: 10), (
      _,
    ) {
      if (roomCode == code) unawaited(_heartbeatControllerSafely(code));
    });
  }

  Future<void> _heartbeatControllerSafely(String code) async {
    if (!_isServerConnected ||
        roomCode != code ||
        _isDisposed ||
        _controllerHeartbeatInFlight) {
      return;
    }
    _controllerHeartbeatInFlight = true;
    try {
      await _service
          .heartbeatController(code)
          .timeout(const Duration(seconds: 8));
      _controllerHeartbeatFailures = 0;
      _controllerHeartbeatRecoveryStarted = false;
    } catch (error) {
      // heartbeat는 다음 주기에 다시 실행됩니다. 순간 단절을 전역 미처리
      // 예외로 올리면 태블릿 디버거가 멈추거나 앱이 종료된 것처럼 보입니다.
      if (kDebugMode) {
        debugPrint(
          '[room_connection] event=controller_heartbeat_failed '
          'errorType=${error.runtimeType}',
        );
      }
      _controllerHeartbeatFailures += 1;
      if (_controllerHeartbeatFailures >= 2 &&
          !_controllerHeartbeatRecoveryStarted &&
          !_isDisposed &&
          roomCode == code &&
          _isServerConnected) {
        _controllerHeartbeatRecoveryStarted = true;
        _confirmedRecovery = null;
        final uid = _currentUid();
        if (uid != null) {
          final session = GameRecoverySession.forRoom(code, uid);
          session.transportRecovering = true;
          session.invalidate();
        }
        unawaited(
          retryConnectionRecovery().catchError((Object _) {
            // 같은 장애 회차에서는 자동 복구 예산을 다시 만들지 않습니다.
          }),
        );
      }
    } finally {
      _controllerHeartbeatInFlight = false;
    }
  }

  /// 마지막 heartbeat가 유예를 넘겼는지 주기적으로 다시 판정합니다.
  ///
  /// 유예의 절반을 주기로 씁니다. 유예와 같은 주기로 돌리면 최악의 경우 판정이
  /// 유예의 두 배만큼 늦습니다.
  void _syncControllerPresenceTimer() {
    _controllerPresenceTimer?.cancel();
    // 이미 끊긴 것으로 확정됐거나 값이 없으면 시계를 돌릴 이유가 없습니다.
    // 복구는 새 heartbeat 이벤트가 알려 줍니다.
    if (_controllerPresence.isEmpty ||
        _controllerPresence.connected == false ||
        _controllerPresence.lastSeen == null) {
      return;
    }
    _controllerPresenceTimer = Timer.periodic(
      Duration(
        milliseconds: controllerPresenceDisplayGrace.inMilliseconds ~/ 2,
      ),
      (_) => _applyControllerPresenceVerdict(),
    );
  }

  void _applyControllerPresenceVerdict() {
    final verdict = judgeControllerPresence(
      _controllerPresence,
      // lastSeen은 ServerValue.timestamp라 서버 시각입니다. 기기 시계로
      // 비교하면 시계 오차만큼 오탐하거나 장애를 놓칩니다.
      nowMillis: ServerClock.nowMillis(),
    );
    final nextState = switch (verdict) {
      ControllerPresenceVerdict.connected => ControllerPresenceState.connected,
      ControllerPresenceVerdict.reconnecting =>
        ControllerPresenceState.reconnecting,
      ControllerPresenceVerdict.unknown => ControllerPresenceState.unknown,
    };
    if (nextState == ControllerPresenceState.reconnecting) {
      // 더 볼 것이 없습니다. 복구는 새 heartbeat 이벤트가 알려 줍니다.
      _controllerPresenceTimer?.cancel();
      _controllerPresenceTimer = null;
      final code = roomCode;
      final lastSeen = _controllerPresence.lastSeen;
      if (_controllerStaleReportLastSeen != lastSeen) {
        _controllerStaleReportLastSeen = lastSeen;
        _controllerStaleReportAttempts = 0;
      }
      if (_controllerPresence.connected == true &&
          code != null &&
          lastSeen != null &&
          ControllerRoomSessionStore.instance.sessionIdForRoom(code) == null &&
          !_controllerStaleReportInFlight &&
          _controllerStaleReportAttempts < 2) {
        _startControllerStaleReport(code, lastSeen);
      }
    }
    if (controllerPresenceState == nextState) return;
    controllerPresenceState = nextState;
    final code = roomCode, uid = _currentUid();
    if (code != null &&
        uid != null &&
        ControllerRoomSessionStore.instance.sessionIdForRoom(code) == null) {
      final session = GameRecoverySession.forRoom(code, uid);
      session.controllerAvailable =
          nextState != ControllerPresenceState.reconnecting;
      session.changed();
    }
    notifyListeners();
  }

  void _startControllerStaleReport(String code, int observedLastSeen) {
    _controllerStaleReportAttempts += 1;
    _controllerStaleReportInFlight = true;
    unawaited(_reportStaleController(code, observedLastSeen));
  }

  Future<void> _reportStaleController(String code, int observedLastSeen) async {
    var succeeded = false;
    try {
      await _service.reportStaleController(
        roomCode: code,
        observedLastSeen: observedLastSeen,
      );
      succeeded = true;
      if (_controllerStaleReportLastSeen == observedLastSeen) {
        _controllerStaleReportAttempts = 2;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[room_connection] event=stale_controller_report_failed '
          'errorType=${error.runtimeType}',
        );
      }
    } finally {
      _controllerStaleReportInFlight = false;
    }
    if (succeeded ||
        _isDisposed ||
        roomCode != code ||
        _controllerPresence.connected != true ||
        _controllerPresence.lastSeen != observedLastSeen ||
        _controllerStaleReportAttempts >= 2) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!_isDisposed &&
        roomCode == code &&
        _controllerPresence.connected == true &&
        _controllerPresence.lastSeen == observedLastSeen &&
        !_controllerStaleReportInFlight &&
        _controllerStaleReportAttempts < 2) {
      _startControllerStaleReport(code, observedLastSeen);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final code = roomCode;
    if (_isDisposed || code == null) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(retryConnectionRecovery().catchError((Object _) {}));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _connectionEpoch++;
      _confirmedRecovery = null;
      _playerHeartbeatTimer?.cancel();
      _controllerHeartbeatTimer?.cancel();
      final uid = _currentUid();
      if (uid != null) {
        final session = GameRecoverySession.forRoom(code, uid);
        session.transportRecovering = true;
        session.invalidate();
      }
      if (ControllerRoomSessionStore.instance.sessionIdForRoom(code) != null) {
        unawaited(
          _service.markControllerDisconnected(code).catchError((Object _) {}),
        );
      } else {
        unawaited(
          _service.markPlayerDisconnected(code).catchError((Object _) {}),
        );
      }
    }
  }

  Future<void> resumeControllerPresence() async {
    if (roomCode != null) await retryConnectionRecovery();
  }

  Future<void> pauseControllerPresence() async {
    _controllerHeartbeatTimer?.cancel();
    _controllerHeartbeatTimer = null;
    final code = roomCode;
    if (code == null) return;
    final uid = _currentUid();
    if (uid != null) GameRecoverySession.forRoom(code, uid).invalidate();
    try {
      await _service.markControllerDisconnected(code);
    } catch (_) {}
  }

  /// 명시적인 방 종료만 서버 closeRoom callable을 사용합니다.
  Future<void> closeControllerRoom() async {
    final code = roomCode;
    if (code == null) return;
    try {
      _controllerHeartbeatTimer?.cancel();
      await _service.closeControllerRoom(code);
      clearRoom();
    } catch (_) {
      // 실패하면 세션과 방을 유지해 사용자가 다시 시도할 수 있게 합니다.
    }
  }

  @override
  Future<bool> removePlayer(String userUid) async {
    final code = roomCode;
    if (code == null || _removingPlayerUids.contains(userUid)) return false;

    _removingPlayerUids.add(userUid);
    errorMessage = null;
    notifyListeners();
    try {
      await _service.removePlayer(code, userUid);
      return true;
    } catch (error) {
      DevErrorLog.instance.add(
        error: error,
        context: 'room/remove_player',
        time: DateTime.now(),
      );
      errorMessage =
          userErrorMessage(error, context: UserErrorContext.roomCommand) ??
          '플레이어를 내보내지 못했습니다.';
      return false;
    } finally {
      _removingPlayerUids.remove(userUid);
      notifyListeners();
    }
  }

  Future<bool> savePlayerSeatIndexes(Map<String, int> seatIndexesByUid) async {
    final code = roomCode;
    if (code == null) {
      errorMessage = '방 정보를 확인할 수 없습니다.';
      notifyListeners();
      return false;
    }

    final result = await _runCommand<bool>(() async {
      await _service.savePlayerSeatIndexes(
        roomCode: code,
        seatIndexesByUid: seatIndexesByUid,
      );
      return true;
    });

    return result ?? false;
  }

  Future<bool> beginPlayerSeating() async {
    final code = roomCode;
    if (code == null) {
      errorMessage = '방 정보를 확인할 수 없습니다.';
      notifyListeners();
      return false;
    }
    final result = await _runCommand<bool>(() async {
      players = await _service.beginPlayerSeating(code);
      notifyListeners();
      return true;
    });
    return result ?? false;
  }

  // ======================[ 방 데이터 변화 구독 ]============================
  // 서버에서 발생하는 변화를 RoomProvider 상태와 화면에 반영한다.
  void listenRoom() {
    final listenedRoomCode = roomCode;
    if (listenedRoomCode == null) return;
    final uid = _currentUid();
    if (uid != null) {
      final session = GameRecoverySession.forRoom(listenedRoomCode, uid);
      session.transportConnected = _isServerConnected;
      session.controllerAvailable = true;
      session.changed();
    }

    // 기존 구독과 타이머 정리
    roomSubscription?.cancel();
    playerSubscription?.cancel();
    connectionSubscription?.cancel();
    statusSubscription?.cancel();
    controllerPresenceSubscription?.cancel();
    roomExistenceSubscription?.cancel();
    _playerHeartbeatTimer?.cancel();
    _controllerPresenceTimer?.cancel();
    _playerPresenceTimer?.cancel();

    // 이전 방에서 계산한 상태 초기화
    controllerPresenceState = ControllerPresenceState.unknown;
    _controllerPresence = ControllerPresence.unknown;
    _controllerPresenceTimer?.cancel();
    _controllerPresenceTimer = null;
    roomStatus = null;
    roomTerminationReason = null;
    _roomMissingCandidate = false;
    _roomDeletionConfirmation = null;
    _roomExistenceRevision += 1;

    connectionSubscription = _service.watchServerConnection().listen(
      _handleServerConnection,
      onError: (_) => _handleServerConnection(false),
    );

    // 방을 관리하는 태블릿의 접속 상태 감시
    // connected와 lastSeen을 함께 받습니다. connected만 보면 태블릿이 강제
    // 종료·크래시·전원 차단으로 markControllerDisconnected를 보낼 기회조차
    // 없었던 경우를 영원히 알 수 없습니다(값이 true로 굳습니다).
    controllerPresenceSubscription = _service
        .watchControllerPresence(listenedRoomCode)
        .listen(
          (presence) {
            if (roomCode != listenedRoomCode) return;
            _controllerPresence = presence;
            _syncControllerPresenceTimer();
            _applyControllerPresenceVerdict();
          },
          onError: (Object error) => _handleSubscriptionError(
            error,
            expectedRoomCode: listenedRoomCode,
          ),
        );

    // 방이 실제로 존재하는지 감시
    roomExistenceSubscription = _service
        .watchRoomExists(listenedRoomCode)
        .listen(
          (exists) {
            if (roomCode != listenedRoomCode) return;
            _roomExistenceRevision += 1;
            if (exists) {
              _roomMissingCandidate = false;
              return;
            }
            _roomMissingCandidate = true;
            unawaited(_confirmRoomDeleted(listenedRoomCode));
          },
          onError: (Object error) => _handleSubscriptionError(
            error,
            expectedRoomCode: listenedRoomCode,
          ),
        );

    // 방 상태 감시
    statusSubscription = _service.watchRoomStatus(listenedRoomCode).listen(
      (status) {
        if (roomCode != listenedRoomCode) return;
        if (roomStatus != status) {
          roomStatus = status;
          _syncPlayerPresenceTimer();
          notifyListeners();
        }
        // finished는 현재 게임만 끝난 상태이며 방과 참가자는 유지합니다.
        // status의 null은 초기 캐시 미수신일 수 있으므로 방 종료로 보지 않고,
        // 실제 삭제는 roomCode 생존 마커를 서버에서 재확인해 판정합니다.
        if (status == 'closed') {
          _terminateRoom(
            RoomTerminationReason.closed,
            expectedRoomCode: listenedRoomCode,
          );
        }
      },
      // 내 참가자 노드가 사라지면 status 읽기 권한도 함께 사라져 이 구독이
      // permission-denied로 종료됩니다. 퇴장·강퇴·방 삭제 정리는 players
      // 구독이 담당하므로 여기서는 표시하지 않고 넘깁니다. 권한 오류를
      // 걸러내는 판단은 userErrorMessage가 소유합니다.
      onError: (Object error) =>
          _handleSubscriptionError(error, expectedRoomCode: listenedRoomCode),
    );

    if (_joinedNickname != null) {
      _startPlayerHeartbeat(listenedRoomCode);
    }

    roomSubscription = _service.watchRoom(listenedRoomCode).listen(
      (event) {
        if (roomCode != listenedRoomCode) return;
        final gameId = event.snapshot.value as String?;

        if (gameId != selectedGameId) {
          selectedGameId = gameId;
          selectedGame = null;
          selectedGameError = null;
          _selectedGameRequestId += 1;
          selectedGameLoadStatus = gameId == null || gameId.isEmpty
              ? RoomDataLoadStatus.idle
              : RoomDataLoadStatus.loading;
          // 게임 시작 판단에 필요한 ID는 Firestore 메타데이터보다 먼저 전달합니다.
          notifyListeners();

          if (gameId != null && gameId.isNotEmpty) {
            unawaited(
              _loadSelectedGame(gameId, expectedRoomCode: listenedRoomCode),
            );
          }
        }
      },
      onError: (Object error) =>
          _handleSubscriptionError(error, expectedRoomCode: listenedRoomCode),
    );
    playerSubscription = _service.watchRoomPlayers(listenedRoomCode).listen(
      (roomPlayer) {
        if (roomCode != listenedRoomCode) return;
        players = roomPlayer;
        _pruneStaleReports(roomPlayer);
        _evaluateStalePlayers();

        final myUid = _currentUid();
        if (myUid != null && myUid.isNotEmpty) {
          final isMeInPlayers = roomPlayer.any(
            (p) => p.uid == myUid && p.isActive,
          );
          if (isMeInPlayers) {
            _hasJoined = true;
          } else if (_hasJoined && !_isLeaving) {
            unawaited(
              _verifyCurrentPlayerRemoval(listenedRoomCode, expectedUid: myUid),
            );
            return;
          }
        }
        // players 변경(heartbeat 포함)은 Firestore 조회를 기다리지 않고 즉시
        // 화면에 반영합니다.
        notifyListeners();

        // 활성화된 유저의 uids 추출
        final activeUids = _groupMemberUids();
        unawaited(
          _refreshGroupGames(activeUids, expectedRoomCode: listenedRoomCode),
        );
      },
      onError: (Object error) =>
          _handleSubscriptionError(error, expectedRoomCode: listenedRoomCode),
    );
  }

  /// 그룹 보유 게임은 활성 참가자 구성이 실제로 바뀔 때만 다시 조회합니다.
  ///
  /// players 노드는 10초 heartbeat(lastSeen)마다 이벤트를 발생시키므로, 매
  /// 이벤트마다 Firestore를 조회하면 게임 내내 주기적인 쿼리 폭주와 프레임
  /// 지연이 생깁니다.
  Future<void> _refreshGroupGames(
    List<String> activeUids, {
    required String expectedRoomCode,
    bool force = false,
  }) async {
    if (roomCode != expectedRoomCode) return;
    final sortedUids = [
      for (final memberUid in activeUids)
        '$memberUid/${players.where((player) => player.uid == memberUid).firstOrNull?.membershipId ?? ""}',
    ]..sort();
    if (!force && listEquals(_lastGroupGameUids, sortedUids)) return;
    _lastGroupGameUids = sortedUids;
    final uid = _currentUid();
    final requestId = ++_groupGamesRequestId;
    groupGames = [];
    groupGamesLoadStatus = RoomDataLoadStatus.loading;
    groupGamesError = null;
    notifyListeners();

    if (activeUids.isEmpty) {
      groupGamesLoadStatus = RoomDataLoadStatus.loaded;
      notifyListeners();
      return;
    }

    try {
      final identity = await _service.roomIdentity(expectedRoomCode);
      final games = await _gameService.fetchGroupGames(
        activeUids,
        roomCode: expectedRoomCode,
        roomInstanceId: identity.roomInstanceId,
      );
      if (_isDisposed ||
          _currentUid() != uid ||
          roomCode != expectedRoomCode ||
          requestId != _groupGamesRequestId) {
        return;
      }
      groupGames = games;
      groupGamesLoadStatus = RoomDataLoadStatus.loaded;
      groupGamesError = null;
      notifyListeners();
    } catch (_) {
      // 실패하면 다음 players 이벤트에서 같은 구성으로도 다시 시도합니다.
      if (_isDisposed ||
          roomCode != expectedRoomCode ||
          requestId != _groupGamesRequestId) {
        return;
      }
      // A bounded failure waits for explicit retry or a changed membership.
      groupGames = [];
      groupGamesLoadStatus = RoomDataLoadStatus.failure;
      groupGamesError = '게임 목록을 불러오지 못했습니다.';
      notifyListeners();
    }
  }

  Future<void> retryGroupGames() async {
    final code = roomCode;
    if (code == null || groupGamesLoadStatus == RoomDataLoadStatus.loading) {
      return;
    }
    final activeUids = _groupMemberUids();
    await _refreshGroupGames(activeUids, expectedRoomCode: code, force: true);
  }

  List<String> _groupMemberUids() {
    final uids = players
        .where((player) => player.isActive)
        .map((player) => player.uid)
        .where((uid) => uid.isNotEmpty)
        .toSet();
    final currentUid = _currentUid();
    if (currentUid != null && currentUid.isNotEmpty) uids.add(currentUid);
    return uids.toList(growable: false);
  }

  void _startPlayerHeartbeat(String code) {
    _playerHeartbeatTimer?.cancel();
    unawaited(_heartbeatPlayerSafely(code));
    _playerHeartbeatTimer = Timer.periodic(playerHeartbeatInterval, (_) {
      if (roomCode == code && !_isLeaving) {
        unawaited(_heartbeatPlayerSafely(code));
      }
    });
  }

  Future<void> _heartbeatPlayerSafely(String code) async {
    if (!_isServerConnected || _isLeaving || roomCode != code || _isDisposed) {
      return;
    }
    try {
      await _service.heartbeatPlayer(code);
    } catch (error) {
      if (isPermissionDenied(error) &&
          !_heartbeatPermissionRecoveryAttempted &&
          !_isDisposed &&
          roomCode == code &&
          !_isLeaving) {
        _heartbeatPermissionRecoveryAttempted = true;
        _confirmedRecovery = null;
        try {
          await retryConnectionRecovery();
        } catch (_) {
          if (!_isDisposed && roomCode == code) {
            errorMessage = '방 연결을 확인하지 못했어요. 다시 연결해주세요.';
            notifyListeners();
          }
        }
      }
      if (kDebugMode) {
        debugPrint(
          '[room_connection] event=player_heartbeat_failed '
          'errorType=${error.runtimeType}',
        );
      }
    }
  }

  //============================[ timer manage ]================================
  // 게임 진행 중 참가자들의 연결 상태를 주기적으로 검사하는 타이머를 시작하거나 중단시킴.
  void _syncPlayerPresenceTimer() {
    _playerPresenceTimer?.cancel();
    _playerPresenceTimer = null;
    if (!_ownsControllerSession ||
        !_isServerConnected ||
        roomStatus != 'playing') {
      return;
    }
    _evaluateStalePlayers();
    _playerPresenceTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _evaluateStalePlayers(),
    );
  }

  void _evaluateStalePlayers() {
    final code = roomCode;
    final currentUid = _currentUid();
    final recovering =
        code != null &&
        currentUid != null &&
        GameRecoverySession.forRoom(code, currentUid).transportRecovering;
    if (code == null ||
        !_ownsControllerSession ||
        !_isServerConnected ||
        _connectionRecoveryFuture != null ||
        recovering ||
        roomStatus != 'playing') {
      return;
    }
    final now = ServerClock.nowMillis();
    for (final player in players) {
      final lastSeen = player.lastSeen;
      if (lastSeen == null ||
          !isStalePlayerHeartbeatCandidate(player, nowMillis: now) ||
          _staleReportInFlight.contains(player.uid)) {
        continue;
      }
      if (!_staleReportTracker.tryStartAttempt(player.uid, lastSeen)) continue;
      _staleReportInFlight.add(player.uid);
      // 복구 신원이 확정된 뒤에도 실패하면 다음 1초 주기에서 한 번만 재확인합니다.
      unawaited(_reportStalePlayer(code, player.uid, lastSeen));
    }
  }

  Future<void> _reportStalePlayer(
    String code,
    String playerUid,
    int observedLastSeen,
  ) async {
    try {
      await _service.reportStalePlayer(
        roomCode: code,
        playerUid: playerUid,
        observedLastSeen: observedLastSeen,
      );
      _staleReportTracker.markSucceeded(playerUid, observedLastSeen);
    } catch (error) {
      // 다음 판정 주기에서 같은 관측값을 한 번만 더 확인합니다.
      if (kDebugMode) {
        debugPrint(
          '[room_connection] event=stale_player_report_failed '
          'errorType=${error.runtimeType}',
        );
      }
    } finally {
      _staleReportInFlight.remove(playerUid);
    }
  }

  void _pruneStaleReports(List<RoomPlayer> currentPlayers) {
    _staleReportTracker.retainCurrent(currentPlayers);
  }

  //================================[method]====================================
  // 서버 연결 상태를 프로바이드에 반영, 연결이 복구되면 방 연결 복구 작업을 시작
  void _handleServerConnection(bool isConnected) {
    // 현재 연결 상태 저장과 화면 알림
    if (_isServerConnected != isConnected) _connectionEpoch += 1;
    if (!isConnected) {
      _confirmedRecovery = null;
      _heartbeatPermissionRecoveryAttempted = false;
      _controllerHeartbeatFailures = 0;
      _controllerHeartbeatRecoveryStarted = false;
    }
    _isServerConnected = isConnected;
    final sessionUid = _currentUid(), sessionCode = roomCode;
    if (sessionUid != null && sessionCode != null) {
      final session = GameRecoverySession.forRoom(sessionCode, sessionUid);
      session.transportConnected = isConnected;
      if (!isConnected) session.transportRecovering = true;
      _reconnectSession = session;
      _reconnectCallback = () async {
        if (_isDisposed ||
            _currentUid() != sessionUid ||
            roomCode != sessionCode) {
          throw const RoomCommandException('이전 방 복구 요청입니다.');
        }
        _requestedRecoveryOwner = session.preparationBatch;
        _confirmedRecovery = null;
        await retryConnectionRecovery();
      };
      session.reconnect = _reconnectCallback;
      session.changed();
    }
    _syncPlayerPresenceTimer();
    notifyListeners();
    // 연결이 끊겼다면 기록하고 종료
    if (!isConnected) {
      _wasServerDisconnected = true;
      final uid = _currentUid();
      final code = roomCode;
      if (uid != null && code != null) {
        GameRecoverySession.forRoom(code, uid).invalidate();
      }
      return;
    }
    if (_pendingControllerRestore && roomCode == null) {
      unawaited(restoreControllerRoom());
    }
    if (_roomMissingCandidate) {
      final code = roomCode;
      if (code != null) unawaited(_confirmRoomDeleted(code));
    }
    if (!_wasServerDisconnected) return;
    _wasServerDisconnected = false;
    unawaited(retryConnectionRecovery().catchError((Object _) {}));
  }

  //=============================[double check]=================================
  // 파베에서 방이 삭제됐는지 다시 확인한다.
  Future<void> _confirmRoomDeleted(String expectedRoomCode) async {
    if (!_roomMissingCandidate ||
        !_isServerConnected ||
        roomCode != expectedRoomCode) {
      return;
    }
    final activeConfirmation = _roomDeletionConfirmation;
    if (activeConfirmation != null) {
      await activeConfirmation;
      return;
    }

    final connectionEpoch = _connectionEpoch;
    final confirmation = _performRoomDeletionConfirmation(expectedRoomCode);
    _roomDeletionConfirmation = confirmation;
    try {
      await confirmation;
    } finally {
      if (identical(_roomDeletionConfirmation, confirmation)) {
        _roomDeletionConfirmation = null;
        if (connectionEpoch != _connectionEpoch &&
            _isServerConnected &&
            _roomMissingCandidate &&
            roomCode == expectedRoomCode) {
          unawaited(_confirmRoomDeleted(expectedRoomCode));
        }
      }
    }
  }

  Future<void> _performRoomDeletionConfirmation(String expectedRoomCode) async {
    final sessionEpoch = _sessionEpoch;
    final connectionEpoch = _connectionEpoch;
    final existenceRevision = _roomExistenceRevision;
    try {
      final exists = await _service
          .roomExists(expectedRoomCode)
          .timeout(const Duration(seconds: 8));
      if (_isDisposed ||
          roomCode != expectedRoomCode ||
          _sessionEpoch != sessionEpoch ||
          _connectionEpoch != connectionEpoch ||
          _roomExistenceRevision != existenceRevision ||
          !_isServerConnected ||
          !_roomMissingCandidate ||
          _isLeaving) {
        return;
      }
      if (exists) {
        _roomMissingCandidate = false;
        return;
      }
      _terminateRoom(
        RoomTerminationReason.deleted,
        expectedRoomCode: expectedRoomCode,
      );
    } catch (error) {
      // 네트워크나 권한 오류를 방 삭제로 오인하지 않습니다. RTDB가 다시 연결되면
      // connection listener가 같은 후보를 재확인합니다.
      if (kDebugMode) {
        debugPrint(
          '[room_connection] event=room_deletion_confirmation_failed '
          'errorType=${error.runtimeType}',
        );
      }
    }
  }

  Future<void> _verifyCurrentPlayerRemoval(
    String expectedRoomCode, {
    required String expectedUid,
  }) async {
    if (!_isServerConnected) return;
    final checkId = ++_playerRemovalCheckId;
    final connectionEpoch = _connectionEpoch;
    try {
      final results = await Future.wait<bool>([
        _service.roomExists(expectedRoomCode),
        _service.hasActivePlayerNode(expectedRoomCode),
      ]).timeout(const Duration(seconds: 8));
      final roomStillExists = results[0];
      final playerStillExists = results[1];
      if (checkId != _playerRemovalCheckId ||
          _connectionEpoch != connectionEpoch ||
          !_isServerConnected ||
          roomCode != expectedRoomCode ||
          _isLeaving) {
        return;
      }
      if (players.any(
        (player) => player.uid == expectedUid && player.isActive,
      )) {
        return;
      }
      // 서로 다른 경로의 조회 결과가 충돌하면 살아 있는 참가자 근거를 보존합니다.
      if (playerStillExists) return;
      if (!roomStillExists) {
        _terminateRoom(
          RoomTerminationReason.deleted,
          expectedRoomCode: expectedRoomCode,
        );
        return;
      }

      // 재연결 직후 players 구독은 빈 로컬 캐시를 먼저 전달할 수 있습니다.
      // 방만 존재한다고 바로 강퇴 처리하면 실제 서버에 내 노드가 살아 있어도
      // 저장 세션을 지우고 로비로 내보냅니다. 반드시 서버의 내 참가자 노드를
      // 별도로 확인합니다.
      _hasJoined = false;
      wasKicked = true;
      roomTerminationReason = null;
      unawaited(
        PlayerRoomSessionStore.instance.clear(onlyRoomCode: expectedRoomCode),
      );
      clearRoom(expectedRoomCode: expectedRoomCode);
    } catch (error) {
      // 확인 실패 시 참가자를 성급하게 강퇴 처리하지 않습니다. players 구독이
      // 복구되면 현재 값을 다시 받아 재판정합니다.
      if (kDebugMode) {
        debugPrint(
          '[room_connection] event=player_removal_confirmation_failed '
          'errorType=${error.runtimeType}',
        );
      }
    }
  }

  void _terminateRoom(
    RoomTerminationReason reason, {
    required String expectedRoomCode,
  }) {
    if (roomCode != expectedRoomCode || roomTerminationReason != null) return;
    _hasJoined = false;
    wasKicked = false;
    wasRoomClosed = true;
    roomTerminationReason = reason;
    unawaited(
      PlayerRoomSessionStore.instance.clear(onlyRoomCode: expectedRoomCode),
    );
    clearRoom(
      expectedRoomCode: expectedRoomCode,
      preserveTerminationReason: true,
    );
  }

  void acknowledgeRoomExit() {
    wasKicked = false;
    wasRoomClosed = false;
    roomTerminationReason = null;
  }

  /// 네트워크 모달의 재시도 버튼에서 현재 세션을 실제로 복원합니다.
  ///
  /// RTDB는 물리 네트워크가 돌아오면 자체 재연결하므로 `goOnline()`을 다시 부르는
  /// 대신, 연결 단절 중 실패했을 presence 예약과 서버의 참가 상태를 복구합니다.
  @override
  Future<void> retryConnectionRecovery() async {
    final activeRecovery = _connectionRecoveryFuture;
    if (activeRecovery != null) {
      await activeRecovery;
      return;
    }

    final code = roomCode, uid = _currentUid();
    final connectionEpoch = _connectionEpoch;
    final role =
        code != null &&
            ControllerRoomSessionStore.instance.sessionIdForRoom(code) != null
        ? 'controller'
        : 'player';
    final identity = code == null || uid == null
        ? null
        : RoomSessionIdentityStore.instance.current(uid, role, code);
    final scope = (
      uid,
      code,
      _sessionEpoch,
      connectionEpoch,
      identity?.connectionId,
    );
    if (_confirmedRecovery == scope && _isServerConnected) return;
    final recovery = _recoverCurrentConnection();
    _connectionRecoveryFuture = recovery;
    try {
      await recovery;
    } finally {
      if (identical(_connectionRecoveryFuture, recovery)) {
        _connectionRecoveryFuture = null;
        if (!_isDisposed &&
            _isServerConnected &&
            _connectionEpoch != connectionEpoch &&
            roomCode == code &&
            code != null &&
            _currentUid() == uid &&
            !_isLeaving) {
          await retryConnectionRecovery();
        }
      }
    }
  }

  Future<void> _recoverCurrentConnection() async {
    final uid = _currentUid();
    final code = roomCode;
    final epoch = _sessionEpoch;
    final connectionEpoch = _connectionEpoch;
    final controllerSessionId = code == null
        ? null
        : ControllerRoomSessionStore.instance.sessionIdForRoom(code);
    final batch = _requestedRecoveryOwner ?? RoomRecoveryBatch();
    _requestedRecoveryOwner = null;
    if (code != null && uid != null) {
      final session = GameRecoverySession.forRoom(code, uid);
      session.preparationBatch = batch;
      session.transportRecovering = true;
      session.invalidate();
    }
    RecoveryMetrics.instance.begin(newEpisode: false);
    RecoveryMetrics.instance.mark(RecoveryStage.connection);
    if (uid != null) RecoveryMetrics.instance.mark(RecoveryStage.auth);
    try {
      await batch.run(
        () async {
          await _performConnectionRecovery();
          if (_isDisposed ||
              _currentUid() != uid ||
              roomCode != code ||
              _sessionEpoch != epoch ||
              code == null ||
              _isLeaving) {
            return;
          }
          if (controllerSessionId != null) {
            if (ControllerRoomSessionStore.instance.sessionIdForRoom(code) !=
                controllerSessionId) {
              return;
            }
            await _service.heartbeatController(code);
          } else {
            await _service.heartbeatPlayer(code);
          }
        },
        isCurrent: () =>
            !_isDisposed &&
            _currentUid() == uid &&
            roomCode == code &&
            _sessionEpoch == epoch,
        retryable: (error) =>
            error is TimeoutException ||
            (error is FirebaseFunctionsException &&
                const {
                  'unavailable',
                  'deadline-exceeded',
                  'aborted',
                }.contains(error.code)),
      );
      if (_isDisposed ||
          _currentUid() != uid ||
          roomCode != code ||
          code == null ||
          _isLeaving ||
          _sessionEpoch != epoch ||
          _connectionEpoch != connectionEpoch) {
        return;
      }
      // Periodic work must be created after leaving the bounded recovery Zone.
      // Late operation continuations retain its deadline; future heartbeats do not.
      if (controllerSessionId != null) {
        if (ControllerRoomSessionStore.instance.sessionIdForRoom(code) !=
            controllerSessionId) {
          return;
        }
        _startControllerHeartbeat(code);
      } else {
        _startPlayerHeartbeat(code);
      }
      final role = controllerSessionId == null ? 'player' : 'controller';
      final identity = uid == null
          ? null
          : RoomSessionIdentityStore.instance.current(uid, role, code);
      _confirmedRecovery = (
        uid,
        code,
        epoch,
        connectionEpoch,
        identity?.connectionId,
      );
      if (uid != null) {
        final session = GameRecoverySession.forRoom(code, uid);
        session.transportRecovering = false;
        session.changed();
      }
      _evaluateStalePlayers();
      errorMessage = null;
      notifyListeners();
      RecoveryMetrics.instance.mark(RecoveryStage.identity);
      if (_currentUid() == uid &&
          roomStatus != 'playing' &&
          GameRecoverySession.forRoom(code, uid ?? '').context == null) {
        RecoveryMetrics.instance.finish(success: true);
      }
    } catch (_) {
      RecoveryMetrics.instance.finish(success: false);
      rethrow;
    }
  }

  Future<void> _performConnectionRecovery() async {
    final code = roomCode;
    if (code == null) {
      throw const RoomCommandException('복구할 방 정보가 없습니다.');
    }
    // 나가는 중이거나 이미 나간 방은 복구하지 않습니다. 이 확인이 없으면
    // 네트워크가 돌아오는 순간 참가자를 다시 join시켜, 사용자의 첫 재시도가
    // "다시 들어간 방에서 나가기"가 됩니다.
    if (_isLeaving || RoomLeaveIntent.blocksRestore(code)) {
      await _runLeave(
        code,
        () => _service.leaveRoom(code),
        errorContext: UserErrorContext.leaveRoom,
      );
      return;
    }

    final controllerSessionId = ControllerRoomSessionStore.instance
        .sessionIdForRoom(code);
    if (controllerSessionId != null) {
      await _service.restoreControllerRoom().timeout(
        const Duration(seconds: 8),
      );
      return;
    }

    final uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      throw const RoomCommandException('인증 정보가 없습니다.');
    }
    RoomPlayer? currentPlayer;
    for (final player in players) {
      if (player.uid == uid) {
        currentPlayer = player;
        break;
      }
    }
    final nickname = currentPlayer?.nickname ?? _joinedNickname;
    final characterId = currentPlayer?.characterId ?? _joinedCharacterId;
    if (nickname == null || characterId == null) {
      throw const RoomCommandException('복구할 플레이어 정보가 없습니다.');
    }

    await _service
        .restorePlayerConnection(
          roomCode: code,
          nickname: nickname,
          characterId: characterId,
        )
        .timeout(const Duration(seconds: 8));
  }

  /// 썸네일·설명 같은 화면용 Firestore 정보는 게임 시작 신호와 분리해 불러옵니다.
  /// 조회가 늦거나 실패해도 Realtime Database의 게임 시작 처리는 계속됩니다.
  Future<void> _loadSelectedGame(
    String gameId, {
    required String expectedRoomCode,
  }) async {
    if (roomCode != expectedRoomCode || selectedGameId != gameId) return;
    final requestId = ++_selectedGameRequestId;
    selectedGame = null;
    selectedGameLoadStatus = RoomDataLoadStatus.loading;
    selectedGameError = null;
    notifyListeners();
    try {
      final game = await _gameService.getGame(gameId);
      if (_isDisposed ||
          roomCode != expectedRoomCode ||
          selectedGameId != gameId ||
          requestId != _selectedGameRequestId) {
        return;
      }
      if (game == null) {
        selectedGameLoadStatus = RoomDataLoadStatus.failure;
        selectedGameError = '선택한 게임 정보를 찾을 수 없습니다.';
        notifyListeners();
        return;
      }
      selectedGame = game;
      selectedGameLoadStatus = RoomDataLoadStatus.loaded;
      selectedGameError = null;
      notifyListeners();
    } catch (_) {
      // 게임 ID와 RTDB 상태만으로 게임 화면을 열 수 있으므로 메타데이터 실패는
      // 대기실의 시작 흐름을 중단하지 않습니다.
      if (_isDisposed ||
          roomCode != expectedRoomCode ||
          selectedGameId != gameId ||
          requestId != _selectedGameRequestId) {
        return;
      }
      selectedGameLoadStatus = RoomDataLoadStatus.failure;
      selectedGameError = '선택한 게임 정보를 불러오지 못했습니다.';
      notifyListeners();
    }
  }

  Future<void> retrySelectedGame() async {
    final code = roomCode;
    final gameId = selectedGameId;
    if (code == null ||
        gameId == null ||
        gameId.isEmpty ||
        selectedGameLoadStatus == RoomDataLoadStatus.loading) {
      return;
    }
    await _loadSelectedGame(gameId, expectedRoomCode: code);
  }

  void _handleSubscriptionError(Object error, {String? expectedRoomCode}) {
    // clearRoom은 구독 cancel을 await하지 않으므로 취소한 뒤에도 오류가 도착할
    // 수 있습니다. 이미 다른 방으로 넘어갔거나 퇴장 중이면 사용자 오류로
    // 표시하지 않습니다.
    if (expectedRoomCode != null && roomCode != expectedRoomCode) return;
    if (_isLeaving) return;
    DevErrorLog.instance.add(
      error: error,
      context: 'room/subscription',
      time: DateTime.now(),
    );
    // 정상 퇴장으로 권한이 사라진 경우와, 연결이 돌아오면 스스로 복구되는
    // 네이티브 오류는 사용자에게 표시하지 않습니다.
    errorMessage = userErrorMessage(
      error,
      context: UserErrorContext.roomSubscription,
    );
    notifyListeners();
  }

  // ============================================== Phone을 위한 메서드 ========================================
  Future<bool> validateRoomJoin(String rawRoomCode) async {
    final code = rawRoomCode.trim().toUpperCase();
    if (code.isEmpty) return false;
    final result = await _runCommand<bool>(() async {
      await _service.validateRoomJoin(code);
      return true;
    });
    return result ?? false;
  }

  Future<bool> joinRoom(
    String rawRoomCode,
    String nickname, {
    required String characterId,
  }) async {
    // Room code 받기
    final code = rawRoomCode.trim().toUpperCase();
    if (code.isEmpty) return false;

    // joinRoom 실행
    final result = await _runCommand(() async {
      await _service.joinRoom(code, nickname, characterId: characterId);
      return true;
    });

    // return 분기
    if (result == true) {
      // 같은 방 코드로 다시 들어왔으므로 이전 퇴장 기록을 지웁니다.
      RoomLeaveIntent.forget(code);
      _sessionEpoch += 1;
      wasKicked = false;
      // 직전 방이 닫히며 세워진 플래그가 새 방 입장으로 넘어오지 않게 합니다.
      wasRoomClosed = false;
      roomTerminationReason = null;
      _hasJoined = false;
      _joinedNickname = nickname;
      _joinedCharacterId = characterId;
      roomCode = code;
      await _persistPlayerSession(
        roomCode: code,
        nickname: nickname,
        characterId: characterId,
      );
      listenRoom();
    }
    return result ?? false;
  }

  Future<bool> updateJoinedPlayerProfile(
    String nickname, {
    required String characterId,
  }) async {
    final code = roomCode;
    if (code == null) return false;
    final result = await _runCommand<bool>(() async {
      await _service.updateRoomPlayerProfile(
        code,
        nickname,
        characterId: characterId,
      );
      return true;
    });
    if (result == true) {
      _joinedNickname = nickname;
      _joinedCharacterId = characterId;
      await _persistPlayerSession(
        roomCode: code,
        nickname: nickname,
        characterId: characterId,
      );
    }
    return result ?? false;
  }

  Future<void> _persistPlayerSession({
    required String roomCode,
    required String nickname,
    required String characterId,
  }) async {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) return;
    try {
      await PlayerRoomSessionStore.instance.save(
        uid: uid,
        roomCode: roomCode,
        nickname: nickname,
        characterId: characterId,
      );
    } catch (_) {
      // 로컬 저장 실패가 이미 성공한 서버 입장을 취소해서는 안 됩니다.
    }
  }

  /// 저장 세션으로 무엇을 복원할 수 있는지 **서버에 쓰지 않고** 확인합니다.
  ///
  /// [restorePlayerRoom]은 참가자 노드를 되살리고 heartbeat를 시작합니다.
  /// 복귀 여부를 사용자에게 물으려면 그 전에 판정만 필요하므로 두 단계로
  /// 나눕니다. 묻기도 전에 서버에 참가자를 만들면, 사용자가 거절해도 이미
  /// 방에 들어가 있게 됩니다(P-01).
  Future<RestorableSession> detectRestorableSession() async {
    if (roomCode != null || _isLeaving) return RestorableSession.none;
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) return RestorableSession.none;
    await RoomLeaveIntent.load(uid);
    final store = PlayerRoomSessionStore.instance;
    final session = await store.load();
    if (session == null) return RestorableSession.none;
    if (session.uid != uid) {
      await store.clear(onlyRoomCode: session.roomCode);
      return RestorableSession.none;
    }
    // 사용자가 이미 나갔거나 나가는 중인 방은 되살리지 않습니다.
    if (RoomLeaveIntent.blocksRestore(session.roomCode)) {
      try {
        await _service.leaveRoom(session.roomCode);
        RoomLeaveIntent.complete(session.roomCode);
        await store.clear(onlyRoomCode: session.roomCode);
      } catch (_) {}
      return RestorableSession.none;
    }
    try {
      final restorable = await _service.restorableSession(session.roomCode);
      if (restorable == RestorableSession.none) {
        await store.clear(onlyRoomCode: session.roomCode);
      }
      return restorable;
    } catch (_) {
      // Unknown lookup results retain the saved membership.
      return RestorableSession.none;
    }
  }

  /// 사용자가 복귀를 거절했습니다. 저장 세션을 지워 다시 묻지 않습니다.
  ///
  /// 서버에는 아직 아무것도 쓰지 않았으므로 참가자 노드를 지울 필요가
  /// 없습니다. 방에 남아 있는 노드는 서버 정리가 담당합니다(C-10).
  Future<void> declineRestorableSession() async {
    final session = await PlayerRoomSessionStore.instance.load();
    if (session == null || session.uid != _currentUid()) return;
    RoomLeaveIntent.begin(session.roomCode);
    await _service.leaveRoom(session.roomCode);
    RoomLeaveIntent.complete(session.roomCode);
    await PlayerRoomSessionStore.instance.clear(onlyRoomCode: session.roomCode);
    notifyListeners();
  }

  /// 앱이 완전히 종료된 뒤에도 같은 Firebase UID의 기존 참가자 상태를 복원합니다.
  /// 직접 나가기·강퇴된 사용자는 저장 세션이 지워지므로 자동 입장하지 않습니다.
  Future<bool> restorePlayerRoom() async {
    if (roomCode != null || _isLeaving) return false;
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) return false;
    await RoomLeaveIntent.load(uid);
    final store = PlayerRoomSessionStore.instance;
    final session = await store.load();
    if (session == null) return false;
    if (session.uid != uid) {
      await store.clear(onlyRoomCode: session.roomCode);
      return false;
    }
    // 사용자가 이미 나갔거나 나가는 중인 방은 되살리지 않습니다. 휴대폰은 홈과
    // 참여 화면이 서로 다른 RoomProvider를 쓰므로 이 판단은 인스턴스 필드가
    // 아니라 프로세스 전역 마커로만 가능합니다.
    if (RoomLeaveIntent.blocksRestore(session.roomCode)) {
      return false;
    }

    final epoch = _sessionEpoch;
    bool stillRestoring() =>
        !_isDisposed &&
        _currentUid() == uid &&
        _sessionEpoch == epoch &&
        roomCode == null &&
        !_isLeaving &&
        !RoomLeaveIntent.blocksRestore(session.roomCode);

    try {
      final restorable = await _service.restorableSession(session.roomCode);
      if (!stillRestoring()) return false;
      if (restorable == RestorableSession.none) {
        await store.clear(onlyRoomCode: session.roomCode);
        return false;
      }
      await _service.restorePlayerConnection(
        roomCode: session.roomCode,
        nickname: session.nickname,
        characterId: session.characterId,
      );
      if (!stillRestoring()) {
        // 복원 요청 도중에 퇴장이 확정됐습니다. 방금 서버에 되살린 참가자
        // 노드를 그대로 두면 유령이 되므로 최선 노력으로 다시 내보냅니다.
        // The leave coordinator owns the exact old membership; a late restore never chooses a new target.
        return false;
      }
      wasKicked = false;
      wasRoomClosed = false;
      roomTerminationReason = null;
      _hasJoined = true;
      _joinedNickname = session.nickname;
      _joinedCharacterId = session.characterId;
      roomCode = session.roomCode;
      listenRoom();
      _startPlayerHeartbeat(session.roomCode);
      errorMessage = null;
      notifyListeners();
      return true;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found' ||
          (error.details is Map &&
              (error.details as Map)['reason'] == 'staleContext')) {
        await store.clear(onlyRoomCode: session.roomCode);
      }
      if (!stillRestoring()) return false;
      errorMessage = '연결 복구 결과를 확인하지 못했습니다. 다시 시도해주세요.';
      notifyListeners();
      return false;
    } on RoomCommandException catch (error) {
      // 네트워크 오류라면 저장값을 유지해 연결이 돌아온 뒤 다시 시도합니다.
      if (error.message.contains('종료된 방') ||
          error.message.contains('방을 찾을 수 없습니다')) {
        await store.clear(onlyRoomCode: session.roomCode);
      }
      errorMessage = error.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveRoom() {
    final code = roomCode;
    if (code == null) return Future.value(false);
    return _runLeave(
      code,
      () => _service.leaveRoom(code),
      errorContext: UserErrorContext.leaveRoom,
    );
  }

  /// 게임 중 퇴장: 서버가 다음 턴 또는 인원 부족 종료까지 결정합니다.
  @override
  Future<bool> leaveGame(String gameId) {
    final code = roomCode;
    final game = gameCatalog.find(gameId);
    if (code == null || game == null) return Future.value(false);
    return _runLeave(
      code,
      () => _service.leaveGame(
        cloudFunctionName: game.leaveFunctionName,
        roomCode: code,
      ),
      errorContext: UserErrorContext.leaveGame,
    );
  }

  /// 대기실 퇴장과 게임 중 퇴장의 성공·실패 처리를 한곳에 둡니다.
  ///
  /// `_runCommand`를 쓰지 않는 이유: `_runCommand`는 `isLoading`이면 try 앞에서
  /// 곧바로 반환하므로, 그 앞에서 `_isLeaving`을 세우면 요청도 보내지 않은 채
  /// 플래그만 래치됩니다. 중복 탭 판정을 플래그 대입보다 먼저 두어 그 경로를
  /// 구조적으로 없앱니다.
  ///
  /// 반환값 false에는 두 가지가 있습니다.
  /// 1. 실제 실패 — [errorMessage]가 채워지고 [isLeaving]은 false입니다.
  /// 2. 이미 다른 퇴장이 진행 중 — [isLeaving]이 true로 남습니다.
  /// 호출자는 `!left && isLeaving`이면 아무 오류도 표시하지 않아야 합니다.
  Future<bool> _runLeave(
    String code,
    Future<void> Function() request, {
    required UserErrorContext errorContext,
  }) async {
    if (_leaveRequestInFlight) return false;

    _leaveRequestInFlight = true;
    _isLeaving = true;
    _sessionEpoch += 1;
    RoomLeaveIntent.begin(code);
    final uid = _currentUid();
    if (uid != null) {
      final session = GameRecoverySession.forRoom(code, uid);
      session.leaving = true;
      session.invalidate();
    }
    // RTDB update는 방금 지워진 경로를 되살립니다. 이미 진행 중인 heartbeat가
    // 퇴장 직후 유령 참가자 노드를 만들지 못하게 타이머를 먼저 끊습니다.
    _playerHeartbeatTimer?.cancel();
    _playerHeartbeatTimer = null;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    var left = false;
    try {
      try {
        await request();
        left = true;
      } catch (error) {
        // 서버가 실패로 답했어도 방이 사라졌거나 내 참가자 노드가 이미 없으면
        // 사용자는 실제로 퇴장한 상태입니다. 게임별 leave callable은 방이
        // 삭제된 뒤에는 언제나 aborted로 답하므로 이 판정 없이는 확실히 나간
        // 사용자에게 실패 문구가 뜹니다.
        left = false;
        if (!left) {
          errorMessage =
              userErrorMessage(error, context: errorContext) ??
              UserErrorCopy.requestFailed;
          RoomLeaveIntent.fail(code);
        }
      }

      if (left) {
        // 정리는 _isLeaving이 아직 true인 동안 끝냅니다. players 구독의 강퇴
        // 판정이 본인 퇴장을 가로채지 못하게 하는 것이 이 순서의 목적입니다.
        RoomLeaveIntent.complete(code);
        wasKicked = false;
        _hasJoined = false;
        await PlayerRoomSessionStore.instance.clear(onlyRoomCode: code);
        clearRoom(expectedRoomCode: code);
      }
    } finally {
      // 성공·실패·예외 어느 경로에서도 여기서 복원됩니다. 예전에는 성공했을
      // 때만 clearRoom이 복원해, 실패한 퇴장이 heartbeat와 강퇴 감지를
      // 영구히 끈 상태로 남겼습니다.
      _isLeaving = !left;
      _leaveRequestInFlight = false;
      isLoading = false;
      notifyListeners();
    }
    return left;
  }

  void _releaseReconnect() {
    if (identical(_reconnectSession?.reconnect, _reconnectCallback)) {
      _reconnectSession?.reconnect = null;
    }
    _reconnectSession = null;
    _reconnectCallback = null;
    _confirmedRecovery = null;
    _requestedRecoveryOwner = null;
    _heartbeatPermissionRecoveryAttempted = false;
  }

  // 메모리 초기화 leaveRoom에서 사용
  void clearRoom({
    String? expectedRoomCode,
    bool preserveTerminationReason = false,
  }) {
    // 이전 방의 늦은 closed/players 이벤트가 새 방 상태를 지우지
    // 못하게 구독을 시작한 방 identity를 검증합니다.
    if (expectedRoomCode != null && roomCode != expectedRoomCode) return;

    roomSubscription?.cancel();
    playerSubscription?.cancel();
    connectionSubscription?.cancel();
    statusSubscription?.cancel();
    controllerPresenceSubscription?.cancel();
    roomExistenceSubscription?.cancel();
    _controllerHeartbeatTimer?.cancel();
    _playerHeartbeatTimer?.cancel();
    _controllerPresenceTimer?.cancel();
    _playerPresenceTimer?.cancel();
    _controllerPresenceTimer = null;
    _controllerPresence = ControllerPresence.unknown;
    _playerPresenceTimer = null;
    _ownsControllerSession = false;
    _staleReportTracker.clear();
    _staleReportInFlight.clear();
    _controllerStaleReportLastSeen = null;
    _controllerStaleReportAttempts = 0;
    _controllerStaleReportInFlight = false;
    roomSubscription = null;
    playerSubscription = null;
    connectionSubscription = null;
    statusSubscription = null;
    controllerPresenceSubscription = null;
    roomExistenceSubscription = null;
    _releaseReconnect();
    roomCode = null;
    players = [];
    _removingPlayerUids.clear();
    selectedGameId = null;
    selectedGame = null;
    selectedGameLoadStatus = RoomDataLoadStatus.idle;
    selectedGameError = null;
    _selectedGameRequestId += 1;
    groupGames = [];
    groupGamesLoadStatus = RoomDataLoadStatus.idle;
    groupGamesError = null;
    _lastGroupGameUids = null;
    _groupGamesRequestId += 1;
    _hasJoined = false;
    _isLeaving = false;
    _sessionEpoch += 1;
    _wasServerDisconnected = false;
    _isServerConnected = false;
    _roomMissingCandidate = false;
    _roomDeletionConfirmation = null;
    _playerRemovalCheckId += 1;
    _connectionRecoveryFuture = null;
    _joinedNickname = null;
    _joinedCharacterId = null;
    controllerPresenceState = ControllerPresenceState.unknown;
    roomStatus = null;
    if (!preserveTerminationReason) roomTerminationReason = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _releaseReconnect();
    _lifecycleBinding?.removeObserver(this);
    roomSubscription?.cancel();
    playerSubscription?.cancel();
    connectionSubscription?.cancel();
    statusSubscription?.cancel();
    controllerPresenceSubscription?.cancel();
    roomExistenceSubscription?.cancel();
    _controllerHeartbeatTimer?.cancel();
    _playerHeartbeatTimer?.cancel();
    _controllerPresenceTimer?.cancel();
    _playerPresenceTimer?.cancel();
    super.dispose();
  }
}
