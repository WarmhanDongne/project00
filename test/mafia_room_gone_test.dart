import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/providers/mafia_session_provider.dart';
import 'package:project00/games/mafia/services/mafia_command_service.dart';
import 'package:project00/games/mafia/services/mafia_query_service.dart';
import 'package:project00/games/mafia/services/mafia_service.dart';
import 'package:project00/games/shared/services/game_interruption_command_service.dart';

//=======================방이 사라졌을 때==============================
// 2026-08 시뮬레이터에서 확인한 문제입니다. 방이 지워지자 공개 상태 구독이
// `permission_denied`로 끊겼는데, 컨트롤러는 '연결이 불안정합니다'만 띄우고
// **마지막 상태(밤)에 그대로 머물렀습니다.** 태블릿은 밤 화면에 굳은 채 밤
// 마감 처리를 끝없이 다시 시도하며 오류만 쌓았습니다.
//
// 이제는 읽기가 거부되면 방이 사라진 것으로 보고 게임을 끝냅니다(태블릿은
// 결과·홈으로 화면으로 빠져나갈 수 있습니다).
void main() {
  /// 규칙에 막힌 오류입니다. RTDB가 실제로 던지는 코드와 같습니다.
  FirebaseException denied() => FirebaseException(
    plugin: 'firebase_database',
    code: 'permission-denied',
    message: 'Client doesn\'t have permission to access the desired data.',
  );

  Future<void> pumpUntil(
    bool Function() done, {
    Duration limit = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(limit);
    while (!done() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  test('읽기가 거부되면 게임을 끝내 화면이 굳지 않는다', () async {
    final query = _DeniedQuery(readError: denied());
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final args = MafiaSessionArgs(
      roomCode: 'AMQ42',
      uid: 'tablet',
      service: MafiaService(
        query: query,
        command: _UnusedCommands(),
        interruption: _UnusedInterruption(),
      ),
      watchPrivate: false,
    );
    // autoDispose 공급자라 듣는 사람이 없으면 곧바로 정리됩니다.
    container.listen(mafiaSessionProvider(args), (_, _) {});
    final controller = container.read(mafiaSessionProvider(args).notifier);
    // 밤 상태를 한 번 받은 뒤 방이 지워진 상황입니다.
    query.emitPublic({
      'phase': 'night',
      'status': 'playing',
      'round': 1,
      'revision': 1,
      'turnDeadlineAt': 0,
      'players': <String, Object?>{},
    });
    await pumpUntil(() => controller.phase == 'night');
    expect(controller.phase, 'night');

    query.failPublic(denied());

    await pumpUntil(() => controller.isFinished);
    expect(
      controller.isFinished,
      isTrue,
      reason: '방이 사라졌는데 밤 화면에 머물면 태블릿이 굳습니다',
    );
    expect(controller.turnDeadlineAt, isNull, reason: '마감이 남아 있으면 다시 시도합니다');
  });

  test('네트워크 문제로 끊긴 것은 게임을 끝내지 않는다', () async {
    // 잠깐 끊긴 것으로 게임을 끝내면 복구 뒤에 돌아갈 곳이 없습니다.
    final query = _DeniedQuery(readError: TimeoutException('네트워크'));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final args = MafiaSessionArgs(
      roomCode: 'AMQ42',
      uid: 'tablet',
      service: MafiaService(
        query: query,
        command: _UnusedCommands(),
        interruption: _UnusedInterruption(),
      ),
      watchPrivate: false,
    );
    // autoDispose 공급자라 듣는 사람이 없으면 곧바로 정리됩니다.
    container.listen(mafiaSessionProvider(args), (_, _) {});
    final controller = container.read(mafiaSessionProvider(args).notifier);
    query.emitPublic({
      'phase': 'night',
      'status': 'playing',
      'round': 1,
      'revision': 1,
      'turnDeadlineAt': 0,
      'players': <String, Object?>{},
    });
    await pumpUntil(() => controller.phase == 'night');

    query.failPublic(TimeoutException('네트워크'));
    await Future<void>.delayed(const Duration(seconds: 2));

    expect(controller.isFinished, isFalse);
    expect(controller.phase, 'night');
  });
}

/// 공개 상태를 직접 흘려 주고, 다시 읽으면 정해 둔 오류를 던지는 가짜입니다.
class _DeniedQuery implements MafiaQueryService {
  _DeniedQuery({required this.readError});

  /// `readPublicGame`이 던질 오류입니다.
  final Object readError;

  final _public = StreamController<DatabaseEvent>.broadcast();

  void emitPublic(Map<String, Object?> value) =>
      _public.add(_FakeEvent(_FakeSnapshot(value)));

  void failPublic(Object error) => _public.addError(error);

  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) => _public.stream;

  @override
  Future<DataSnapshot> readPublicGame(String roomCode) async => throw readError;

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

/// 이 테스트는 서버 명령을 부르지 않습니다(부르면 바로 알 수 있게 던집니다).
class _UnusedCommands implements MafiaCommandService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedInterruption implements GameInterruptionCommandService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
