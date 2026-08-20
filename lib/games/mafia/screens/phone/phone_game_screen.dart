import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/games/mafia/controllers/mafia_controller.dart';
import 'package:project00/games/mafia/widgets/phone/day_discussion_view.dart';
import 'package:project00/games/mafia/widgets/phone/execution_view.dart';
import 'package:project00/games/mafia/widgets/phone/night_action_view.dart';
import 'package:project00/games/mafia/widgets/phone/role_reveal_view.dart';
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
enum _ExecutionStage { announce, reveal, done }

class _MafiaPhoneGameScreenState extends State<MafiaPhoneGameScreen> {
  /// 처형자 이름을 보여 주는 시간입니다. 이 뒤에 카드를 뒤집습니다.
  static const Duration _announceHold = Duration(milliseconds: 2600);

  _ExecutionStage _executionStage = _ExecutionStage.done;
  int? _executionRound;
  Timer? _announceTimer;

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
      'roleReveal' => MafiaRoleRevealView(
        role: game.myRole,
        initiallyRevealed: game.hasConfirmedRole,
        onRevealed: game.confirmRole,
      ),
      'night' => _buildNight(game),
      // 아침은 태블릿이 발표하고 휴대폰은 기다립니다.
      // ⚠️ 시안이 없어 낮 화면을 제목만 바꿔 씁니다(미확정).
      'morning' => MafiaDayDiscussionView(role: game.myRole, title: '아침'),
      'day' => MafiaDayDiscussionView(
        role: game.myRole,
        remainingSeconds: _remainingSeconds(game),
        canEndDiscussion: game.canEndDiscussion,
        onEndDiscussion: game.endDiscussion,
      ),
      'voting' => MafiaVoteView(
        role: game.myRole,
        players: game.voteTargets,
        selectedUid: game.voteTargetUid,
        remainingSeconds: _remainingSeconds(game),
        isSubmitted: game.hasVoted,
        onSelect: game.canVote ? _submitVote : null,
        onConfirm: null,
      ),
      // 그 밖의 단계(연결 중·종료)는 셸이 처리합니다.
      _ => MafiaDayDiscussionView(role: game.myRole, title: '잠시만 기다려 주세요'),
    };
  }

  Widget _buildNight(MafiaController game) {
    final investigation = game.currentInvestigation;
    final target = investigation == null
        ? null
        : game.players[investigation.targetUid];

    return MafiaNightActionView(
      role: game.myRole,
      players: game.nightTargets,
      selectedUid: game.nightTargetUid,
      allySelectedUids: game.allySelectedUids,
      remainingSeconds: _remainingSeconds(game),
      isSubmitted: game.hasSubmittedNight,
      onSelect: game.canSubmitNightAction ? game.submitNightAction : null,
      onConfirm: null,
      investigationResult: (investigation == null || target == null)
          ? null
          : MafiaNightInvestigationResult(
              target: target,
              verdict: investigation.verdict,
              title: game.myRole?.nightPromptVerb == '추적' ? '추적 결과' : '조사 결과',
            ),
      onConfirmResult: null,
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

  void _submitVote(String targetUid) {
    unawaited(widget.controller.submitVote(targetUid));
  }
}
