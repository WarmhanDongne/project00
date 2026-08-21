import 'package:firebase_database/firebase_database.dart';
import 'package:project00/games/shared/services/game_interruption_command_service.dart';

//=======================연습장 공용 가짜 부품 (개발 전용)=====================
// 로컬 연습 엔진과 원격(같은 맥) 연습 접속이 함께 쓰는 최소 구현입니다.
// 실제 Firebase 객체 대신 값만 실어 나릅니다.

/// 값 하나를 담은 가짜 스냅샷입니다.
class MafiaPracticeFakeSnapshot implements DataSnapshot {
  MafiaPracticeFakeSnapshot(this._value);
  final Object? _value;

  @override
  Object? get value => _value;

  @override
  bool get exists => _value != null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// [MafiaPracticeFakeSnapshot]을 실은 가짜 이벤트입니다.
class MafiaPracticeFakeEvent implements DatabaseEvent {
  MafiaPracticeFakeEvent(Object? value)
    : snapshot = MafiaPracticeFakeSnapshot(value);

  @override
  final DataSnapshot snapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 연습장에는 중단(끊김 투표) 서버가 없으므로 아무것도 하지 않는 구현입니다.
class MafiaPracticeNoopInterruption implements GameInterruptionCommandService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
