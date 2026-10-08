// [player_select_grid.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성함
//
// 즉, 플레이어 조작과 상태 표시를 화면별로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/widgets/noir.dart';
import 'package:game_mafia/phone/widgets/game_layout.dart';
import 'package:game_mafia/game_theme.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 플레이어 선택 그리드
// ---------------------------------------------------------------------------
/// 프로필을 눌러 대상 한 명을 고르는 격자입니다.
///
/// 밤 지목(P2~P4)과 낮 투표(P7)가 같은 배치를 쓰므로 여기 한곳에 둡니다.
/// 좌표는 시안(402 × 874)의 값을 비율로 바꿔 어떤 휴대폰에서도 같게 보입니다.
///
/// 열 수는 인원이 정합니다. 9인까지는 시안대로 3열, **10~12인은 4열**로 바꾸고
/// 프로필·닉네임을 줄입니다([MafiaTileGridSpec] 참고).
class MafiaPlayerSelectGrid extends StatelessWidget {
  const MafiaPlayerSelectGrid({
    super.key,
    required this.players,
    required this.selectedUid,
    required this.onSelect,
    this.allySelectedUids = const {},
    this.selectionColor = MafiaColors.noirScarlet,
    this.selectionBorderWidth = 3,
    this.idleBorderColor = MafiaColors.noirBrass,
    this.selectedBanner,
    this.allyCornerColor = MafiaColors.noirScarlet,
    this.dimsUnselected = false,
    this.enabled = true,
    this.selectsDead = false,
  });

  final List<MafiaPlayer> players;

  /// 내가 고른 대상입니다.
  final String? selectedUid;

  /// 동료가 고른 대상입니다(마피아끼리 서로의 선택을 봅니다).
  ///
  /// 시안: 카드 오른쪽 위 **빨간 모서리**로 표시합니다.
  final Set<String> allySelectedUids;

  /// 선택 테두리·빛 색입니다(제거 빨강·치료 청록·조사 회청·투표 놋쇠).
  final Color selectionColor;

  /// 내 선택 테두리 두께입니다. 밤은 3, 낮 투표는 4입니다.
  final double selectionBorderWidth;

  /// 고르지 않은 카드의 테두리 색입니다. 밤은 놋쇠, 낮(종이 바탕)은 먹색입니다.
  final Color idleBorderColor;

  /// 고른 카드에 비스듬히 두르는 띠입니다(표적·치료·지목).
  final MafiaNoirBannerSpec? selectedBanner;

  /// 동료가 고른 카드의 모서리 색입니다.
  final Color allyCornerColor;

  /// 고르고 나면 나머지를 흐리게 할지입니다(낮 투표).
  final bool dimsUnselected;

  final ValueChanged<String>? onSelect;
  final bool enabled;

  /// 고를 대상이 **사망자**인지입니다(영매의 교신, 도둑의 절도).
  ///
  /// 기본값에서는 죽은 사람을 누를 수 없습니다. 영매·도둑은 그 반대라, 이
  /// 값이 없어서 **명단이 보이는데도 아무도 고를 수 없었습니다**(2026-08).
  final bool selectsDead;

  /// 시안의 흐린 상태 불투명도입니다.
  static const double _dimmedOpacity = 0.4;

  /// 고를 수 없는 사람의 불투명도입니다.
  static const double _deadOpacity = 0.35;

  static const Size _designSize = Size(402, 874);

  /// 이 인원에서 쓰는 열 수입니다.
  static int columnsFor(int playerCount) =>
      MafiaTileGridSpec.of(playerCount).columns;

  /// 그리드가 차지하는 전체 크기입니다. 부모가 배치에 사용합니다.
  static Size gridSize(int playerCount) =>
      MafiaTileGridSpec.of(playerCount).sizeFor(playerCount);

  /// 시안에서 그리드가 시작하는 top 값입니다.
  static double get designTop => MafiaPhoneDesign.contentBandTop + 12;

  /// [playerCount]명일 때 격자가 놓일 top입니다(시안 기준 좌표).
  ///
  /// 시안처럼 타이머 바로 아래(226)에서 시작합니다. 인원이 적어 격자가 짧아도
  /// 위에 붙여 두어, 아래 안내 문구가 격자 바로 밑에 옵니다.
  static double topFor(int playerCount) => designTop;

  /// 시안 기준으로 그리드가 끝나는 top 값입니다. 하단 버튼을 덮지 않아야 합니다.
  static double designBottom(int playerCount) =>
      designTop + gridSize(playerCount).height;

  @override
  Widget build(BuildContext context) {
    final spec = MafiaTileGridSpec.of(players.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : _designSize.width;
        final scale = width / _designSize.width;
        final rows = spec.rowsFor(players.length);

        return SizedBox(
          width: width,
          height: spec.cellHeight * rows * scale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < players.length; index += 1)
                _buildTile(
                  spec: spec,
                  player: players[index],
                  offset: spec.offsetOf(index, players.length) * scale,
                  scale: scale,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTile({
    required MafiaTileGridSpec spec,
    required MafiaPlayer player,
    required Offset offset,
    required double scale,
  }) {
    final isMine = selectedUid == player.uid;
    final isAlly = allySelectedUids.contains(player.uid);
    // 고를 수 있는 상태는 대상 범위와 함께 봅니다. 영매·도둑은 사망자를
    // 고르므로 살아 있는 사람이 눌리지 않습니다.
    final isTargetable = selectsDead ? !player.isAlive : player.isAlive;
    final canTap = enabled && isTargetable && onSelect != null;

    // 고른 뒤에는 시안대로 나머지를 흐립니다. **고를 수 없는 사람**은 그보다
    // 더 어둡습니다(평소에는 사망자, 영매·도둑의 밤에는 살아 있는 사람).
    final isDimmed = dimsUnselected && selectedUid != null && !isMine;
    final opacity = !isTargetable
        ? _deadOpacity
        : (isDimmed ? _dimmedOpacity : 1.0);

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: spec.tile * scale,
      height: spec.tileHeight * scale,
      child: Semantics(
        button: canTap,
        selected: isMine,
        label: player.nickname,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canTap ? () => onSelect!(player.uid) : null,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: const Duration(milliseconds: 220),
            child: AnimatedScale(
              scale: isMine ? 1.04 : 1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: MafiaNoirPortraitCard(
                player: player,
                width: spec.tile * scale,
                height: spec.tileHeight * scale,
                borderColor: isMine ? selectionColor : idleBorderColor,
                borderWidth: isMine ? selectionBorderWidth : 2,
                circleColor: isMine
                    ? Color.lerp(selectionColor, MafiaColors.noirInk, 0.3)!
                    : MafiaColors.noirTeal,
                glowColor: isMine ? selectionColor : null,
                grayscale: !player.isAlive,
                nameSize: spec.nicknameFontSize * scale,
                cornerColor: isAlly && !isMine ? allyCornerColor : null,
                banner: isMine ? selectedBanner : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
