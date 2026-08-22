import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/diagnostics/crash_reporting.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/providers/mafia_game_state.dart';
import 'package:project00/games/mafia/services/mafia_service.dart';
import 'package:project00/games/shared/game_flow/game_interruption.dart';

//=======================마피아 Riverpod 게임 컨트롤러==============================
/// 서버 상태는 불변 [MafiaGameState]로 발행하고, 화면 연출 상태는 위젯에
/// 남깁니다. Provider가 폐기되면 Realtime Database 구독도 종료됩니다.
///
/// 휴대폰과 태블릿이 **같은 컨트롤러**를 씁니다. 다른 점은 하나뿐입니다 —
/// [watchPrivate]가 false면 개인 구독(내 역할·조사 결과)을 열지 않습니다.
/// 태블릿 화면에 신분이 흘러들면 옆에서 보는 사람에게 다 드러나기 때문입니다.
class MafiaController extends Notifier<MafiaGameState> {
  MafiaController({
    required this.roomCode,
    required this.uid,
    required this.service,
    this.watchPrivate = true,
  });

  final String roomCode;
  final String uid;
  final MafiaService service;
  final bool watchPrivate;

  StreamSubscription<DatabaseEvent>? _publicSubscription;
  StreamSubscription<DatabaseEvent>? _privateSubscription;
  Timer? _missingPublicTimer;

  @override
  MafiaGameState build() {
    final initialState = MafiaGameState.initial();
    _publicSubscription = service.query
        .watchPublicGame(roomCode)
        .listen(_handlePublic, onError: _handlePublicError);
    if (watchPrivate) {
      _privateSubscription = service.query
          .watchPrivatePlayer(roomCode: roomCode, uid: uid)
          .listen(
            _handlePrivate,
            onError: (Object error) => _setError('역할 정보 연결이 불안정합니다: $error'),
          );
    }
    ref.onDispose(() {
      _missingPublicTimer?.cancel();
      unawaited(_publicSubscription?.cancel());
      unawaited(_privateSubscription?.cancel());
    });
    return initialState;
  }

  //=======================상태 접근자==============================
  bool get loading => state.loading;
  bool get commandInFlight => state.commandInFlight;
  String? get errorMessage => state.errorMessage;
  String get status => state.status;
  String? get finishReason => state.finishReason;
  String get phase => state.phase;
  int get round => state.round;
  int? get turnDeadlineAt => state.turnDeadlineAt;
  Map<String, MafiaPlayer> get players => state.players;
  GameInterruption? get interruption => state.interruption;

  //=======================단계 판정 — 한곳에서만==============================
  bool get isFinished => status == 'finished';
  bool get isRoleReveal => phase == 'roleReveal';
  bool get isNight => phase == 'night';
  bool get isMorning => phase == 'morning';
  bool get isDay => phase == 'day';
  bool get isVoting => phase == 'voting';
  bool get isVoteResult => phase == 'voteResult';

  /// 승자가 정해져 정상적으로 끝났는지입니다.
  ///
  /// 수동 종료·인원 부족은 '나가야 하는 종료'라 결과 화면을 띄우지 않습니다.
  bool get isNaturalResult =>
      isFinished &&
      (finishReason == 'citizenWin' || finishReason == 'mafiaWin');

  //=======================플레이어==============================
  List<MafiaPlayer> get orderedPlayers =>
      players.values.toList(growable: false);
  List<MafiaPlayer> get alivePlayers =>
      orderedPlayers.where((player) => player.isAlive).toList(growable: false);

  /// 사망한 사람입니다. 영매·도둑의 밤 대상 명단이 이 목록을 씁니다.
  List<MafiaPlayer> get deadPlayers =>
      orderedPlayers.where((player) => !player.isAlive).toList(growable: false);

  MafiaPlayer? get me => players[uid];
  bool get isAlive => me?.isAlive ?? true;

  /// 사망해서 관전 중인지입니다. 게임이 끝나면 관전이 아닙니다.
  bool get isSpectating => !isAlive && !isFinished;

  //=======================내 역할==============================
  /// 내 역할입니다. 이 빌드가 모르는 신분이면 null입니다.
  ///
  /// 서버가 새 역할을 먼저 배포하고 구버전 앱이 붙는 경우를 대비해, 화면은
  /// null을 받아도 깨지지 않아야 합니다.
  MafiaRole? get myRole =>
      state.myRoleId == null ? null : MafiaRoles.find(state.myRoleId!);

  bool get hasConfirmedRole => state.roleRevealedUids.contains(uid);
  int get roleConfirmedCount => state.roleRevealedUids.length;

  //=======================진행 현황 (인원수만)==============================
  // **누가** 했는지는 서버가 보내지 않습니다. 보이면 특수직이 드러납니다.
  int get nightSubmittedCount => state.nightSubmittedCount;
  int get nightActorCount => state.nightActorCount;

  /// 방금 제출된 밤 행동의 소리 신호입니다(태블릿이 효과음을 냅니다).
  MafiaNightActionCue? get nightActionCue => state.nightActionCue;
  int get voteSubmittedCount => state.voteSubmittedCount;

  /// 투표를 마친 사람들입니다. 태블릿 투표지 연출이 씁니다(어디에 냈는지는
  /// 서버가 보내지 않습니다).
  List<String> get voteSubmittedUids => state.voteSubmittedUids;
  int get voteEligibleCount => state.voteEligibleCount;

  /// 밤에 대상을 골라야 하는 역할인지입니다.
  bool get actsAtNight => myRole?.actsAtNight ?? false;

  /// 내가 이번 밤에 고른 대상입니다. 아직 안 골랐으면 null입니다.
  String? get nightTargetUid => state.nightTargetUid;

  /// 이번 밤에 이미 제출했는지입니다.
  bool get hasSubmittedNight => nightTargetUid != null;

  /// 밤 화면에서 고를 수 있는 대상입니다.
  ///
  /// 역할 이름으로 분기하지 않습니다. 대상 범위·행동 종류·동료 목록만 보고
  /// 걸러 서버 검증([assertValidNightTarget])과 같은 규칙을 씁니다.
  ///
  /// 영매·도둑은 **사망자**를 고릅니다. 그래서 명단의 출처부터 갈립니다.
  List<MafiaPlayer> get nightTargets {
    final role = myRole;
    if (role == null || !role.actsAtNight) return const <MafiaPlayer>[];
    if (role.targetsDead) return deadPlayers;

    final isProtect = role.nightAction == MafiaNightAction.protect;
    final isEliminate = role.nightAction == MafiaNightAction.eliminate;
    return alivePlayers
        .where((player) {
          // 보호는 자기 자신도 고를 수 있습니다.
          if (player.uid == uid) return isProtect;
          // 동료를 **아는** 역할만 같은 편을 목록에서 뺍니다. 모르는 역할
          // (짐승인간·연쇄살인마)은 allyUids가 비어 있어 그대로 보입니다.
          if (isEliminate && state.allyUids.contains(player.uid)) return false;
          return true;
        })
        .toList(growable: false);
  }

  /// 남은 능력 사용 횟수입니다. 제한이 없으면 null입니다(자경단원 1회).
  int? get abilityUsesLeft => state.abilityUsesLeft;

  /// 능력을 다 써서 이번 밤에 아무것도 할 수 없는지입니다.
  bool get abilityExhausted => (state.abilityUsesLeft ?? 1) <= 0;

  /// 내 신분이 지난밤에 바뀌었는지입니다(도둑의 절도, 교주의 전향).
  bool get roleChangedThisRound => state.roleChangedRound == round;

  /// 처형자에게 지정된 목표입니다. 처형자가 아니면 null입니다.
  MafiaPlayer? get executionerTarget {
    final targetUid = state.executionerTargetUid;
    return targetUid == null ? null : players[targetUid];
  }

  /// 동료가 고른 대상입니다. 마피아끼리 서로의 선택을 봅니다.
  Set<String> get allySelectedUids => state.allySelections.values.toSet();

  /// 이번 라운드의 조사·추적 결과입니다. 라운드가 지나면 보여주지 않습니다.
  MafiaInvestigation? get currentInvestigation {
    final record = state.latestInvestigation;
    if (record == null || record.round != round) return null;
    return record;
  }

  //=======================투표==============================
  /// 내가 찍은 대상입니다. 비밀 투표라 **나만** 볼 수 있습니다.
  String? get voteTargetUid => state.voteTargetUid;

  bool get hasVoted => voteTargetUid != null;

  /// 이번 낮에 투표할 수 없는지입니다(마담에게 유혹당함).
  bool get isVoteBanned => state.voteBanned;

  /// 투표 대상입니다. 자기 자신은 뺍니다(시안 기준).
  List<MafiaPlayer> get voteTargets =>
      alivePlayers.where((player) => player.uid != uid).toList(growable: false);

  MafiaVoteResult? get voteResult => state.voteResult;
  MafiaMorningResult? get morningResult => state.morningResult;

  //=======================토론 조기 종료 (과반수 투표)==============================
  /// 조기 종료에 동의한 인원수입니다. 버튼이 `n/m`으로 표시합니다.
  int get discussionSkipCount => state.discussionSkipCount;

  /// 내가 이미 동의를 눌렀는지입니다. 한 번 누르면 취소할 수 없습니다.
  bool get hasVotedToSkipDiscussion => state.discussionSkipVoted;

  /// 처형된 사람입니다. 동표로 무처형이면 null입니다.
  MafiaPlayer? get executedPlayer {
    final executedUid = state.voteResult?.executedUid;
    return executedUid == null ? null : players[executedUid];
  }

  /// 처형된 사람이 나인지입니다. 당사자 화면으로 갈리는 기준입니다.
  bool get isExecutedMe => state.voteResult?.executedUid == uid;

  //=======================공개된 신분==============================
  /// 모두에게 공개된 신분입니다. 공개되지 않았으면 null입니다.
  MafiaRole? revealedRoleOf(String playerUid) {
    final roleId = state.revealedRoles[playerUid];
    return roleId == null ? null : MafiaRoles.find(roleId);
  }

  /// 관전자에게만 보이는 전원 신분표입니다. 살아 있으면 비어 있습니다.
  Map<String, MafiaRole?> get spectatorRoles => {
    for (final entry in state.spectatorRoles.entries)
      entry.key: MafiaRoles.find(entry.value),
  };

  /// 승리 진영입니다. 중립 개별 승리도 [MafiaFaction.neutral]로 옵니다.
  MafiaFaction? get winnerFaction => switch (state.winner) {
    'citizen' => MafiaFaction.citizen,
    'mafia' => MafiaFaction.mafia,
    'neutral' => MafiaFaction.neutral,
    _ => null,
  };

  /// 이긴 사람들의 역할 id입니다. 결과 포스터를 고르는 데 씁니다.
  ///
  /// 게임이 끝나면 전원 신분이 공개되므로 승자의 신분도 읽을 수 있습니다.
  Set<String> get winnerRoleIds => {
    for (final winnerUid in state.winnerUids)
      if (state.revealedRoles[winnerUid] != null)
        state.revealedRoles[winnerUid]!,
  };

  /// 결과 화면 문구입니다. 예: `시민 승리` · `광대 승리`.
  ///
  /// 중립은 진영 대결이 아니라 **개별 승리**라 "중립 승리"로는 무슨 일이
  /// 일어났는지 알 수 없습니다. 승자의 신분을 읽어 역할 이름으로 알려 줍니다.
  ///
  /// 포스터가 있는 승리는 그림에 문구가 들어 있어 이 값을 쓰지 않습니다.
  /// 그림이 없는 승리(생존자 등)에서만 화면에 나옵니다.
  String get winnerLabel {
    final faction = winnerFaction;
    if (faction == null) return '게임 종료';
    if (faction != MafiaFaction.neutral) return '${faction.displayName} 승리';

    final roles = winnerRoleIds
        .map(MafiaRoles.find)
        .whereType<MafiaRole>()
        .toList(growable: false);
    if (roles.isEmpty) return '중립 승리';
    // 교주와 광신도는 한 세력이라 이름을 나열하지 않고 `교단`으로 묶습니다.
    if (roles.every(
      (role) => role.winCondition == MafiaWinCondition.factionDominance,
    )) {
      return '교단 승리';
    }
    return '${roles.map((role) => role.displayName).toSet().join('·')} 승리';
  }

  //=======================조작 가능 여부==============================
  /// 지금 서버에 명령을 보낼 수 있는 상태인지입니다.
  bool get canAct =>
      status == 'playing' &&
      interruption == null &&
      isAlive &&
      !commandInFlight;

  bool get canSubmitNightAction =>
      canAct &&
      isNight &&
      actsAtNight &&
      !hasSubmittedNight &&
      !abilityExhausted;
  bool get canVote => canAct && isVoting && !hasVoted && !isVoteBanned;
  bool get canEndDiscussion => canAct && isDay && !hasVotedToSkipDiscussion;

  String get actionErrorMessage =>
      errorMessage == null || errorMessage!.trim().isEmpty
      ? '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.'
      : errorMessage!;

  //=======================공개 상태 수신==============================
  void _handlePublic(DatabaseEvent event) {
    if (!ref.mounted) return;

    // 재연결 직후 캐시가 잠깐 null인 경우를 실제 게임 삭제로 오인하지 않습니다.
    if (!event.snapshot.exists || event.snapshot.value == null) {
      _confirmMissingPublicGame();
      return;
    }
    _missingPublicTimer?.cancel();
    _missingPublicTimer = null;
    _applyPublicValue(event.snapshot.value);
  }

  /// 공개 상태 구독이 끊긴 경우입니다.
  ///
  /// **읽기가 거부되면(`permission_denied`) 방이 사라진 것으로 봅니다.** 방이
  /// 지워지거나 이 기기가 방에서 빠지면 규칙이 읽기를 막습니다. 예전에는 이때
  /// '연결이 불안정합니다'만 띄우고 **마지막 상태에 그대로 머물렀습니다** —
  /// 태블릿이 밤 화면에 굳은 채 마감 처리를 끝없이 다시 시도하며 오류만
  /// 쌓였습니다(2026-08 시뮬레이터에서 확인).
  ///
  /// 로그아웃·토큰 갱신 직후에도 잠깐 거부될 수 있어, 곧바로 끝내지 않고
  /// [_confirmMissingPublicGame]으로 한 번 더 읽어 확인합니다.
  void _handlePublicError(Object error) {
    if (!_isPermissionDenied(error)) {
      _setError('게임 연결이 불안정합니다: $error');
      return;
    }
    _setError('게임을 읽을 수 없습니다. 방이 사라졌는지 확인합니다…');
    _confirmMissingPublicGame();
  }

  /// 읽기 권한이 거부된 오류인지입니다.
  ///
  /// RTDB는 규칙에 막히면 `permission-denied`(Dart 코드) 또는
  /// `permission_denied`(원본 메시지)로 알려 줍니다. 둘 다 봅니다.
  static bool _isPermissionDenied(Object error) {
    final code = error is FirebaseException ? error.code : '';
    if (code.replaceAll('_', '-') == 'permission-denied') return true;
    return error.toString().contains('permission_denied') ||
        error.toString().contains('permission-denied');
  }

  void _confirmMissingPublicGame() {
    if (_missingPublicTimer != null) return;
    _missingPublicTimer = Timer(const Duration(milliseconds: 1500), () async {
      _missingPublicTimer = null;
      try {
        final snapshot = await service.query.readPublicGame(roomCode);
        if (!ref.mounted) return;
        if (snapshot.exists && snapshot.value != null) {
          _applyPublicValue(snapshot.value);
          return;
        }
        _finishForRemovedGame();
      } catch (error) {
        if (!ref.mounted) return;
        // 다시 읽어도 거부되면 방이 없는 것이 확실합니다.
        if (_isPermissionDenied(error)) {
          _finishForRemovedGame();
          return;
        }
        // 네트워크가 아직 복구 중이면 마지막 정상 상태를 유지합니다.
      }
    });
  }

  void _finishForRemovedGame() {
    if (!ref.mounted) return;
    state = state.copyWith(
      loading: false,
      status: 'finished',
      finishReason: 'manual',
      phase: 'finished',
      turnDeadlineAt: null,
    );
  }

  void _applyPublicValue(Object? value) {
    if (!ref.mounted || value is! Map) return;

    final current = state;
    final map = Map<Object?, Object?>.from(value);

    final parsedPlayers = <String, MafiaPlayer>{};
    final rawPlayers = map['players'];
    if (rawPlayers is Map) {
      for (final entry in rawPlayers.entries) {
        if (entry.value is Map) {
          parsedPlayers[entry.key.toString()] = MafiaPlayer.fromMap(
            entry.key.toString(),
            Map<Object?, Object?>.from(entry.value as Map),
          );
        }
      }
    }
    // 좌석 순서로 정렬해 화면마다 다시 정렬하지 않게 합니다.
    final sortedPlayers = <String, MafiaPlayer>{
      for (final player
          in parsedPlayers.values.toList()
            ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex)))
        player.uid: player,
    };

    final rawRevealed = map['revealedRoles'];
    final revealedRoles = <String, String>{};
    if (rawRevealed is Map) {
      for (final entry in rawRevealed.entries) {
        revealedRoles[entry.key.toString()] = entry.value.toString();
      }
    }

    final rawMorning = map['morningResult'];
    final rawVote = map['voteResult'];
    final rawInterruption = map['interruption'];

    state = current.copyWith(
      loading: false,
      errorMessage: null,
      status: map['status']?.toString() ?? current.status,
      finishReason: map['finishReason']?.toString(),
      phase: map['phase']?.toString() ?? current.phase,
      round: (map['round'] as num?)?.toInt() ?? current.round,
      revision: (map['revision'] as num?)?.toInt() ?? current.revision,
      turnDeadlineAt: (map['turnDeadlineAt'] as num?)?.toInt(),
      players: sortedPlayers.isEmpty ? current.players : sortedPlayers,
      roleRevealedUids: mafiaStringList(map['roleRevealedUids']),
      nightSubmittedCount: (map['nightSubmittedCount'] as num?)?.toInt() ?? 0,
      nightActorCount: (map['nightActorCount'] as num?)?.toInt() ?? 0,
      nightActionCue: MafiaNightActionCue.fromMap(map['nightActionCue']),
      voteSubmittedCount: (map['voteSubmittedCount'] as num?)?.toInt() ?? 0,
      // 토론 조기 종료에 동의한 사람 수입니다(서버 day.ts가 갱신).
      // 이 줄이 없어 폰의 'n/m' 실시간 집계가 항상 0으로 보였습니다.
      discussionSkipCount: (map['discussionSkipCount'] as num?)?.toInt() ?? 0,
      voteSubmittedUids: mafiaStringList(map['voteSubmittedUids']),
      voteEligibleCount: (map['voteEligibleCount'] as num?)?.toInt() ?? 0,
      morningResult: rawMorning is Map
          ? MafiaMorningResult.fromMap(Map<Object?, Object?>.from(rawMorning))
          : null,
      voteResult: rawVote is Map
          ? MafiaVoteResult.fromMap(Map<Object?, Object?>.from(rawVote))
          : null,
      revealedRoles: revealedRoles,
      winner: map['winner']?.toString(),
      winnerUids: mafiaStringList(map['winnerUids']),
      interruption: rawInterruption is Map
          ? GameInterruption.fromMap(
              Map<Object?, Object?>.from(rawInterruption),
            )
          : null,
    );
  }

  //=======================개인 상태 수신==============================
  void _handlePrivate(DatabaseEvent event) {
    if (!ref.mounted) return;
    final value = event.snapshot.value;
    if (value is! Map) {
      // 재시작 직후 잠깐 비는 경우가 있어 마지막 값을 유지합니다.
      return;
    }
    final map = Map<Object?, Object?>.from(value);

    final rawAllySelections = map['allySelections'];
    final allySelections = <String, String>{};
    if (rawAllySelections is Map) {
      for (final entry in rawAllySelections.entries) {
        allySelections[entry.key.toString()] = entry.value.toString();
      }
    }

    final rawSpectator = map['spectatorRoles'];
    final spectatorRoles = <String, String>{};
    if (rawSpectator is Map) {
      for (final entry in rawSpectator.entries) {
        spectatorRoles[entry.key.toString()] = entry.value.toString();
      }
    }

    // 조사 기록은 라운드별로 쌓입니다. 가장 최근 라운드만 화면에 씁니다.
    MafiaInvestigation? latest;
    final rawInvestigations = map['investigations'];
    if (rawInvestigations is Map) {
      for (final entry in rawInvestigations.entries) {
        if (entry.value is! Map) continue;
        final record = MafiaInvestigation.fromMap(
          Map<Object?, Object?>.from(entry.value as Map),
        );
        if (latest == null || record.round > latest.round) latest = record;
      }
    }

    state = state.copyWith(
      myRoleId: map['roleId']?.toString(),
      allyUids: mafiaStringList(map['allyUids']),
      nightTargetUid: map['nightTargetUid']?.toString(),
      allySelections: allySelections,
      latestInvestigation: latest,
      voteTargetUid: map['voteTargetUid']?.toString(),
      discussionSkipVoted: map['discussionSkipVoted'] == true,
      spectatorRoles: spectatorRoles,
      executionerTargetUid: map['executionerTargetUid']?.toString(),
      abilityUsesLeft: (map['abilityUsesLeft'] as num?)?.toInt(),
      voteBanned: map['voteBanned'] == true,
      roleChangedRound: (map['roleChangedRound'] as num?)?.toInt(),
    );
  }

  //=======================휴대폰 명령==============================
  Future<bool> confirmRole() =>
      _run(() => service.command.confirmRole(roomCode: roomCode));

  Future<bool> submitNightAction(String targetUid) => _run(
    () => service.command.submitNightAction(
      roomCode: roomCode,
      targetUid: targetUid,
    ),
  );

  Future<bool> endDiscussion() =>
      _run(() => service.command.endDiscussion(roomCode: roomCode));

  Future<bool> submitVote(String targetUid) => _run(
    () => service.command.submitVote(roomCode: roomCode, targetUid: targetUid),
  );

  //=======================태블릿 명령==============================
  Future<bool> completeRoleReveal() =>
      _run(() => service.command.completeRoleReveal(roomCode: roomCode));
  Future<bool> timeoutNight() =>
      _run(() => service.command.timeoutNight(roomCode: roomCode));
  Future<bool> completeMorning() =>
      _run(() => service.command.completeMorning(roomCode: roomCode));
  Future<bool> timeoutDay() =>
      _run(() => service.command.timeoutDay(roomCode: roomCode));
  Future<bool> timeoutVote() =>
      _run(() => service.command.timeoutVote(roomCode: roomCode));
  Future<bool> completeVoteResult() =>
      _run(() => service.command.completeVoteResult(roomCode: roomCode));
  Future<bool> restartGame() =>
      _run(() => service.command.restartGame(roomCode: roomCode));
  Future<bool> endGame() =>
      _run(() => service.command.endGame(roomCode: roomCode));

  /// 첫 조작이 느려지지 않게 서버를 미리 깨웁니다. 실패는 무시합니다.
  Future<void> warmUp() async {
    try {
      await service.command.warmUp(roomCode: roomCode);
    } catch (_) {
      // 예열은 보조 기능이라 실패해도 게임 진행을 막지 않습니다.
    }
  }

  //=======================중단 처리==============================
  Future<bool> voteToContinueInterruption() {
    final current = interruption;
    if (current == null) return Future.value(false);
    return _run(
      () => service.interruption.voteToContinue(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
    );
  }

  Future<bool> expireInterruption() {
    final current = interruption;
    if (current == null) return Future.value(false);
    return _run(
      () => service.interruption.expire(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
    );
  }

  Future<bool> excludeInterruptedPlayerAndContinue() {
    final current = interruption;
    if (current == null || !current.canContinue) return Future.value(false);
    return _run(
      () => service.interruption.excludeAndContinue(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
    );
  }

  //=======================공통==============================
  Future<bool> _run(Future<Object?> Function() command) async {
    if (commandInFlight) return false;
    state = state.copyWith(commandInFlight: true, errorMessage: null);
    try {
      final result = await command();
      // 서버는 "아직 할 일이 아니다"를 예외가 아니라 정상 응답으로 알립니다
      // (예: 마감 전 타임아웃 호출 → {success: false, reason: "notExpired"}).
      // 이를 성공으로 넘기면 호출자가 재시도하지 않아 진행이 멈춥니다.
      // 명시적인 success:false만 실패로 봅니다(success 필드가 없는 명령도 있음).
      if (result is Map && result['success'] == false) return false;
      return true;
    } catch (error, stack) {
      // 사용자에게는 짧은 안내만 보여 주고, 실제 원인은 따로 남깁니다.
      // 개발 중에는 화면 오른쪽 아래 표시로, 출시 뒤에는 Crashlytics로
      // 올라가 어떤 명령이 실패했는지 추적할 수 있습니다.
      CrashReporting.recordError(error, stack, reason: '마피아 서버 명령');
      _setError(
        error is FirebaseFunctionsException
            ? (error.message ?? '요청을 처리하지 못했습니다.')
            : '서버 연결이 불안정합니다. 잠시 후 다시 시도해주세요.',
      );
      return false;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(commandInFlight: false);
      }
    }
  }

  void _setError(String message) {
    if (!ref.mounted) return;
    state = state.copyWith(errorMessage: message);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
