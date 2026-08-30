import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/controllers/mafia_controller.dart';
import 'package:project00/games/mafia/providers/mafia_session_provider.dart';
import 'package:project00/games/mafia/services/mafia_command_service.dart';
import 'package:project00/games/mafia/services/mafia_query_service.dart';
import 'package:project00/games/mafia/services/mafia_service.dart';
import 'package:project00/games/shared/services/game_interruption_command_service.dart';

//=======================인원 부족 즉시 종료 가드 (C-11)==============================
// 즉시 종료는 `제외하고 계속하기`의 거울상입니다. 계속할 수 있는 중단에서
// 호출되면 진행 가능한 판을 버튼 하나로 없애게 되므로 서버로 보내기 전에
// 컨트롤러가 막아야 합니다. 세 게임의 메서드가 같은 모양이라 마피아 하나로
// 규칙을 고정합니다.

void main() {
  Map<String, Object?> publicGame({
    required bool canContinue,
    bool withInterruption = true,
  }) {
    return {
      'phase': 'night',
      'status': 'playing',
      'round': 1,
      'revision': 1,
      'turnDeadlineAt': 0,
      'players': <String, Object?>{},
      if (withInterruption)
        'interruption': <String, Object?>{
          'id': 'gone-1000',
          'playerUid': 'gone',
          'playerNickname': '나간사람',
          'playerCharacterId': 'frog',
          'reason': 'left',
          'startedAt': 0,
          'deadlineAt': 60000,
          'eligibleVoterUids': <Object?>['a', 'b'],
          'requiredVotes': canContinue ? 2 : 0,
          'remainingPlayerCount': canContinue ? 4 : 3,
          'minimumPlayerCount': 4,
          'canContinue': canContinue,
        },
    };
  }

  Future<void> pumpUntil(
    bool Function() done, {
    Duration limit = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(limit);
    while (!done() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// 공개 상태를 흘려 넣은 컨트롤러와 기록용 가짜를 돌려줍니다.
  Future<(MafiaController, _RecordingInterruption)> boot(
    Map<String, Object?> value,
  ) async {
    final query = _StreamQuery();
    final interruption = _RecordingInterruption();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final args = MafiaSessionArgs(
      roomCode: 'AMQ42',
      uid: 'tablet',
      service: MafiaService(
        query: query,
        command: _UnusedCommands(),
        interruption: interruption,
      ),
      watchPrivate: false,
    );
    // autoDispose 공급자라 듣는 사람이 없으면 곧바로 정리됩니다.
    container.listen(mafiaSessionProvider(args), (_, _) {});
    final controller = container.read(mafiaSessionProvider(args).notifier);
    query.emitPublic(value);
    await pumpUntil(() => controller.phase == 'night');
    return (controller, interruption);
  }

  test('중단이 없으면 서버로 보내지 않는다', () async {
    final (controller, interruption) = await boot(
      publicGame(canContinue: false, withInterruption: false),
    );
    expect(controller.interruption, isNull);

    expect(await controller.finishInterruptedGameNow(), isFalse);
    expect(interruption.finishNowCalls, isEmpty);
  });

  test('계속할 수 있는 중단은 즉시 종료하지 않는다', () async {
    final (controller, interruption) = await boot(
      publicGame(canContinue: true),
    );
    await pumpUntil(() => controller.interruption != null);
    expect(controller.interruption?.canContinue, isTrue);

    expect(await controller.finishInterruptedGameNow(), isFalse);
    expect(
      interruption.finishNowCalls,
      isEmpty,
      reason: '진행 가능한 판을 버튼 하나로 없애면 안 됩니다',
    );
  });

  test('계속할 수 없는 중단은 현재 중단 ID로 종료를 보낸다', () async {
    final (controller, interruption) = await boot(
      publicGame(canContinue: false),
    );
    await pumpUntil(() => controller.interruption != null);
    expect(controller.interruption?.canContinue, isFalse);

    expect(await controller.finishInterruptedGameNow(), isTrue);
    expect(interruption.finishNowCalls, ['gone-1000']);
  });
}

/// 공개 상태를 직접 흘려 주는 가짜입니다.
class _StreamQuery implements MafiaQueryService {
  final _public = StreamController<DatabaseEvent>.broadcast();

  void emitPublic(Map<String, Object?> value) =>
      _public.add(_FakeEvent(_FakeSnapshot(value)));

  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) => _public.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeEvent implements DatabaseEvent {
  _FakeEvent(this.snapshot);

  @override
  final DataSnapshot snapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeSnapshot implements DataSnapshot {
  _FakeSnapshot(this.value);

  @override
  final Object? value;

  @override
  bool get exists => value != null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedCommands implements MafiaCommandService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 즉시 종료 호출만 기록하고, 나머지 명령이 불리면 바로 알 수 있게 던집니다.
class _RecordingInterruption implements GameInterruptionCommandService {
  final finishNowCalls = <String>[];

  @override
  Future<void> finishNow({
    required String roomCode,
    required String interruptionId,
  }) async {
    finishNowCalls.add(interruptionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
