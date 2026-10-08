import 'package:flutter/foundation.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';

@immutable
class HoldemCardModel {
  const HoldemCardModel({
    required this.id,
    required this.rank,
    required this.suit,
  });

  factory HoldemCardModel.fromValue(Object? value) {
    final map = value is Map
        ? Map<Object?, Object?>.from(value)
        : const <Object?, Object?>{};
    return HoldemCardModel(
      id: map['id']?.toString() ?? '',
      rank: map['rank']?.toString() ?? '',
      suit: map['suit']?.toString() ?? '',
    );
  }

  final String id;
  final String rank;
  final String suit;

  @override
  bool operator ==(Object other) =>
      other is HoldemCardModel &&
      id == other.id &&
      rank == other.rank &&
      suit == other.suit;
  @override
  int get hashCode => Object.hash(id, rank, suit);
}

@immutable
class HoldemPlayerModel {
  const HoldemPlayerModel({
    required this.uid,
    required this.nickname,
    required this.characterId,
    required this.seatIndex,
    required this.stack,
    required this.status,
    required this.handStatus,
    required this.streetContribution,
    required this.totalContribution,
  });

  factory HoldemPlayerModel.fromValue(String uid, Object? value) {
    final map = value is Map
        ? Map<Object?, Object?>.from(value)
        : const <Object?, Object?>{};
    return HoldemPlayerModel(
      uid: uid,
      nickname: map['nickname']?.toString() ?? 'Player',
      characterId: map['characterId']?.toString() ?? 'frog',
      seatIndex: (map['seatIndex'] as num?)?.toInt() ?? -1,
      stack: (map['stack'] as num?)?.toInt() ?? 0,
      status: map['status']?.toString() ?? 'eliminated',
      handStatus: map['handStatus']?.toString() ?? 'eliminated',
      streetContribution: (map['streetContribution'] as num?)?.toInt() ?? 0,
      totalContribution: (map['totalContribution'] as num?)?.toInt() ?? 0,
    );
  }

  final String uid;
  final String nickname;
  final String characterId;
  final int seatIndex;
  final int stack;
  final String status;
  final String handStatus;
  final int streetContribution;
  final int totalContribution;

  @override
  bool operator ==(Object other) =>
      other is HoldemPlayerModel &&
      uid == other.uid &&
      nickname == other.nickname &&
      characterId == other.characterId &&
      seatIndex == other.seatIndex &&
      stack == other.stack &&
      status == other.status &&
      handStatus == other.handStatus &&
      streetContribution == other.streetContribution &&
      totalContribution == other.totalContribution;
  @override
  int get hashCode => Object.hash(
    uid,
    nickname,
    characterId,
    seatIndex,
    stack,
    status,
    handStatus,
    streetContribution,
    totalContribution,
  );
}

@immutable
class HoldemLegalActionsModel {
  const HoldemLegalActionsModel({
    required this.fold,
    required this.check,
    required this.call,
    required this.bet,
    required this.raise,
    required this.allIn,
    required this.toCall,
    required this.callAmount,
    required this.minimumTarget,
    required this.maximumTarget,
  });

  factory HoldemLegalActionsModel.fromValue(Object? value) {
    final map = value is Map
        ? Map<Object?, Object?>.from(value)
        : const <Object?, Object?>{};
    return HoldemLegalActionsModel(
      fold: map['fold'] == true,
      check: map['check'] == true,
      call: map['call'] == true,
      bet: map['bet'] == true,
      raise: map['raise'] == true,
      allIn: map['allIn'] == true,
      toCall: (map['toCall'] as num?)?.toInt() ?? 0,
      callAmount: (map['callAmount'] as num?)?.toInt() ?? 0,
      minimumTarget: (map['minimumTarget'] as num?)?.toInt(),
      maximumTarget: (map['maximumTarget'] as num?)?.toInt() ?? 0,
    );
  }

  final bool fold;
  final bool check;
  final bool call;
  final bool bet;
  final bool raise;
  final bool allIn;
  final int toCall;
  final int callAmount;
  final int? minimumTarget;
  final int maximumTarget;

  @override
  bool operator ==(Object other) =>
      other is HoldemLegalActionsModel &&
      fold == other.fold &&
      check == other.check &&
      call == other.call &&
      bet == other.bet &&
      raise == other.raise &&
      allIn == other.allIn &&
      toCall == other.toCall &&
      callAmount == other.callAmount &&
      minimumTarget == other.minimumTarget &&
      maximumTarget == other.maximumTarget;
  @override
  int get hashCode => Object.hash(
    fold,
    check,
    call,
    bet,
    raise,
    allIn,
    toCall,
    callAmount,
    minimumTarget,
    maximumTarget,
  );
}

@immutable
class HoldemHandResultModel {
  const HoldemHandResultModel({
    required this.reason,
    required this.winnerUids,
    required this.awards,
    required this.revealedHands,
    required this.handCategories,
    this.bestCards = const {},
  });

  factory HoldemHandResultModel.fromValue(Object? value) {
    final map = value is Map
        ? Map<Object?, Object?>.from(value)
        : const <Object?, Object?>{};
    return HoldemHandResultModel(
      reason: map['reason']?.toString() ?? '',
      winnerUids: _stringList(map['winnerUids']),
      awards: _intMap(map['awards']),
      revealedHands: _cardMap(map['revealedHands']),
      handCategories: _stringMap(map['handCategories']),
      bestCards: _cardMap(map['bestCards']),
    );
  }

  final String reason;
  final List<String> winnerUids;
  final Map<String, int> awards;
  final Map<String, List<HoldemCardModel>> revealedHands;
  final Map<String, String> handCategories;

  /// 쇼다운 참가자별 최종 5장입니다. 구버전 서버 결과에는 비어 있습니다.
  final Map<String, List<HoldemCardModel>> bestCards;

  @override
  bool operator ==(Object other) =>
      other is HoldemHandResultModel &&
      reason == other.reason &&
      listEquals(winnerUids, other.winnerUids) &&
      mapEquals(awards, other.awards) &&
      mapEquals(handCategories, other.handCategories) &&
      _cardMapEquals(revealedHands, other.revealedHands) &&
      _cardMapEquals(bestCards, other.bestCards);
  @override
  int get hashCode => Object.hash(
    reason,
    Object.hashAll(winnerUids),
    Object.hashAll(awards.entries),
    Object.hashAll(handCategories.entries),
    Object.hashAll(
      revealedHands.entries.map(
        (entry) => Object.hash(entry.key, Object.hashAll(entry.value)),
      ),
    ),
    Object.hashAll(
      bestCards.entries.map(
        (entry) => Object.hash(entry.key, Object.hashAll(entry.value)),
      ),
    ),
  );
}

/// 휴대폰 본인에게만 내려오는 현재 족보입니다. 화면 표시 전용입니다.
@immutable
class HoldemHandRankModel {
  const HoldemHandRankModel({required this.category, required this.bestCards});

  static HoldemHandRankModel? fromValue(Object? value) {
    if (value is! Map) return null;
    final map = Map<Object?, Object?>.from(value);
    final category = map['category']?.toString();
    final cards = map['bestCards'];
    if (category == null || cards is! List) return null;
    return HoldemHandRankModel(
      category: category,
      bestCards: cards.map(HoldemCardModel.fromValue).toList(growable: false),
    );
  }

  final String category;
  final List<HoldemCardModel> bestCards;

  @override
  bool operator ==(Object other) =>
      other is HoldemHandRankModel &&
      category == other.category &&
      listEquals(bestCards, other.bestCards);
  @override
  int get hashCode => Object.hash(category, Object.hashAll(bestCards));
}

/// 마지막 공개 행동입니다. 태블릿 좌석 라벨과 휴대폰 안내 문구에 씁니다.
@immutable
class HoldemLastActionModel {
  const HoldemLastActionModel({
    required this.uid,
    required this.kind,
    required this.amount,
    required this.createdAt,
  });

  static HoldemLastActionModel? fromValue(Object? value) {
    if (value is! Map) return null;
    final map = Map<Object?, Object?>.from(value);
    final uid = map['uid']?.toString();
    final kind = map['kind']?.toString();
    if (uid == null || kind == null) return null;
    return HoldemLastActionModel(
      uid: uid,
      kind: kind,
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  final String uid;
  final String kind;
  final int amount;
  final int createdAt;

  @override
  bool operator ==(Object other) =>
      other is HoldemLastActionModel &&
      uid == other.uid &&
      kind == other.kind &&
      amount == other.amount &&
      createdAt == other.createdAt;
  @override
  int get hashCode => Object.hash(uid, kind, amount, createdAt);
}

List<String> _stringList(Object? value) => value is List
    ? value.map((item) => item.toString()).toList(growable: false)
    : const [];
Map<String, int> _intMap(Object? value) => value is Map
    ? Map<String, int>.fromEntries(
        value.entries.map(
          (entry) => MapEntry(
            entry.key.toString(),
            (entry.value as num?)?.toInt() ?? 0,
          ),
        ),
      )
    : const {};
Map<String, String> _stringMap(Object? value) => value is Map
    ? Map<String, String>.fromEntries(
        value.entries.map(
          (entry) => MapEntry(entry.key.toString(), entry.value.toString()),
        ),
      )
    : const {};
Map<String, List<HoldemCardModel>> _cardMap(Object? value) => value is Map
    ? Map<String, List<HoldemCardModel>>.fromEntries(
        value.entries.map(
          (entry) => MapEntry(
            entry.key.toString(),
            entry.value is List
                ? (entry.value as List)
                      .map(HoldemCardModel.fromValue)
                      .toList(growable: false)
                : const [],
          ),
        ),
      )
    : const {};
bool _cardMapEquals(
  Map<String, List<HoldemCardModel>> a,
  Map<String, List<HoldemCardModel>> b,
) =>
    a.length == b.length &&
    a.entries.every((entry) => listEquals(entry.value, b[entry.key]));

GameInterruption? interruptionFrom(Object? value) => value is Map
    ? GameInterruption.fromMap(Map<Object?, Object?>.from(value))
    : null;
