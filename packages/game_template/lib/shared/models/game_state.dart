// [game_state.dart] 는 새 게임 템플릿에서 사용하는 서버 상태를 한 번에 발행하는 불변 상태 파일이다.
//
// - [Package] : 새 게임 템플릿
// - [State] : 공용 뼈대(GameSessionState)가 요구하는 계약을 채운 최소 상태
//
// 즉, 새 게임이 이 파일을 복사해 자기 필드만 더하면 되도록 하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
import 'package:game_kit/game_flow/game_interruption.dart';
import 'package:game_kit/game_flow/game_session_state.dart';
// ============================================================

/// [TemplateGameState.copyWith]에서 "넘기지 않음"과 "null로 비움"을 구분합니다.
const Object _notProvided = Object();

// ---------------------------------------------------------------------------
// 새 게임 불변 상태
// ---------------------------------------------------------------------------
/// 새 게임의 서버 미러 상태 견본입니다.
///
/// 세 게임(라이어스포커·파이널콜·마피아)과 같은 규칙을 따릅니다.
/// - 필드는 전부 `final`, 바꿀 때는 [copyWith]로 새 객체를 만듭니다.
/// - **필드를 더하면 [==]와 [hashCode]에도 반드시 더합니다.** 빠뜨리면 그 값이
///   바뀌어도 화면이 다시 그려지지 않습니다.
/// - 아래 여섯 멤버(명령 진행·오류·방 삭제)는 공용 뼈대가 씁니다. 지우지 마세요.
@immutable
class TemplateGameState implements GameSessionState<TemplateGameState> {
  const TemplateGameState({
    required this.loading,
    required this.status,
    required this.phase,
    required this.round,
    required this.revision,
    required this.commandInFlight,
    this.errorMessage,
    this.interruption,
  });

  factory TemplateGameState.initial() => const TemplateGameState(
    loading: true,
    status: 'waiting',
    phase: 'waiting',
    round: 1,
    revision: 0,
    commandInFlight: false,
  );

  /// 첫 공개 상태(`game/public`)를 아직 받지 못했는지입니다.
  final bool loading;
  final String status;
  final String phase;
  final int round;
  final int revision;

  @override
  final bool commandInFlight;

  @override
  final String? errorMessage;

  /// 참가자 끊김 안내입니다. 없으면 null입니다.
  final GameInterruption? interruption;

  bool get isFinished => status == 'finished';

  TemplateGameState copyWith({
    bool? loading,
    String? status,
    String? phase,
    int? round,
    int? revision,
    bool? commandInFlight,
    Object? errorMessage = _notProvided,
    Object? interruption = _notProvided,
  }) {
    return TemplateGameState(
      loading: loading ?? this.loading,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      round: round ?? this.round,
      revision: revision ?? this.revision,
      commandInFlight: commandInFlight ?? this.commandInFlight,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
      interruption: identical(interruption, _notProvided)
          ? this.interruption
          : interruption as GameInterruption?,
    );
  }

  // ---------------------------------------------------------------------------
  // 공용 뼈대가 쓰는 계약
  // ---------------------------------------------------------------------------
  @override
  TemplateGameState markCommandStarted() =>
      copyWith(commandInFlight: true, errorMessage: null);

  @override
  TemplateGameState markCommandFinished() => copyWith(commandInFlight: false);

  @override
  TemplateGameState withError(String? message) =>
      copyWith(errorMessage: message);

  @override
  TemplateGameState asRemovedGame() =>
      copyWith(loading: false, status: 'finished', phase: 'finished');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateGameState &&
          loading == other.loading &&
          status == other.status &&
          phase == other.phase &&
          round == other.round &&
          revision == other.revision &&
          commandInFlight == other.commandInFlight &&
          errorMessage == other.errorMessage &&
          interruption == other.interruption;

  @override
  int get hashCode => Object.hash(
    loading,
    status,
    phase,
    round,
    revision,
    commandInFlight,
    errorMessage,
    interruption,
  );
}
