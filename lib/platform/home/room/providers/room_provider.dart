import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:project00/games/game_registry.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/controller_room_session_store.dart';
import 'package:project00/platform/home/room/services/player_room_session_store.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/services/room_service.dart';

enum RoomDataLoadStatus { idle, loading, loaded, failure }

class RoomProvider extends ChangeNotifier {
  RoomProvider({RoomService? service, GameService? gameService})
    : _service = service ?? RoomService(),
      _gameService = gameService ?? GameService();

  final RoomService _service;
  final GameService _gameService;

  String? roomCode;
  StreamSubscription<DatabaseEvent>? roomSubscription;
  StreamSubscription<List<RoomPlayer>>? playerSubscription;
  StreamSubscription<bool>? connectionSubscription;
  StreamSubscription<String?>? statusSubscription;

  List<RoomPlayer> players = [];
  List<GameInfo> groupGames = [];
  RoomDataLoadStatus groupGamesLoadStatus = RoomDataLoadStatus.idle;
  String? groupGamesError;
  bool isLoading = false;
  bool get isInRoom => roomCode != null; // 사용자가 Room 안인지 판단하는 기준 변수.

  bool wasKicked = false;
  bool wasRoomClosed = false;
  bool _hasJoined = false;
  bool _isLeaving = false;
  bool _wasServerDisconnected = false;
  bool _presenceRestoreInFlight = false;
  int _presenceRestoreAttempt = 0;
  Timer? _presenceRetryTimer;
  Timer? _controllerHeartbeatTimer;
  Timer? _playerHeartbeatTimer;
  String? _joinedNickname;
  String? _joinedCharacterId;
  List<String>? _lastGroupGameUids;
  int _groupGamesRequestId = 0;
  int _selectedGameRequestId = 0;
  String? _pendingCreateRoomOperationId;

  String? errorMessage;
  String? selectedGameId;
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

  // phone용 공통함수
  Future<T?> _runCommand<T>(Future<T> Function() command) async {
    // 버튼이 비활성화되기 전 연타 입력이 이미 큐에 들어온
    // 경우에도 동일한 방 명령이 중복 실행되지 않게 합니다.
    if (isLoading) return null;

    // 로딩 시작 및 이전 에러 초기화
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      return await command();
    } on RoomCommandException catch (error) {
      // 비즈니스 로직 예외 처리
      errorMessage = error.message;
      return null;
    } on FirebaseFunctionsException catch (error) {
      // callable 내부 코드·stack trace는 화면에 노출하지 않고 서버가 전달한
      // 사용 가능한 안내 문구만 표시합니다.
      errorMessage = error.message ?? '서버 요청을 처리하지 못했습니다.';
      return null;
    } catch (error) {
      // 기타 일반 예외 처리
      errorMessage = error.toString();
      return null;
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

  Future<void> createRoom() async {
    // Figma 상태 계약에서 방 생성은 `구성원 없음`에서만 가능합니다.
    // 기존 방의 `초기화`는 closeRoom이 담당하며 새 코드를 만들지 않습니다.
    if (roomCode != null || isLoading) return;

    final operationId = _pendingCreateRoomOperationId ??=
        'create_room_${DateTime.now().microsecondsSinceEpoch}';
    final code = await _runCommand<String>(
      () => _service.createRoom(operationId: operationId),
    );

    if (code != null) {
      _pendingCreateRoomOperationId = null;
      roomCode = code;
      listenRoom();
      _startControllerHeartbeat(code);
      notifyListeners();
    }
  }

  Future<void> closeRoom() async {
    final currentCode = roomCode;
    if (currentCode == null || isLoading) return;

    final success = await _runCommand<bool>(() async {
      await _service.closeControllerRoom(currentCode);
      return true;
    });

    if (success == true) {
      clearRoom(expectedRoomCode: currentCode);
    }
  }

  Future<bool> selectGame(String gameId) async {
    if (roomCode == null) return false;

    final result = await _runCommand<bool>(() async {
      await _service.selectGame(roomCode: roomCode!, gameId: gameId);
      return true;
    });

    return result ?? false;
  }

  /// 휴대폰 대기실에서 게임 종류와 무관하게 시작 상태를 한 번만 구독합니다.
  Stream<String?> watchGameStatus(String code) =>
      _service.watchGameStatus(code.trim().toUpperCase());

  /// 태블릿이 방을 열고 있는지 구독합니다. 휴대폰이 무한 대기하지 않도록
  /// 태블릿이 사라지면 알려 줍니다.
  Stream<bool?> watchControllerConnected(String code) =>
      _service.watchControllerConnected(code.trim().toUpperCase());

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
    }, onError: _handleSubscriptionError);
  }

  void stopRoomPreview() {
    if (roomCode != null) return;
    playerSubscription?.cancel();
    playerSubscription = null;
    players = [];
    notifyListeners();
  }

  Stream<bool> watchServerConnection() => _service.watchServerConnection();

  /// 태블릿이 방 화면을 열고 있는 동안 접속 표시를 유지합니다.
  Future<void> markControllerConnected() async {
    final code = roomCode;
    if (code == null) return;
    try {
      await _service.markControllerConnected(code);
      _startControllerHeartbeat(code);
    } catch (_) {
      // 접속 표시 실패가 방 진행을 막지 않습니다.
    }
  }

  Future<void> restoreControllerRoom() async {
    if (roomCode != null) return;
    try {
      final restoredCode = await _service.restoreControllerRoom();
      if (restoredCode == null || _isDisposed) return;
      roomCode = restoredCode;
      listenRoom();
      _startControllerHeartbeat(restoredCode);
      notifyListeners();
    } on RoomCommandException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  void _startControllerHeartbeat(String code) {
    _controllerHeartbeatTimer?.cancel();
    _controllerHeartbeatTimer = Timer.periodic(const Duration(seconds: 10), (
      _,
    ) {
      if (roomCode == code) unawaited(_service.heartbeatController(code));
    });
  }

  Future<void> resumeControllerPresence() async {
    final code = roomCode;
    if (code == null) return;
    try {
      await _service.markControllerConnected(code);
      _startControllerHeartbeat(code);
    } catch (_) {}
  }

  Future<void> pauseControllerPresence() async {
    _controllerHeartbeatTimer?.cancel();
    _controllerHeartbeatTimer = null;
    final code = roomCode;
    if (code == null) return;
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

  Future<bool> removePlayer(String userUid) async {
    final result = await _runCommand<bool>(() async {
      await _service.removePlayer(roomCode!, userUid);
      return true;
    });
    return result ?? false;
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

  void listenRoom() {
    final listenedRoomCode = roomCode;
    if (listenedRoomCode == null) return;

    roomSubscription?.cancel();
    playerSubscription?.cancel();
    connectionSubscription?.cancel();
    statusSubscription?.cancel();
    _presenceRetryTimer?.cancel();
    _playerHeartbeatTimer?.cancel();

    connectionSubscription = _service.watchServerConnection().listen(
      _handleServerConnection,
      onError: (_) => _handleServerConnection(false),
    );

    statusSubscription = _service
        .watchRoomStatus(listenedRoomCode)
        .listen(
          (status) {
            if (roomCode != listenedRoomCode) return;
            // Realtime Database는 삭제된 노드를 null로 전달합니다. cleanup으로
            // 방 노드가 삭제됐거나 status 없이 players만 남은 깨진 방은 종료된
            // 방과 동일하게 처리해, heartbeat가 유령 방을 되살리지 않게 합니다.
            if (status == 'closed' || status == null) {
              _hasJoined = false;
              wasRoomClosed = true;
              unawaited(
                PlayerRoomSessionStore.instance.clear(
                  onlyRoomCode: listenedRoomCode,
                ),
              );
              clearRoom(expectedRoomCode: listenedRoomCode);
            }
          },
          onError: (Object error) {
            // 내 참가자 노드가 사라지면 status 읽기 권한도 함께 사라져 이 구독이
            // permission-denied로 종료됩니다. 퇴장·강퇴·방 삭제 정리는 players
            // 구독이 담당하므로 여기서는 unhandled exception만 막습니다.
            final message = error.toString().toLowerCase();
            if (message.contains('permission')) return;
            _handleSubscriptionError(error);
          },
        );

    if (_joinedNickname != null) {
      _startPlayerHeartbeat(listenedRoomCode);
    }

    roomSubscription = _service.watchRoom(listenedRoomCode).listen((event) {
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
    }, onError: _handleSubscriptionError);
    playerSubscription = _service.watchRoomPlayers(listenedRoomCode).listen((
      roomPlayer,
    ) {
      if (roomCode != listenedRoomCode) return;
      players = roomPlayer;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final myUid = currentUser.uid;
        final isMeInPlayers = roomPlayer.any(
          (p) => p.uid == myUid && p.isActive,
        );
        if (isMeInPlayers) {
          _hasJoined = true;
        } else if (_hasJoined && !_isLeaving) {
          _hasJoined = false;
          wasKicked = true;
          unawaited(
            PlayerRoomSessionStore.instance.clear(
              onlyRoomCode: listenedRoomCode,
            ),
          );
          clearRoom(expectedRoomCode: listenedRoomCode);
          return;
        }
      }
      // players 변경(heartbeat 포함)은 Firestore 조회를 기다리지 않고 즉시
      // 화면에 반영합니다.
      notifyListeners();

      // 활성화된 유저의 uids 추출
      final activeUids = players
          .where((p) => p.isActive)
          .map((p) => p.uid)
          .toList(growable: false);
      unawaited(
        _refreshGroupGames(activeUids, expectedRoomCode: listenedRoomCode),
      );
    }, onError: _handleSubscriptionError);
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
    final sortedUids = [...activeUids]..sort();
    if (!force && listEquals(_lastGroupGameUids, sortedUids)) return;
    _lastGroupGameUids = sortedUids;
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
      final games = await _gameService.fetchGroupGames(activeUids);
      if (_isDisposed ||
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
      _lastGroupGameUids = null;
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
    final activeUids = players
        .where((player) => player.isActive)
        .map((player) => player.uid)
        .toList(growable: false);
    await _refreshGroupGames(activeUids, expectedRoomCode: code, force: true);
  }

  void _startPlayerHeartbeat(String code) {
    _playerHeartbeatTimer?.cancel();
    unawaited(_service.heartbeatPlayer(code));
    _playerHeartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (roomCode == code && !_isLeaving) {
        unawaited(_service.heartbeatPlayer(code));
      }
    });
  }

  void _handleServerConnection(bool isConnected) {
    if (!isConnected) {
      _wasServerDisconnected = true;
      return;
    }
    if (!_wasServerDisconnected) return;
    _wasServerDisconnected = false;
    final code = roomCode;
    final isController =
        code != null &&
        ControllerRoomSessionStore.instance.sessionIdForRoom(code) != null;
    if (isController) {
      unawaited(resumeControllerPresence());
    } else {
      unawaited(_restorePlayerConnection());
    }
  }

  /// 네트워크 모달의 재시도 버튼에서 현재 세션을 실제로 복원합니다.
  ///
  /// RTDB는 물리 네트워크가 돌아오면 자체 재연결하므로 `goOnline()`을 다시 부르는
  /// 대신, 연결 단절 중 실패했을 presence 예약과 서버의 참가 상태를 복구합니다.
  Future<void> retryConnectionRecovery() async {
    final code = roomCode;
    if (code == null) return;

    final controllerSessionId = ControllerRoomSessionStore.instance
        .sessionIdForRoom(code);
    if (controllerSessionId != null) {
      await _service
          .markControllerConnected(code)
          .timeout(const Duration(seconds: 8));
      _startControllerHeartbeat(code);
      errorMessage = null;
      notifyListeners();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    RoomPlayer? currentPlayer;
    for (final player in players) {
      if (player.uid == user.uid) {
        currentPlayer = player;
        break;
      }
    }
    final nickname = currentPlayer?.nickname ?? _joinedNickname;
    final characterId = currentPlayer?.characterId ?? _joinedCharacterId;
    if (nickname == null || characterId == null) return;

    await _service
        .restorePlayerConnection(
          roomCode: code,
          nickname: nickname,
          characterId: characterId,
        )
        .timeout(const Duration(seconds: 8));
    if (roomCode != code) return;
    _presenceRestoreAttempt = 0;
    _presenceRetryTimer?.cancel();
    _startPlayerHeartbeat(code);
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _restorePlayerConnection() async {
    if (_presenceRestoreInFlight || _isLeaving) return;
    final code = roomCode;
    final user = FirebaseAuth.instance.currentUser;
    if (code == null || user == null) return;
    RoomPlayer? currentPlayer;
    for (final player in players) {
      if (player.uid == user.uid) {
        currentPlayer = player;
        break;
      }
    }
    final nickname = currentPlayer?.nickname ?? _joinedNickname;
    final characterId = currentPlayer?.characterId ?? _joinedCharacterId;
    if (nickname == null || characterId == null) return;

    _presenceRestoreInFlight = true;
    _presenceRetryTimer?.cancel();
    try {
      await _service.restorePlayerConnection(
        roomCode: code,
        nickname: nickname,
        characterId: characterId,
      );
      if (roomCode != code) return;
      _presenceRestoreAttempt = 0;
      _startPlayerHeartbeat(code);
      errorMessage = null;
      notifyListeners();
    } catch (_) {
      if (roomCode != code || _isLeaving) return;
      _presenceRestoreAttempt += 1;
      if (_presenceRestoreAttempt < 4) {
        final delaySeconds = 1 << (_presenceRestoreAttempt - 1);
        _presenceRetryTimer = Timer(Duration(seconds: delaySeconds), () {
          unawaited(_restorePlayerConnection());
        });
      } else {
        errorMessage = '게임 연결을 복원하지 못했습니다. 네트워크를 확인해주세요.';
        notifyListeners();
      }
    } finally {
      _presenceRestoreInFlight = false;
    }
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

  void _handleSubscriptionError(Object error) {
    final message = error.toString().toLowerCase();
    // Realtime Database 스트림은 네트워크 복구 시 자동으로 다시 연결됩니다.
    // iOS 플러그인의 native unknown Stacktrace는 화면에 노출하지 않습니다.
    if (message.contains('firebase_database/unknown') ||
        message.contains('stacktrace:')) {
      errorMessage = null;
      notifyListeners();
      return;
    }
    errorMessage = error.toString();
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
      wasKicked = false;
      // 직전 방이 닫히며 세워진 플래그가 새 방 입장으로 넘어오지 않게 합니다.
      wasRoomClosed = false;
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
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

  /// 앱이 완전히 종료된 뒤에도 같은 Firebase UID의 기존 참가자 상태를 복원합니다.
  /// 직접 나가기·강퇴된 사용자는 저장 세션이 지워지므로 자동 입장하지 않습니다.
  Future<bool> restorePlayerRoom() async {
    if (roomCode != null || _isLeaving) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final store = PlayerRoomSessionStore.instance;
    final session = await store.load();
    if (session == null) return false;
    if (session.uid != user.uid) {
      await store.clear(onlyRoomCode: session.roomCode);
      return false;
    }

    try {
      final exists = await _service.hasExistingPlayer(session.roomCode);
      if (!exists) {
        await store.clear(onlyRoomCode: session.roomCode);
        return false;
      }
      await _service.restorePlayerConnection(
        roomCode: session.roomCode,
        nickname: session.nickname,
        characterId: session.characterId,
      );
      if (_isDisposed) return false;
      wasKicked = false;
      wasRoomClosed = false;
      _hasJoined = true;
      _joinedNickname = session.nickname;
      _joinedCharacterId = session.characterId;
      roomCode = session.roomCode;
      listenRoom();
      _startPlayerHeartbeat(session.roomCode);
      errorMessage = null;
      notifyListeners();
      return true;
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

  Future<bool> leaveRoom() async {
    final code = roomCode;
    if (code == null) return false;

    _isLeaving = true;
    final result = await _runCommand<bool>(() async {
      await _service.leaveRoom(code);
      return true;
    });
    if (result == true) {
      await PlayerRoomSessionStore.instance.clear(onlyRoomCode: code);
      clearRoom();
    }
    return result ?? false;
  }

  /// 게임 중 퇴장: 서버가 다음 턴 또는 인원 부족 종료까지 결정합니다.
  Future<bool> leaveGame(String gameId) async {
    final code = roomCode;
    final game = GameRegistry.find(gameId);
    if (code == null || game == null) return false;

    final result = await _runCommand<bool>(() async {
      await _service.leaveGame(
        cloudFunctionName: game.leaveFunctionName,
        roomCode: code,
      );
      return true;
    });
    if (result == true) {
      await PlayerRoomSessionStore.instance.clear(onlyRoomCode: code);
      clearRoom();
    }
    return result ?? false;
  }

  // 메모리 초기화 leaveRoom에서 사용
  void clearRoom({String? expectedRoomCode}) {
    // 이전 방의 늦은 closed/players 이벤트가 새 방 상태를 지우지
    // 못하게 구독을 시작한 방 identity를 검증합니다.
    if (expectedRoomCode != null && roomCode != expectedRoomCode) return;

    roomSubscription?.cancel();
    playerSubscription?.cancel();
    connectionSubscription?.cancel();
    statusSubscription?.cancel();
    _presenceRetryTimer?.cancel();
    _controllerHeartbeatTimer?.cancel();
    _playerHeartbeatTimer?.cancel();
    roomSubscription = null;
    playerSubscription = null;
    connectionSubscription = null;
    statusSubscription = null;
    roomCode = null;
    players = [];
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
    _wasServerDisconnected = false;
    _presenceRestoreInFlight = false;
    _presenceRestoreAttempt = 0;
    _joinedNickname = null;
    _joinedCharacterId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    roomSubscription?.cancel();
    playerSubscription?.cancel();
    connectionSubscription?.cancel();
    statusSubscription?.cancel();
    _presenceRetryTimer?.cancel();
    _controllerHeartbeatTimer?.cancel();
    _playerHeartbeatTimer?.cancel();
    super.dispose();
  }
}
