import 'package:flutter/foundation.dart';
import 'package:game_kit/recovery/services/room_recovery_batch.dart';
import 'package:game_kit/core/diagnostics/frame_safe_notifier.dart';

@immutable
class GameRecoveryContext {
  const GameRecoveryContext({
    required this.gameInstanceId,
    required this.phaseSeq,
    required this.turnSeq,
    required this.dataSeq,
    required this.resumeEpoch,
  });
  factory GameRecoveryContext.fromMap(Map map) => GameRecoveryContext(
    gameInstanceId: map['gameInstanceId']?.toString() ?? '',
    phaseSeq: map['phaseSeq'] is num ? (map['phaseSeq'] as num).toInt() : 0,
    turnSeq: map['turnSeq'] is num ? (map['turnSeq'] as num).toInt() : 0,
    dataSeq: map['dataSeq'] is num ? (map['dataSeq'] as num).toInt() : 0,
    resumeEpoch: map['resumeEpoch'] is num
        ? (map['resumeEpoch'] as num).toInt()
        : 0,
  );
  final String gameInstanceId;
  final int phaseSeq, turnSeq, dataSeq, resumeEpoch;
  bool get valid =>
      gameInstanceId.isNotEmpty && phaseSeq > 0 && turnSeq > 0 && dataSeq > 0;
  Map<String, dynamic> get envelope => {
    'gameInstanceId': gameInstanceId,
    'phaseSeq': phaseSeq,
    'turnSeq': turnSeq,
    'dataSeq': dataSeq,
    'resumeEpoch': resumeEpoch,
  };
  bool matchesPrivate(Object? value) {
    if (value is! Map || value['_context'] is! Map) return false;
    final context = GameRecoveryContext.fromMap(value['_context'] as Map);
    return gameInstanceId == context.gameInstanceId &&
        phaseSeq == context.phaseSeq &&
        turnSeq == context.turnSeq &&
        dataSeq == context.dataSeq;
  }

  String get key => '$gameInstanceId/$phaseSeq/$turnSeq/$dataSeq/$resumeEpoch';
}

/// A live controller publishes only validated data. Commands never use cached DTOs.
class GameRecoverySession extends ChangeNotifier with FrameSafeNotifier {
  static final Map<String, GameRecoverySession> _sessions = {};
  static GameRecoverySession forRoom(String code, String uid) => _sessions
      .putIfAbsent('$uid/${code.toUpperCase()}', GameRecoverySession.new);
  GameRecoveryContext? context;
  bool localUsable = false,
      paused = true,
      leaving = false,
      serverConfirmed = false;
  RoomRecoveryBatch? preparationBatch;
  bool transportConnected = true;
  bool transportRecovering = false;

  /// 휴대폰이 관찰한 진행 기기 접속 상태입니다.
  ///
  /// 휴대폰 자신의 Firebase transport와 별개입니다. 태블릿 재연결 안내가
  /// 표시되는 동안 로컬 타이머도 명령을 보내지 못하게 합니다.
  bool controllerAvailable = true;
  Future<void> Function()? reconnect;
  Map<dynamic, dynamic>? publicValue;
  VoidCallback? retry;
  Future<Map<String, dynamic>> Function()? retryCommand;
  void changed() => notifySafely();
  void invalidate() {
    localUsable = false;
    serverConfirmed = false;
    changed();
  }

  bool get canSend =>
      localUsable &&
      transportConnected &&
      !transportRecovering &&
      controllerAvailable &&
      serverConfirmed &&
      !paused &&
      !leaving;
}
