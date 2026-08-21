import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_execution_view.dart';
import 'package:project00/games/mafia/animations/role_deal_toss_animation.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_night_bird.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_tally_view.dart';
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
    this.showsNightNotice = false,
    this.onRulebookPressed,
    this.onSettingsPressed,
  });

  final List<MafiaPlayer> players;

  /// 역할 카드를 확인한 인원입니다. 누가 확인했는지는 공개해도 무해합니다.
  final int confirmedCount;

  /// '밤이 됐습니다' 안내를 덮어 보여 줄지입니다(확정: 전원 확인 10초 뒤).
  final bool showsNightNotice;

  final VoidCallback? onRulebookPressed;
  final VoidCallback? onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    final seatIndexes = players
        .map((player) => player.seatIndex)
        .toList(growable: false);
    // 좌석 번호는 방 기준이라 인원수보다 클 수 있습니다(12인 방에 4명이
    // 흩어져 앉는 경우). 좌석판 크기를 함께 주지 않으면 분배 연출이 좌석을
    // 찾다가 터집니다. 가장 큰 좌석 번호까지 담기는 크기로 넘깁니다.
    final boardSeatCount = seatIndexes.isEmpty
        ? players.length
        : seatIndexes.reduce((a, b) => a > b ? a : b) + 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 확정(2026-08): 마피아는 1장씩 — 중앙 더미에서 각 좌석 방향으로
        // 날아가 화면 밖(그 사람의 휴대폰)으로 나갑니다. 분배음은 발사 순간.
        // 첫 공개 상태가 아직 없으면 나눠 줄 사람도 없으므로 그리지 않습니다.
        if (players.isNotEmpty)
          MafiaRoleDealTossAnimation(
            playerSeatIndexes: seatIndexes,
            boardSeatCount: boardSeatCount,
          ),
        MafiaTabletHeadline(
          text: '확인 $confirmedCount / ${players.length}',
          top: 705,
          fontSize: 32,
        ),
        // 전원 확인 뒤 10초가 지나면 어두워지며 밤을 알립니다. 이 안내가 끝나면
        // 화면(tablet_game.dart)이 서버에 밤 시작을 알립니다.
        if (showsNightNotice)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xCC10131A),
              child: Center(
                child: Text(
                  '밤이 됐습니다',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
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
/// 밤 화면입니다(시안 `tablet-T2`).
///
/// **시안에 문구가 하나도 없습니다.** 달만 뜹니다. 진행 현황도 넣지 않습니다 —
/// 누가 행동을 마쳤는지 보이면 특수직이 드러나고, 인원수조차 시안에 없습니다.
class MafiaTabletNightView extends StatelessWidget {
  const MafiaTabletNightView({
    super.key,
    this.onRulebookPressed,
    this.onSettingsPressed,
  });

  final VoidCallback? onRulebookPressed;
  final VoidCallback? onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const MafiaTabletMoon(),
        // 새가 한 번씩 오른쪽에서 왼쪽으로 지나갑니다.
        const MafiaTabletNightBird(),
        MafiaTabletChrome(
          isNight: true,
          onRulebookPressed: onRulebookPressed,
          onSettingsPressed: onSettingsPressed,
        ),
      ],
    );
  }
}

//=======================T3 아침 발표==============================
/// 밤 사이 일어난 일을 알립니다(시안 `tablet-t3` 두 상태).
///
/// | 상태 | 시안 |
/// |---|---|
/// | 사망자 있음 | 시체 그림 + `○○님은 밤을 넘기지 못했습니다.` |
/// | 사망자 없음 | `어제 밤, 아무도 죽지 않았습니다.` |
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

  //=======================시안 기준 좌표==============================
  /// 시체 그림입니다. 시안은 754 × 754 자리에 여백을 포함한 그림을 넣었지만,
  /// 저장소 파일(`dead_message`)은 그 여백이 없는 판이라 실제 그림이 놓이는
  /// 자리에 맞춰 넣습니다.
  static const Rect _corpse = Rect.fromLTWH(257.9, 323.7, 675.2, 262.1);

  /// 사망자 문구입니다. 시안은 48px Regular입니다.
  static const double _deathTextTop = 694;

  /// 사망자가 없을 때의 문구 위치입니다.
  static const double _noDeathTextTop = 415;

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
        if (deadNames.isEmpty)
          const MafiaTabletHeadline(
            text: '어제 밤, 아무도 죽지 않았습니다.',
            top: _noDeathTextTop,
            fontSize: 48,
            fontWeight: FontWeight.w400,
          )
        else ...[
          MafiaTabletBox(
            rect: _corpse,
            child: Assets.games.mafia.images.other.deadMessage.game.image(
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          MafiaTabletHeadline(
            text: '${deadNames.join(' · ')}님은 밤을 넘기지 못했습니다.',
            top: _deathTextTop,
            fontSize: 48,
            fontWeight: FontWeight.w400,
          ),
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

  /// 개표판을 보여 주는 시간입니다(확정: 4초).
  static const Duration tallyHold = Duration(milliseconds: 4000);

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
