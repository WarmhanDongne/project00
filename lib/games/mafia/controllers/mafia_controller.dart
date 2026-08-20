import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        .listen(
          _handlePublic,
          onError: (Object error) => _setError('게임 연결이 불안정합니다: $error'),
        );
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
  int get voteSubmittedCount => state.voteSubmittedCount;
  int get voteEligibleCount => state.voteEligibleCount;

  /// 밤에 대상을 골라야 하는 역할인지입니다.
  bool get actsAtNight => myRole?.actsAtNight ?? false;

  /// 내가 이번 밤에 고른 대상입니다. 아직 안 골랐으면 null입니다.
  String? get nightTargetUid => state.nightTargetUid;

  /// 이번 밤에 이미 제출했는지입니다.
  bool get hasSubmittedNight => nightTargetUid != null;

  /// 밤 화면에서 고를 수 있는 대상입니다.
  ///
  /// 역할 이름으로 분기하지 않습니다. 행동 종류와 진영만 보고 걸러 서버 검증과
  /// 같은 규칙을 씁니다.
  List<MafiaPlayer> get nightTargets {
    final role = myRole;
    if (role == null || !role.actsAtNight) return const <MafiaPlayer>[];
    final isProtect = role.nightAction == MafiaNightAction.protect;
    final isEliminate = role.nightAction == MafiaNightAction.eliminate;
    return alivePlayers
        .where((player) {
          // 보호는 자기 자신도 고를 수 있습니다.
          if (player.uid == uid) return isProtect;
          // 같은 편은 제거 대상이 될 수 없습니다.
          if (isEliminate && state.allyUids.contains(player.uid)) return false;
          return true;
        })
        .toList(growable: false);
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

  /// 승리 진영입니다. 중립 개별 승리는 서버가 별도로 판정합니다.
  MafiaFaction? get winnerFaction => switch (state.winner) {
    'citizen' => MafiaFaction.citizen,
    'mafia' => MafiaFaction.mafia,
    'neutral' => MafiaFaction.neutral,
    _ => null,
  };

  //=======================조작 가능 여부==============================
  /// 지금 서버에 명령을 보낼 수 있는 상태인지입니다.
  bool get canAct =>
      status == 'playing' &&
      interruption == null &&
      isAlive &&
      !commandInFlight;

  bool get canSubmitNightAction =>
      canAct && isNight && actsAtNight && !hasSubmittedNight;
  bool get canVote => canAct && isVoting && !hasVoted;
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
      } catch (_) {
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
      voteSubmittedCount: (map['voteSubmittedCount'] as num?)?.toInt() ?? 0,
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
      await command();
      return true;
    } catch (error) {
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
