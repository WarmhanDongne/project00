import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/platform/home/room/models/room_character.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================플레이어 선택 그리드==============================
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
    this.selectionColor = const Color(0xFFFF0000),
    this.selectionBorderWidth = 4,
    this.nicknameColor = Colors.white,
    this.dimsUnselected = false,
    this.enabled = true,
    this.selectsDead = false,
  });

  final List<MafiaPlayer> players;

  /// 내가 고른 대상입니다.
  final String? selectedUid;

  /// 동료가 고른 대상입니다(마피아끼리 서로의 선택을 봅니다).
  ///
  /// 내 선택보다 얇은 테두리로 구분해, 누가 골랐는지 헷갈리지 않게 합니다.
  final Set<String> allySelectedUids;

  /// 선택 테두리 색입니다.
  ///
  /// 밤에는 행동의 의미색(제거 빨강·치료 초록·조사 하늘), 낮 투표는 시안의
  /// 금색 `#B18D56`을 씁니다.
  final Color selectionColor;

  /// 내 선택 테두리 두께입니다. 밤은 4, 낮 투표 시안은 3입니다.
  final double selectionBorderWidth;

  /// 닉네임 색입니다. 밤은 흰색, 낮(투표·관전)은 배경이 밝아 검은색입니다.
  final Color nicknameColor;

  /// 고르고 나면 나머지를 흐리게 할지입니다.
  ///
  /// 낮 투표 시안은 대상을 고르면 **나머지 8명이 40%로 흐려집니다.** 밤 화면은
  /// 흐리지 않고 테두리만 씁니다. 아직 아무도 고르지 않았으면 흐리지 않습니다.
  final bool dimsUnselected;

  final ValueChanged<String>? onSelect;
  final bool enabled;

  /// 고를 대상이 **사망자**인지입니다(영매의 교신, 도둑의 절도).
  ///
  /// 기본값에서는 죽은 사람을 누를 수 없습니다 — 밤 지목·낮 투표의 대상은 늘
  /// 살아 있는 사람이니까요. 영매·도둑은 그 반대라, 이 값이 없어서 **명단이
  /// 보이는데도 아무도 고를 수 없었습니다**(2026-08).
  final bool selectsDead;

  /// 시안의 흐린 상태 불투명도입니다.
  static const double _dimmedOpacity = 0.4;

  /// 사망자 불투명도입니다. 선택 대상이 아님을 보여줍니다.
  static const double _deadOpacity = 0.35;

  //=======================시안 기준 좌표==============================
  static const Size _designSize = Size(402, 874);
  static const double _firstTop = 226;

  /// 이 인원에서 쓰는 열 수입니다.
  static int columnsFor(int playerCount) =>
      MafiaTileGridSpec.of(playerCount).columns;

  /// 그리드가 차지하는 전체 크기입니다. 부모가 배치에 사용합니다.
  static Size gridSize(int playerCount) =>
      MafiaTileGridSpec.of(playerCount).sizeFor(playerCount);

  /// 시안에서 그리드가 시작하는 top 값입니다.
  static double get designTop => _firstTop;

  /// [playerCount]명일 때 격자가 놓일 top입니다(시안 기준 좌표).
  ///
  /// 확정(2026-08): 인원이 적으면 격자가 짧아 시안 자리(226)에 두면 화면
  /// 위쪽으로 치우칩니다. 그래서 내용 띠 **가운데**에 맞춥니다. 인원이 많아
  /// 격자가 길어지면 띠 위쪽까지만 올라갑니다.
  static double topFor(int playerCount) {
    final spec = MafiaTileGridSpec.of(playerCount);
    final height = spec.cellHeight * spec.rowsFor(playerCount);
    final centered = MafiaPhoneDesign.contentBandCenter - height / 2;
    return centered < MafiaPhoneDesign.contentBandTop
        ? MafiaPhoneDesign.contentBandTop
        : centered;
  }

  /// 시안 기준으로 그리드가 끝나는 top 값입니다.
  ///
  /// 하단 버튼(top 652)을 덮지 않아야 합니다.
  /// `test/mafia_player_select_grid_test.dart`가 이 조건을 지킵니다.
  static double designBottom(int playerCount) =>
      _firstTop + gridSize(playerCount).height;

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
                  left:
                      (MafiaTileGridSpec.firstLeft +
                          spec.step * (index % spec.columns)) *
                      scale,
                  top: (spec.cellHeight * (index ~/ spec.columns)) * scale,
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
    required double left,
    required double top,
    required double scale,
  }) {
    final isMine = selectedUid == player.uid;
    final isAlly = allySelectedUids.contains(player.uid);
    // 내 선택은 굵게, 동료 선택은 한 단계 얇게 그려 서로 구분합니다. 타일이
    // 작아지는 4열에서도 선택 표시가 묻히지 않게 두께는 줄이지 않습니다.
    final borderWidth = isMine
        ? selectionBorderWidth
        : (isAlly ? selectionBorderWidth - 1 : 0.0);
    // 고를 수 있는 상태는 대상 범위와 함께 봅니다. 영매·도둑은 사망자를
    // 고르므로 살아 있는 사람이 눌리지 않습니다.
    final isTargetable = selectsDead ? !player.isAlive : player.isAlive;
    final canTap = enabled && isTargetable && onSelect != null;
    final tile = spec.tile * scale;
    final radius = BorderRadius.circular(spec.cornerRadius * scale);

    // 고른 뒤에는 시안대로 나머지를 흐립니다. **고를 수 없는 사람**은 그보다
    // 더 어둡습니다(평소에는 사망자, 영매·도둑의 밤에는 살아 있는 사람).
    final isDimmed = dimsUnselected && selectedUid != null && !isMine;
    final opacity = !isTargetable
        ? _deadOpacity
        : (isDimmed ? _dimmedOpacity : 1.0);

    return Positioned(
      left: left,
      top: top,
      width: tile,
      height: spec.cellHeight * scale,
      child: Semantics(
        button: canTap,
        selected: isMine,
        label: player.nickname,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canTap ? () => onSelect!(player.uid) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // DecoratedBox가 아니라 Container를 씁니다. DecoratedBox는 테두리를
              // 자식 **뒤에** 그려서 프로필 사진이 테두리를 덮어 선택 표시가
              // 보이지 않습니다. Container는 테두리 두께만큼 자식을 안으로
              // 밀어 넣어 시안(CSS border)과 같은 결과가 됩니다.
              Container(
                width: tile,
                height: tile,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: borderWidth > 0
                      ? Border.all(
                          color: selectionColor,
                          width: borderWidth * scale,
                        )
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Opacity(
                    opacity: opacity,
                    child: MafiaProfileImage(
                      url: player.profileImageUrl,
                      characterId: player.characterId,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 3 * scale),
              Text(
                player.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  // 흐린 칸은 닉네임도 같이 흐립니다.
                  color: nicknameColor.withValues(alpha: opacity),
                  fontSize: spec.nicknameFontSize * scale,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 프로필 사진입니다. URL이 없거나 실패하면 기본 이미지로 대체합니다.
class MafiaProfileImage extends StatelessWidget {
  const MafiaProfileImage({super.key, required this.url, this.characterId});

  final String url;

  /// 로비에서 고른 동물 아이콘 id입니다.
  ///
  /// 사진을 올리지 않은 사람은 이 아이콘으로 보입니다. 이 값을 넘기지 않아
  /// 마피아 화면에서만 카드 뒷면이 나왔습니다(2026-08).
  final String? characterId;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return _buildFallback();

    return Image.network(
      url,
      fit: BoxFit.cover,
      // 프로필 서버가 느리거나 실패해도 게임 진행을 막지 않습니다.
      errorBuilder: (_, _, _) => _buildFallback(),
      gaplessPlayback: true,
    );
  }

  /// 사진이 없을 때 그릴 그림입니다. 로비에서 고른 동물이 있으면 그것을,
  /// 없으면 카드 뒷면을 씁니다.
  Widget _buildFallback() {
    final id = characterId?.trim() ?? '';
    if (id.isNotEmpty) {
      return Image.asset(
        roomCharacterAssetPath(id),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildCardBack(),
      );
    }
    return _buildCardBack();
  }

  Widget _buildCardBack() =>
      Assets.games.mafia.images.cards.roleBack.game.image(fit: BoxFit.cover);
}
