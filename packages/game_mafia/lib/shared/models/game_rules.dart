import 'package:flutter/foundation.dart';

@immutable
class MafiaRules {
  const MafiaRules({this.trial = false, this.executionReveal = 'role'});
  final bool trial;
  final String executionReveal;
  factory MafiaRules.fromMap(Object? value) {
    final map = value is Map ? value : const {};
    return MafiaRules(
      trial: map['trial'] == true,
      executionReveal:
          ['role', 'faction', 'hidden'].contains(map['executionReveal'])
          ? map['executionReveal'] as String
          : 'role',
    );
  }
  Map<String, Object> toMap() => {
    'trial': trial,
    'executionReveal': executionReveal,
  };
  @override
  bool operator ==(Object other) =>
      other is MafiaRules &&
      trial == other.trial &&
      executionReveal == other.executionReveal;
  @override
  int get hashCode => Object.hash(trial, executionReveal);
}

/// 신분 배정은 포함하지 않는 공개 규칙·재판 상태입니다.
@immutable
class MafiaRuleState {
  const MafiaRuleState({
    this.rules = const MafiaRules(),
    this.composition = const {},
    this.trialStage,
    this.candidateUid,
    this.revealedFactions = const {},
  });
  final MafiaRules rules;
  final Map<String, int> composition;
  final String? trialStage;
  final String? candidateUid;
  final Map<String, String> revealedFactions;
  factory MafiaRuleState.fromMap(Map<Object?, Object?> map) {
    final trial = map['trial'] is Map ? map['trial'] as Map : const {};
    final composition = map['composition'] is Map
        ? map['composition'] as Map
        : const {};
    final factions = map['revealedFactions'] is Map
        ? map['revealedFactions'] as Map
        : const {};
    return MafiaRuleState(
      rules: MafiaRules.fromMap(map['rules']),
      trialStage: trial['stage'] as String?,
      candidateUid: trial['candidateUid'] as String?,
      composition: Map.unmodifiable({
        for (final e in composition.entries)
          if (e.value is num) e.key.toString(): (e.value as num).toInt(),
      }),
      revealedFactions: Map.unmodifiable({
        for (final e in factions.entries) e.key.toString(): e.value.toString(),
      }),
    );
  }
  @override
  bool operator ==(Object other) =>
      other is MafiaRuleState &&
      rules == other.rules &&
      trialStage == other.trialStage &&
      candidateUid == other.candidateUid &&
      mapEquals(composition, other.composition) &&
      mapEquals(revealedFactions, other.revealedFactions);
  @override
  int get hashCode => Object.hash(
    rules,
    trialStage,
    candidateUid,
    Object.hashAllUnordered(
      composition.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(
      revealedFactions.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
