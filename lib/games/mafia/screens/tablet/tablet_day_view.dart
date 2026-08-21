import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/animations/ballot_animations.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/gen/fonts.gen.dart';

//=======================태블릿 낮 화면==============================
/// 낮 토론과 투표 시간을 그립니다(시안 `tablet-p6 자유토론`·`tablet-p7 투표 시간`).
///
/// 두 화면은 **가운데가 같습니다.** 확정(2026-08): 토론에서 투표로 넘어갈 때
/// 삽화는 **크기를 그대로 유지**하고, 삽화 가운데에서 투표함이 부드럽게
/// 떠오르며 큰 타이머가 사라집니다. 그래서 한 위젯으로 두고 [showBallotBox]로
/// 갈라 씁니다. 삽화가 다시 그려지지 않도록 두 단계는 화면 전환에서 같은
/// 것으로 취급합니다(`tablet_game_stage.dart`).
///
/// 시안에는 태블릿에 남은 시간 표시가 없습니다. 타이머는 휴대폰에만 있습니다.
class MafiaTabletDayView extends StatelessWidget {
  const MafiaTabletDayView({
    super.key,
    required this.showBallotBox,
    this.remainingSeconds,
    this.voteSubmittedUids = const [],
    this.seatIndexes = const {},
    this.boardSeatCount = 1,
  });

  /// 투표 시간이면 true입니다. 삽화가 작아지고 투표함이 나옵니다.
  final bool showBallotBox;

  /// 남은 시간(초)입니다. null이면 타이머를 그리지 않습니다.
  final int? remainingSeconds;

  /// 투표를 마친 사람들입니다. 늘어날 때마다 그 좌석에서 투표지가 날아갑니다.
  final List<String> voteSubmittedUids;

  /// `uid → 좌석 번호`입니다. 투표지가 어느 자리에서 출발할지 정합니다.
  final Map<String, int> seatIndexes;

  /// 방의 전체 좌석 수입니다. 좌석 방향 계산 기준입니다.
  final int boardSeatCount;

  //=======================시안 기준 좌표==============================
  /// 토론 화면의 큰 삽화입니다(시안 `tablet-T4 자유토론`).
  static const Rect _talkLarge = Rect.fromLTWH(126, 0, 943, 943);

  /// 토론 타이머입니다. 시안은 96px 흰색 숫자입니다.
  static const Rect _timer = Rect.fromLTWH(405, 325, 384, 124);

  /// 투표 화면의 투표함입니다. 개표에서 이 자리에서 이동하기 시작하므로
  /// 좌표는 [MafiaBallotBoxRects]에 함께 둡니다.
  static const Rect _ballotBox = MafiaBallotBoxRects.voting;

  /// 투표함이 떠오르고 타이머가 사라지는 시간입니다.
  static const Duration _crossFade = Duration(milliseconds: 520);

  /// 시안 표기법입니다. `02:30`처럼 분·초를 두 자리로 씁니다.
  static String formatTabletTimer(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = (safe ~/ 60).toString().padLeft(2, '0');
    final rest = (safe % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    final other = Assets.games.mafia.images.other;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 삽화는 토론·투표에서 **같은 크기 그대로** 있습니다.
        MafiaTabletBox(
          rect: _talkLarge,
          child: other.talkTablet.game.image(
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        // 큰 타이머는 토론에만 있습니다. 투표로 넘어가면 서서히 사라집니다.
        MafiaTabletBox(
          rect: _timer,
          child: AnimatedOpacity(
            opacity: showBallotBox ? 0 : 1,
            duration: _crossFade,
            curve: Curves.easeOut,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                remainingSeconds == null
                    ? ''
                    : formatTabletTimer(remainingSeconds!),
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 96,
                  // 시안은 7세그먼트 숫자 글꼴입니다. 다른 게임의 턴 타이머와
                  // 같은 글꼴을 씁니다.
                  fontFamily: FontFamily.digitalTimer,
                ),
              ),
            ),
          ),
        ),
        // 투표함은 삽화 가운데에서 살짝 커지며 떠오릅니다.
        MafiaTabletBox(
          rect: _ballotBox,
          child: AnimatedOpacity(
            opacity: showBallotBox ? 1 : 0,
            duration: _crossFade,
            curve: Curves.easeOut,
            child: AnimatedScale(
              scale: showBallotBox ? 1 : 0.8,
              duration: _crossFade,
              curve: Curves.easeOutBack,
              child: other.voteBox.game.image(
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        // 확정(2026-08): 누군가 투표하면 그 좌석에서 투표지가 날아와
        // 투표함에 들어가며 사라집니다.
        if (showBallotBox)
          MafiaBallotTossLayer(
            submittedUids: voteSubmittedUids,
            seatIndexes: seatIndexes,
            boardSeatCount: boardSeatCount,
          ),
      ],
    );
  }
}
