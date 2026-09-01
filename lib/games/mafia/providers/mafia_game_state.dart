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
    required this.nightActionCue,
    required this.nightStage,
    required this.nightStageActorCount,
    required this.nightStageSubmittedCount,
    required this.dayEndReason,
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
    required this.executionerTargetUid,
    required this.abilityUsesLeft,
    required this.voteBanned,
    required this.roleChangedRound,
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
    nightActionCue: null,
    nightStage: null,
    nightStageActorCount: 0,
    nightStageSubmittedCount: 0,
    dayEndReason: null,
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
    executionerTargetUid: null,
    abilityUsesLeft: null,
    voteBanned: false,
    roleChangedRound: null,
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

  /// 방금 제출된 밤 행동의 소리 신호입니다.
  ///
  /// 태블릿이 이 신호가 바뀔 때 그 직업의 효과음을 냅니다
  /// ([MafiaNightActionCue]). 아무도 제출하지 않았으면 null입니다.
  final MafiaNightActionCue? nightActionCue;

  //=======================밤의 순위 구간==============================
  /// 밤의 어느 구간인지입니다 — `priority` · `attack` · `support` ·
  /// `wrapUp`.
  ///
  /// 역할 순위 1~4, 5~8, 9~14를 각각 함께 진행하고, 마지막
  /// `wrapUp`은 아침을 기다리는 10초입니다.
  final String? nightStage;

  /// 이번 구간에 행동해야 하는 인원수입니다.
  final int nightStageActorCount;

  /// 이번 구간에 제출한 인원수입니다.
  final int nightStageSubmittedCount;

  /// 낮 토론이 끝난 이유입니다 — `vote`면 과반수 투표로 끝났습니다.
  ///
  /// 이 값이 `vote`가 되면 낮 마감이 짧게 줄어들고, 태블릿이 "토론이 투표로
  /// 종료되었습니다" 안내를 띄운 뒤 투표로 넘어갑니다.
  final String? dayEndReason;

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

  /// 처형자에게 지정된 목표입니다. 처형자가 아니면 null입니다.
  ///
  /// 이 사람이 **낮 투표로** 처형되면 처형자가 단독 승리합니다.
  final String? executionerTargetUid;

  /// 남은 능력 사용 횟수입니다. 제한이 없는 역할이면 null입니다(자경단원 1).
  ///
  /// 0이면 밤에 아무것도 제출할 수 없습니다.
  final int? abilityUsesLeft;

  /// 이번 낮에 투표할 수 없는지입니다(마담에게 유혹당함).
  final bool voteBanned;

  /// 내 신분이 바뀐 라운드입니다(도둑의 절도, 교주의 전향).
  ///
  /// 바뀐 신분은 [myRoleId]에 이미 반영돼 있습니다. 이 값은 "당신은 이제
  /// ○○입니다" 안내를 띄울지 판단하는 데만 씁니다.
  final int? roleChangedRound;

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
    String? nightStage,
    int? nightStageActorCount,
    int? nightStageSubmittedCount,
    String? dayEndReason,
    MafiaNightActionCue? nightActionCue,
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
    Object? executionerTargetUid = _notProvided,
    Object? abilityUsesLeft = _notProvided,
    bool? voteBanned,
    Object? roleChangedRound = _notProvided,
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
      // 구간·토론 종료 이유는 **서버가 지우면 함께 사라져야** 합니다. 그래서
      // `?? this.` 로 이어 두지 않고 받은 값을 그대로 씁니다.
      nightStage: nightStage,
      nightStageActorCount: nightStageActorCount ?? 0,
      nightStageSubmittedCount: nightStageSubmittedCount ?? 0,
      dayEndReason: dayEndReason,
      nightActionCue: nightActionCue ?? this.nightActionCue,
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
      executionerTargetUid: identical(executionerTargetUid, _notProvided)
          ? this.executionerTargetUid
          : executionerTargetUid as String?,
      abilityUsesLeft: identical(abilityUsesLeft, _notProvided)
          ? this.abilityUsesLeft
          : abilityUsesLeft as int?,
      voteBanned: voteBanned ?? this.voteBanned,
      roleChangedRound: identical(roleChangedRound, _notProvided)
          ? this.roleChangedRound
          : roleChangedRound as int?,
    );
  }
}
