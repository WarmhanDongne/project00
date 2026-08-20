import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/gen/fonts.gen.dart';

//=======================태블릿 낮 화면==============================
/// 낮 토론과 투표 시간을 그립니다(시안 `tablet-p6 자유토론`·`tablet-p7 투표 시간`).
///
/// 두 화면은 **가운데 그림만 다릅니다.** 토론은 큰 삽화, 투표는 작은 삽화 +
/// 투표함입니다. 그래서 한 위젯으로 두고 [showBallotBox]로 갈라 씁니다.
///
/// 시안에는 태블릿에 남은 시간 표시가 없습니다. 타이머는 휴대폰에만 있습니다.
class MafiaTabletDayView extends StatelessWidget {
  const MafiaTabletDayView({
    super.key,
    required this.showBallotBox,
    this.remainingSeconds,
    this.onRulebookPressed,
    this.onSettingsPressed,
  });

  /// 투표 시간이면 true입니다. 삽화가 작아지고 투표함이 나옵니다.
  final bool showBallotBox;

  /// 남은 시간(초)입니다. null이면 타이머를 그리지 않습니다.
  final int? remainingSeconds;

  final VoidCallback? onRulebookPressed;
  final VoidCallback? onSettingsPressed;

  //=======================시안 기준 좌표==============================
  /// 토론 화면의 큰 삽화입니다(시안 `tablet-T4 자유토론`).
  static const Rect _talkLarge = Rect.fromLTWH(126, 0, 943, 943);

  /// 토론 타이머입니다. 시안은 96px 흰색 숫자입니다.
  static const Rect _timer = Rect.fromLTWH(405, 325, 384, 124);

  /// 투표 화면의 작은 삽화입니다(`tablet-p7 투표 시간`).
  static const Rect _talkSmall = Rect.fromLTWH(282, 126, 636, 636);

  /// 투표 화면의 투표함입니다.
  static const Rect _ballotBox = Rect.fromLTWH(544, 322, 124.44, 122);

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
        const MafiaTabletSun(),
        MafiaTabletBox(
          rect: showBallotBox ? _talkSmall : _talkLarge,
          child: other.talkTablet.game.image(
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        // 토론 화면에만 큰 타이머가 있습니다. 시안의 투표 화면에는 없습니다.
        if (!showBallotBox && remainingSeconds != null)
          MafiaTabletBox(
            rect: _timer,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                formatTabletTimer(remainingSeconds!),
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
        if (showBallotBox)
          MafiaTabletBox(
            rect: _ballotBox,
            child: other.voteBox.game.image(
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
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
