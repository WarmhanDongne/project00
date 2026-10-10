import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:game_kit/core/diagnostics/game_communication_log.dart';

enum RoomTimedAction { create, close }

/// Measures existing room operations without sending any diagnostic requests.
/// Callable durations include SDK, transport and server work; they are not ping.
/// Only fixed stage names and local sample numbers enter the debug log.
class RoomActionTiming {
  RoomActionTiming._(this.action, this._clock)
    : sample = ++_nextSample,
      _started = _clock();

  static final Object _zoneKey = Object();
  static int _nextSample = 0;
  final RoomTimedAction action;
  final Duration Function() _clock;
  final Duration _started;
  final int sample;
  int _step = 0;
  bool _finished = false;

  String get _label => action == RoomTimedAction.create ? '방 생성' : '방 초기화';
  String get _operation => 'room_${action.name}_timing';
  Duration get _elapsed => _clock() - _started;

  static Future<void> run(
    RoomTimedAction action,
    Future<bool> Function() body, {
    @visibleForTesting Duration Function()? clock,
  }) async {
    if (!kDebugMode) {
      await body();
      return;
    }
    final watch = Stopwatch()..start();
    final timing = RoomActionTiming._(action, clock ?? () => watch.elapsed);
    timing._record('측정 시작', 'status=started', GameCommunicationLevel.info);
    var success = false;
    try {
      success = await runZoned(body, zoneValues: {_zoneKey: timing});
    } finally {
      timing._finished = true;
      timing._record(
        '전체 ${success ? '완료' : '실패'}',
        'total_ms=${timing._elapsed.inMilliseconds} '
            'status=${success ? 'success' : 'failure'}',
        success
            ? GameCommunicationLevel.success
            : GameCommunicationLevel.failure,
      );
      watch.stop();
    }
  }

  static Future<T> measure<T>(String stage, Future<T> Function() body) async {
    final timing = kDebugMode
        ? Zone.current[_zoneKey] as RoomActionTiming?
        : null;
    if (timing == null || timing._finished) return body();
    final step = ++timing._step;
    final started = timing._elapsed;
    timing._record(
      stage,
      'step=$step status=started',
      GameCommunicationLevel.info,
    );
    var success = false;
    String? errorCode;
    try {
      final value = await body();
      success = true;
      return value;
    } catch (error) {
      // Log only canonical codes, never messages, details or request values.
      if (error is FirebaseFunctionsException) {
        errorCode =
            const {
              'cancelled',
              'unknown',
              'invalid-argument',
              'deadline-exceeded',
              'not-found',
              'already-exists',
              'permission-denied',
              'resource-exhausted',
              'failed-precondition',
              'aborted',
              'out-of-range',
              'unimplemented',
              'internal',
              'unavailable',
              'data-loss',
              'unauthenticated',
            }.contains(error.code)
            ? error.code
            : 'unknown';
      } else if (error is TimeoutException) {
        errorCode = 'deadline-exceeded';
      }
      rethrow;
    } finally {
      // A late Future cannot add a success to a completed/failed sample.
      if (!timing._finished) {
        timing._record(
          stage,
          'step=$step elapsed_ms=${(timing._elapsed - started).inMilliseconds} '
          'total_ms=${timing._elapsed.inMilliseconds} '
          'status=${success ? 'success' : 'failure'}'
          '${errorCode == null ? '' : ' error_code=$errorCode'}',
          success
              ? GameCommunicationLevel.info
              : GameCommunicationLevel.warning,
        );
      }
    }
  }

  void _record(String stage, String detail, GameCommunicationLevel level) {
    GameCommunicationLog.instance.add(
      level: level,
      title: '$_label · $stage',
      detail: 'sample=$sample $detail',
      operation: _operation,
      traceId: 'local_room_$sample',
    );
  }
}
