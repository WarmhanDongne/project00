import 'package:flutter/foundation.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/models/game_session_state.dart';

const Object _notProvided = Object();

@immutable
class HoldemGameState implements GameSessionState<HoldemGameState> {
  const HoldemGameState({
    required this.loading,
    required this.status,
    required this.phase,
    required this.handNumber,
    required this.revision,
    required this.dealerUid,
    required this.smallBlindUid,
    required this.bigBlindUid,
    required this.smallBlind,
    required this.bigBlind,
    required this.communityCards,
    required this.potTotal,
    required this.turnUid,
    required this.turnDeadlineAt,
    required this.currentBet,
    required this.minimumRaise,
    required this.players,
    required this.hand,
    required this.commandInFlight,
    this.legalActions,
    this.handRank,
    this.lastAction,
    this.result,
    this.winnerUid,
    this.finishReason,
    this.interruption,
    this.errorMessage,
  });

  factory HoldemGameState.initial() => const HoldemGameState(
    loading: true,
    status: 'waiting',
    phase: 'waiting',
    handNumber: 1,
    revision: 0,
    dealerUid: '',
    smallBlindUid: '',
    bigBlindUid: '',
    smallBlind: 10,
    bigBlind: 20,
    communityCards: [],
    potTotal: 0,
    turnUid: null,
    turnDeadlineAt: null,
    currentBet: 0,
    minimumRaise: 20,
    players: {},
    hand: [],
    commandInFlight: false,
  );

  final bool loading;
  final String status;
  final String phase;
  final int handNumber;
  final int revision;
  final String dealerUid;
  final String smallBlindUid;
  final String bigBlindUid;
  final int smallBlind;
  final int bigBlind;
  final List<HoldemCardModel> communityCards;
  final int potTotal;
  final String? turnUid;
  final int? turnDeadlineAt;
  final int currentBet;
  final int minimumRaise;
  final Map<String, HoldemPlayerModel> players;
  final List<HoldemCardModel> hand;
  final HoldemLegalActionsModel? legalActions;
  final HoldemHandRankModel? handRank;
  final HoldemLastActionModel? lastAction;
  final HoldemHandResultModel? result;
  final String? winnerUid;
  final String? finishReason;
  final GameInterruption? interruption;
  @override
  final bool commandInFlight;
  @override
  final String? errorMessage;

  bool get isFinished => status == 'finished';
  bool get isNaturalResult => finishReason == 'winner';

  HoldemGameState copyWith({
    bool? loading,
    String? status,
    String? phase,
    int? handNumber,
    int? revision,
    String? dealerUid,
    String? smallBlindUid,
    String? bigBlindUid,
    int? smallBlind,
    int? bigBlind,
    List<HoldemCardModel>? communityCards,
    int? potTotal,
    Object? turnUid = _notProvided,
    Object? turnDeadlineAt = _notProvided,
    int? currentBet,
    int? minimumRaise,
    Map<String, HoldemPlayerModel>? players,
    List<HoldemCardModel>? hand,
    Object? legalActions = _notProvided,
    Object? handRank = _notProvided,
    Object? lastAction = _notProvided,
    Object? result = _notProvided,
    Object? winnerUid = _notProvided,
    Object? finishReason = _notProvided,
    Object? interruption = _notProvided,
    bool? commandInFlight,
    Object? errorMessage = _notProvided,
  }) => HoldemGameState(
    loading: loading ?? this.loading,
    status: status ?? this.status,
    phase: phase ?? this.phase,
    handNumber: handNumber ?? this.handNumber,
    revision: revision ?? this.revision,
    dealerUid: dealerUid ?? this.dealerUid,
    smallBlindUid: smallBlindUid ?? this.smallBlindUid,
    bigBlindUid: bigBlindUid ?? this.bigBlindUid,
    smallBlind: smallBlind ?? this.smallBlind,
    bigBlind: bigBlind ?? this.bigBlind,
    communityCards: communityCards ?? this.communityCards,
    potTotal: potTotal ?? this.potTotal,
    turnUid: identical(turnUid, _notProvided)
        ? this.turnUid
        : turnUid as String?,
    turnDeadlineAt: identical(turnDeadlineAt, _notProvided)
        ? this.turnDeadlineAt
        : turnDeadlineAt as int?,
    currentBet: currentBet ?? this.currentBet,
    minimumRaise: minimumRaise ?? this.minimumRaise,
    players: players ?? this.players,
    hand: hand ?? this.hand,
    legalActions: identical(legalActions, _notProvided)
        ? this.legalActions
        : legalActions as HoldemLegalActionsModel?,
    handRank: identical(handRank, _notProvided)
        ? this.handRank
        : handRank as HoldemHandRankModel?,
    lastAction: identical(lastAction, _notProvided)
        ? this.lastAction
        : lastAction as HoldemLastActionModel?,
    result: identical(result, _notProvided)
        ? this.result
        : result as HoldemHandResultModel?,
    winnerUid: identical(winnerUid, _notProvided)
        ? this.winnerUid
        : winnerUid as String?,
    finishReason: identical(finishReason, _notProvided)
        ? this.finishReason
        : finishReason as String?,
    interruption: identical(interruption, _notProvided)
        ? this.interruption
        : interruption as GameInterruption?,
    commandInFlight: commandInFlight ?? this.commandInFlight,
    errorMessage: identical(errorMessage, _notProvided)
        ? this.errorMessage
        : errorMessage as String?,
  );

  @override
  HoldemGameState markCommandStarted() =>
      copyWith(commandInFlight: true, errorMessage: null);
  @override
  HoldemGameState markCommandFinished() => copyWith(commandInFlight: false);
  @override
  HoldemGameState withError(String? message) => copyWith(errorMessage: message);
  @override
  HoldemGameState asRemovedGame() => copyWith(
    loading: false,
    status: 'finished',
    phase: 'finished',
    finishReason: 'removed',
  );

  @override
  bool operator ==(Object other) =>
      other is HoldemGameState &&
      loading == other.loading &&
      status == other.status &&
      phase == other.phase &&
      handNumber == other.handNumber &&
      revision == other.revision &&
      dealerUid == other.dealerUid &&
      smallBlindUid == other.smallBlindUid &&
      bigBlindUid == other.bigBlindUid &&
      smallBlind == other.smallBlind &&
      bigBlind == other.bigBlind &&
      listEquals(communityCards, other.communityCards) &&
      potTotal == other.potTotal &&
      turnUid == other.turnUid &&
      turnDeadlineAt == other.turnDeadlineAt &&
      currentBet == other.currentBet &&
      minimumRaise == other.minimumRaise &&
      mapEquals(players, other.players) &&
      listEquals(hand, other.hand) &&
      legalActions == other.legalActions &&
      handRank == other.handRank &&
      lastAction == other.lastAction &&
      result == other.result &&
      winnerUid == other.winnerUid &&
      finishReason == other.finishReason &&
      interruption == other.interruption &&
      commandInFlight == other.commandInFlight &&
      errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hashAll([
    loading,
    status,
    phase,
    handNumber,
    revision,
    dealerUid,
    smallBlindUid,
    bigBlindUid,
    smallBlind,
    bigBlind,
    Object.hashAll(communityCards),
    potTotal,
    turnUid,
    turnDeadlineAt,
    currentBet,
    minimumRaise,
    Object.hashAll(players.entries),
    Object.hashAll(hand),
    legalActions,
    handRank,
    lastAction,
    result,
    winnerUid,
    finishReason,
    interruption,
    commandInFlight,
    errorMessage,
  ]);
}
