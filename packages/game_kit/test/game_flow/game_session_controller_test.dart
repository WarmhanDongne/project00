import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_flow/game_interruption.dart';
import 'package:game_kit/game_flow/game_session_controller.dart';
import 'package:game_kit/game_flow/game_session_state.dart';
import 'package:game_kit/services/game_interruption_command_service.dart';
import 'package:game_kit/services/game_query_service.dart';

void main() {
  late _Query query;
  late ProviderContainer container;
  late NotifierProvider<_Controller, _State> provider;
  void start() {
    query = _Query();
    container = ProviderContainer();
    provider = NotifierProvider(() => _Controller(query));
    container.listen(provider, (_, _) {});
  }

  tearDown(() async {
    container.dispose();
    await query.events.close();
  });
  Map<String, Object> snapshot(int startedAt, int revision) => {
    'startedAt': startedAt,
    'revision': revision,
  };

  testWidgets('정상 스트림 복구 뒤 늦은 빈 조회는 게임을 종료하지 않는다', (tester) async {
    start();
    query.events.add(_Event(null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(query.reads, 1);
    query.events.add(_Event(snapshot(100, 3)));
    await tester.pump();
    query.read.complete(_Snapshot(null));
    await tester.pump();
    expect(container.read(provider).removed, isFalse);
    expect(container.read(provider).value, snapshot(100, 3));
  });

  testWidgets('정상 스트림 복구 뒤 늦은 이전 조회는 최신 상태를 덮지 않는다', (tester) async {
    start();
    query.events.add(_Event(null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    query.events.add(_Event(snapshot(100, 5)));
    await tester.pump();
    query.read.complete(_Snapshot(snapshot(100, 1)));
    await tester.pump();
    expect(container.read(provider).value, snapshot(100, 5));
  });

  testWidgets('읽기 권한 오류가 반복되어도 방 삭제로 처리하지 않는다', (tester) async {
    start();
    query.events.add(_Event(snapshot(100, 1)));
    await tester.pump();
    final denied = FirebaseException(
      plugin: 'firebase_database',
      code: 'permission-denied',
    );
    query.events.addError(denied);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    query.read.completeError(denied);
    await tester.pump();
    expect(container.read(provider).removed, isFalse);
    expect(container.read(provider).value, snapshot(100, 1));
  });

  testWidgets('정상 상태가 돌아오지 않고 빈 조회가 확인되면 기존 종료 동작 유지', (tester) async {
    start();
    query.events.add(_Event(null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    query.read.complete(_Snapshot(null));
    await tester.pump();
    expect(container.read(provider).removed, isTrue);
  });

  testWidgets('같은 판의 낡은 revision은 무시하고 새 판의 revision 1은 허용', (tester) async {
    start();
    for (final value in [snapshot(100, 5), snapshot(100, 2)]) {
      query.events.add(_Event(value));
      await tester.pump();
    }
    expect(container.read(provider).value, snapshot(100, 5));
    query.events.add(_Event(snapshot(200, 1)));
    await tester.pump();
    query.events.add(_Event(snapshot(100, 6)));
    await tester.pump();
    expect(container.read(provider).value, snapshot(200, 1));
    expect(container.read(provider.notifier).gameStartedAt, 200);
  });

  testWidgets('다시하기에서 DTO가 같아도 새 판 시작을 화면에 알린다', (tester) async {
    start();
    var notifications = 0;
    container.listen(provider, (_, _) => notifications++);
    for (final startedAt in [100, 200]) {
      query.events.add(_Event({'startedAt': startedAt, 'unchangedDto': true}));
      await tester.pump();
    }
    expect(notifications, 2);
  });
}

class _Snapshot extends Fake implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
  @override
  bool get exists => value != null;
}

class _Event extends Fake implements DatabaseEvent {
  _Event(Object? value) : snapshot = _Snapshot(value);
  @override
  final DataSnapshot snapshot;
}

class _Query extends Fake implements GameQueryService {
  final events = StreamController<DatabaseEvent>();
  final read = Completer<DataSnapshot>();
  int reads = 0;
  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) => events.stream;
  @override
  Future<DataSnapshot> readPublicGame(String roomCode) {
    reads++;
    return read.future;
  }
}

class _State implements GameSessionState<_State> {
  const _State({this.value, this.removed = false, this.errorMessage});
  final Object? value;
  final bool removed;
  @override
  final String? errorMessage;
  @override
  bool get commandInFlight => false;
  @override
  _State markCommandStarted() => this;
  @override
  _State markCommandFinished() => this;
  @override
  _State withError(String? message) =>
      _State(value: value, removed: removed, errorMessage: message);
  @override
  _State asRemovedGame() => _State(value: value, removed: true);
}

class _Controller extends GameSessionController<_State> {
  _Controller(this.query);
  @override
  final GameQueryService query;
  @override
  String get roomCode => 'test';
  @override
  String get uid => 'player';
  @override
  String get commandCrashReason => 'test';
  @override
  GameInterruption? get interruption => null;
  @override
  GameInterruptionCommandService get interruptionCommands =>
      throw UnimplementedError();
  @override
  _State build() {
    startSession(watchPrivate: false);
    return const _State();
  }

  @override
  void applyPublicValue(Object? value) {
    state = value is Map && value['unchangedDto'] == true
        ? const _State()
        : _State(value: value);
  }

  @override
  void handlePrivateEvent(DatabaseEvent event) {}
}
