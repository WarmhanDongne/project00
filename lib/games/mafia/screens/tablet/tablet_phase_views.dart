import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_execution_view.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_tally_view.dart';
import 'package:project00/games/shared/animations/card_deal.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================T1 역할 배분==============================
/// 카드를 각 자리로 나눠 주는 연출입니다.
///
/// 시안 없이 확정된 방식입니다 — 태블릿 배경 위에서 **공용 분배 애니메이션**을
/// 돌리고, 카드는 **뒷면 그대로** 둡니다. 태블릿에 신분이 보이면 옆에서 보는
/// 사람에게 다 드러납니다.
class MafiaTabletRoleDealView extends StatelessWidget {
  const MafiaTabletRoleDealView({
    super.key,
    required this.players,
    required this.confirmedCount,
    this.onRulebookPressed,
    this.onSettingsPressed,
  });

  final List<MafiaPlayer> players;

  /// 역할 카드를 확인한 인원입니다. 누가 확인했는지는 공개해도 무해합니다.
  final int confirmedCount;

  final VoidCallback? onRulebookPressed;
  final VoidCallback? onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 분배음은 카드가 착지하는 순간에 이 연출이 알아서 재생합니다.
        CardDealAnimation(
          playerCount: players.isEmpty ? 4 : players.length,
          playerSeatIndexes: players
              .map((player) => player.seatIndex)
              .toList(growable: false),
          cardsPerPlayer: 1,
          cardAsset: Assets.games.mafia.images.cards.roleBack.game,
          autoplay: true,
          backgroundColor: Colors.transparent,
        ),
        MafiaTabletHeadline(
          text: '확인 $confirmedCount / ${players.length}',
          top: 705,
          fontSize: 32,
        ),
        MafiaTabletChrome(
          onRulebookPressed: onRulebookPressed,
          onSettingsPressed: onSettingsPressed,
        ),
      ],
    );
  }
}

//=======================T2 밤==============================
/// 밤 화면입니다.
///
/// **개별 완료 여부는 절대 표시하지 않습니다.** 누가 행동을 마쳤는지 보이면
/// 특수직이 드러납니다. 인원수만 보여 줍니다.
class MafiaTabletNightView extends StatefulWidget {
  const MafiaTabletNightView({
    super.key,
    required this.submittedCount,
    required this.actorCount,
    this.onRulebookPressed,
    this.onSettingsPressed,
  });

  final int submittedCount;
  final int actorCount;
  final VoidCallback? onRulebookPressed;
  final VoidCallback? onSettingsPressed;

  /// 새가 날갯짓하는 한 프레임의 길이입니다.
  static const Duration birdFrameDuration = Duration(milliseconds: 220);

  @override
  State<MafiaTabletNightView> createState() => _MafiaTabletNightViewState();
}

class _MafiaTabletNightViewState extends State<MafiaTabletNightView> {
  Timer? _birdTimer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _birdTimer = Timer.periodic(MafiaTabletNightView.birdFrameDuration, (_) {
      if (mounted) setState(() => _frame = (_frame + 1) % 4);
    });
  }

  @override
  void dispose() {
    _birdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bird = Assets.games.mafia.images.background.bird;
    final frames = [
      bird.nightBird0.game,
      bird.nightBird1.game,
      bird.nightBird2.game,
      bird.nightBird3.game,
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        // 새 4프레임을 돌려 밤 배경에 움직임을 줍니다.
        frames[_frame].image(
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
        const MafiaTabletHeadline(
          text: '밤이 되었습니다',
          top: 340,
          color: Colors.white,
        ),
        MafiaTabletHeadline(
          text: '행동 완료 ${widget.submittedCount} / ${widget.actorCount}',
          top: 440,
          fontSize: 32,
          color: Colors.white,
        ),
        MafiaTabletChrome(
          onRulebookPressed: widget.onRulebookPressed,
          onSettingsPressed: widget.onSettingsPressed,
        ),
      ],
    );
  }
}

//=======================T3 아침 발표==============================
/// 밤 사이 일어난 일을 알립니다.
///
/// 누가 살렸는지는 절대 보여 주지 않습니다. 의사와 대상이 드러납니다.
class MafiaTabletMorningView extends StatelessWidget {
  const MafiaTabletMorningView({
    super.key,
    required this.result,
    required this.players,
    this.onRulebookPressed,
    this.onSettingsPressed,
  });

  final MafiaMorningResult? result;
  final Map<String, MafiaPlayer> players;
  final VoidCallback? onRulebookPressed;
  final VoidCallback? onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    final current = result;
    final deadNames = current == null
        ? const <String>[]
        : current.deadUids
              .map((uid) => players[uid]?.nickname ?? '플레이어')
              .toList(growable: false);

    return Stack(
      fit: StackFit.expand,
      children: [
        const MafiaTabletSun(),
        const MafiaTabletHeadline(text: '아침이 되었습니다', top: 260, fontSize: 48),
        if (deadNames.isEmpty)
          const MafiaTabletHeadline(text: '아무도 죽지 않았습니다', top: 378)
        else ...[
          MafiaTabletHeadline(text: deadNames.join(' · '), top: 360),
          const MafiaTabletHeadline(text: '사망했습니다', top: 470, fontSize: 32),
        ],
        MafiaTabletChrome(
          onRulebookPressed: onRulebookPressed,
          onSettingsPressed: onSettingsPressed,
        ),
      ],
    );
  }
}

//=======================T6·T7 개표 → 처형 발표==============================
/// 개표판을 보여 준 뒤 처형 발표로 넘어갑니다.
///
/// 서버는 `voteResult` 하나로만 알려 주므로 두 시안의 순서를 화면이 셉니다.
/// 연출 상태라 컨트롤러에 두지 않습니다.
class MafiaTabletVoteResultSequence extends StatefulWidget {
  const MafiaTabletVoteResultSequence({
    super.key,
    required this.result,
    required this.players,
    required this.executed,
    required this.executedRole,
    this.onRulebookPressed,
    this.onSettingsPressed,
  });

  final MafiaVoteResult? result;
  final Map<String, MafiaPlayer> players;
  final MafiaPlayer? executed;
  final MafiaRole? executedRole;
  final VoidCallback? onRulebookPressed;
  final VoidCallback? onSettingsPressed;

  /// 개표판을 보여 주는 시간입니다.
  static const Duration tallyHold = Duration(milliseconds: 2600);

  @override
  State<MafiaTabletVoteResultSequence> createState() =>
      _MafiaTabletVoteResultSequenceState();
}

class _MafiaTabletVoteResultSequenceState
    extends State<MafiaTabletVoteResultSequence> {
  Timer? _timer;
  bool _showsExecution = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(MafiaTabletVoteResultSequence.tallyHold, () {
      if (mounted) setState(() => _showsExecution = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showsExecution) {
      return MafiaTabletTallyView(
        result: widget.result,
        players: widget.players,
        onRulebookPressed: widget.onRulebookPressed,
        onSettingsPressed: widget.onSettingsPressed,
      );
    }
    return MafiaTabletExecutionView(
      executed: widget.executed,
      executedRole: widget.executedRole,
      isTie: widget.result?.tie ?? false,
      onRulebookPressed: widget.onRulebookPressed,
      onSettingsPressed: widget.onSettingsPressed,
    );
  }
}
