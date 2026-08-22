import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/liars_poker/controllers/liars_poker_controller.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_session_provider.dart';
import 'package:project00/games/liars_poker/services/liars_poker_command_service.dart';
import 'package:project00/games/liars_poker/services/liars_poker_query_service.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/shared/services/game_interruption_command_service.dart';

//=======================인원 부족 즉시 종료 (C-11)==============================
// 라이어스 포커는 즉시 종료 메서드가 **두 개**입니다. 휴대폰용은 명령 잠금을,
// 태블릿용은 메뉴 잠금을 씁니다. 태블릿 화면이 `isMenuCommandInFlight`를 보고
// 버튼을 잠그므로, 태블릿용이 명령 잠금을 쓰면 버튼이 활성인 채로 남고 두 번째
// 탭이 컨트롤러 안에서 표시 없이 드롭됩니다. 그 어긋남을 여기서 고정합니다.

void main() {
  Map<String, Object?> publicGame({
    required bool canContinue,
    bool withInterruption = true,
  }) {
    return {
      'status': 'playing',
      'phase': 'playing',
      'table': 'K',
      'turnUid': 'u1',
      'round': 1,
      'revision': 3,
      'players': <String, Object?>{
        'u1': {
          'uid': 'u1',
          'nickname': '플레이어1',
          'characterId': 'frog',
          'status': 'alive',
          'remainingCardCount': 5,
          'seatIndex': 0,
        },
      },
      if (withInterruption)
        'interruption': <String, Object?>{
          'id': 'gone-1000',
          'playerUid': 'gone',
          'playerNickname': '나간사람',
          'playerCharacterId': 'frog',
          'reason': 'left',
          'startedAt': 0,
          'deadlineAt': 60000,
          'eligibleVoterUids': <Object?>['u1'],
          'requiredVotes': canContinue ? 1 : 0,
          'remainingPlayerCount': canContinue ? 2 : 1,
          'minimumPlayerCount': 2,
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

  Future<(LiarsPokerController, _RecordingInterruption)> boot(
    Map<String, Object?> value,
  ) async {
    final query = _FakeQuery();
    final interruption = _RecordingInterruption();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    addTearDown(() {
      unawaited(query.publicGame.close());
      unawaited(query.privateHand.close());
    });

    final provider = liarsPokerSessionProvider(
      LiarsPokerSessionArgs(
        roomCode: 'TESTR',
        uid: 'u1',
        service: LiarsPokerService(
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

  //=======================휴대폰용==============================

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

    expect(await controller.finishInterruptedGameNow(), isTrue);
    expect(interruption.finishNowCalls, ['gone-1000']);
  });

  //=======================태블릿(진행자)용==============================

  test('태블릿용도 계속할 수 있는 중단은 즉시 종료하지 않는다', () async {
    final (controller, interruption) = await boot(
      publicGame(canContinue: true),
    );
    await pumpUntil(() => controller.interruption != null);

    expect(await controller.finishInterruptedGameNowFromController(), isFalse);
    expect(interruption.finishNowCalls, isEmpty);
  });

  test('태블릿용은 현재 중단 ID로 종료를 보낸다', () async {
    final (controller, interruption) = await boot(
      publicGame(canContinue: false),
    );
    await pumpUntil(() => controller.interruption != null);

    expect(await controller.finishInterruptedGameNowFromController(), isTrue);
    expect(interruption.finishNowCalls, ['gone-1000']);
  });

  test('태블릿용은 메뉴 잠금을 쓴다', () async {
    // 태블릿 화면이 `isSubmitting: game.isMenuCommandInFlight`로 버튼을 잠급니다.
    // 여기서 명령 잠금(isCommandInFlight)이 대신 켜지면 버튼이 활성인 채로 남고,
    // 두 번째 탭이 컨트롤러 안에서 표시 없이 드롭됩니다.
    final gate = Completer<void>();
    final (controller, interruption) = await boot(
      publicGame(canContinue: false),
    );
    await pumpUntil(() => controller.interruption != null);
    interruption.gate = gate;

    final pending = controller.finishInterruptedGameNowFromController();
    await pumpUntil(() => controller.isMenuCommandInFlight);

    expect(controller.isMenuCommandInFlight, isTrue);
    expect(
      controller.isCommandInFlight,
      isFalse,
      reason: '태블릿 화면이 보지 않는 잠금을 켜면 버튼이 풀린 채로 남습니다',
    );

    gate.complete();
    expect(await pending, isTrue);
    expect(controller.isMenuCommandInFlight, isFalse);
  });

  test('휴대폰용은 명령 잠금을 쓴다', () async {
    final gate = Completer<void>();
    final (controller, interruption) = await boot(
      publicGame(canContinue: false),
    );
    await pumpUntil(() => controller.interruption != null);
    interruption.gate = gate;

    final pending = controller.finishInterruptedGameNow();
    await pumpUntil(() => controller.isCommandInFlight);

    expect(controller.isCommandInFlight, isTrue);
    expect(controller.isMenuCommandInFlight, isFalse);

    gate.complete();
    expect(await pending, isTrue);
    expect(controller.isCommandInFlight, isFalse);
  });
}

class _FakeQuery implements LiarsPokerQueryService {
  final publicGame = StreamController<DatabaseEvent>.broadcast();
  final privateHand = StreamController<DatabaseEvent>.broadcast();

  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) => publicGame.stream;

  @override
  Stream<DatabaseEvent> watchPrivateHand({
    required String roomCode,
    required String uid,
  }) => privateHand.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeCommand implements LiarsPokerCommandService {
  @override
  Future<Map<String, dynamic>> warmUpGameplayCommands() async => const {};

  @override
  Future<Map<String, dynamic>> warmUpLiarCommand() async => const {};

  @override
  Future<Map<String, dynamic>> readyTurn({required String roomCode}) async =>
      const {};

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
