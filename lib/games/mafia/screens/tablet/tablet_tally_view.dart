import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/games/mafia/widgets/phone/player_select_grid.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================태블릿 개표 화면==============================
/// 표를 세는 화면입니다(시안 `tablet-p7 개표`).
///
/// 시안은 흰 개표판과 투표함, 그리고 아래쪽 프로필 네 칸만 그려져 있고 문구가
/// 없습니다. 득표 숫자를 어떻게 보여 줄지는 시안에 없어, **표를 받은 사람만
/// 왼쪽부터 늘어놓고 득표수를 프로필 아래에 적습니다.**
///
/// 비밀 투표라 **누가 찍었는지는 절대 보여 주지 않습니다.** 서버도 보내지 않습니다.
class MafiaTabletTallyView extends StatelessWidget {
  const MafiaTabletTallyView({
    super.key,
    required this.result,
    required this.players,
    this.onRulebookPressed,
    this.onSettingsPressed,
  });

  final MafiaVoteResult? result;
  final Map<String, MafiaPlayer> players;
  final VoidCallback? onRulebookPressed;
  final VoidCallback? onSettingsPressed;

  //=======================시안 기준 좌표==============================
  static const Rect _board = Rect.fromLTWH(37, 50, 822, 748);
  static const Rect _ballotBox = Rect.fromLTWH(886, 528, 277, 270);

  /// 프로필 한 칸입니다. 시안은 136 × 136, top 595, left 140부터 160 간격입니다.
  static const double _avatarTop = 595;
  static const double _avatarSize = 136;
  static const double _avatarFirstLeft = 140;
  static const double _avatarStep = 160;

  /// 시안 개표판 테두리 색입니다.
  static const Color _boardBorder = Color(0xFFAF7F3F);

  @override
  Widget build(BuildContext context) {
    final ranked = result?.ranked ?? const <({String uid, int count})>[];

    return Stack(
      fit: StackFit.expand,
      children: [
        MafiaTabletBox(
          rect: _board,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _boardBorder),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        MafiaTabletBox(
          rect: _ballotBox,
          child: Assets.games.mafia.images.other.voteBox.game.image(
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        // 표를 받은 사람만 왼쪽부터 늘어놓습니다. 시안의 네 칸을 넘으면 간격이
        // 그만큼 좁아지도록 폭을 나눠 씁니다.
        for (var index = 0; index < ranked.length; index += 1)
          _buildTallyEntry(ranked[index], index, ranked.length),
        MafiaTabletChrome(
          onRulebookPressed: onRulebookPressed,
          onSettingsPressed: onSettingsPressed,
        ),
      ],
    );
  }

  Widget _buildTallyEntry(
    ({String uid, int count}) entry,
    int index,
    int total,
  ) {
    final player = players[entry.uid];
    // 시안은 네 칸 기준입니다. 그보다 많으면 같은 폭 안에서 간격만 줄입니다.
    final step = total <= 4
        ? _avatarStep
        : (_avatarStep * 3 + _avatarSize) / (total - 1);
    final left = _avatarFirstLeft + step * index;

    return MafiaTabletBox(
      rect: Rect.fromLTWH(left, _avatarTop, _avatarSize, _avatarSize + 46),
      child: Column(
        children: [
          SizedBox(
            width: _avatarSize,
            height: _avatarSize,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: MafiaProfileImage(url: player?.profileImageUrl ?? ''),
            ),
          ),
          const SizedBox(height: 4),
          // 득표수입니다. 누가 찍었는지는 담지 않습니다.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${entry.count}표',
              maxLines: 1,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
