import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/games/mafia/animations/mafia_phase_transition.dart';
import 'package:project00/games/mafia/animations/role_deal_toss_animation.dart';
import 'package:project00/games/mafia/controllers/mafia_controller.dart';
import 'package:project00/games/mafia/mafia_flow_config.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/shared/widgets/game_turn_countdown.dart';
import 'package:project00/games/mafia/widgets/phone/day_discussion_view.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/games/mafia/widgets/phone/role_card_layer.dart';
import 'package:project00/games/mafia/widgets/phone/morning_announcement_view.dart';
import 'package:project00/games/mafia/widgets/phone/execution_view.dart';
import 'package:project00/games/mafia/widgets/phone/night_action_view.dart';
import 'package:project00/games/mafia/widgets/phone/spectator_roster_view.dart';
import 'package:project00/games/mafia/widgets/phone/vote_view.dart';

//=======================휴대폰 진행 화면==============================
/// 서버 단계를 시안 화면으로 옮기는 **한 곳**입니다.
///
/// 하위 위젯은 서버 문자열을 다시 해석하지 않습니다. 여기서만 갈라 주세요.
///
/// | 서버 phase | 화면 |
/// |---|---|
/// | `roleReveal` | P1 역할 카드 확인 |
/// | `night` | P2~P5 밤 행동 (조사 결과 포함) |
/// | `morning` | P6 (아침 — 태블릿이 발표, 휴대폰은 대기) |
/// | `day` | P6 자유 토론 |
/// | `voting` | P7 투표 |
/// | `voteResult` | P7 처형 발표 → 신분 공개 (2박자) |
///
/// 사망하면 단계와 무관하게 P8 관전 명단을 보여 줍니다. 단, 자기가 처형된
/// 순간에는 당사자 화면을 먼저 보여 준 뒤 관전으로 넘어갑니다.
class MafiaPhoneGameScreen extends StatefulWidget {
  const MafiaPhoneGameScreen({super.key, required this.controller});

  final MafiaController controller;

  @override
  State<MafiaPhoneGameScreen> createState() => _MafiaPhoneGameScreenState();
}

/// 처형 발표의 지역 진행 단계입니다.
///
/// 서버는 `voteResult` 하나로만 알려 주므로 발표 → 신분 공개 순서는 화면이
/// 직접 셉니다. 연출 상태라 컨트롤러에 두지 않습니다.
///
/// 서버는 `voteResult` 하나로만 알려 주므로 발표 → 신분 공개 순서는 화면이
/// 직접 셉니다. 연출 상태라 컨트롤러에 두지 않습니다.
enum _ExecutionStage { announce, reveal, done }

class _MafiaPhoneGameScreenState extends State<MafiaPhoneGameScreen> {
  /// 처형자 이름을 보여 주는 시간입니다(확정: 이름 4초). 이 뒤에 카드를 뒤집습니다.
  static const Duration _announceHold = Duration(milliseconds: 4000);

  _ExecutionStage _executionStage = _ExecutionStage.done;
  int? _executionRound;
  Timer? _announceTimer;

  //=======================밤 행동 로컬 상태==============================
  // 확정 흐름: 대상 탭 = **선택만**, '선택 완료' 버튼 = 제출. 그래서 제출 전
  // 선택은 서버가 아니라 화면이 들고 있습니다.
  String? _nightSelection;
  int? _nightSelectionRound;

  //=======================투표 로컬 상태==============================
  // 투표도 같은 방식입니다: 탭 = 선택만, '선택 완료' 버튼 = 제출.
  String? _voteSelection;
  int? _voteSelectionRound;

  /// 조사 결과에서 '확인'을 누른 라운드입니다. 누르면 대기 화면으로 넘어갑니다.
  int? _acknowledgedInvestigationRound;

  @override
  void didUpdateWidget(MafiaPhoneGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncExecutionStage();
  }

  @override
  void initState() {
    super.initState();
    _syncExecutionStage();
  }

  /// 서버가 새 개표 결과를 주면 발표부터 다시 시작합니다.
  void _syncExecutionStage() {
    final game = widget.controller;
    if (!game.isVoteResult) {
      if (_executionStage != _ExecutionStage.done) {
        _announceTimer?.cancel();
        _executionStage = _ExecutionStage.done;
        _executionRound = null;
      }
      return;
    }
    if (_executionRound == game.round) return;

    _announceTimer?.cancel();
    _executionRound = game.round;
    _executionStage = _ExecutionStage.announce;

    // 아무도 처형되지 않았으면 뒤집을 카드가 없어 발표에서 멈춥니다.
    if (game.executedPlayer == null) return;
    _announceTimer = Timer(_announceHold, () {
      if (!mounted) return;
      setState(() => _executionStage = _ExecutionStage.reveal);
    });
  }

  @override
  void dispose() {
    _announceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.controller;

    // 확정(2026-08): 단계가 바뀔 때 화면 전체가 새로 그려지는 느낌을 없애려고
    // **배경과 내 보관 카드는 셸이 계속 그립니다.** 바뀌는 내용만 전환합니다.
    return Stack(
      fit: StackFit.expand,
      children: [
        // 낮·밤 배경은 부드럽게 바뀝니다(태블릿은 방사형 전환, 휴대폰은 겹침).
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: KeyedSubtree(
            key: ValueKey(game.isNight),
            child: MafiaPhoneBackground(isNight: game.isNight),
          ),
        ),
        MafiaPhoneShellChrome(
          child: MafiaPhaseTransition(
            child: KeyedSubtree(
              key: ValueKey(_pageKey(game)),
              // 타이머가 1초마다 움직여야 하므로 남은 시간을 여기서 셉니다.
              // 서버 상태만 보고 그리면 상태가 안 바뀌는 동안 숫자가 굳습니다.
              child: GameTurnCountdown(
                expiresAt: game.turnDeadlineAt,
                builder: (context, remaining) => _buildPage(game, remaining),
              ),
            ),
          ),
        ),
        // 내 신분 카드는 **모든 단계에 걸쳐 한 장**입니다. 아래에 놓여 있다가
        // 누르면 가운데로 올라와 열리고 다시 내려갑니다(확정 2026-08).
        // 결과 화면부터는 카드가 필요 없어 얹지 않습니다.
        if (_showsRoleCard(game))
          MafiaPhoneRoleCardLayer(
            role: game.myRole,
            phaseKey: _pageKey(game),
            // 아직 확인하지 않았으면 화면 위에서 내려오는 첫 확인 연출입니다.
            isFirstReveal: game.phase == 'roleReveal' && !game.hasConfirmedRole,
            // 태블릿의 분배 연출이 끝난 뒤에 카드가 들어옵니다(확정 2026-08).
            entranceDelay: _dealEntranceDelay(game),
            // 그 사람만의 안내입니다(처형자의 목표, 신분이 바뀌었다는 알림).
            notice: _roleNotice(game),
            onRevealed: game.confirmRole,
          ),
      ],
    );
  }

  /// 신분 카드 아래에 한 줄 더 붙일 **그 사람만의 안내**입니다.
  ///
  /// 역할 이름으로 분기하지 않습니다. 서버가 그 사람의 private에 값을 넣어
  /// 줬을 때만 문구가 생깁니다.
  ///
  /// - **처형자** — 목표를 모르면 역할이 성립하지 않습니다. 계속 보여 줍니다.
  /// - **동료를 아는 역할** — 마피아·스파이·마담·도둑·교단은 서로를 압니다.
  ///   확정(2026-08): 스파이는 밤에 하는 일이 없어 이 줄이 없으면 누가
  ///   마피아인지 끝까지 알 수 없었습니다. 마피아끼리도 밤 화면에서는 동료가
  ///   *고른 대상*만 보여 서로가 누구인지 확인할 자리가 없었습니다.
  /// - **도둑·전향된 사람** — 카드 그림은 이미 새 신분으로 바뀌지만, 바뀐 줄
  ///   모르고 지나칠 수 있어 그 라운드 동안 한 줄로 알려 줍니다.
  static String? _roleNotice(MafiaController game) {
    final lines = <String>[];
    final target = game.executionerTarget;
    if (target != null) lines.add('목표 · ${target.nickname}');
    final allies = game.allyPlayers;
    if (allies.isNotEmpty) {
      lines.add('동료 · ${allies.map((player) => player.nickname).join(', ')}');
    }
    if (game.roleChangedThisRound) lines.add('지난밤 신분이 바뀌었습니다');
    // 자리는 한 줄입니다. 여러 개면 가운뎃점으로 이어 붙입니다(넘치면 줄어듭니다).
    return lines.isEmpty ? null : lines.join('  ·  ');
  }

  /// 태블릿에서 카드를 다 나눠 줄 때까지 남은 시간입니다.
  ///
  /// 확정(2026-08): 휴대폰의 신분 카드는 **분배 연출이 끝난 뒤에** 화면 위에서
  /// 들어옵니다. 태블릿에서 카드가 아직 날아가는 중인데 휴대폰에 이미 카드가
  /// 있으면 카드를 건네받는 느낌이 사라집니다.
  ///
  /// 서버가 신호를 따로 보내지 않으므로 **마감 시각으로 되짚어** 계산합니다.
  /// 신분 확인 단계의 마감은 `시작 + MafiaTiming.roleReveal`이라,
  /// `마감 − roleReveal`이 분배가 시작된 시각입니다. 재접속처럼 이미 지난
  /// 경우에는 0이 되어 곧바로 들어옵니다.
  Duration _dealEntranceDelay(MafiaController game) {
    if (game.phase != 'roleReveal' || game.hasConfirmedRole) {
      return Duration.zero;
    }
    final deadline = game.turnDeadlineAt;
    if (deadline == null) return Duration.zero;

    final dealStartAt = deadline - MafiaTiming.roleReveal.inMilliseconds;
    final dealMs = MafiaRoleDealTossAnimation.totalDuration(
      game.players.length,
    ).inMilliseconds;
    final remaining = dealStartAt + dealMs - ServerClock.nowMillis();
    return remaining <= 0 ? Duration.zero : Duration(milliseconds: remaining);
  }

  /// 지금 보여 줄 화면을 가리키는 값입니다. 이 값이 바뀔 때만 전환합니다.
  ///
  /// 같은 화면 안의 상태 변화(선택·집계·타이머)로는 바뀌지 않아야 합니다.
  String _pageKey(MafiaController game) {
    if (game.isVoteResult && _executionStage != _ExecutionStage.done) {
      return 'execution';
    }
    if (game.isSpectating) return 'spectator';
    return game.phase;
  }

  /// 신분 카드를 얹을 단계인지입니다.
  ///
  /// 결과 화면부터는 승패가 다 드러나 카드를 볼 이유가 없습니다.
  bool _showsRoleCard(MafiaController game) => !game.isFinished;

  Widget _buildPage(MafiaController game, Duration? remaining) {
    // 처형 발표는 사망 여부보다 먼저 봅니다. 자기가 처형된 사람도 발표를
    // 봐야 하기 때문입니다.
    if (game.isVoteResult && _executionStage != _ExecutionStage.done) {
      return _buildExecution(game);
    }

    // 사망자는 단계와 무관하게 관전 명단을 봅니다.
    if (game.isSpectating) {
      return MafiaSpectatorRosterView(
        myRole: game.myRole,
        myUid: game.uid,
        isNight: game.isNight,
        revealed: [
          for (final player in game.orderedPlayers)
            MafiaRevealedPlayer(
              player: player,
              role: game.spectatorRoles[player.uid],
            ),
        ],
      );
    }

    return switch (game.phase) {
      // 신분 확인은 카드 레이어가 전부 그립니다(카드·화살표·문구).
      'roleReveal' => const SizedBox.shrink(),
      'night' => _buildNight(game, remaining),
      // 아침은 태블릿과 같은 발표 문구를 보여 줍니다(확정).
      'morning' => MafiaMorningAnnouncementView(
        role: game.myRole,
        result: game.morningResult,
        players: game.players,
      ),
      'day' => MafiaDayDiscussionView(
        role: game.myRole,
        remainingSeconds: remaining?.inSeconds,
        // 과반수 투표로 끝난 낮입니다. 안내만 남기고 곧 투표로 넘어갑니다.
        endedByVote: game.isDayEndedByVote,
        canEndDiscussion: game.canEndDiscussion,
        skipVoteCount: game.discussionSkipCount,
        aliveCount: game.alivePlayers.length,
        hasVotedToSkip: game.hasVotedToSkipDiscussion,
        onEndDiscussion: game.endDiscussion,
      ),
      'voting' => _buildVoting(game, remaining),
      // 그 밖의 단계(연결 중·종료)는 셸이 처리합니다.
      _ => MafiaDayDiscussionView(role: game.myRole, title: '잠시만 기다려 주세요'),
    };
  }

  Widget _buildNight(MafiaController game, Duration? remaining) {
    // 라운드가 바뀌면 지난 밤의 선택·확인 기록을 버립니다.
    if (_nightSelectionRound != game.round) {
      _nightSelectionRound = game.round;
      _nightSelection = null;
    }

    final investigation = game.currentInvestigation;
    final target = investigation == null
        ? null
        : game.players[investigation.targetUid];
    // 조사 결과는 '확인'을 누를 때까지만 보여 줍니다(확정 흐름).
    final showsResult =
        investigation != null &&
        target != null &&
        _acknowledgedInvestigationRound != game.round;

    // 확정(2026-08): 밤은 **차단 구간 → 행동 구간 → 마무리**로 흐릅니다.
    // 내 차례가 아닌 구간에서는 격자를 감추고 대기 화면을 보여 줍니다.
    // 서버가 구간을 알려 주므로 남은 시간으로 되짚지 않습니다.
    final actionWindowClosed = game.nightStageClosed;

    return MafiaNightActionView(
      role: game.myRole,
      actionWindowClosed: actionWindowClosed,
      // 능력을 다 쓴 밤은 대기 화면입니다(자경단원의 한 발).
      abilityExhausted: game.abilityExhausted,
      players: game.nightTargets,
      selectedUid: game.hasSubmittedNight
          ? game.nightTargetUid
          : _nightSelection,
      allySelectedUids: game.allySelectedUids,
      remainingSeconds: remaining?.inSeconds,
      isSubmitted: game.hasSubmittedNight,
      // 탭은 선택만 바꿉니다. 제출은 아래 '선택 완료' 버튼이 합니다.
      onSelect: game.canSubmitNightAction && !actionWindowClosed
          ? (uid) => setState(() => _nightSelection = uid)
          : null,
      onConfirm:
          game.canSubmitNightAction &&
              !actionWindowClosed &&
              _nightSelection != null
          ? () => unawaited(game.submitNightAction(_nightSelection!))
          : null,
      investigationResult: showsResult
          ? MafiaNightInvestigationResult(
              target: target,
              verdict: investigation.verdict,
              // 제목은 역할의 동사에서 만듭니다. 조사·추적·교신·절도가
              // 모두 같은 자리를 쓰므로 역할 이름으로 분기하지 않습니다.
              title: _investigationTitle(game.myRole),
              // 진영만 알아내는 조사는 문장으로 적습니다(확정 2026-08).
              asFactionSentence:
                  game.myRole?.nightAction == MafiaNightAction.investigate,
            )
          : null,
      onConfirmResult: showsResult
          ? () => setState(() => _acknowledgedInvestigationRound = game.round)
          : null,
    );
  }

  /// 밤 결과 화면의 제목입니다. 예: `조사 결과`·`교신 결과`.
  static String _investigationTitle(MafiaRole? role) {
    final verb = role?.nightPromptVerb ?? '';
    return verb.isEmpty ? '조사 결과' : '$verb 결과';
  }

  Widget _buildVoting(MafiaController game, Duration? remaining) {
    // 라운드가 바뀌면 지난 투표의 선택을 버립니다.
    if (_voteSelectionRound != game.round) {
      _voteSelectionRound = game.round;
      _voteSelection = null;
    }

    return MafiaVoteView(
      role: game.myRole,
      players: game.voteTargets,
      selectedUid: game.hasVoted ? game.voteTargetUid : _voteSelection,
      remainingSeconds: remaining?.inSeconds,
      isSubmitted: game.hasVoted,
      // 마담에게 유혹당하면 이번 낮에는 표를 낼 수 없습니다.
      voteBanned: game.isVoteBanned,
      // 탭은 선택만 바꿉니다. 제출은 아래 '선택 완료' 버튼이 합니다.
      onSelect: game.canVote
          ? (uid) => setState(() => _voteSelection = uid)
          : null,
      onConfirm: game.canVote && _voteSelection != null
          ? () => unawaited(game.submitVote(_voteSelection!))
          : null,
    );
  }

  Widget _buildExecution(MafiaController game) {
    final executed = game.executedPlayer;
    if (_executionStage == _ExecutionStage.announce || executed == null) {
      return MafiaExecutionResultView(
        role: game.myRole,
        executed: executed,
        isMe: game.isExecutedMe,
      );
    }
    return MafiaExecutionRevealView(
      myRole: game.myRole,
      executed: executed,
      executedRole: game.revealedRoleOf(executed.uid),
    );
  }
}
