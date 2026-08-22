import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:project00/games/mafia/mafia_flow_config.dart';
import 'package:project00/games/mafia/models/mafia_composition.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/dev/mafia_practice_fakes.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_phase_views.dart';
import 'package:project00/games/mafia/services/mafia_command_service.dart';
import 'package:project00/games/mafia/services/mafia_query_service.dart';
import 'package:project00/games/mafia/services/mafia_service.dart';

//=======================마피아 연습장 엔진 (개발 전용)==============================
// Firebase 없이 마피아 한 판을 통째로 돌리는 **로컬 가짜 서버**입니다.
//
// 목적은 하나입니다 — 시뮬레이터 여러 대에 사람을 모으지 않고도, 실제 화면
// (휴대폰·태블릿)을 그대로 띄워 흐름 전체를 눈으로 보며 핫 리로드로 고치는 것.
//
// 실제 컨트롤러(`MafiaController`)가 서버 대신 이 엔진을 구독하도록
// [MafiaService] 모양의 가짜([practiceService])를 만들어 줍니다. 화면 코드는
// 한 줄도 다르지 않게 동작합니다.
//
// ⚠️ **규칙의 원본은 서버(functions/src/mafia)입니다.** 여기는 개발 확인용
// 복제라 세부 판정(동표 무작위 시드 등)이 완전히 같지는 않습니다. 발견한
// 문제를 고칠 때는 서버 쪽도 함께 고치세요.

/// 연습장의 봇 한 명입니다.
class MafiaPracticeBot {
  MafiaPracticeBot({required this.uid, required this.nickname});

  final String uid;
  final String nickname;
}

class MafiaPracticeEngine {
  MafiaPracticeEngine({
    required this.playerCount,
    this.humanUids = const ['me'],
    this.preferredRoleId,
    this.botDelay = const Duration(seconds: 2),
  }) {
    _start();
  }

  final int playerCount;

  /// 봇이 대신 조작하지 **않는** 사람 자리입니다. 혼자 연습이면 ['me'],
  /// 여러 기기 모드면 ['p1', 'p2']처럼 접속할 폰 수만큼 둡니다.
  final List<String> humanUids;

  /// 첫 번째 사람에게 우선 배정할 역할입니다.
  final String? preferredRoleId;

  /// 봇이 행동하기까지의 기본 지연입니다. 사람처럼 약간 뜸을 들입니다.
  final Duration botDelay;

  final Random _random = Random();
  final Map<String, StreamController<DatabaseEvent>> _privateControllers = {};
  final StreamController<DatabaseEvent> _publicController =
      StreamController<DatabaseEvent>.broadcast();

  /// 봇이 알아서 진행할지입니다. 끄면 아래 step 버튼으로만 움직입니다.
  bool autoPlay = true;

  /// 태블릿 '밤이 됐습니다' 안내가 보이는 동안 true입니다(확정: 2.5초).
  ///
  /// 실기기에서는 태블릿 화면(tablet_game.dart)이 이 연출을 지휘하지만,
  /// 연습장은 휴대폰 화면만 보고 있을 때도 판이 굴러가야 하므로 엔진이
  /// 지휘하고 화면은 이 값을 구독해 그리기만 합니다.
  final ValueNotifier<bool> nightNotice = ValueNotifier(false);

  /// 단계 자동 진행 타이머입니다. 단계가 바뀔 때마다 갈아 끼웁니다.
  Timer? _phaseTimer;

  //=======================서버 상태 (functions/src/mafia 와 같은 모양)=========
  late Map<String, String> _roles;
  late Map<String, Map<String, Object?>> _players;
  final Map<String, String> _nightActions = {};

  /// 밤 행동 소리 신호입니다(태블릿이 그 직업의 효과음을 냅니다).
  Map<String, Object?>? _nightActionCue;
  int _nightActionCueId = 0;
  final Map<String, String> _votes = {};
  final Set<String> _skipVotes = {};
  final Set<String> _confirmed = {};
  final Map<String, Map<String, Object?>> _private = {};
  String _phase = 'roleReveal';
  int _round = 1;
  int _revision = 1;
  int? _deadlineAt;
  Map<String, Object?>? _morningResult;
  Map<String, Object?>? _voteResult;
  final Map<String, String> _revealedRoles = {};

  /// 자기 방어를 이미 쓴 사람입니다(군인).
  final Set<String> _defenseUsed = {};

  /// 능력을 쓴 횟수입니다(자경단원 등 제한이 있는 역할).
  final Map<String, int> _abilityUses = {};

  /// 다음 낮에 투표할 수 없는 사람입니다(마담에게 유혹당함).
  final Set<String> _voteBans = {};

  /// 처형자의 목표입니다. `처형자 uid → 목표 uid`.
  final Map<String, String> _executionerTargets = {};

  /// 처형으로 확정된 단독 승리자입니다(광대·처형자).
  final List<String> _pendingNeutralWinUids = [];

  String? _winner;
  List<String> _winnerUids = const [];
  final List<Timer> _timers = [];

  List<String> get _uids => _players.keys.toList(growable: false);
  List<String> get _aliveUids => _players.entries
      .where((entry) => entry.value['status'] == 'alive')
      .map((entry) => entry.key)
      .toList(growable: false);

  MafiaRole? _roleOf(String uid) => MafiaRoles.find(_roles[uid] ?? '');

  void _start() {
    // 역할 배분 — 실제 구성표를 그대로 씁니다.
    final composition = MafiaComposition.recommendedFor(playerCount)!;
    final pool = <String>[
      for (final entry in composition.entries)
        for (var i = 0; i < entry.value; i += 1) entry.key,
    ]..shuffle(_random);

    // 첫 번째 사람이 원하는 역할이 있으면 그 몫으로 빼 둡니다.
    //
    // 구성표에 없는 역할(자경단원·영매·짐승인간처럼 기본 구성 밖의 역할)도
    // 연습할 수 있어야 하므로, 없으면 **시민 한 자리를 바꿔** 끼웁니다.
    // 시민을 고르는 이유는 능력이 없어 판의 균형을 가장 덜 흔들기 때문입니다.
    final preferred = preferredRoleId;
    if (preferred != null &&
        MafiaRoles.find(preferred)?.isImplemented == true) {
      if (pool.contains(preferred)) {
        pool
          ..remove(preferred)
          ..insert(0, preferred);
      } else {
        // 시민이 없는 구성(12인)이면 시민 진영 아무 자리를 내줍니다.
        // 마피아 자리를 지우면 판이 시작부터 기울어집니다.
        var swapIndex = pool.indexOf('citizen');
        if (swapIndex < 0) {
          swapIndex = pool.indexWhere(
            (id) => MafiaRoles.find(id)?.faction == MafiaFaction.citizen,
          );
        }
        if (swapIndex < 0) swapIndex = pool.length - 1;
        pool
          ..removeAt(swapIndex)
          ..insert(0, preferred);
      }
    }

    _players = {};
    _roles = {};
    final humans = humanUids.take(playerCount).toList();
    for (var i = 0; i < playerCount; i += 1) {
      final isHuman = i < humans.length;
      final uid = isHuman ? humans[i] : 'bot$i';
      // 혼자 연습이면 '나', 여러 기기 모드면 접속 순서대로 '폰1'·'폰2'입니다.
      final nickname = !isHuman
          ? '봇$i'
          : (humans.length == 1 ? '나' : '폰${i + 1}');
      _players[uid] = {
        'uid': uid,
        'nickname': nickname,
        'profileImageUrl': '',
        'seatIndex': i,
        'status': 'alive',
      };
      _roles[uid] = pool[i];
      _private[uid] = {'roleId': pool[i]};
    }
    // 서로 아는 편(마피아) 목록을 채웁니다.
    for (final uid in _uids) {
      final role = _roleOf(uid);
      if (role == null || !role.knowsAllies) continue;
      final allies = _uids
          .where(
            (other) =>
                other != uid &&
                (_roleOf(other)?.knowsAllies ?? false) &&
                _roleOf(other)?.faction == role.faction,
          )
          .toList();
      if (allies.isNotEmpty) _private[uid]!['allyUids'] = allies;
    }
    // 사용 횟수 제한이 있는 역할은 남은 횟수를 본인에게만 알려 줍니다.
    for (final uid in _uids) {
      final maxUses = _roleOf(uid)?.maxUses;
      if (maxUses != null) _private[uid]!['abilityUsesLeft'] = maxUses;
    }
    // 처형자에게 시민 진영 목표를 지정합니다.
    for (final uid in _uids) {
      if (_roleOf(uid)?.winCondition != MafiaWinCondition.lynchTarget) continue;
      final candidates = _uids
          .where(
            (other) =>
                other != uid && _roleOf(other)?.faction == MafiaFaction.citizen,
          )
          .toList();
      if (candidates.isEmpty) continue;
      final target = candidates[_random.nextInt(candidates.length)];
      _executionerTargets[uid] = target;
      _private[uid]!['executionerTargetUid'] = target;
    }
    // 휴대폰이 이 마감으로 분배가 시작된 시각을 되짚어 카드 등장을 맞춥니다.
    // 값이 서버·MafiaTiming과 갈리면 연습장에서 카드가 엉뚱하게 들어옵니다.
    _deadlineAt = _now + MafiaTiming.roleReveal.inMilliseconds;
    _publish();
    _scheduleBots();
    // 확인 제한시간(1분)이 지나면 전원 확인 없이도 같은 안내를 거쳐 밤으로.
    _schedulePhase(
      MafiaTiming.roleReveal + const Duration(milliseconds: 250),
      _nightNoticeSequence,
    );
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  //=======================MafiaService 흉내==============================
  /// 실제 컨트롤러에 꽂을 가짜 서비스입니다. [uid]가 조작 명령의 주인입니다.
  MafiaService practiceServiceFor(String uid) => MafiaService(
    command: _PracticeCommands(this, uid),
    query: _PracticeQuery(this),
    interruption: MafiaPracticeNoopInterruption(),
  );

  /// 현재 상태를 모든 구독자에게 다시 흘립니다(원격 서버가 접속 직후 씁니다).
  void publishNow() => _publish();

  /// 자리의 별명입니다(원격 서버가 접속 인사에 씁니다).
  String? nicknameOf(String uid) => _players[uid]?['nickname'] as String?;

  Stream<DatabaseEvent> watchPublic() => _publicController.stream;

  Stream<DatabaseEvent> watchPrivate(String uid) => _privateControllers
      .putIfAbsent(uid, StreamController<DatabaseEvent>.broadcast)
      .stream;

  void _publish() {
    _revision += 1;
    _publicController.add(MafiaPracticeFakeEvent(_publicMap()));
    for (final entry in _privateControllers.entries) {
      entry.value.add(MafiaPracticeFakeEvent(_private[entry.key]));
    }
  }

  Map<String, Object?> _publicMap() => {
    'gameType': 'mafia',
    'status': _winner == null ? 'playing' : 'finished',
    if (_winner != null)
      'finishReason': switch (_winner) {
        'mafia' => 'mafiaWin',
        'neutral' => 'neutralWin',
        _ => 'citizenWin',
      },
    'phase': _phase,
    'round': _round,
    'revision': _revision,
    'turnDeadlineAt': _deadlineAt,
    'players': _players,
    'roleRevealedUids': _confirmed.toList(),
    'nightSubmittedCount': _nightActions.length,
    if (_nightActionCue != null) 'nightActionCue': _nightActionCue,
    'nightActorCount': _aliveUids
        .where((uid) => _roleOf(uid)?.actsAtNight ?? false)
        .length,
    'discussionSkipCount': _skipVotes.length,
    'voteSubmittedCount': _votes.length,
    'voteSubmittedUids': _votes.keys.toList(),
    'voteEligibleCount': _aliveUids.length,
    if (_morningResult != null) 'morningResult': _morningResult,
    if (_voteResult != null) 'voteResult': _voteResult,
    if (_revealedRoles.isNotEmpty) 'revealedRoles': _revealedRoles,
    'winner': _winner,
    'winnerUids': _winnerUids,
    'startedAt': 0,
    'updatedAt': _now,
  };

  /// 단계 자동 진행을 예약합니다. 이전 예약은 취소되고, 실행 시점에
  /// [autoPlay]가 꺼져 있으면 아무것도 하지 않습니다(수동 모드).
  void _schedulePhase(Duration delay, void Function() action) {
    _phaseTimer?.cancel();
    _phaseTimer = Timer(delay, () {
      if (autoPlay) action();
    });
  }

  //=======================명령 (서버 함수와 같은 의미)=====================
  void confirmRole(String uid) {
    if (_phase != 'roleReveal') return;
    _confirmed.add(uid);
    _publish();
    // 확정 흐름: 전원 확인 → 10초 → '밤이 됐습니다' 2.5초 → 밤.
    if (_confirmed.length >= _uids.length) {
      _schedulePhase(const Duration(seconds: 10), _nightNoticeSequence);
    }
  }

  /// '밤이 됐습니다'를 2.5초 보여 준 뒤 밤을 시작합니다(실제 태블릿과 동일).
  void _nightNoticeSequence() {
    if (_phase != 'roleReveal') return;
    nightNotice.value = true;
    _phaseTimer?.cancel();
    // 안내가 화면에 걸린 채 남지 않도록, 여기서는 autoPlay를 다시 묻지 않습니다.
    _phaseTimer = Timer(const Duration(milliseconds: 2500), () {
      nightNotice.value = false;
      completeRoleReveal();
    });
  }

  void completeRoleReveal() {
    if (_phase != 'roleReveal') return;
    nightNotice.value = false;
    _beginNight();
  }

  void submitNightAction(String uid, String targetUid) {
    if (_phase != 'night') return;
    final actor = _roleOf(uid);
    if (actor == null || !actor.actsAtNight) return;
    // 능력을 다 썼으면 아무것도 할 수 없습니다(자경단원).
    final maxUses = actor.maxUses;
    if (maxUses != null && (_abilityUses[uid] ?? 0) >= maxUses) return;
    // 대상 범위는 역할이 정합니다. 영매·도둑만 사망자를 고릅니다.
    final targetAlive = _players[targetUid]?['status'] == 'alive';
    if (actor.targetsDead ? targetAlive : !targetAlive) return;
    // 확정(2026-08): 직업 효과음은 선택을 완료한 순간 태블릿에서 울립니다.
    // 서버(functions/src/mafia/game.ts의 bumpNightActionCue)와 같은 규칙 —
    // 첫 제출에만 신호를 올립니다.
    final action = _roleOf(uid)?.nightAction;
    if (!_nightActions.containsKey(uid) &&
        action != null &&
        action != MafiaNightAction.none) {
      _nightActionCue = {'id': _nightActionCueId += 1, 'action': action.name};
    }
    _nightActions[uid] = targetUid;
    _private[uid]!['nightTargetUid'] = targetUid;
    // 동료 공유
    final allies = (_private[uid]!['allyUids'] as List?)?.cast<String>() ?? [];
    for (final ally in allies) {
      final selections =
          (_private[ally]!['allySelections'] as Map?)
              ?.cast<String, Object?>() ??
          <String, Object?>{};
      selections[uid] = targetUid;
      _private[ally]!['allySelections'] = selections;
    }
    // 조사류 즉시 결과 (서버와 같은 규칙)
    final role = _roleOf(uid);
    if (role?.nightAction == MafiaNightAction.investigate) {
      final target = _roleOf(targetUid);
      final verdict = switch (target?.investigationAppearance) {
        MafiaInvestigationAppearance.asMafia => '마피아',
        MafiaInvestigationAppearance.asCitizen => '시민',
        _ => target?.faction == MafiaFaction.mafia ? '마피아' : '시민',
      };
      _recordInvestigation(uid, targetUid, verdict);
    } else if (role?.nightAction == MafiaNightAction.investigateRole ||
        role?.nightAction == MafiaNightAction.steal) {
      // 영매·도둑은 사망자를 보므로 이 값이 그대로 최종값입니다.
      _recordInvestigation(
        uid,
        targetUid,
        _roleOf(targetUid)?.displayName ?? '알 수 없음',
      );
    } else if (role?.nightAction == MafiaNightAction.track) {
      final visited = _nightActions[targetUid];
      _recordInvestigation(
        uid,
        targetUid,
        visited == null
            ? '방문 없음'
            : (_players[visited]?['nickname'] as String? ?? '알 수 없음'),
      );
    }
    _publish();
    // 확정(2026-08): 전원이 제출해도 밤은 마감(3분)까지 유지합니다.
  }

  void _recordInvestigation(String uid, String targetUid, String verdict) {
    final investigations =
        (_private[uid]!['investigations'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    investigations['r$_round'] = {
      'round': _round,
      'targetUid': targetUid,
      'verdict': verdict,
    };
    _private[uid]!['investigations'] = investigations;
  }

  void endDiscussion(String uid) {
    if (_phase != 'day') return;
    _skipVotes.add(uid);
    _private[uid]!['discussionSkipVoted'] = true;
    if (_skipVotes.length * 2 > _aliveUids.length) {
      _beginVoting();
    } else {
      _publish();
    }
  }

  void timeoutDay() {
    if (_phase == 'day') _beginVoting();
  }

  void submitVote(String uid, String targetUid) {
    if (_phase != 'voting' || _votes.containsKey(uid)) return;
    // 유혹당하면 이번 낮에는 투표할 수 없습니다(마담).
    if (_private[uid]?['voteBanned'] == true) return;
    _votes[uid] = targetUid;
    _private[uid]!['voteTargetUid'] = targetUid;
    // 투표권이 없는 사람은 참여 인원에서 빠집니다.
    final eligible = _aliveUids
        .where((other) => _private[other]?['voteBanned'] != true)
        .length;
    if (_votes.length >= eligible) {
      _resolveVoting();
    } else {
      _publish();
    }
  }

  /// 밤 마감(조종판) — 남은 사람 없이 바로 해결합니다.
  void timeoutNightNow() {
    if (_phase == 'night') _resolveNight();
  }

  /// 투표 마감(조종판) — 안 낸 사람은 기권으로 개표합니다.
  void timeoutVoteNow() {
    if (_phase == 'voting') _resolveVoting();
  }

  void completeMorning() {
    if (_phase != 'morning') return;
    if (_checkWinner()) return;
    _phase = 'day';
    // 토론 시간은 생존 인원에 따라 다릅니다(서버 mafiaDiscussionMs와 같은 표).
    final discussion = MafiaTiming.discussion(_aliveUids.length);
    _deadlineAt = _now + discussion.inMilliseconds;
    _skipVotes.clear();
    for (final map in _private.values) {
      map.remove('discussionSkipVoted');
    }
    _publish();
    _scheduleBots();
    // 토론 시간이 지나면 투표로 넘어갑니다(timeout_day).
    _schedulePhase(discussion + const Duration(milliseconds: 250), () {
      if (_phase == 'day') _beginVoting();
    });
  }

  void completeVoteResult() {
    if (_phase != 'voteResult') return;
    if (_checkWinner()) return;
    _round += 1;
    _beginNight();
  }

  //=======================단계 전환==============================
  void _beginNight() {
    _phase = 'night';
    _deadlineAt = _now + MafiaTiming.night.inMilliseconds;
    _nightActions.clear();
    _votes.clear();
    for (final map in _private.values) {
      map
        ..remove('nightTargetUid')
        ..remove('allySelections')
        ..remove('voteTargetUid')
        ..remove('voteBanned')
        ..remove('roleChangedRound');
    }
    _morningResult = null;
    _voteResult = null;
    _publish();
    _scheduleBots();
    // 마감(행동 1분 + 대기 30초)이 지나면 해결합니다(실제 태블릿의
    // timeout_night). 개발 중 기다리기 싫으면 조종판의 '밤 마감' 버튼을 쓰세요.
    _schedulePhase(MafiaTiming.night + const Duration(milliseconds: 250), () {
      if (_phase == 'night') _resolveNight();
    });
  }

  void _beginVoting() {
    _phase = 'voting';
    _deadlineAt = _now + 30000;
    _votes.clear();
    // 유혹당한 사람은 이번 투표에 참여하지 못합니다(마담).
    for (final map in _private.values) {
      map.remove('voteBanned');
    }
    for (final uid in _voteBans) {
      if (_players[uid]?['status'] != 'alive') continue;
      _private[uid]?['voteBanned'] = true;
    }
    _voteBans.clear();
    _publish();
    _scheduleBots();
    // 투표 시간(30초)이 지나면 안 낸 사람은 기권으로 개표합니다(timeout_vote).
    _schedulePhase(const Duration(milliseconds: 30250), () {
      if (_phase == 'voting') _resolveVoting();
    });
  }

  void _resolveNight() {
    if (_phase != 'night') return;
    // 서버(functions/src/mafia/game.ts의 resolveMafiaNight)와 같은 순서입니다.
    // 차단 → 보호 → 전향 → 조사 → 마피아 공격 → 단독 공격 → 상태 효과.
    final blocked = <String>{};
    final protected = <String>{};
    final attacks = <String, List<String>>{};
    final mafiaVotes = <String, int>{};
    final usedAbility = <String>{};

    final ordered =
        _nightActions.entries
            .where((entry) => _players[entry.key]?['status'] == 'alive')
            .where((entry) => _roleOf(entry.key)?.nightPhase != null)
            .toList()
          ..sort(
            (left, right) => _roleOf(left.key)!.nightPhase!.order.compareTo(
              _roleOf(right.key)!.nightPhase!.order,
            ),
          );

    for (final entry in ordered) {
      final actor = entry.key;
      final target = entry.value;
      final role = _roleOf(actor)!;
      if (blocked.contains(actor)) continue;
      // 대상 범위를 다시 확인합니다. 영매·도둑만 사망자를 고릅니다.
      final targetAlive = _players[target]?['status'] == 'alive';
      if (role.targetsDead ? targetAlive : !targetAlive) continue;

      switch (role.nightAction) {
        case MafiaNightAction.roleblock:
          blocked.add(target);
          if (role.blocksTargetVote) _voteBans.add(target);
          usedAbility.add(actor);
        case MafiaNightAction.protect:
          protected.add(target);
          usedAbility.add(actor);
        case MafiaNightAction.convert:
          final becomes = role.convertsTargetTo;
          if (becomes == null) break;
          if (_roleOf(target)?.faction == MafiaFaction.mafia) break;
          if (_roles[target] == becomes) break;
          _changeRole(target, becomes);
          usedAbility.add(actor);
        case MafiaNightAction.expose:
          _revealedRoles[target] = _roles[target]!;
          usedAbility.add(actor);
        case MafiaNightAction.steal:
          final stolen = _roles[target];
          if (stolen == null) break;
          _changeRole(actor, stolen);
          usedAbility.add(actor);
        case MafiaNightAction.eliminate:
          if (role.nightPhase == MafiaNightPhase.mafiaAttack) {
            mafiaVotes[target] = (mafiaVotes[target] ?? 0) + 1;
            usedAbility.add(actor);
            break;
          }
          // 같은 편은 죽이지 않습니다(짐승인간이 마피아를 고른 경우).
          if (_roleOf(target)?.faction == role.faction &&
              role.faction == MafiaFaction.mafia) {
            break;
          }
          (attacks[target] ??= []).add(actor);
          usedAbility.add(actor);
        // 조사류는 제출 순간 이미 기록했습니다. 그 밖의 행동은 아직 없습니다.
        case MafiaNightAction.none:
        case MafiaNightAction.investigate:
        case MafiaNightAction.investigateRole:
        case MafiaNightAction.frame:
        case MafiaNightAction.silence:
        case MafiaNightAction.watch:
        case MafiaNightAction.track:
        case MafiaNightAction.mark:
          break;
      }
    }

    // 마피아 다수결 — 동표면 무작위 한 명입니다.
    if (mafiaVotes.isNotEmpty) {
      final best = mafiaVotes.values.reduce(max);
      final leaders = mafiaVotes.entries
          .where((entry) => entry.value == best)
          .map((entry) => entry.key)
          .toList();
      (attacks[leaders[_random.nextInt(leaders.length)]] ??= []).add('');
    }

    final deadUids = <String>{};
    var savedCount = 0;
    for (final entry in attacks.entries) {
      final target = entry.key;
      if (protected.contains(target)) {
        savedCount += 1;
        continue;
      }
      // 군인은 공격 한 번마다 방어를 하나 소모합니다. 같은 밤에 두 번
      // 공격받으면 한 번만 막고 두 번째에 죽습니다.
      final charges = _roleOf(target)?.defenseCharges ?? 0;
      var survived = true;
      for (var i = 0; i < entry.value.length; i += 1) {
        if (charges > 0 && !_defenseUsed.contains(target)) {
          _defenseUsed.add(target);
          continue;
        }
        survived = false;
        break;
      }
      if (survived) {
        savedCount += 1;
        continue;
      }
      deadUids.add(target);
      // 자경단원 오발 — 같은 편을 쏘면 자신도 죽습니다.
      for (final attacker in entry.value) {
        if (attacker.isEmpty) continue;
        final role = _roleOf(attacker);
        if (role == null || !role.selfDestructsOnAllyKill) continue;
        if (_roleOf(target)?.faction != role.faction) continue;
        deadUids.add(attacker);
      }
    }

    _countAbilityUses(usedAbility);
    for (final uid in deadUids) {
      _kill(uid, 'nightAttack');
    }

    _morningResult = {
      'deadUids': deadUids.toList(),
      'savedCount': savedCount,
      'resolvedAt': _now,
    };
    _phase = 'morning';
    _deadlineAt = null;
    _nightActions.clear();
    _publish();
    // 확정: '아침이 되었습니다'(2.5초) → 사망자 발표(8초) →
    // '토론을 시작합니다'(2.5초) 뒤 낮으로.
    _schedulePhase(MafiaTabletMorningSequence.totalHold, completeMorning);
  }

  /// 게임 중에 신분을 바꿉니다(교주의 전향, 도둑의 절도).
  void _changeRole(String uid, String roleId) {
    if (MafiaRoles.find(roleId) == null) return;
    _roles[uid] = roleId;
    _private[uid]?['roleId'] = roleId;
    _private[uid]?['roleChangedRound'] = _round;
    // 진영이 바뀌었으니 전원의 동료 목록을 다시 계산합니다.
    for (final other in _uids) {
      final role = _roleOf(other);
      final allies = (role?.knowsAllies ?? false)
          ? _uids
                .where(
                  (candidate) =>
                      candidate != other &&
                      (_roleOf(candidate)?.knowsAllies ?? false) &&
                      _roleOf(candidate)?.faction == role!.faction,
                )
                .toList()
          : const <String>[];
      if (allies.isEmpty) {
        _private[other]?.remove('allyUids');
      } else {
        _private[other]?['allyUids'] = allies;
      }
    }
  }

  /// 실제로 발동한 능력의 사용 횟수를 셉니다(차단당한 밤은 세지 않습니다).
  void _countAbilityUses(Set<String> usedAbility) {
    for (final uid in usedAbility) {
      final maxUses = _roleOf(uid)?.maxUses;
      if (maxUses == null) continue;
      final used = (_abilityUses[uid] ?? 0) + 1;
      _abilityUses[uid] = used;
      _private[uid]?['abilityUsesLeft'] = max(0, maxUses - used);
    }
  }

  void _resolveVoting() {
    if (_phase != 'voting') return;
    // 정치인의 표는 2표로 셉니다(voteWeight).
    final tally = <String, int>{};
    for (final entry in _votes.entries) {
      final weight = _roleOf(entry.key)?.voteWeight ?? 1;
      tally[entry.value] = (tally[entry.value] ?? 0) + weight;
    }
    String? executed;
    var tie = false;
    if (tally.isNotEmpty) {
      final best = tally.values.reduce(max);
      final leaders = tally.entries
          .where((entry) => entry.value == best)
          .map((entry) => entry.key)
          .toList();
      if (leaders.length == 1) {
        executed = leaders.first;
        _pendingNeutralWinUids.addAll(_lynchWinnerUids(executed));
        _kill(executed, 'execution');
        _revealedRoles[executed] = _roles[executed]!;
      } else {
        tie = true;
      }
    }
    final eligible = _aliveUids
        .where((uid) => _private[uid]?['voteBanned'] != true)
        .length;
    _voteResult = {
      'tally': tally,
      'executedUid': executed,
      'tie': tie,
      'abstainCount': max(0, eligible - _votes.length),
      'resolvedAt': _now,
    };
    _phase = 'voteResult';
    _deadlineAt = null;
    _votes.clear();
    _publish();
    // 확정: 개표(4초) → 처형 발표(9초) → '밤이 되었습니다'(2.5초) 뒤 다음 밤으로.
    _schedulePhase(MafiaTabletVoteResultSequence.totalHold, completeVoteResult);
  }

  /// 이 처형으로 단독 승리한 사람입니다(광대·처형자).
  List<String> _lynchWinnerUids(String executedUid) {
    final winners = <String>[];
    if (_roleOf(executedUid)?.winCondition == MafiaWinCondition.lynchedSelf) {
      winners.add(executedUid);
    }
    for (final entry in _executionerTargets.entries) {
      if (entry.value != executedUid) continue;
      if (_players[entry.key]?['status'] != 'alive') continue;
      if (_roleOf(entry.key)?.winCondition != MafiaWinCondition.lynchTarget) {
        continue;
      }
      winners.add(entry.key);
    }
    return winners;
  }

  void _kill(String uid, String cause) {
    _players[uid]?['status'] = 'dead';
    _players[uid]?['deathCause'] = cause;
    _players[uid]?['diedRound'] = _round;
    _private[uid]?['spectatorRoles'] = Map<String, Object?>.from(_roles);
  }

  bool _checkWinner() {
    // 처형으로 정해진 단독 승리를 가장 먼저 봅니다(광대·처형자).
    if (_pendingNeutralWinUids.isNotEmpty) {
      return _finish('neutral', _pendingNeutralWinUids.toList());
    }

    var mafia = 0;
    var cult = 0;
    var killers = 0;
    for (final uid in _aliveUids) {
      final role = _roleOf(uid);
      if (role?.faction == MafiaFaction.mafia) {
        mafia += 1;
      } else if (role?.winCondition == MafiaWinCondition.factionDominance) {
        cult += 1;
      } else if (role?.winCondition == MafiaWinCondition.lastStanding) {
        killers += 1;
      }
    }
    final alive = _aliveUids.length;
    final others = alive - mafia;

    if (cult > 0 && cult == alive) {
      return _finish(
        'neutral',
        _uids
            .where(
              (uid) =>
                  _roleOf(uid)?.winCondition ==
                  MafiaWinCondition.factionDominance,
            )
            .toList(),
      );
    }
    if (killers > 0 && killers == alive) {
      return _finish('neutral', _aliveUids);
    }
    // 판을 뒤집을 사람이 남아 있으면 진영 승리가 확정되지 않습니다.
    if (cult > 0 || killers > 0) return false;

    if (mafia == 0) {
      return _finish(
        'citizen',
        _uids
            .where((uid) => _roleOf(uid)?.faction == MafiaFaction.citizen)
            .toList(),
      );
    }
    if (mafia >= others) {
      return _finish(
        'mafia',
        _uids
            .where((uid) => _roleOf(uid)?.faction == MafiaFaction.mafia)
            .toList(),
      );
    }
    return false;
  }

  /// 게임을 끝냅니다. 끝나는 순간 전원 신분을 공개합니다.
  bool _finish(String winner, List<String> winnerUids) {
    _winner = winner;
    _winnerUids = List.unmodifiable(winnerUids);
    _phase = 'finished';
    _deadlineAt = null;
    _phaseTimer?.cancel();
    _revealedRoles.addAll(_roles);
    _publish();
    return true;
  }

  //=======================봇==============================
  /// 지금 단계에서 봇들이 해야 할 일을 지연을 두고 실행합니다.
  void _scheduleBots() {
    if (!autoPlay) return;
    stepBots(delayed: true);
  }

  /// 봇을 즉시(또는 지연을 두고) 한 단계 진행시킵니다. 수동 조작 버튼용입니다.
  void stepBots({bool delayed = false}) {
    var order = 0;
    void run(void Function() action) {
      if (!delayed) {
        action();
        return;
      }
      order += 1;
      final timer = Timer(botDelay * order, action);
      _timers.add(timer);
    }

    switch (_phase) {
      case 'roleReveal':
        for (final uid in _uids.where((uid) => !humanUids.contains(uid))) {
          if (!_confirmed.contains(uid)) run(() => confirmRole(uid));
        }
      case 'night':
        for (final uid in _aliveUids.where((uid) => !humanUids.contains(uid))) {
          final role = _roleOf(uid);
          if (role == null || !role.actsAtNight) continue;
          if (_nightActions.containsKey(uid)) continue;
          // 능력을 다 쓴 봇은 이 밤에 아무것도 하지 않습니다(자경단원).
          final maxUses = role.maxUses;
          if (maxUses != null && (_abilityUses[uid] ?? 0) >= maxUses) continue;
          // 영매·도둑은 사망자를 고릅니다.
          final pool = role.targetsDead
              ? _uids
                    .where((target) => _players[target]?['status'] != 'alive')
                    .toList()
              : _aliveUids;
          final targets = pool.where((target) {
            if (target == uid) {
              return role.nightAction == MafiaNightAction.protect;
            }
            // 동료를 아는 역할만 같은 편을 뺍니다(짐승인간은 모릅니다).
            if (role.nightAction == MafiaNightAction.eliminate &&
                role.knowsAllies &&
                _roleOf(target)?.faction == role.faction) {
              return false;
            }
            return true;
          }).toList();
          if (targets.isEmpty) continue;
          final target = targets[_random.nextInt(targets.length)];
          run(() => submitNightAction(uid, target));
        }
      case 'voting':
        for (final uid in _aliveUids.where((uid) => !humanUids.contains(uid))) {
          if (_votes.containsKey(uid)) continue;
          // 유혹당한 봇은 이번 낮에 투표할 수 없습니다(마담).
          if (_private[uid]?['voteBanned'] == true) continue;
          final targets = _aliveUids.where((target) => target != uid).toList();
          final target = targets[_random.nextInt(targets.length)];
          run(() => submitVote(uid, target));
        }
      case 'day':
        // 낮에는 봇이 저절로 조기 종료하지 않습니다. 버튼으로 시킵니다.
        break;
    }
  }

  /// 살아 있는 봇들이 토론 조기 종료에 동의합니다(과반까지).
  void botsSkipDiscussion() {
    for (final uid in _aliveUids.where((uid) => !humanUids.contains(uid))) {
      if (_phase != 'day') return;
      endDiscussion(uid);
    }
  }

  void dispose() {
    _phaseTimer?.cancel();
    nightNotice.dispose();
    for (final timer in _timers) {
      timer.cancel();
    }
    _publicController.close();
    for (final controller in _privateControllers.values) {
      controller.close();
    }
  }
}

//=======================가짜 서비스 부품==============================
class _PracticeQuery implements MafiaQueryService {
  _PracticeQuery(this.engine);
  final MafiaPracticeEngine engine;

  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) {
    // 첫 구독자가 현재 상태를 바로 받도록 마이크로태스크로 한 번 흘립니다.
    scheduleMicrotask(engine._publish);
    return engine.watchPublic();
  }

  @override
  Stream<DatabaseEvent> watchPrivatePlayer({
    required String roomCode,
    required String uid,
  }) {
    scheduleMicrotask(engine._publish);
    return engine.watchPrivate(uid);
  }

  @override
  Future<DataSnapshot> readPublicGame(String roomCode) async =>
      MafiaPracticeFakeSnapshot(engine._publicMap());

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _PracticeCommands implements MafiaCommandService {
  _PracticeCommands(this.engine, this.uid);
  final MafiaPracticeEngine engine;

  /// 이 서비스로 보내는 조작 명령의 주인입니다.
  final String uid;

  @override
  Future<Map<String, dynamic>> confirmRole({required String roomCode}) async {
    engine.confirmRole(uid);
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> completeRoleReveal({
    required String roomCode,
  }) async {
    engine.completeRoleReveal();
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> submitNightAction({
    required String roomCode,
    required String targetUid,
  }) async {
    engine.submitNightAction(uid, targetUid);
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> timeoutNight({required String roomCode}) async {
    engine._resolveNight();
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> completeMorning({
    required String roomCode,
  }) async {
    engine.completeMorning();
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> endDiscussion({required String roomCode}) async {
    engine.endDiscussion(uid);
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> timeoutDay({required String roomCode}) async {
    engine.timeoutDay();
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> submitVote({
    required String roomCode,
    required String targetUid,
  }) async {
    engine.submitVote(uid, targetUid);
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> timeoutVote({required String roomCode}) async {
    engine._resolveVoting();
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> completeVoteResult({
    required String roomCode,
  }) async {
    engine.completeVoteResult();
    return const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> warmUp({required String roomCode}) async =>
      const {'success': true};

  @override
  Future<Map<String, dynamic>> startGame({
    required String roomCode,
    Map<String, int>? composition,
  }) async => const {'success': true};

  @override
  Future<Map<String, dynamic>> restartGame({required String roomCode}) async =>
      const {'success': true};

  @override
  Future<Map<String, dynamic>> endGame({required String roomCode}) async =>
      const {'success': true};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
