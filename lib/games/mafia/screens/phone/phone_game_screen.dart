import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/games/mafia/animations/mafia_phase_transition.dart';
import 'package:project00/games/mafia/controllers/mafia_controller.dart';
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
              child: _buildPage(game),
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
            onRevealed: game.confirmRole,
          ),
      ],
    );
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

  Widget _buildPage(MafiaController game) {
    // 처형 발표는 사망 여부보다 먼저 봅니다. 자기가 처형된 사람도 발표를
    // 봐야 하기 때문입니다.
    if (game.isVoteResult && _executionStage != _ExecutionStage.done) {
      return _buildExecution(game);
    }

    // 사망자는 단계와 무관하게 관전 명단을 봅니다.
    if (game.isSpectating) {
      return MafiaSpectatorRosterView(
        myRole: game.myRole,
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
      'night' => _buildNight(game),
      // 아침은 태블릿과 같은 발표 문구를 보여 줍니다(확정).
      'morning' => MafiaMorningAnnouncementView(
        role: game.myRole,
        result: game.morningResult,
        players: game.players,
      ),
      'day' => MafiaDayDiscussionView(
        role: game.myRole,
        remainingSeconds: _remainingSeconds(game),
        canEndDiscussion: game.canEndDiscussion,
        skipVoteCount: game.discussionSkipCount,
        aliveCount: game.alivePlayers.length,
        hasVotedToSkip: game.hasVotedToSkipDiscussion,
        onEndDiscussion: game.endDiscussion,
      ),
      'voting' => _buildVoting(game),
      // 그 밖의 단계(연결 중·종료)는 셸이 처리합니다.
      _ => MafiaDayDiscussionView(role: game.myRole, title: '잠시만 기다려 주세요'),
    };
  }

  Widget _buildNight(MafiaController game) {
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

    return MafiaNightActionView(
      role: game.myRole,
      players: game.nightTargets,
      selectedUid: game.hasSubmittedNight
          ? game.nightTargetUid
          : _nightSelection,
      allySelectedUids: game.allySelectedUids,
      remainingSeconds: _remainingSeconds(game),
      isSubmitted: game.hasSubmittedNight,
      // 탭은 선택만 바꿉니다. 제출은 아래 '선택 완료' 버튼이 합니다.
      onSelect: game.canSubmitNightAction
          ? (uid) => setState(() => _nightSelection = uid)
          : null,
      onConfirm: game.canSubmitNightAction && _nightSelection != null
          ? () => unawaited(game.submitNightAction(_nightSelection!))
          : null,
      investigationResult: showsResult
          ? MafiaNightInvestigationResult(
              target: target,
              verdict: investigation.verdict,
              title: game.myRole?.nightPromptVerb == '추적' ? '추적 결과' : '조사 결과',
            )
          : null,
      onConfirmResult: showsResult
          ? () => setState(() => _acknowledgedInvestigationRound = game.round)
          : null,
    );
  }

  Widget _buildVoting(MafiaController game) {
    // 라운드가 바뀌면 지난 투표의 선택을 버립니다.
    if (_voteSelectionRound != game.round) {
      _voteSelectionRound = game.round;
      _voteSelection = null;
    }

    return MafiaVoteView(
      role: game.myRole,
      players: game.voteTargets,
      selectedUid: game.hasVoted ? game.voteTargetUid : _voteSelection,
      remainingSeconds: _remainingSeconds(game),
      isSubmitted: game.hasVoted,
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

  /// 남은 시간(초)입니다. 마감이 없는 단계면 null입니다.
  ///
  /// 서버 시계와 기기 시계가 어긋날 수 있어 음수는 0으로 눌러 보여 줍니다.
  int? _remainingSeconds(MafiaController game) {
    final deadline = game.turnDeadlineAt;
    if (deadline == null) return null;
    final remaining = (deadline - DateTime.now().millisecondsSinceEpoch) / 1000;
    return remaining <= 0 ? 0 : remaining.ceil();
  }
}
