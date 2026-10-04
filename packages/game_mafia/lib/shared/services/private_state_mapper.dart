// [private_state_mapper.dart] 마피아 개인 snapshot을 화면용 값으로 변환하는
// 순수 파서입니다. 가장 최근 조사 기록을 고르는 일도 여기서 한 번만 수행합니다.

import 'package:game_mafia/shared/models/state_models.dart';
import 'package:game_mafia/shared/services/public_state_mapper.dart';

class MafiaPrivateSnapshot {
  const MafiaPrivateSnapshot({
    this.roleId,
    this.allyUids = const [],
    this.nightTargetUid,
    this.allySelections = const {},
    this.latestInvestigation,
    this.voteTargetUid,
    this.trialVote,
    this.discussionSkipVoted = false,
    this.spectatorRoles = const {},
    this.executionerTargetUid,
    this.abilityUsesLeft,
    this.voteBanned = false,
    this.roleChangedRound,
  });

  factory MafiaPrivateSnapshot.fromValue(Object? value) {
    if (value is! Map) return const MafiaPrivateSnapshot();
    final map = Map<Object?, Object?>.from(value);

    MafiaInvestigation? latestInvestigation;
    final rawInvestigations = map['investigations'];
    if (rawInvestigations is Map) {
      for (final entry in rawInvestigations.entries) {
        if (entry.value is! Map) continue;
        final record = MafiaInvestigation.fromMap(
          Map<Object?, Object?>.from(entry.value as Map),
        );
        if (latestInvestigation == null ||
            record.round > latestInvestigation.round) {
          latestInvestigation = record;
        }
      }
    }

    return MafiaPrivateSnapshot(
      roleId: map['roleId']?.toString(),
      allyUids: mafiaStringList(map['allyUids']),
      nightTargetUid: map['nightTargetUid']?.toString(),
      allySelections: parseMafiaStringMap(map['allySelections']),
      latestInvestigation: latestInvestigation,
      voteTargetUid: map['voteTargetUid']?.toString(),
      trialVote: map['trialVote'] is bool ? map['trialVote'] as bool : null,
      discussionSkipVoted: map['discussionSkipVoted'] == true,
      spectatorRoles: parseMafiaStringMap(map['spectatorRoles']),
      executionerTargetUid: map['executionerTargetUid']?.toString(),
      abilityUsesLeft: (map['abilityUsesLeft'] as num?)?.toInt(),
      voteBanned: map['voteBanned'] == true,
      roleChangedRound: (map['roleChangedRound'] as num?)?.toInt(),
    );
  }

  final String? roleId;
  final List<String> allyUids;
  final String? nightTargetUid;
  final Map<String, String> allySelections;
  final MafiaInvestigation? latestInvestigation;
  final String? voteTargetUid;
  final bool? trialVote;
  final bool discussionSkipVoted;
  final Map<String, String> spectatorRoles;
  final String? executionerTargetUid;
  final int? abilityUsesLeft;
  final bool voteBanned;
  final int? roleChangedRound;
}
