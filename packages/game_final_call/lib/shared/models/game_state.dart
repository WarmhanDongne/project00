// [game_state.dart] 는 파이널콜에서 사용하는 게임 상태와 Riverpod 생명주기를 관리하는 파일이다.
//
// - [Package] : 파이널콜
// - [State] : 게임 상태와 Riverpod 생명주기를 관리함
//
// 즉, 휴대폰과 태블릿이 같은 서버 상태를 안정적으로 구독하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/models/game_session_state.dart';

// ============================================================

const Object _notProvided = Object();

// ---------------------------------------------------------------------------
// Final Call 불변 게임 상태
// ---------------------------------------------------------------------------
/// Realtime Database 공개 상태, 개인 손패, 명령 실행 상태를 한 시점의
/// 스냅샷으로 표현합니다. 모든 컬렉션은 외부에서 변경할 수 없습니다.
@immutable
class FinalCallGameState implements GameSessionState<FinalCallGameState> {
  const FinalCallGameState({
    required this.loading,
    required this.commandInFlight,
    required this.errorMessage,
    required this.status,
    required this.finishReason,
    required this.phase,
    required this.round,
    required this.revision,
    required this.turnUid,
    required this.turnDeadlineAt,
    required this.callerUid,
    required this.deckRemainingCount,
    required this.discardCard,
    required this.pendingDrawUid,
    required this.pendingDrawSource,
    required this.finalTurnPendingUids,
    required this.winnerUid,
    required this.winnerUids,
    required this.winningTeam,
    required this.resultRevealCompletedAt,
    required this.players,
    required this.hand,
    required this.pendingDraw,
    required this.roundResult,
    required this.discardEvent,
    required this.interruption,
  });

  factory FinalCallGameState.initial() => const FinalCallGameState(
    loading: true,
    commandInFlight: false,
    errorMessage: null,
    status: 'playing',
    finishReason: null,
    phase: 'dealing',
    round: 1,
    revision: 0,
    turnUid: null,
    turnDeadlineAt: null,
    callerUid: null,
    deckRemainingCount: 0,
    discardCard: null,
    pendingDrawUid: null,
    pendingDrawSource: null,
    finalTurnPendingUids: <String>[],
    winnerUid: null,
    winnerUids: <String>[],
    winningTeam: null,
    resultRevealCompletedAt: null,
    players: <String, FinalCallPlayer>{},
    hand: <FinalCallCard>[],
    pendingDraw: null,
    roundResult: null,
    discardEvent: null,
    interruption: null,
  );

  final bool loading;
  @override
  final bool commandInFlight;
  @override
  final String? errorMessage;
  final String status;
  final String? finishReason;
  final String phase;
  final int round;
  final int revision;
  final String? turnUid;
  final int? turnDeadlineAt;
  final String? callerUid;
  final int deckRemainingCount;
  final FinalCallCard? discardCard;
  final String? pendingDrawUid;
  final String? pendingDrawSource;
  final List<String> finalTurnPendingUids;
  final String? winnerUid;
  final List<String> winnerUids;
  final FinalCallTeam? winningTeam;
  final int? resultRevealCompletedAt;
  final Map<String, FinalCallPlayer> players;
  final List<FinalCallCard> hand;
  final FinalCallCard? pendingDraw;
  final FinalCallRoundResult? roundResult;
  final FinalCallDiscardEvent? discardEvent;
  final GameInterruption? interruption;

  FinalCallGameState copyWith({
    bool? loading,
    bool? commandInFlight,
    Object? errorMessage = _notProvided,
    String? status,
    Object? finishReason = _notProvided,
    String? phase,
    int? round,
    int? revision,
    Object? turnUid = _notProvided,
    Object? turnDeadlineAt = _notProvided,
    Object? callerUid = _notProvided,
    int? deckRemainingCount,
    Object? discardCard = _notProvided,
    Object? pendingDrawUid = _notProvided,
    Object? pendingDrawSource = _notProvided,
    List<String>? finalTurnPendingUids,
    Object? winnerUid = _notProvided,
    List<String>? winnerUids,
    Object? winningTeam = _notProvided,
    Object? resultRevealCompletedAt = _notProvided,
    Map<String, FinalCallPlayer>? players,
    List<FinalCallCard>? hand,
    Object? pendingDraw = _notProvided,
    Object? roundResult = _notProvided,
    Object? discardEvent = _notProvided,
    Object? interruption = _notProvided,
  }) {
    return FinalCallGameState(
      loading: loading ?? this.loading,
      commandInFlight: commandInFlight ?? this.commandInFlight,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
      status: status ?? this.status,
      finishReason: identical(finishReason, _notProvided)
          ? this.finishReason
          : finishReason as String?,
      phase: phase ?? this.phase,
      round: round ?? this.round,
      revision: revision ?? this.revision,
      turnUid: identical(turnUid, _notProvided)
          ? this.turnUid
          : turnUid as String?,
      turnDeadlineAt: identical(turnDeadlineAt, _notProvided)
          ? this.turnDeadlineAt
          : turnDeadlineAt as int?,
      callerUid: identical(callerUid, _notProvided)
          ? this.callerUid
          : callerUid as String?,
      deckRemainingCount: deckRemainingCount ?? this.deckRemainingCount,
      discardCard: identical(discardCard, _notProvided)
          ? this.discardCard
          : discardCard as FinalCallCard?,
      pendingDrawUid: identical(pendingDrawUid, _notProvided)
          ? this.pendingDrawUid
          : pendingDrawUid as String?,
      pendingDrawSource: identical(pendingDrawSource, _notProvided)
          ? this.pendingDrawSource
          : pendingDrawSource as String?,
      finalTurnPendingUids: List.unmodifiable(
        finalTurnPendingUids ?? this.finalTurnPendingUids,
      ),
      winnerUid: identical(winnerUid, _notProvided)
          ? this.winnerUid
          : winnerUid as String?,
      winnerUids: List.unmodifiable(winnerUids ?? this.winnerUids),
      winningTeam: identical(winningTeam, _notProvided)
          ? this.winningTeam
          : winningTeam as FinalCallTeam?,
      resultRevealCompletedAt: identical(resultRevealCompletedAt, _notProvided)
          ? this.resultRevealCompletedAt
          : resultRevealCompletedAt as int?,
      players: Map.unmodifiable(players ?? this.players),
      hand: List.unmodifiable(hand ?? this.hand),
      pendingDraw: identical(pendingDraw, _notProvided)
          ? this.pendingDraw
          : pendingDraw as FinalCallCard?,
      roundResult: identical(roundResult, _notProvided)
          ? this.roundResult
          : roundResult as FinalCallRoundResult?,
      discardEvent: identical(discardEvent, _notProvided)
          ? this.discardEvent
          : discardEvent as FinalCallDiscardEvent?,
      interruption: identical(interruption, _notProvided)
          ? this.interruption
          : interruption as GameInterruption?,
    );
  }

  // ---------------------------------------------------------------------------
  // 값 동등성
  // ---------------------------------------------------------------------------
  // Riverpod 의 Notifier 는 `previous != next` 일 때만 알림을 보냅니다.
  // == 가 없으면 copyWith 가 만든 새 객체는 내용이 같아도 늘 다른 것으로
  // 취급되어, 바뀐 게 없는 스냅샷에도 화면 전체가 다시 그려집니다.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinalCallGameState &&
        loading == other.loading &&
        commandInFlight == other.commandInFlight &&
        errorMessage == other.errorMessage &&
        status == other.status &&
        finishReason == other.finishReason &&
        phase == other.phase &&
        round == other.round &&
        revision == other.revision &&
        turnUid == other.turnUid &&
        turnDeadlineAt == other.turnDeadlineAt &&
        callerUid == other.callerUid &&
        deckRemainingCount == other.deckRemainingCount &&
        discardCard == other.discardCard &&
        pendingDrawUid == other.pendingDrawUid &&
        pendingDrawSource == other.pendingDrawSource &&
        listEquals(finalTurnPendingUids, other.finalTurnPendingUids) &&
        winnerUid == other.winnerUid &&
        listEquals(winnerUids, other.winnerUids) &&
        winningTeam == other.winningTeam &&
        resultRevealCompletedAt == other.resultRevealCompletedAt &&
        mapEquals(players, other.players) &&
        listEquals(hand, other.hand) &&
        pendingDraw == other.pendingDraw &&
        roundResult == other.roundResult &&
        discardEvent == other.discardEvent &&
        interruption == other.interruption;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    loading,
    commandInFlight,
    errorMessage,
    status,
    finishReason,
    phase,
    round,
    revision,
    turnUid,
    turnDeadlineAt,
    callerUid,
    deckRemainingCount,
    discardCard,
    pendingDrawUid,
    pendingDrawSource,
    Object.hashAll(finalTurnPendingUids),
    winnerUid,
    Object.hashAll(winnerUids),
    winningTeam,
    resultRevealCompletedAt,
    Object.hashAllUnordered(
      players.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAll(hand),
    pendingDraw,
    roundResult,
    discardEvent,
    interruption,
  ]);

  // ---------------------------------------------------------------------------
  // 공용 컨트롤러 계약
  // ---------------------------------------------------------------------------
  // [GameSessionController] 가 게임 필드를 모른 채 상태를 바꿀 수 있게
  // 네 가지 순간만 열어 줍니다. 어떤 필드를 어떻게 정리할지는 여기서 정합니다.
  @override
  FinalCallGameState markCommandStarted() =>
      copyWith(commandInFlight: true, errorMessage: null);

  @override
  FinalCallGameState markCommandFinished() => copyWith(commandInFlight: false);

  @override
  FinalCallGameState withError(String? message) =>
      copyWith(errorMessage: message);

  @override
  FinalCallGameState asRemovedGame() => copyWith(
    loading: false,
    status: 'finished',
    finishReason: 'manual',
    phase: 'finished',
    turnUid: null,
    turnDeadlineAt: null,
    pendingDrawUid: null,
    pendingDrawSource: null,
  );
}
