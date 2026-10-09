// [game_interruption_command_service.dart] 는 여러 게임이 함께 사용하는 서버의 게임 상태를 변경하는 명령을 모아둔 파일이다.
//
// - [Package] : 게임 공통 기반
// - [RecoveryService] : 준비 보고·진행자 선택 명령을 서버에 전달함
//
// 즉, 화면에서 발생한 행동을 정해진 서버 쓰기 경계로 전달하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:game_kit/services/game_command_service.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'package:game_kit/recovery/services/room_recovery_batch.dart';

// ============================================================

/// 게임 종류와 무관한 연결 중단 투표 명령입니다.
///
/// 네 명령 모두 payload가 `roomCode` + `interruptionId`로 같고, 서버가
/// `interruptionId` 소진으로 멱등하게 처리하므로 전부 재전송을 켭니다.
/// 재전송해도 두 번 처리되지 않고, 서로 경합해도 먼저 도착한 쪽만 반영됩니다.
class GameInterruptionCommandService extends GameCommandService {
  GameInterruptionCommandService({super.functions, super.retryPolicy});
  Future<Map<String, dynamic>> report({
    required String roomCode,
    required Map<String, dynamic> context,
    required int reportSeq,
    required bool ready,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final session = GameRecoverySession.forRoom(roomCode, uid ?? '');
    final data = {
      'roomCode': roomCode,
      ...context,
      'commandId': commandId('report'),
      'reportSeq': reportSeq,
      'state': ready ? 'ready' : 'failed',
      'screenUsable': ready,
      'assetsReady': ready,
    };
    final batch =
        RoomRecoveryBatch.current ??
        (session.preparationBatch ??= RoomRecoveryBatch());
    return batch.run(
      () => invoke('game_common_recovery_report', data, capturedUid: uid),
      isCurrent: () =>
          FirebaseAuth.instance.currentUser?.uid == uid &&
          !session.leaving &&
          session.transportConnected,
      retryable: (error) =>
          error is TimeoutException ||
          (error is FirebaseFunctionsException &&
              const {
                'aborted',
                'deadline-exceeded',
                'unavailable',
              }.contains(error.code)),
    );
  }

  Map<String, dynamic> _causeData(String roomCode, String incidentId) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final pub = GameRecoverySession.forRoom(roomCode, uid).publicValue;
    final raw = pub?['recovery'];
    final recovery = raw is Map ? GameInterruption.fromMap(raw) : null;
    return {
      'roomCode': roomCode,
      'incidentId': incidentId,
      'pauseId': recovery?.pauseId,
      'playerUid': recovery?.playerUid,
    };
  }

  Future<Map<String, dynamic>> waitMore({
    required String roomCode,
    required String interruptionId,
  }) => invoke(
    'game_common_interruption_wait_more',
    _causeData(roomCode, interruptionId),
    retryTransientFailure: true,
  );
  Future<Map<String, dynamic>> expire({
    required String roomCode,
    required String interruptionId,
  }) => invoke(
    'game_common_interruption_expire',
    _causeData(roomCode, interruptionId),
    retryTransientFailure: true,
  );
  Future<Map<String, dynamic>> excludeAndContinue({
    required String roomCode,
    required String interruptionId,
  }) => invoke(
    'game_common_interruption_exclude_player',
    _causeData(roomCode, interruptionId),
    retryTransientFailure: true,
  );
}
