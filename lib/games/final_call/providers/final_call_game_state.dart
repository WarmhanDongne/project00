import 'package:flutter/foundation.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/shared/game_flow/game_interruption.dart';

const Object _notProvided = Object();

//=======================Final Call 불변 게임 상태==============================
/// Realtime Database 공개 상태, 개인 손패, 명령 실행 상태를 한 시점의
/// 스냅샷으로 표현합니다. 모든 컬렉션은 외부에서 변경할 수 없습니다.
@immutable
class FinalCallGameState {
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
  final bool commandInFlight;
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
}
