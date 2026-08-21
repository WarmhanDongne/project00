import 'package:flutter/foundation.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/shared/game_flow/game_interruption.dart';

const Object _notProvided = Object();

//=======================마피아 불변 게임 상태==============================
/// 서버 공개 상태, 본인만 보는 값, 명령 실행 상태를 한 시점의 스냅샷으로
/// 표현합니다. 모든 컬렉션은 외부에서 변경할 수 없습니다.
///
/// **비공개 값은 [myRoleId] 아래 묶음뿐입니다.** 태블릿은 개인 구독을 열지
/// 않으므로 그 값들이 전부 비어 있습니다.
@immutable
class MafiaGameState {
  const MafiaGameState({
    required this.loading,
    required this.commandInFlight,
    required this.errorMessage,
    required this.status,
    required this.finishReason,
    required this.phase,
    required this.round,
    required this.revision,
    required this.turnDeadlineAt,
    required this.players,
    required this.roleRevealedUids,
    required this.nightSubmittedCount,
    required this.nightActorCount,
    required this.discussionSkipCount,
    required this.voteSubmittedCount,
    required this.voteSubmittedUids,
    required this.voteEligibleCount,
    required this.morningResult,
    required this.voteResult,
    required this.revealedRoles,
    required this.winner,
    required this.winnerUids,
    required this.interruption,
    required this.myRoleId,
    required this.allyUids,
    required this.nightTargetUid,
    required this.allySelections,
    required this.latestInvestigation,
    required this.voteTargetUid,
    required this.discussionSkipVoted,
    required this.spectatorRoles,
  });

  factory MafiaGameState.initial() => const MafiaGameState(
    loading: true,
    commandInFlight: false,
    errorMessage: null,
    status: 'playing',
    finishReason: null,
    phase: 'roleReveal',
    round: 1,
    revision: 0,
    turnDeadlineAt: null,
    players: <String, MafiaPlayer>{},
    roleRevealedUids: <String>[],
    nightSubmittedCount: 0,
    nightActorCount: 0,
    discussionSkipCount: 0,
    voteSubmittedCount: 0,
    voteSubmittedUids: <String>[],
    voteEligibleCount: 0,
    morningResult: null,
    voteResult: null,
    revealedRoles: <String, String>{},
    winner: null,
    winnerUids: <String>[],
    interruption: null,
    myRoleId: null,
    allyUids: <String>[],
    nightTargetUid: null,
    allySelections: <String, String>{},
    latestInvestigation: null,
    voteTargetUid: null,
    discussionSkipVoted: false,
    spectatorRoles: <String, String>{},
  );

  //=======================전원 공개==============================
  final bool loading;
  final bool commandInFlight;
  final String? errorMessage;
  final String status;
  final String? finishReason;

  /// `roleReveal` · `night` · `morning` · `day` · `voting` · `voteResult` ·
  /// `finished`.
  final String phase;
  final int round;
  final int revision;

  /// 현재 단계 마감 시각입니다. 제한시간이 없는 단계면 null입니다.
  final int? turnDeadlineAt;
  final Map<String, MafiaPlayer> players;

  /// 역할 확인을 마친 사람입니다.
  final List<String> roleRevealedUids;

  /// 밤 행동을 제출한 **인원수**입니다. 누가 냈는지는 서버가 보내지 않습니다.
  final int nightSubmittedCount;
  final int nightActorCount;

  /// 토론 조기 종료에 동의한 인원수입니다. 버튼이 `n/m`으로 표시합니다.
  final int discussionSkipCount;

  final int voteSubmittedCount;

  /// 투표를 마친 사람들입니다(**표를 어디에 냈는지는 없습니다**).
  ///
  /// 태블릿이 그 좌석에서 투표지가 날아가는 연출을 그리는 데 씁니다.
  final List<String> voteSubmittedUids;

  final int voteEligibleCount;

  final MafiaMorningResult? morningResult;
  final MafiaVoteResult? voteResult;

  /// 모두에게 공개된 신분입니다. `uid → 역할 id`.
  ///
  /// 처형자, 기자가 지목한 사람, 게임 종료 시 전원이 들어옵니다.
  final Map<String, String> revealedRoles;

  /// 승리 진영 id(`citizen`·`mafia`·`neutral`)입니다.
  final String? winner;
  final List<String> winnerUids;
  final GameInterruption? interruption;

  //=======================본인만 (태블릿은 비어 있음)==============================
  /// 내 역할 id입니다. 아직 못 받았거나 태블릿이면 null입니다.
  final String? myRoleId;

  /// 서로 아는 같은 편입니다(마피아).
  final List<String> allyUids;

  /// 내가 이번 밤에 고른 대상입니다.
  final String? nightTargetUid;

  /// 동료가 고른 대상입니다. `동료 uid → 대상 uid`.
  final Map<String, String> allySelections;

  /// 이번 라운드의 조사·추적 결과입니다. 없으면 null입니다.
  final MafiaInvestigation? latestInvestigation;

  /// 내가 투표한 대상입니다.
  final String? voteTargetUid;

  /// 토론 조기 종료에 동의했는지입니다. 재접속해도 버튼 상태가 유지됩니다.
  final bool discussionSkipVoted;

  /// 관전자에게만 주는 전원 신분표입니다. 사망 후에만 채워집니다.
  final Map<String, String> spectatorRoles;

  MafiaGameState copyWith({
    bool? loading,
    bool? commandInFlight,
    Object? errorMessage = _notProvided,
    String? status,
    Object? finishReason = _notProvided,
    String? phase,
    int? round,
    int? revision,
    Object? turnDeadlineAt = _notProvided,
    Map<String, MafiaPlayer>? players,
    List<String>? roleRevealedUids,
    int? nightSubmittedCount,
    int? nightActorCount,
    int? discussionSkipCount,
    int? voteSubmittedCount,
    List<String>? voteSubmittedUids,
    int? voteEligibleCount,
    Object? morningResult = _notProvided,
    Object? voteResult = _notProvided,
    Map<String, String>? revealedRoles,
    Object? winner = _notProvided,
    List<String>? winnerUids,
    Object? interruption = _notProvided,
    Object? myRoleId = _notProvided,
    List<String>? allyUids,
    Object? nightTargetUid = _notProvided,
    Map<String, String>? allySelections,
    Object? latestInvestigation = _notProvided,
    Object? voteTargetUid = _notProvided,
    bool? discussionSkipVoted,
    Map<String, String>? spectatorRoles,
  }) {
    return MafiaGameState(
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
      turnDeadlineAt: identical(turnDeadlineAt, _notProvided)
          ? this.turnDeadlineAt
          : turnDeadlineAt as int?,
      players: Map.unmodifiable(players ?? this.players),
      roleRevealedUids: List.unmodifiable(
        roleRevealedUids ?? this.roleRevealedUids,
      ),
      nightSubmittedCount: nightSubmittedCount ?? this.nightSubmittedCount,
      nightActorCount: nightActorCount ?? this.nightActorCount,
      discussionSkipCount: discussionSkipCount ?? this.discussionSkipCount,
      voteSubmittedCount: voteSubmittedCount ?? this.voteSubmittedCount,
      voteSubmittedUids: List.unmodifiable(
        voteSubmittedUids ?? this.voteSubmittedUids,
      ),
      voteEligibleCount: voteEligibleCount ?? this.voteEligibleCount,
      morningResult: identical(morningResult, _notProvided)
          ? this.morningResult
          : morningResult as MafiaMorningResult?,
      voteResult: identical(voteResult, _notProvided)
          ? this.voteResult
          : voteResult as MafiaVoteResult?,
      revealedRoles: Map.unmodifiable(revealedRoles ?? this.revealedRoles),
      winner: identical(winner, _notProvided) ? this.winner : winner as String?,
      winnerUids: List.unmodifiable(winnerUids ?? this.winnerUids),
      interruption: identical(interruption, _notProvided)
          ? this.interruption
          : interruption as GameInterruption?,
      myRoleId: identical(myRoleId, _notProvided)
          ? this.myRoleId
          : myRoleId as String?,
      allyUids: List.unmodifiable(allyUids ?? this.allyUids),
      nightTargetUid: identical(nightTargetUid, _notProvided)
          ? this.nightTargetUid
          : nightTargetUid as String?,
      allySelections: Map.unmodifiable(allySelections ?? this.allySelections),
      latestInvestigation: identical(latestInvestigation, _notProvided)
          ? this.latestInvestigation
          : latestInvestigation as MafiaInvestigation?,
      voteTargetUid: identical(voteTargetUid, _notProvided)
          ? this.voteTargetUid
          : voteTargetUid as String?,
      discussionSkipVoted: discussionSkipVoted ?? this.discussionSkipVoted,
      spectatorRoles: Map.unmodifiable(spectatorRoles ?? this.spectatorRoles),
    );
  }
}
