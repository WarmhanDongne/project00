// [game_screen.dart] 는 마피아에서 사용하는 휴대폰에서 보이는 게임 진행 화면을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [PhoneScreen] : 휴대폰에서 보이는 게임 진행 화면을 구성함
//
// 즉, 플레이어가 자신의 정보와 행동 버튼을 확인하고 조작하기 위해 필요한 파일이다.

import 'package:game_mafia/phone/phone_board.dart';
import 'dart:async';
import 'package:game_mafia/shared/widgets/trial_view.dart';
import 'package:game_mafia/shared/widgets/noir.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_mafia/phone/providers/game_stage.dart';
import 'package:game_mafia/shared/animations/phase_transition.dart';
import 'package:game_mafia/shared/animations/role_deal_toss_animation.dart';
import 'package:game_mafia/shared/providers/game_controller.dart';
import 'package:game_mafia/shared/models/server_timing.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown.dart';
import 'package:game_mafia/phone/widgets/day_discussion_view.dart';
import 'package:game_mafia/phone/widgets/game_layout.dart';
import 'package:game_mafia/phone/widgets/role_card_layer.dart';
import 'package:game_mafia/phone/widgets/morning_announcement_view.dart';
import 'package:game_mafia/phone/widgets/execution_view.dart';
import 'package:game_mafia/phone/widgets/night_action_view.dart';
import 'package:game_mafia/phone/widgets/spectator_roster_view.dart';
import 'package:game_mafia/phone/widgets/vote_view.dart';
import 'package:game_mafia/phone/widgets/phase_notice.dart';
import 'package:game_mafia/shared/models/presentation_timing.dart';
import 'package:game_kit/game_flow/game_presentation_sequence.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 휴대폰 진행 화면
// ---------------------------------------------------------------------------
/// 서버 단계를 시안 화면으로 옮기는 **한 곳**입니다.
///
/// 하위 위젯은 서버 문자열을 다시 해석하지 않습니다. 여기서만 갈라 주세요.
///
/// | 서버 phase | 화면 |
/// |---|---|
/// | `roleReveal` | P1 역할 카드 확인 |
/// | `night` | P2~P5 밤 행동 (조사 결과 포함) |
/// | `morning` | 아침 → 사망 발표 → 취재 공개(있는 경우) → 토론 안내 |
/// | `day` | P6 자유 토론 |
/// | `voting` | P7 투표 |
/// | `voteResult` | 개표 대기 → 처형 발표 → 신분 공개 → 밤 안내 |
///
/// 사망자는 관전 명단을 봅니다. 단, 자신의 아침 사망이나 처형 결과는 먼저
/// 발표한 뒤 관전으로 넘어가므로 사망 이유를 놓치지 않습니다.
class MafiaPhoneGameScreen extends StatefulWidget {
  const MafiaPhoneGameScreen({
    super.key,
    required this.controller,
    required this.stage,
    required this.regions,
  });

  final MafiaController controller;
  final MafiaPhoneStage stage;
  final PhoneGameRegions regions;

  @override
  State<MafiaPhoneGameScreen> createState() => _MafiaPhoneGameScreenState();
}

/// 제출 전 대상 선택과 조사 결과 확인 여부만 로컬 상태로 보관합니다.
/// 발표 순서·유지 시간은 공용 Sequence/Timing에서 관리하며, 연출이 끝나도
/// 이 화면이 서버 phase를 임의로 바꾸지는 않습니다.
class _MafiaPhoneGameScreenState extends State<MafiaPhoneGameScreen> {
  // ---------------------------------------------------------------------------
  // 밤 행동 로컬 상태
  // ---------------------------------------------------------------------------
  // 확정 흐름: 대상 탭 = **선택만**, '선택 완료' 버튼 = 제출. 그래서 제출 전
  // 선택은 서버가 아니라 화면이 들고 있습니다.
  String? _nightSelection;
  int? _nightSelectionRound;

  // ---------------------------------------------------------------------------
  // 투표 로컬 상태
  // ---------------------------------------------------------------------------
  // 투표도 같은 방식입니다: 탭 = 선택만, '선택 완료' 버튼 = 제출.
  String? _voteSelection;
  int? _voteSelectionRound;

  // 서버 응답을 기다리는 동안에도 누른 결과를 즉시 유지합니다. 서버가
  // 거절했을 때만 선택 화면으로 돌아가므로 느린 네트워크에서 화면이
  // 선택→로딩→선택으로 튀지 않습니다.
  String? _pendingNightTargetUid;
  int? _pendingNightRound;
  String? _pendingVoteTargetUid;
  int? _pendingVoteRound;
  bool? _pendingTrialVote;
  String? _pendingTrialKey;
  bool _pendingDiscussionSkip = false;
  int? _pendingDiscussionRound;
  int _discussionSkipCountAtSubmit = 0;

  /// 조사 결과에서 '확인'을 누른 라운드입니다. 누르면 대기 화면으로 넘어갑니다.
  int? _acknowledgedInvestigationRound;

  @override
  Widget build(BuildContext context) {
    final game = widget.controller;
    _discardSettledSubmissions(game);

    // 확정(2026-08): 단계가 바뀔 때 화면 전체가 새로 그려지는 느낌을 없애려고
    // **배경과 내 보관 카드는 셸이 계속 그립니다.** 바뀌는 내용만 전환합니다.
    return Stack(
      fit: StackFit.expand,
      children: [
        // 낮·밤 배경은 부드럽게 바뀝니다(태블릿은 방사형 전환, 휴대폰은 겹침).
        AnimatedSwitcher(
          duration: MafiaPhoneTiming.backgroundTransition,
          child: KeyedSubtree(
            key: ValueKey(game.usesNightScene),
            child: MafiaPhoneBackground(isNight: game.usesNightScene),
          ),
        ),
        MafiaPhoneShellChrome(
          child: MafiaPhaseTransition(
            child: KeyedSubtree(
              key: ValueKey(_pageKey(game)),
              // 타이머가 1초마다 움직여야 하므로 남은 시간을 여기서 셉니다.
              // 서버 상태만 보고 그리면 상태가 안 바뀌는 동안 숫자가 굳습니다.
              child: GameTurnCountdown(
                expiresAt: widget.regions.showTimer
                    ? game.turnDeadlineAt
                    : null,
                builder: (context, remaining) => _buildPage(
                  game,
                  game.actionDeadlinePassed ? null : remaining,
                ),
              ),
            ),
          ),
        ),
        // 내 신분 카드는 **모든 단계에 걸쳐 한 장**입니다. 아래에 놓여 있다가
        // 누르면 가운데로 올라와 열리고 다시 내려갑니다(확정 2026-08).
        // 결과 화면부터는 카드가 필요 없어 얹지 않습니다.
        if (_showsRoleCard(game) && widget.regions.showHand)
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
            showPeekHint: !game.usesNightScene && !game.isSpectating,
          ),
        // 개인 기록은 휴대폰에서만 엽니다. 태블릿으로 전달하거나 공개 문구에 섞지 않습니다.
        if (game.privateDataReady &&
            !game.isFinished &&
            (game.currentInvestigation != null || game.roleChangedThisRound))
          Positioned(
            top: 72,
            right: 12,
            child: SizedBox(
              height: 40,
              child: MafiaNoirButton(
                label: game.roleChangedThisRound ? '신분 변경 확인' : '내 조사 기록',
                onTap: () => _showPrivateRecord(game),
                color: MafiaColors.noirSlab,
                textColor: MafiaColors.noirPaper,
                fontSize: 15,
                letterSpacing: 0,
              ),
            ),
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
    return widget.stage.name;
  }

  /// 신분 카드를 얹을 단계인지입니다.
  ///
  /// 결과 화면부터는 승패가 다 드러나 카드를 볼 이유가 없습니다.
  bool _showsRoleCard(MafiaController game) => !game.isFinished;

  Widget _buildPage(MafiaController game, Duration? remaining) {
    // 처형 발표는 사망 여부보다 먼저 봅니다. 자기가 처형된 사람도 발표를
    // 봐야 하기 때문입니다.
    if (widget.stage == MafiaPhoneStage.voteResult) {
      return _buildExecution(game);
    }

    // 사망자는 단계와 무관하게 관전 명단을 봅니다.
    if (widget.stage == MafiaPhoneStage.spectator) {
      return _spectator(game);
    }

    return switch (widget.stage) {
      // 신분 확인은 카드 레이어가 전부 그립니다(카드·화살표·문구).
      MafiaPhoneStage.roleReveal => const SizedBox.shrink(),
      MafiaPhoneStage.night => _buildNight(game, remaining),
      // 아침은 태블릿과 같은 발표 문구를 보여 줍니다(확정).
      MafiaPhoneStage.morning => _buildMorning(game),
      MafiaPhoneStage.day => MafiaDayDiscussionView(
        role: game.myRole,
        remainingSeconds: widget.regions.showTimer
            ? remaining?.inSeconds
            : null,
        // 과반수 투표로 끝난 낮입니다. 안내만 남기고 곧 투표로 넘어갑니다.
        endedByVote: game.isDayEndedByVote,
        canEndDiscussion:
            game.canEndDiscussion && !_isPendingDiscussionSkip(game),
        skipVoteCount: _discussionSkipCount(game),
        aliveCount: game.alivePlayers.length,
        hasVotedToSkip:
            game.hasVotedToSkipDiscussion || _isPendingDiscussionSkip(game),
        onEndDiscussion: widget.regions.showActions
            ? () => unawaited(_submitDiscussionSkip(game))
            : null,
        alivePlayers: game.alivePlayers,
        lastNightDead: [
          for (final uid in game.morningResult?.deadUids ?? const <String>[])
            ?game.players[uid],
        ],
      ),
      MafiaPhoneStage.voting => _buildVoting(game, remaining),
      // 그 밖의 단계(연결 중·종료)는 셸이 처리합니다.
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildNight(MafiaController game, Duration? remaining) {
    // 라운드가 바뀌면 지난 밤의 선택·확인 기록을 버립니다.
    if (_nightSelectionRound != game.round) {
      _nightSelectionRound = game.round;
      _nightSelection = null;
    }
    if (_nightSelection != null &&
        !game.nightTargets.any((player) => player.uid == _nightSelection)) {
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

    // 확정(2026-08): 밤은 **1~4 → 5~8 → 9~14 → 마무리**로 흐릅니다.
    // 내 차례가 아닌 구간에서는 격자를 감추고 대기 화면을 보여 줍니다.
    // 서버가 구간을 알려 주므로 남은 시간으로 되짚지 않습니다.
    final actionWindowClosed =
        game.nightStageClosed || game.actionDeadlinePassed;

    final pendingTarget = _pendingNightTarget(game);
    final isSubmitted = game.hasSubmittedNight || pendingTarget != null;

    return MafiaNightActionView(
      waitingMessage: game.nightStage == 'wrapUp'
          ? '밤이 지나가고 있습니다'
          : pendingTarget == null
          ? game.nightWaitingMessage
          : '다른 플레이어의 행동을 기다리는 중…',
      isWrappingUp: game.nightStage == 'wrapUp',
      role: game.myRole,
      actionWindowClosed: actionWindowClosed,
      // 능력을 다 쓴 밤은 대기 화면입니다(자경단원의 한 발).
      abilityExhausted: game.abilityExhausted,
      players: game.nightTargets,
      selectedUid: game.hasSubmittedNight
          ? game.nightTargetUid
          : pendingTarget ?? _nightSelection,
      allySelectedUids: game.allySelectedUids,
      remainingSeconds: widget.regions.showTimer ? remaining?.inSeconds : null,
      isSubmitted: isSubmitted,
      // 탭은 선택만 바꿉니다. 제출은 아래 '선택 완료' 버튼이 합니다.
      onSelect:
          widget.regions.showActions &&
              game.canSubmitNightAction &&
              pendingTarget == null &&
              !actionWindowClosed
          ? (uid) => setState(() => _nightSelection = uid)
          : null,
      onConfirm:
          widget.regions.showActions &&
              game.canSubmitNightAction &&
              pendingTarget == null &&
              !actionWindowClosed &&
              _nightSelection != null
          ? () => unawaited(_submitNightAction(game, _nightSelection!))
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
    final trial = game.ruleState;
    if (trial.trialStage != null) {
      final pendingTrialVote = _pendingTrialValue(game);
      return MafiaTrialView(
        candidate: game.players[trial.candidateUid]?.nickname ?? '후보',
        defending: trial.trialStage == 'defense',
        isCandidate: trial.candidateUid == game.uid,
        remainingSeconds: remaining?.inSeconds,
        hasVoted: game.trialVote != null || pendingTrialVote != null,
        onVote:
            game.canAct &&
                !game.isVoteBanned &&
                !game.actionDeadlinePassed &&
                trial.trialStage == 'verdict' &&
                game.trialVote == null &&
                pendingTrialVote == null
            ? (value) => unawaited(_submitTrialVote(game, value))
            : null,
      );
    }
    // 라운드가 바뀌면 지난 투표의 선택을 버립니다.
    if (_voteSelectionRound != game.round) {
      _voteSelectionRound = game.round;
      _voteSelection = null;
    }
    if (_voteSelection != null &&
        !game.voteTargets.any((player) => player.uid == _voteSelection)) {
      _voteSelection = null;
    }

    final pendingTarget = _pendingVoteTarget(game);
    final isSubmitted = game.hasVoted || pendingTarget != null;
    return MafiaVoteView(
      requestInFlight: game.commandInFlight,
      timeExpired: game.actionDeadlinePassed,
      role: game.myRole,
      players: game.voteTargets,
      selectedUid: game.hasVoted
          ? game.voteTargetUid
          : pendingTarget ?? _voteSelection,
      remainingSeconds: widget.regions.showTimer ? remaining?.inSeconds : null,
      isSubmitted: isSubmitted,
      // 마담에게 유혹당하면 이번 낮에는 표를 낼 수 없습니다.
      voteBanned: game.isVoteBanned,
      // 탭은 선택만 바꿉니다. 제출은 아래 '선택 완료' 버튼이 합니다.
      onSelect:
          widget.regions.showActions && game.canVote && pendingTarget == null
          ? (uid) => setState(() => _voteSelection = uid)
          : null,
      onConfirm:
          widget.regions.showActions &&
              game.canVote &&
              pendingTarget == null &&
              _voteSelection != null
          ? () => unawaited(_submitVote(game, _voteSelection!))
          : null,
    );
  }

  String? _pendingNightTarget(MafiaController game) =>
      _pendingNightRound == game.round && game.isNight
      ? _pendingNightTargetUid
      : null;

  String? _pendingVoteTarget(MafiaController game) =>
      _pendingVoteRound == game.round &&
          game.isVoting &&
          game.ruleState.trialStage == null
      ? _pendingVoteTargetUid
      : null;

  String _trialKey(MafiaController game) =>
      '${game.gameStartedAt}:${game.round}:${game.ruleState.trialStage}:${game.ruleState.candidateUid}';

  bool? _pendingTrialValue(MafiaController game) =>
      _pendingTrialKey == _trialKey(game) ? _pendingTrialVote : null;

  bool _isPendingDiscussionSkip(MafiaController game) =>
      _pendingDiscussionSkip &&
      _pendingDiscussionRound == game.round &&
      game.isDay;

  int _discussionSkipCount(MafiaController game) {
    if (!_isPendingDiscussionSkip(game)) return game.discussionSkipCount;
    final optimisticCount = _discussionSkipCountAtSubmit + 1;
    return game.discussionSkipCount < optimisticCount
        ? optimisticCount
        : game.discussionSkipCount;
  }

  void _discardSettledSubmissions(MafiaController game) {
    if (!game.isNight ||
        _pendingNightRound != game.round ||
        game.hasSubmittedNight) {
      _pendingNightTargetUid = null;
      _pendingNightRound = null;
    }
    if (!game.isVoting ||
        game.ruleState.trialStage != null ||
        _pendingVoteRound != game.round ||
        game.hasVoted) {
      _pendingVoteTargetUid = null;
      _pendingVoteRound = null;
    }
    if (_pendingTrialKey != _trialKey(game) || game.trialVote != null) {
      _pendingTrialVote = null;
      _pendingTrialKey = null;
    }
    if (!game.isDay ||
        _pendingDiscussionRound != game.round ||
        game.hasVotedToSkipDiscussion) {
      _pendingDiscussionSkip = false;
      _pendingDiscussionRound = null;
    }
  }

  Future<void> _submitNightAction(
    MafiaController game,
    String targetUid,
  ) async {
    final submittedRound = game.round;
    setState(() {
      _pendingNightTargetUid = targetUid;
      _pendingNightRound = submittedRound;
    });
    final accepted = await game.submitNightAction(targetUid);
    if (!mounted ||
        _pendingNightRound != submittedRound ||
        _pendingNightTargetUid != targetUid) {
      return;
    }
    if (!accepted && !game.hasSubmittedNight) {
      setState(() {
        _pendingNightTargetUid = null;
        _pendingNightRound = null;
      });
    }
  }

  Future<void> _submitDiscussionSkip(MafiaController game) async {
    if (_isPendingDiscussionSkip(game)) return;
    final submittedRound = game.round;
    setState(() {
      _pendingDiscussionSkip = true;
      _pendingDiscussionRound = submittedRound;
      _discussionSkipCountAtSubmit = game.discussionSkipCount;
    });
    final accepted = await game.endDiscussion();
    if (!mounted || _pendingDiscussionRound != submittedRound) return;
    if (!accepted && !game.hasVotedToSkipDiscussion) {
      setState(() {
        _pendingDiscussionSkip = false;
        _pendingDiscussionRound = null;
      });
    }
  }

  Future<void> _submitVote(MafiaController game, String targetUid) async {
    final submittedRound = game.round;
    setState(() {
      _pendingVoteTargetUid = targetUid;
      _pendingVoteRound = submittedRound;
    });
    final accepted = await game.submitVote(targetUid);
    if (!mounted ||
        _pendingVoteRound != submittedRound ||
        _pendingVoteTargetUid != targetUid) {
      return;
    }
    if (!accepted && !game.hasVoted) {
      setState(() {
        _pendingVoteTargetUid = null;
        _pendingVoteRound = null;
      });
    }
  }

  Future<void> _submitTrialVote(MafiaController game, bool execute) async {
    final submittedKey = _trialKey(game);
    setState(() {
      _pendingTrialVote = execute;
      _pendingTrialKey = submittedKey;
    });
    final accepted = await game.submitTrialVote(execute);
    if (!mounted || _pendingTrialKey != submittedKey) return;
    if (!accepted && game.trialVote == null) {
      setState(() {
        _pendingTrialVote = null;
        _pendingTrialKey = null;
      });
    }
  }

  Widget _buildExecution(MafiaController game) {
    final executed = game.executedPlayer;
    return GamePresentationSequence(
      key: ValueKey(('vote', game.gameStartedAt, game.round)),
      beats: [
        GamePresentationBeat(
          hold: MafiaPresentationTiming.voteTally,
          child: game.voteResult?.hasVerdict == true
              ? MafiaVerdictSummary(result: game.voteResult!)
              : const MafiaPhonePhaseNotice(
                  message: '개표합니다',
                  detail: '누가 누구를 찍었는지는 비밀입니다',
                ),
        ),
        GamePresentationBeat(
          hold: MafiaPresentationTiming.executionName,
          child: MafiaExecutionResultView(
            role: game.myRole,
            executed: executed,
            isMe: game.isExecutedMe,
          ),
        ),
        GamePresentationBeat(
          hold: MafiaPresentationTiming.executionReveal,
          child: executed == null
              ? const MafiaPhonePhaseNotice(message: '아무도 처형되지 않았습니다.')
              : game.ruleState.rules.executionReveal != 'role'
              ? MafiaLimitedDisclosure(
                  nickname: executed.nickname,
                  faction: game.ruleState.rules.executionReveal == 'faction'
                      ? game.ruleState.revealedFactions[executed.uid]
                      : null,
                )
              : MafiaExecutionRevealView(
                  myRole: game.myRole,
                  executed: executed,
                  executedRole: game.revealedRoleOf(executed.uid),
                ),
        ),
        if (!(game.voteResult?.endsGame ?? false))
          const GamePresentationBeat(
            hold: MafiaPresentationTiming.nextPhase,
            child: MafiaPhonePhaseNotice(message: '밤이 찾아왔다'),
          ),
      ],
    );
  }

  /// 아침 안내 → 밤 결과 → 취재 공개 → 토론/관전. 시간표는 태블릿과 공유합니다.
  Widget _buildMorning(MafiaController game) {
    final result = game.morningResult;
    final exposed = game.players[result?.exposedUid];
    return GamePresentationSequence(
      key: ValueKey(('morning', game.gameStartedAt, game.round)),
      completed: game.isSpectating ? _spectator(game) : null,
      beats: [
        // 시안: '아침이 밝았다' 제목과 사망 포스터가 한 화면입니다. 여는 문구와
        // 발표를 한 박자로 묶어 화면이 한 번만 바뀌게 합니다(전체 시간은 같음).
        GamePresentationBeat(
          hold:
              MafiaPresentationTiming.morningOpening +
              MafiaPresentationTiming.morningDeaths,
          child: game.isSpectating
              ? const MafiaPhonePhaseNotice(
                  message: '당신은 밤사이 사망했습니다.',
                  detail:
                      '발표가 끝나면 관전할 수 있습니다.\n알게 된 신분은 게임이 끝날 때까지 비밀로 유지해 주세요.',
                )
              : MafiaMorningAnnouncementView(
                  role: game.myRole,
                  result: result,
                  players: game.players,
                  hold:
                      MafiaPresentationTiming.morningOpening +
                      MafiaPresentationTiming.morningDeaths,
                ),
        ),
        if (result?.hasExposure ?? false)
          GamePresentationBeat(
            hold: MafiaPresentationTiming.exposure,
            child: exposed == null
                ? const MafiaPhonePhaseNotice(message: '취재 결과 발표')
                : GamePresentationSequence(
                    beats: [
                      GamePresentationBeat(
                        hold: MafiaPresentationTiming.executionName,
                        child: MafiaPhonePhaseNotice(
                          message: '${exposed.nickname}님의 신분이 공개됩니다.',
                        ),
                      ),
                      GamePresentationBeat(
                        hold: MafiaPresentationTiming.executionReveal,
                        child: MafiaExecutionRevealView(
                          myRole: game.myRole,
                          executed: exposed,
                          executedRole: game.revealedRoleOf(exposed.uid),
                        ),
                      ),
                    ],
                  ),
          ),
        if (!(result?.endsGame ?? false))
          GamePresentationBeat(
            hold: MafiaPresentationTiming.nextPhase,
            child: game.isSpectating
                ? _spectator(game)
                : const MafiaPhonePhaseNotice(message: '토론을 시작합니다'),
          ),
      ],
    );
  }

  Widget _spectator(MafiaController game) => MafiaSpectatorRosterView(
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

  void _showPrivateRecord(MafiaController game) {
    final investigation = game.currentInvestigation;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('나만 볼 수 있는 정보'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (game.roleChangedThisRound) ...[
                Text('현재 신분: ${game.myRole?.displayName ?? '확인 중'}'),
                const SizedBox(height: 8),
                Text(game.myRole?.description ?? ''),
                const SizedBox(height: 16),
              ],
              if (investigation != null)
                Text(
                  '${game.round}라운드 조사 기록\n'
                  '${game.players[investigation.targetUid]?.nickname ?? '플레이어'}: ${investigation.verdict}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
