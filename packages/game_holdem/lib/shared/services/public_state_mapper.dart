import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';

class HoldemPublicSnapshot {
  const HoldemPublicSnapshot({
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
    required this.lastAction,
    required this.players,
    required this.result,
    required this.winnerUid,
    required this.finishReason,
    required this.interruption,
  });

  factory HoldemPublicSnapshot.fromValue(Object? value) {
    final map = value is Map
        ? Map<Object?, Object?>.from(value)
        : const <Object?, Object?>{};
    final rawPlayers = map['players'];
    final players = <String, HoldemPlayerModel>{};
    if (rawPlayers is Map) {
      for (final entry in rawPlayers.entries) {
        players[entry.key.toString()] = HoldemPlayerModel.fromValue(
          entry.key.toString(),
          entry.value,
        );
      }
    }
    final rawCards = map['communityCards'];
    return HoldemPublicSnapshot(
      status: map['status']?.toString() ?? 'waiting',
      phase: map['phase']?.toString() ?? 'waiting',
      handNumber: (map['handNumber'] as num?)?.toInt() ?? 1,
      revision: (map['revision'] as num?)?.toInt() ?? 0,
      dealerUid: map['dealerUid']?.toString() ?? '',
      smallBlindUid: map['smallBlindUid']?.toString() ?? '',
      bigBlindUid: map['bigBlindUid']?.toString() ?? '',
      smallBlind: (map['smallBlind'] as num?)?.toInt() ?? 10,
      bigBlind: (map['bigBlind'] as num?)?.toInt() ?? 20,
      communityCards: rawCards is List
          ? rawCards.map(HoldemCardModel.fromValue).toList(growable: false)
          : const [],
      potTotal: (map['potTotal'] as num?)?.toInt() ?? 0,
      turnUid: map['turnUid']?.toString(),
      turnDeadlineAt: (map['turnDeadlineAt'] as num?)?.toInt(),
      currentBet: (map['currentBet'] as num?)?.toInt() ?? 0,
      minimumRaise: (map['minimumRaise'] as num?)?.toInt() ?? 20,
      lastAction: HoldemLastActionModel.fromValue(map['lastAction']),
      players: Map.unmodifiable(players),
      result: map['result'] is Map
          ? HoldemHandResultModel.fromValue(map['result'])
          : null,
      winnerUid: map['winnerUid']?.toString(),
      finishReason: map['finishReason']?.toString(),
      interruption: interruptionFrom(map['recovery']),
    );
  }

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
  final HoldemLastActionModel? lastAction;
  final Map<String, HoldemPlayerModel> players;
  final HoldemHandResultModel? result;
  final String? winnerUid;
  final String? finishReason;
  final GameInterruption? interruption;
}
