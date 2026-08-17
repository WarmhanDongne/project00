import 'package:flutter/foundation.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/games/shared/game_flow/game_interruption.dart';

const Object _notProvided = Object();

//=======================휴대폰 공개 모델==============================
@immutable
class PhoneHandCard {
  const PhoneHandCard({required this.id, required this.rank});

  final String id;
  final String rank;

  /// RTDB `hand/<cardKey>` 항목을 파싱합니다. rank가 없으면 null입니다.
  static PhoneHandCard? fromMap(String key, Map<Object?, Object?> map) {
    final id = map['id']?.toString();
    final rank = map['rank']?.toString();
    if (rank == null || rank.isEmpty) return null;
    return PhoneHandCard(
      id: (id == null || id.isEmpty) ? key : id,
      rank: rank.toUpperCase(),
    );
  }
}

@immutable
class PhoneGamePlayer {
  const PhoneGamePlayer({
    required this.uid,
    required this.nickname,
    required this.profileImageUrl,
    required this.status,
    required this.remainingCardCount,
  });

  final String uid;
  final String nickname;
  final String profileImageUrl;
  final String status;
  final int remainingCardCount;

  factory PhoneGamePlayer.fromMap(String key, Map<Object?, Object?> map) {
    final uid = map['uid']?.toString();
    return PhoneGamePlayer(
      uid: (uid == null || uid.isEmpty) ? key : uid,
      nickname: map['nickname']?.toString() ?? 'Player',
      profileImageUrl: map['profileImageUrl']?.toString() ?? '',
      status: map['status']?.toString() ?? 'alive',
      remainingCardCount: (map['remainingCardCount'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class PhonePenaltyResult {
  const PhonePenaltyResult({
    required this.targetUid,
    required this.result,
    required this.resolvedAt,
  });

  final String targetUid;
  final String result;
  final int resolvedAt;

  /// RTDB `penaltyResult`를 파싱합니다. 필수 값이 없거나 결과 값이 유효하지
  /// 않으면 null입니다.
  static PhonePenaltyResult? fromMap(Map<Object?, Object?> map) {
    final targetUid = map['targetUid']?.toString();
    final result = map['result']?.toString();
    final resolvedAt = (map['resolvedAt'] as num?)?.toInt();
    if (targetUid == null ||
        targetUid.isEmpty ||
        result == null ||
        (result != 'safe' && result != 'eliminated') ||
        resolvedAt == null) {
      return null;
    }
    return PhonePenaltyResult(
      targetUid: targetUid,
      result: result,
      resolvedAt: resolvedAt,
    );
  }
}

//=======================Liar's Poker 휴대폰 불변 상태==============================
@immutable
class LiarsPokerPhoneState {
  const LiarsPokerPhoneState({
    required this.status,
    required this.finishReason,
    required this.phase,
    required this.table,
    required this.turnUid,
    required this.winnerUid,
    required this.penaltyTargetUid,
    required this.lastPlayPlayerUid,
    required this.lastPlayId,
    required this.lastPlayRevealed,
    required this.lastPlayCardCount,
    required this.round,
    required this.revision,
    required this.turnDeadlineAt,
    required this.players,
    required this.handCards,
    required this.handCardAssets,
    required this.isCommandInFlight,
    required this.hasRevealedHand,
    required this.handDealVersion,
    required this.errorMessage,
    required this.liarVerdictMessage,
    required this.liarVerdictIsFalse,
    required this.isLiarVerdictPending,
    required this.penaltyResult,
    required this.isPenaltyResultVisible,
    required this.interruption,
  });

  factory LiarsPokerPhoneState.initial() => const LiarsPokerPhoneState(
    status: 'waiting',
    finishReason: null,
    phase: 'playing',
    table: 'K',
    turnUid: null,
    winnerUid: null,
    penaltyTargetUid: null,
    lastPlayPlayerUid: null,
    lastPlayId: null,
    lastPlayRevealed: false,
    lastPlayCardCount: 0,
    round: 1,
    revision: 0,
    turnDeadlineAt: null,
    players: <String, PhoneGamePlayer>{},
    handCards: <PhoneHandCard>[],
    handCardAssets: <AssetGenImage>[],
    isCommandInFlight: false,
    hasRevealedHand: false,
    handDealVersion: 0,
    errorMessage: null,
    liarVerdictMessage: null,
    liarVerdictIsFalse: false,
    isLiarVerdictPending: false,
    penaltyResult: null,
    isPenaltyResultVisible: false,
    interruption: null,
  );

  final String status;
  final String? finishReason;
  final String phase;
  final String table;
  final String? turnUid;
  final String? winnerUid;
  final String? penaltyTargetUid;
  final String? lastPlayPlayerUid;
  final String? lastPlayId;
  final bool lastPlayRevealed;
  final int lastPlayCardCount;
  final int round;
  final int revision;
  final int? turnDeadlineAt;
  final Map<String, PhoneGamePlayer> players;
  final List<PhoneHandCard> handCards;
  final List<AssetGenImage> handCardAssets;
  final bool isCommandInFlight;
  final bool hasRevealedHand;
  final int handDealVersion;
  final String? errorMessage;
  final String? liarVerdictMessage;
  final bool liarVerdictIsFalse;
  final bool isLiarVerdictPending;
  final PhonePenaltyResult? penaltyResult;
  final bool isPenaltyResultVisible;
  final GameInterruption? interruption;

  LiarsPokerPhoneState copyWith({
    String? status,
    Object? finishReason = _notProvided,
    String? phase,
    String? table,
    Object? turnUid = _notProvided,
    Object? winnerUid = _notProvided,
    Object? penaltyTargetUid = _notProvided,
    Object? lastPlayPlayerUid = _notProvided,
    Object? lastPlayId = _notProvided,
    bool? lastPlayRevealed,
    int? lastPlayCardCount,
    int? round,
    int? revision,
    Object? turnDeadlineAt = _notProvided,
    Map<String, PhoneGamePlayer>? players,
    List<PhoneHandCard>? handCards,
    List<AssetGenImage>? handCardAssets,
    bool? isCommandInFlight,
    bool? hasRevealedHand,
    int? handDealVersion,
    Object? errorMessage = _notProvided,
    Object? liarVerdictMessage = _notProvided,
    bool? liarVerdictIsFalse,
    bool? isLiarVerdictPending,
    Object? penaltyResult = _notProvided,
    bool? isPenaltyResultVisible,
    Object? interruption = _notProvided,
  }) {
    return LiarsPokerPhoneState(
      status: status ?? this.status,
      finishReason: identical(finishReason, _notProvided)
          ? this.finishReason
          : finishReason as String?,
      phase: phase ?? this.phase,
      table: table ?? this.table,
      turnUid: identical(turnUid, _notProvided)
          ? this.turnUid
          : turnUid as String?,
      winnerUid: identical(winnerUid, _notProvided)
          ? this.winnerUid
          : winnerUid as String?,
      penaltyTargetUid: identical(penaltyTargetUid, _notProvided)
          ? this.penaltyTargetUid
          : penaltyTargetUid as String?,
      lastPlayPlayerUid: identical(lastPlayPlayerUid, _notProvided)
          ? this.lastPlayPlayerUid
          : lastPlayPlayerUid as String?,
      lastPlayId: identical(lastPlayId, _notProvided)
          ? this.lastPlayId
          : lastPlayId as String?,
      lastPlayRevealed: lastPlayRevealed ?? this.lastPlayRevealed,
      lastPlayCardCount: lastPlayCardCount ?? this.lastPlayCardCount,
      round: round ?? this.round,
      revision: revision ?? this.revision,
      turnDeadlineAt: identical(turnDeadlineAt, _notProvided)
          ? this.turnDeadlineAt
          : turnDeadlineAt as int?,
      players: Map.unmodifiable(players ?? this.players),
      handCards: List.unmodifiable(handCards ?? this.handCards),
      handCardAssets: List.unmodifiable(handCardAssets ?? this.handCardAssets),
      isCommandInFlight: isCommandInFlight ?? this.isCommandInFlight,
      hasRevealedHand: hasRevealedHand ?? this.hasRevealedHand,
      handDealVersion: handDealVersion ?? this.handDealVersion,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
      liarVerdictMessage: identical(liarVerdictMessage, _notProvided)
          ? this.liarVerdictMessage
          : liarVerdictMessage as String?,
      liarVerdictIsFalse: liarVerdictIsFalse ?? this.liarVerdictIsFalse,
      isLiarVerdictPending: isLiarVerdictPending ?? this.isLiarVerdictPending,
      penaltyResult: identical(penaltyResult, _notProvided)
          ? this.penaltyResult
          : penaltyResult as PhonePenaltyResult?,
      isPenaltyResultVisible:
          isPenaltyResultVisible ?? this.isPenaltyResultVisible,
      interruption: identical(interruption, _notProvided)
          ? this.interruption
          : interruption as GameInterruption?,
    );
  }
}
