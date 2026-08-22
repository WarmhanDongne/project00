import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/mafia_copy.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/sound/mafia_sounds.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_execution_view.dart';
import 'package:project00/games/mafia/animations/announcement_reveal.dart';
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
class MafiaTabletRoleDealView extends StatefulWidget {
  const MafiaTabletRoleDealView({
    super.key,
    required this.players,
    required this.confirmedCount,
    this.showsNightNotice = false,
    this.showsGameStartNotice = false,
  });

  final List<MafiaPlayer> players;

  /// 역할 카드를 확인한 인원입니다. 누가 확인했는지는 공개해도 무해합니다.
  final int confirmedCount;

  /// '밤이 됐습니다' 안내를 덮어 보여 줄지입니다(확정: 전원 확인 10초 뒤).
  final bool showsNightNotice;

  /// '게임을 시작하겠습니다' 안내를 덮어 보여 줄지입니다.
  ///
  /// 확정(2026-08): 전원이 신분을 확인한 **그 순간** 소리와 함께 띄웁니다.
  final bool showsGameStartNotice;

  //=======================확인 현황 문구 자리==============================
  /// 확인 현황('5 / 6')이 놓이는 자리입니다(시안 좌표 기준).
  ///
  /// 확정(2026-08): 이 문구는 **가운데 카드 더미 아래쪽에 숨어 있다가**, 카드가
  /// 모두 날아가면 그 자리에 남습니다. 더미는 화면 가운데(417)에 높이 246으로
  /// 놓이므로(294~540), 이 값은 그 안쪽 아래입니다.
  static const double confirmTextTop = 462;

  /// 카드가 다 날아간 뒤 문구가 드러나는 시간입니다.
  static const Duration confirmRevealDuration = Duration(milliseconds: 220);

  @override
  State<MafiaTabletRoleDealView> createState() =>
      _MafiaTabletRoleDealViewState();
}

class _MafiaTabletRoleDealViewState extends State<MafiaTabletRoleDealView> {
  /// 카드 더미가 비었는지입니다. 그 전에는 문구가 카드 뒤에 숨습니다.
  bool _deckCleared = false;

  /// 전원이 카드를 확인했는지입니다.
  bool get _allConfirmed =>
      widget.players.isNotEmpty &&
      widget.confirmedCount >= widget.players.length;

  @override
  Widget build(BuildContext context) {
    final players = widget.players;
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
        // 확인 현황은 카드 더미 **뒤**에 둡니다(그리는 순서가 곧 z순서).
        // 나눠 주는 동안에는 카드에 가려 보이지 않고, 마지막 장이 떠나면
        // 그 자리에 남습니다. 인원이 많아 문구가 카드보다 넓어지는 경우까지
        // 확실히 가리려고, 더미가 빌 때까지 투명도로도 감춥니다.
        // 확정(2026-08): 전원이 확인하면(4/4) 숫자를 **곧바로** 거둡니다. 더
        // 기다릴 것이 없는데 남겨 두면 밤 안내까지 10초를 멍하니 보게 됩니다.
        AnimatedOpacity(
          opacity: _allConfirmed
              ? 0
              : (_deckCleared || players.isEmpty ? 1 : 0),
          duration: MafiaTabletRoleDealView.confirmRevealDuration,
          child: MafiaTabletHeadline(
            // 확정(2026-08): '확인' 글자는 빼고 숫자만 둡니다.
            text: '${widget.confirmedCount} / ${players.length}',
            top: MafiaTabletRoleDealView.confirmTextTop,
            fontSize: 32,
          ),
        ),
        if (players.isNotEmpty)
          MafiaRoleDealTossAnimation(
            playerSeatIndexes: seatIndexes,
            boardSeatCount: boardSeatCount,
            onDeckCleared: () {
              if (mounted) setState(() => _deckCleared = true);
            },
          ),
        // 전원이 신분을 확인하면 곧바로 게임 시작을 알립니다(소리는 화면이
        // 냅니다). 밤 안내가 시작되면 이 안내는 이미 물러나 있습니다.
        if (widget.showsGameStartNotice && !widget.showsNightNotice)
          const Positioned.fill(
            child: MafiaAnnouncementReveal(
              child: MafiaTabletNotice.day(text: MafiaCopy.gameStartNotice),
            ),
          ),
        // 전원 확인 뒤 10초가 지나면 어두워지며 밤을 알립니다. 이 안내가 끝나면
        // 화면(tablet_game.dart)이 서버에 밤 시작을 알립니다.
        if (widget.showsNightNotice)
          const Positioned.fill(
            child: MafiaAnnouncementReveal(
              child: MafiaTabletNotice.night(text: MafiaCopy.nightNotice),
            ),
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
  const MafiaTabletNightView({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const MafiaTabletMoon(),
        // 새가 한 번씩 오른쪽에서 왼쪽으로 지나갑니다.
        const MafiaTabletNightBird(),
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
  });

  final MafiaMorningResult? result;
  final Map<String, MafiaPlayer> players;

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
        // 확정(2026-08): 긴 문장은 두 박자로 나눠 내려찍습니다.
        if (deadNames.isEmpty)
          const MafiaTabletAnnouncement(
            beats: MafiaCopy.noDeathBeats,
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
          MafiaTabletAnnouncement(
            beats: MafiaCopy.deathBeats(deadNames.join(' · ')),
            top: _deathTextTop,
            fontSize: 48,
            fontWeight: FontWeight.w400,
          ),
        ],
      ],
    );
  }
}

//=======================T3 아침 순서==============================
/// 아침을 세 박자로 알립니다(확정 2026-08).
///
///   '아침이 되었습니다'(2.5초) → 사망자 발표(8초) → '토론을 시작합니다'(2.5초)
///
/// 각 박자는 **떠올랐다가 물러납니다**([MafiaAnnouncementReveal]). 그래서 안내가
/// 뜨는 동안 사망자 발표가 뒤에 깔려 있지 않고, 발표도 다 읽은 뒤 물러납니다.
///
/// 마지막 안내가 끝나면 화면(tablet_game.dart)이 서버에 아침 완료를 알려
/// 토론으로 넘어갑니다. 그래서 이 세 박자의 합이 아침 단계의 시간입니다
/// ([MafiaTabletStage.announcementHold]와 반드시 같아야 합니다).
class MafiaTabletMorningSequence extends StatelessWidget {
  const MafiaTabletMorningSequence({
    super.key,
    required this.result,
    required this.players,
    this.exposedRole,
  });

  final MafiaMorningResult? result;
  final Map<String, MafiaPlayer> players;

  /// 기자가 취재한 사람의 신분입니다. 취재가 없었으면 null입니다.
  ///
  /// 서버가 `revealedRoles`에 공개한 값을 그대로 받습니다.
  final MafiaRole? exposedRole;

  /// '아침이 되었습니다'를 보여 주는 시간입니다.
  static const Duration openingHold = Duration(milliseconds: 2500);

  /// 사망자 발표를 읽을 시간입니다(확정: 8초).
  static const Duration announcementHold = Duration(milliseconds: 8000);

  /// 기자의 취재 공개를 보여 주는 시간입니다(처형 공개와 같은 9초).
  static const Duration exposureHold = Duration(milliseconds: 9000);

  /// '토론을 시작합니다'를 보여 주는 시간입니다.
  static const Duration closingHold = Duration(milliseconds: 2500);

  /// 세 박자를 합한 아침 전체 시간입니다(취재 공개 없음).
  static Duration get totalHold => openingHold + announcementHold + closingHold;

  /// 이 결과로 실제로 보여 줄 시간입니다.
  ///
  /// 확정(2026-08): 사망자 발표로 게임이 끝나면 **'토론을 시작합니다'를 건너뛰고
  /// 곧바로** 결과 화면으로 갑니다. 이미 끝난 판에서 다음 단계를 예고하면 게임이
  /// 계속되는 것처럼 보입니다.
  ///
  /// 기자의 취재가 성공한 아침은 카드 공개 박자가 하나 더 들어갑니다. 이 값이
  /// 실제 연출보다 짧으면 발표가 잘린 채 단계가 넘어갑니다.
  static Duration holdOf(MafiaMorningResult? result) {
    final ends = result?.endsGame ?? false;
    // 취재 공개는 게임이 끝나는 아침에도 보여 줍니다 — 이미 공개된 신분이라
    // 승패를 앞당겨 알려 주는 것이 아닙니다.
    final exposure = (result?.hasExposure ?? false)
        ? exposureHold
        : Duration.zero;
    final base = openingHold + announcementHold + exposure;
    return ends ? base : base + closingHold;
  }

  @override
  Widget build(BuildContext context) {
    final exposedUid = result?.exposedUid;
    final exposed = exposedUid == null ? null : players[exposedUid];
    // 취재 대상이 명단에서 사라진 경우(퇴장)에는 박자를 건너뜁니다.
    final showsExposure = exposed != null;
    final afterAnnouncement = openingHold + announcementHold;
    final afterExposure =
        afterAnnouncement + (showsExposure ? exposureHold : Duration.zero);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1박자: 아침 안내가 떠올랐다 물러납니다.
        MafiaAnnouncementReveal(
          visibleFor: openingHold,
          child: const MafiaTabletNotice.day(text: MafiaCopy.morningNotice),
        ),
        // 2박자: 안내가 물러난 뒤 사망자 발표가 떠오르고, 다 읽으면 물러납니다.
        MafiaAnnouncementReveal(
          delay: openingHold,
          visibleFor: announcementHold,
          child: MafiaTabletMorningView(result: result, players: players),
        ),
        // 3박자(있을 때만): 기자의 취재 공개입니다. **처형 공개와 같은 연출**을
        // 그대로 씁니다 — 카드가 뒤집혀 신분이 드러나고, 그 사람은 죽지 않습니다.
        if (showsExposure)
          MafiaAnnouncementReveal(
            delay: afterAnnouncement,
            visibleFor: exposureHold,
            child: MafiaTabletExecutionView(
              executed: exposed,
              executedRole: exposedRole,
              isTie: false,
              headlineBeats: MafiaCopy.exposureBeats,
            ),
          ),
        // 마지막 박자: 토론 시작 안내입니다. 단계가 넘어갈 때까지 남습니다.
        // 이 발표로 게임이 끝나면 띄우지 않습니다.
        if (!(result?.endsGame ?? false))
          MafiaAnnouncementReveal(
            delay: afterExposure,
            child: const MafiaTabletNotice.day(
              text: MafiaCopy.discussionNotice,
              // '지금부터 토론을 시작합니다' 음성(2.24초)이 2.5초 안내에 맞습니다.
              voice: MafiaSounds.voiceDiscussion,
            ),
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
class MafiaTabletVoteResultSequence extends StatelessWidget {
  const MafiaTabletVoteResultSequence({
    super.key,
    required this.result,
    required this.players,
    required this.executed,
    required this.executedRole,
  });

  final MafiaVoteResult? result;
  final Map<String, MafiaPlayer> players;
  final MafiaPlayer? executed;
  final MafiaRole? executedRole;

  /// 개표판을 보여 주는 시간입니다(확정: 4초).
  static const Duration tallyHold = Duration(milliseconds: 4000);

  /// 처형 발표(이름 4초 + 신분 공개 5초)를 보여 주는 시간입니다.
  static const Duration executionHold = Duration(milliseconds: 9000);

  /// 마지막에 '밤이 되었습니다'를 보여 주는 시간입니다.
  static const Duration nightNoticeHold = Duration(milliseconds: 2500);

  /// 개표부터 밤 안내까지 합한 전체 시간입니다.
  static Duration get totalHold => tallyHold + executionHold + nightNoticeHold;

  /// 이 결과로 실제로 보여 줄 시간입니다.
  ///
  /// 확정(2026-08): 이 처형으로 게임이 끝나면 **'밤이 되었습니다'를 건너뛰고
  /// 곧바로** 결과 화면으로 갑니다. 밤을 예고했다가 게임이 끝나면 흐름이
  /// 끊깁니다.
  static Duration holdOf(MafiaVoteResult? result) =>
      (result?.endsGame ?? false) ? tallyHold + executionHold : totalHold;

  @override
  Widget build(BuildContext context) {
    // 아침 발표와 같은 말투입니다 — 각 박자가 떠올랐다 물러납니다.
    return Stack(
      fit: StackFit.expand,
      children: [
        MafiaAnnouncementReveal(
          visibleFor: tallyHold,
          child: MafiaTabletTallyView(result: result, players: players),
        ),
        MafiaAnnouncementReveal(
          delay: tallyHold,
          visibleFor: executionHold,
          child: MafiaTabletExecutionView(
            executed: executed,
            executedRole: executedRole,
            isTie: result?.tie ?? false,
          ),
        ),
        // 확정(2026-08): 밤으로 가기 전에 안내를 띄우고 그 뒤에 배경이 바뀝니다.
        // 이 처형으로 게임이 끝나면 띄우지 않습니다.
        if (!(result?.endsGame ?? false))
          MafiaAnnouncementReveal(
            delay: tallyHold + executionHold,
            child: const MafiaTabletNotice.night(text: MafiaCopy.nightNotice),
          ),
      ],
    );
  }
}
