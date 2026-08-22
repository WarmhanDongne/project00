import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/gen/assets.gen.dart';

/// 관전자에게 공개된 플레이어 한 명입니다.
///
/// 신분은 **서버가 보낸 값을 그대로** 담습니다. 클라이언트가 다시 계산하면
/// 밀러·마피아 보스처럼 보이는 진영이 다른 역할에서 어긋납니다.
@immutable
class MafiaRevealedPlayer {
  const MafiaRevealedPlayer({required this.player, required this.role});

  final MafiaPlayer player;

  /// 공개된 신분입니다. 이 빌드가 모르는 신분이면 null입니다.
  final MafiaRole? role;
}

//=======================P8 관전자 정보==============================
/// 사망한 뒤 보는 관전 화면입니다. 시안 P8의 낮·밤 두 상태가 이 위젯 하나입니다.
///
/// 살아 있는 동안에는 볼 수 없던 **모든 플레이어의 신분**을 격자로 보여 줍니다.
/// 낮과 밤의 차이는 배경과 글자색뿐입니다.
///
/// 역할 이름으로 분기하지 않고 [MafiaRole]의 값만 읽으므로, 새 신분을 추가해도
/// 이 화면은 수정할 필요가 없습니다.
class MafiaSpectatorRosterView extends StatelessWidget {
  const MafiaSpectatorRosterView({
    super.key,
    required this.myRole,
    required this.revealed,
    required this.isNight,
    this.myUid,
    this.isFinished = false,
  });

  /// 내 역할입니다. 아래 보관 카드에만 씁니다.
  final MafiaRole? myRole;

  /// 공개된 플레이어 목록입니다. 호출부가 좌석 순서대로 전달합니다.
  final List<MafiaRevealedPlayer> revealed;

  /// 지금이 밤인지입니다. 배경과 글자색을 정합니다.
  final bool isNight;

  /// 내 uid입니다. 명단에서 **내 닉네임만 빨간색**으로 표시합니다.
  ///
  /// 사람이 많으면 격자에서 자기 자리를 찾기 어렵습니다.
  final String? myUid;

  /// 게임이 끝난 뒤인지입니다.
  ///
  /// 끝난 뒤에는 관전이 아니라 **결과를 보는 화면**입니다. 제목을 '신분 정보'로
  /// 바꾸고, '비밀로 유지하세요' 안내는 지웁니다(더 숨길 것이 없습니다).
  final bool isFinished;

  //=======================시안 기준 좌표==============================
  static const double _titleTop = 125;
  static const double _bodyTop = 158;
  static const double _bodyLeft = 55;

  /// 문구가 넘치지 않도록 남겨 두는 오른쪽 여백입니다(시안의 좌우 여백과 같음).
  static const double _rightMargin = MafiaTileGridSpec.firstLeft;

  /// 격자가 시작하는 top입니다. 밤 지목(226)보다 위에서 시작합니다.
  static const double gridTop = 203;

  static const String _guidance =
      '이제 모든 플레이어의 신분을 확인할 수 있습니다.\n'
      '확인한 정보는 게임이 끝날 때까지 비밀로 유지하세요.';

  /// 관전 중일 때의 제목입니다.
  static const String spectatingTitle = '관전자 정보';

  /// 게임이 끝난 뒤의 제목입니다.
  static const String finishedTitle = '신분 정보';

  /// 내 닉네임 색입니다.
  static const Color myNicknameColor = Color(0xFFFF0000);

  @override
  Widget build(BuildContext context) {
    final textColor = isNight ? Colors.white : Colors.black;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: MafiaPhoneBackground(isNight: isNight)),
            _buildLeftAlignedText(
              size,
              left: MafiaTileGridSpec.firstLeft,
              top: _titleTop,
              text: isFinished ? finishedTitle : spectatingTitle,
              style: TextStyle(
                color: textColor,
                fontSize: 24 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
            // 끝난 뒤에는 숨길 것이 없어 안내를 지웁니다.
            if (!isFinished)
              _buildLeftAlignedText(
                size,
                left: _bodyLeft,
                top: _bodyTop,
                text: _guidance,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w400,
                  height: 1.25,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: MafiaPhoneDesign.top(size, gridTop),
              child: _buildRoster(scale, textColor),
            ),
            MafiaStoredRoleCard(role: myRole),
          ],
        );
      },
    );
  }

  /// 왼쪽 정렬 문구입니다.
  ///
  /// 시안은 줄바꿈을 직접 넣은 고정 문구(nowrap)입니다. 폭을 열어 두면 글꼴이
  /// 넓은 기기에서 문구가 화면 밖으로 나가므로, 오른쪽 여백까지를 한계로 두고
  /// 넘칠 때만 줄여 담습니다.
  Widget _buildLeftAlignedText(
    Size size, {
    required double left,
    required double top,
    required String text,
    required TextStyle style,
  }) {
    // 시안의 좌우 여백(52)을 남기고 쓸 수 있는 폭입니다.
    final available = MafiaPhoneDesign.size.width - left - _rightMargin;

    return Positioned(
      left: MafiaPhoneDesign.left(size, left),
      top: MafiaPhoneDesign.top(size, top),
      width: MafiaPhoneDesign.left(size, available),
      child: IgnorePointer(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: Text(text, softWrap: false, style: style),
        ),
      ),
    );
  }

  Widget _buildRoster(double scale, Color textColor) {
    final spec = MafiaTileGridSpec.of(revealed.length);
    final rows = spec.rowsFor(revealed.length);

    return SizedBox(
      height: spec.cellHeight * rows * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < revealed.length; index += 1)
            _buildTile(
              spec: spec,
              entry: revealed[index],
              offset: spec.offsetOf(index) * scale,
              scale: scale,
              textColor: textColor,
            ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required MafiaTileGridSpec spec,
    required MafiaRevealedPlayer entry,
    required Offset offset,
    required double scale,
    required Color textColor,
  }) {
    final tile = spec.tile * scale;
    final radius = BorderRadius.circular(spec.cornerRadius * scale);

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: tile,
      height: spec.cellHeight * scale,
      child: Semantics(
        label: '${entry.player.nickname} ${entry.role?.displayName ?? ''}',
        child: IgnorePointer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: tile,
                height: tile,
                child: ClipRRect(
                  borderRadius: radius,
                  child: _buildCard(entry.role, scale),
                ),
              ),
              SizedBox(height: MafiaTileGridSpec.labelGap * scale),
              Text(
                entry.player.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  // 격자에서 나를 바로 찾을 수 있게 내 이름만 빨간색입니다.
                  color: entry.player.uid == myUid
                      ? myNicknameColor
                      : textColor,
                  fontSize: spec.nicknameFontSize * scale,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 역할 카드입니다. 좋은 것부터 순서대로 씁니다.
  ///
  /// 1. [MafiaRole.squareCard] — 정사각형 전용 이미지. 있으면 그대로 채웁니다.
  /// 2. [MafiaRole.card] — 세로 카드를 시안대로 **위쪽 기준 가로 폭 맞춤**으로
  ///    넣습니다. 아래 1/3이 잘려 인쇄된 역할 이름이 사라지고 그림만 보입니다.
  /// 3. 둘 다 없으면 P1과 같은 방식으로 뒷면 + 역할 이름을 씁니다. 뒷면만 두면
  ///    어떤 신분인지 전혀 알 수 없어, 이 화면의 목적(모든 신분 확인)이
  ///    무너지기 때문입니다.
  ///
  /// 정사각형 이미지를 받으면 `mafia_roles.dart`에 `squareCard:` 한 줄만
  /// 추가하면 됩니다. 이 화면은 고치지 않습니다.
  Widget _buildCard(MafiaRole? role, double scale) {
    final square = role?.squareCard;
    if (square != null) {
      return square.image(fit: BoxFit.cover, filterQuality: FilterQuality.high);
    }

    final card = role?.card;
    if (card != null) {
      return card.image(
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.high,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Assets.games.mafia.images.cards.roleBack.game.image(
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
        if (role != null)
          Center(
            child: Padding(
              padding: EdgeInsets.all(4 * scale),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  role.displayName,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: role.accentColor,
                    fontSize: 20 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
