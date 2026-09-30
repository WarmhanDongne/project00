// [game_query_service.dart] 는 여러 게임이 함께 사용하는 서버의 게임 상태를 조회하고 해석하는 파일이다.

// - [Query] : 상태 조회

// ========================[ import ]==========================
import 'dart:async';
import 'package:firebase_database/firebase_database.dart'; // 방과 게임 상태를 실시간으로 읽고 구독
import 'package:game_kit/firebase/services/realtime_database_service.dart'; // 접근을 공통으로 처리 기능 사용
import 'package:flutter/foundation.dart';
import 'package:game_kit/core/diagnostics/game_communication_log.dart';
// ============================================================

//=======================게임 구독 서비스 공통 베이스==============================

/// rooms/{roomCode}/game/public          방 참가자에게 공개할 상태
/// rooms/{roomCode}/game/private/{uid}   해당 사용자만 읽을 상태
/// rooms/{roomCode}/game/server          클라이언트에 노출하지 않는 서버 상태
/// 그래서 경로 조합은 [publicRef]와 [privateRef] 두 곳에만 둡니다. 게임별

abstract class GameQueryService {
  GameQueryService({FirebaseDatabase? database})
    : database = database ?? RealtimeDatabaseService.instance;

  @protected
  final FirebaseDatabase database;

  /// `rooms/{roomCode}/game/public` 또는 그 하위 노드 참조입니다.
  @protected
  DatabaseReference publicRef(String roomCode, [String? child]) {
    final suffix = child == null ? '' : '/$child';
    return database.ref('rooms/$roomCode/game/public$suffix');
  }

  /// `rooms/{roomCode}/game/private/{uid}` 또는 그 하위 노드 참조입니다.
  @protected
  DatabaseReference privateRef({
    required String roomCode,
    required String uid,
    String? child,
  }) {
    final suffix = child == null ? '' : '/$child';
    return database.ref('rooms/$roomCode/game/private/$uid$suffix');
  }

  /// 모든 기기가 공유하는 공개 게임 상태입니다.
  Stream<DatabaseEvent> watchPublicGame(String roomCode) =>
      observeRealtime(publicRef(roomCode).onValue, channel: '공개 게임');

  /// 공개 게임 노드가 실제로 삭제됐는지 재확인합니다.
  ///
  /// 재연결 직후 스트림이 잠깐 null을 전달한 경우와, 태블릿이 게임을 실제로
  /// 정리한 경우를 구분할 때 사용합니다.
  Future<DataSnapshot> readPublicGame(String roomCode) async {
    GameCommunicationLog.instance.add(
      level: GameCommunicationLevel.info,
      title: '공개 게임 상태 재확인',
      detail: '단일 RTDB 조회 시작',
      operation: 'realtime_database_get',
    );
    try {
      final snapshot = await publicRef(roomCode).get();
      GameCommunicationLog.instance.recordRealtimeSnapshot(
        channel: '공개 게임 재확인',
        value: snapshot.value,
      );
      return snapshot;
    } catch (error) {
      GameCommunicationLog.instance.add(
        level: GameCommunicationLevel.failure,
        title: '공개 게임 상태 재확인 실패',
        detail: '클라이언트 ${error.runtimeType}',
        operation: 'realtime_database_get',
      );
      rethrow;
    }
  }

  /// 게임 상태(`waiting`/`playing`/...)입니다.
  ///
  /// 플랫폼 대기 화면이 `playing`으로 바뀌는 시점에 게임 화면을 엽니다.
  Stream<DatabaseEvent> watchStatus(String roomCode) => observeRealtime(
    publicRef(roomCode, 'status').onValue,
    channel: '게임 status',
  );

  /// 본인만 읽는 상태입니다.
  ///
  /// **태블릿(진행 기기)은 이 구독을 열지 않습니다.** 태블릿 화면에 개인 정보가
  /// 흘러들면 옆에서 보는 사람에게 전부 드러납니다.
  Stream<DatabaseEvent> watchPrivatePlayer({
    required String roomCode,
    required String uid,
  }) => observeRealtime(
    privateRef(roomCode: roomCode, uid: uid).onValue,
    channel: '개인 게임',
  );

  /// 게임별 세부 구독도 같은 진단 타임라인을 사용하게 합니다.
  @protected
  Stream<DatabaseEvent> observeRealtime(
    Stream<DatabaseEvent> source, {
    required String channel,
  }) => source.transform(
    StreamTransformer<DatabaseEvent, DatabaseEvent>.fromHandlers(
      handleData: (event, sink) {
        GameCommunicationLog.instance.recordRealtimeSnapshot(
          channel: channel,
          value: event.snapshot.value,
        );
        sink.add(event);
      },
      handleError: (error, stackTrace, sink) {
        GameCommunicationLog.instance.add(
          level: GameCommunicationLevel.failure,
          title: '$channel 구독 실패',
          detail: '클라이언트 ${error.runtimeType}',
          operation: 'realtime_database',
        );
        sink.addError(error, stackTrace);
      },
    ),
  );
}
