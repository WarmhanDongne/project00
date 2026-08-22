import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/final_call/providers/final_call_session_provider.dart';
import 'package:project00/games/final_call/services/final_call_command_service.dart';
import 'package:project00/games/final_call/services/final_call_query_service.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/shared/services/game_interruption_command_service.dart';

//=======================콜드스타트 예열==============================
// 라이어스 포커·마피아와 같은 규칙입니다. 게임에 들어갈 때 **진행 기기(태블릿)**
// 가 첫 조작 함수를 미리 깨웁니다. 이걸 하지 않으면 그 판의 첫 카드 뽑기와 첫
// CALL이 콜드스타트를 그대로 맞습니다.
//
// 휴대폰은 명령을 보내는 시점이 제각각이라 예열하지 않습니다.
void main() {
  FinalCallService buildService(_RecordingCommands command) => FinalCallService(
    command: command,
    query: _SilentQuery(),
    interruption: _UnusedInterruption(),
  );

  Future<void> pumpUntil(
    bool Function() done, {
    Duration limit = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(limit);
    while (!done() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('태블릿은 첫 조작 함수를 미리 깨운다', () async {
    final command = _RecordingCommands();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final args = FinalCallSessionArgs(
      roomCode: 'ABCDE',
      uid: 'tablet',
      service: buildService(command),
      // 태블릿은 개인 손패를 구독하지 않습니다.
      watchPrivateHand: false,
    );
    container.listen(finalCallSessionProvider(args), (_, _) {});
    container.read(finalCallSessionProvider(args).notifier);

    await pumpUntil(() => command.warmUpCount > 0);
    expect(command.warmUpCount, 1);
  });

  test('휴대폰은 예열하지 않는다', () async {
    final command = _RecordingCommands();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final args = FinalCallSessionArgs(
      roomCode: 'ABCDE',
      uid: 'phone',
      service: buildService(command),
      watchPrivateHand: true,
    );
    container.listen(finalCallSessionProvider(args), (_, _) {});
    container.read(finalCallSessionProvider(args).notifier);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(command.warmUpCount, 0);
  });

  test('예열이 실패해도 게임 진입을 막지 않는다', () async {
    final command = _RecordingCommands(fails: true);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final args = FinalCallSessionArgs(
      roomCode: 'ABCDE',
      uid: 'tablet',
      service: buildService(command),
      watchPrivateHand: false,
    );
    container.listen(finalCallSessionProvider(args), (_, _) {});
    final controller = container.read(finalCallSessionProvider(args).notifier);

    await pumpUntil(() => command.warmUpCount > 0);
    // 예열 실패는 삼킵니다(실제 명령이 재시도합니다).
    expect(controller.errorMessage, isNull);
  });
}

/// 예열 호출만 세는 가짜 명령 서비스입니다.
class _RecordingCommands implements FinalCallCommandService {
  _RecordingCommands({this.fails = false});

  final bool fails;
  int warmUpCount = 0;

  @override
  Future<void> warmUpGameplayCommands() async {
    warmUpCount += 1;
    if (fails) throw StateError('예열 실패');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 아무 상태도 흘리지 않는 가짜 구독입니다(예열만 확인합니다).
class _SilentQuery implements FinalCallQueryService {
  final _public = StreamController<DatabaseEvent>.broadcast();
  final _private = StreamController<DatabaseEvent>.broadcast();

  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) => _public.stream;

  @override
  Stream<DatabaseEvent> watchPrivatePlayer({
    required String roomCode,
    required String uid,
  }) => _private.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedInterruption implements GameInterruptionCommandService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
