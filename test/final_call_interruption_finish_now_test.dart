import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/final_call/controllers/final_call_controller.dart';
import 'package:project00/games/final_call/providers/final_call_session_provider.dart';
import 'package:project00/games/final_call/services/final_call_command_service.dart';
import 'package:project00/games/final_call/services/final_call_query_service.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/shared/services/game_interruption_command_service.dart';

//=======================인원 부족 즉시 종료 (C-11)==============================
// 파이널 콜은 최소 인원이 4명이라 한 명만 빠져도 `canContinue == false`가 됩니다.
// 즉시 종료가 가장 자주 쓰이는 게임이므로 컨트롤러 가드를 따로 고정합니다.
//
// 태블릿과 휴대폰이 같은 메서드(`finishInterruptedGameNow`)와 같은 잠금
// (`commandInFlight`)을 씁니다. 두 화면 모두 `isSubmitting: game.commandInFlight`로
// 버튼을 잠그므로 이 일치가 깨지면 버튼이 활성인 채로 남습니다.

void main() {
  Map<String, Object?> publicGame({
    required bool canContinue,
    bool withInterruption = true,
  }) {
    return {
      'status': 'playing',
      'phase': 'playing',
      'round': 1,
      'revision': 3,
      'turnUid': 'u1',
      'turnDeadlineAt': 0,
      'deckRemainingCount': 20,
      'players': <String, Object?>{
        'u1': {
          'uid': 'u1',
          'nickname': '플레이어1',
          'characterId': 'frog',
          'status': 'alive',
          'seatIndex': 0,
        },
      },
      if (withInterruption)
        'interruption': <String, Object?>{
          'id': 'gone-1000',
          'playerUid': 'gone',
          'playerNickname': '나간사람',
          'playerCharacterId': 'frog',
          'reason': 'disconnected',
          'startedAt': 0,
          'deadlineAt': 60000,
          'eligibleVoterUids': <Object?>['u1'],
          'requiredVotes': canContinue ? 1 : 0,
          // 파이널 콜 최소 인원은 4명입니다(functions.ts MINIMUM_PLAYER_COUNTS).
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

  Future<(FinalCallController, _RecordingInterruption)> boot(
    Map<String, Object?> value,
  ) async {
    final query = _FakeQuery();
    final interruption = _RecordingInterruption();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    addTearDown(() {
      unawaited(query.publicGame.close());
      unawaited(query.privatePlayer.close());
    });

    final provider = finalCallSessionProvider(
      FinalCallSessionArgs(
        roomCode: 'TESTR',
        uid: 'u1',
        service: FinalCallService(
          command: _FakeCommand(),
          query: query,
          interruption: interruption,
        ),
        // 태블릿(진행 기기)은 손패를 구독하지 않습니다.
        watchPrivateHand: false,
      ),
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(provider.notifier);

    query.publicGame.add(_FakeEvent(value));
    await pumpUntil(() => controller.phase == 'playing');
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
    expect(controller.interruption?.minimumPlayerCount, 4);

    expect(await controller.finishInterruptedGameNow(), isTrue);
    expect(interruption.finishNowCalls, ['gone-1000']);
  });

  test('화면이 보는 잠금(commandInFlight)을 쓴다', () async {
    // 휴대폰·태블릿 모두 `isSubmitting: game.commandInFlight`로 버튼을 잠급니다.
    final gate = Completer<void>();
    final (controller, interruption) = await boot(
      publicGame(canContinue: false),
    );
    await pumpUntil(() => controller.interruption != null);
    interruption.gate = gate;

    final pending = controller.finishInterruptedGameNow();
    await pumpUntil(() => controller.commandInFlight);
    expect(controller.commandInFlight, isTrue);

    gate.complete();
    expect(await pending, isTrue);
    expect(controller.commandInFlight, isFalse);
  });

  test('요청이 날아가 있는 동안 두 번째 호출은 보내지 않는다', () async {
    final gate = Completer<void>();
    final (controller, interruption) = await boot(
      publicGame(canContinue: false),
    );
    await pumpUntil(() => controller.interruption != null);
    interruption.gate = gate;

    final first = controller.finishInterruptedGameNow();
    await pumpUntil(() => controller.commandInFlight);
    expect(await controller.finishInterruptedGameNow(), isFalse);
    expect(interruption.finishNowCalls, hasLength(1));

    gate.complete();
    expect(await first, isTrue);
  });
}

class _FakeQuery implements FinalCallQueryService {
  final publicGame = StreamController<DatabaseEvent>.broadcast();
  final privatePlayer = StreamController<DatabaseEvent>.broadcast();

  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) => publicGame.stream;

  @override
  Stream<DatabaseEvent> watchPrivatePlayer({
    required String roomCode,
    required String uid,
  }) => privatePlayer.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeCommand implements FinalCallCommandService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeEvent implements DatabaseEvent {
  _FakeEvent(Object? value) : snapshot = _FakeSnapshot(value);

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

/// 즉시 종료 호출만 기록합니다. [gate]를 채우면 응답을 붙잡아 잠금 상태를
/// 관찰할 수 있습니다.
class _RecordingInterruption implements GameInterruptionCommandService {
  final finishNowCalls = <String>[];
  Completer<void>? gate;

  @override
  Future<void> finishNow({
    required String roomCode,
    required String interruptionId,
  }) async {
    finishNowCalls.add(interruptionId);
    final pending = gate;
    if (pending != null) await pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
