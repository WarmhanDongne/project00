import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================휴대폰 화면 공용 골격==============================
// 마피아 휴대폰 시안(P1~P9)은 전부 같은 골격 위에 내용만 바뀝니다.
//
//   배경 → (화면별 내용) → 하단 버튼(top 652) → 보관 카드(top 776)
//
// 그래서 좌표·버튼·보관 카드를 여기 한곳에 두고 각 화면은 가운데 내용만
// 만듭니다. 새 신분이나 새 단계 화면이 늘어도 이 파일만 공유하면 배치가
// 어긋나지 않습니다.
//
// 상단 우측 아이콘(룰·나가기)은 이 파일이 그리지 않습니다. `PhoneGameShell`이
// 모든 게임에 공통으로 얹기 때문에, 화면마다 그리면 두 번 겹칩니다.

/// 시안 좌표를 실제 화면 크기로 옮기는 기준값입니다.
///
/// 시안은 402 × 874(휴대폰 세로)로 그려졌습니다. 좌표를 픽셀로 박지 않고
/// 비율로 바꿔 어떤 기기에서도 같은 위치에 오게 합니다.
abstract final class MafiaPhoneDesign {
  static const Size size = Size(402, 874);

  /// 시안에서 좌우 여백을 뺀 본문 폭입니다. 버튼·보관 카드가 이 폭을 씁니다.
  static const double contentLeft = 58;
  static const double contentWidth = 286;

  static const double buttonTop = 652;
  static const double buttonHeight = 79.613;
  static const double buttonRadius = 20;

  static const double storedCardTop = 776;
  static const double storedCardAspectRatio = 286 / 419.39;

  //=======================내용 띠==============================
  // 상단 안내·타이머 아래부터 하단 버튼 위까지가 화면별 내용(그림·문구·격자)이
  // 놓이는 자리입니다. 확정(2026-08): 화면마다 내용이 이 띠 **가운데**에
  // 오도록 맞춥니다. 그러지 않으면 단계가 바뀔 때 내용이 위아래로 튑니다.
  static const double contentBandTop = 190;
  static const double contentBandBottom = 640;

  /// 내용 띠의 가운데입니다(시안 기준 좌표).
  static const double contentBandCenter =
      (contentBandTop + contentBandBottom) / 2;

  /// 시안의 top 값을 실제 높이에 맞춘 값으로 바꿉니다.
  static double top(Size actual, double designTop) =>
      actual.height * (designTop / size.height);

  /// 시안의 left 값을 실제 폭에 맞춘 값으로 바꿉니다.
  static double left(Size actual, double designLeft) =>
      actual.width * (designLeft / size.width);

  /// 시안 대비 확대 비율입니다. 글자 크기·테두리 두께에 곱합니다.
  static double scaleOf(Size actual) => actual.width / size.width;

  /// [LayoutBuilder]가 준 제약을 화면 크기로 정리합니다.
  ///
  /// 제약이 무한한 곳(스크롤 안 등)에 놓여도 시안 크기로 물러나 깨지지 않습니다.
  static Size resolve(BoxConstraints constraints) => Size(
    constraints.hasBoundedWidth ? constraints.maxWidth : size.width,
    constraints.hasBoundedHeight ? constraints.maxHeight : size.height,
  );
}

//=======================상태 문구 공통 좌표==============================
/// 화면 상단 상태 문구의 공통 자리·크기입니다(2026-08 통일 지시).
///
/// '제거할 대상을 선택하세요'(밤) · '투표 할 대상을 선택하세요'(투표) ·
/// '자유 토론'(낮) 등 단계 안내와 그 아래 남은 시간이 모두 이 값을 씁니다.
/// 화면마다 제각각이면 단계가 바뀔 때 글자가 튀어 보입니다.
abstract final class MafiaPhoneStatusText {
  /// 안내 문구 자리(시안 P2~P7의 top 102)와 크기입니다.
  static const double promptTop = 102;
  static const double promptFontSize = 24;

  /// 남은 시간 자리(시안 top 142)와 크기입니다.
  static const double timerTop = 142;
  static const double timerFontSize = 36;

  /// 제출 뒤 대기 문구 자리와 크기입니다.
  ///
  /// 확정(2026-08): 문구 묶음이 내용 띠([MafiaPhoneDesign.contentBandCenter])
  /// 가운데에 오게 내렸습니다(시안은 325·377이라 화면 위쪽으로 치우쳤습니다).
  static const double waitingTop = 377;
  static const double waitingFontSize = 24;
  static const double waitingSubTop = 429;
  static const double waitingSubFontSize = 20;

  /// 발표 한 줄만 있는 화면(아침·처형 없음)의 문구 자리입니다.
  ///
  /// 한 줄이라 띠 가운데에 그대로 맞춥니다.
  static const double announcementTop = 400;
}

//=======================격자 규격==============================
/// 플레이어를 격자로 늘어놓는 화면들의 공용 규격입니다.
///
/// 밤 지목(P2~P4) · 낮 투표(P7) · 관전자 명단(P8)이 모두 같은 격자를 씁니다.
///
/// 시안은 3열까지만 그려져 있습니다. 10인이 되면 3열로는 4행이 되어 격자가
/// 하단 버튼(top 652)을 덮으므로, **10인부터는 4열로 바꾸고 프로필·닉네임을
/// 줄입니다.** 두 규격 모두 좌우 여백이 52로 같아 화면 정렬이 흔들리지 않습니다.
///
/// 규격을 여기 한곳에 두었기 때문에, 인원이 늘어날 때 격자를 쓰는 화면들이
/// **동시에** 4열로 바뀝니다. 화면마다 따로 고칠 일이 없습니다.
@immutable
class MafiaTileGridSpec {
  const MafiaTileGridSpec({
    required this.columns,
    required this.tile,
    required this.step,
    required this.cellHeight,
    required this.nicknameFontSize,
    required this.cornerRadius,
  });

  final int columns;

  /// 프로필·카드 한 변의 길이입니다.
  final double tile;

  /// 열 간격입니다(타일 왼쪽 기준).
  final double step;

  /// 타일 + 닉네임까지 포함한 한 칸의 높이이자 행 간격입니다.
  final double cellHeight;

  final double nicknameFontSize;
  final double cornerRadius;

  /// 좌우 여백입니다. 두 규격이 같은 값을 씁니다.
  static const double firstLeft = 52;

  /// 타일과 닉네임 사이 간격입니다.
  static const double labelGap = 3;

  /// 4열로 바꾸는 인원입니다.
  static const int fourColumnFrom = 10;

  /// 시안 그대로의 3열 규격입니다(9인까지).
  ///
  /// 열 위치 52 · 158 · 264, 오른쪽 끝 350 → 좌우 여백 52.
  static const MafiaTileGridSpec threeColumn = MafiaTileGridSpec(
    columns: 3,
    tile: 86,
    step: 106,
    cellHeight: 116,
    nicknameFontSize: 20,
    cornerRadius: 10,
  );

  /// 10~12인용 4열 규격입니다.
  ///
  /// 열 위치 52 · 130 · 208 · 286, 오른쪽 끝 350 → 3열과 같은 여백 52.
  /// 타일 86 → 64, 닉네임 20 → 15로 같은 비율로 줄였습니다.
  static const MafiaTileGridSpec fourColumn = MafiaTileGridSpec(
    columns: 4,
    tile: 64,
    step: 78,
    cellHeight: 88,
    nicknameFontSize: 15,
    cornerRadius: 7,
  );

  static MafiaTileGridSpec of(int playerCount) =>
      playerCount >= fourColumnFrom ? fourColumn : threeColumn;

  int rowsFor(int playerCount) => (playerCount / columns).ceil();

  /// 격자가 차지하는 크기입니다.
  Size sizeFor(int playerCount) => Size(
    firstLeft * 2 + step * (columns - 1) + tile,
    cellHeight * rowsFor(playerCount),
  );

  /// 한 칸에서 타일 왼쪽 위 좌표입니다(격자 왼쪽 위 기준).
  Offset offsetOf(int index) => Offset(
    firstLeft + step * (index % columns),
    cellHeight * (index ~/ columns),
  );
}

/// 시안 하단의 넓은 버튼입니다.
///
/// '선택 완료'·'확인'·'토론 종료 하기'·'투표 완료'가 모두 같은 자리·모양이라
/// 하나로 씁니다. 비활성은 시안대로 40% 불투명입니다.
class MafiaPhoneActionButton extends StatelessWidget {
  const MafiaPhoneActionButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.enabled,
    this.top = MafiaPhoneDesign.buttonTop,
    this.colorlessWhenDisabled = false,
    this.labelColor,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  /// 비활성일 때 배경을 **무색**으로 그립니다(확정: 밤 행동 화면).
  ///
  /// 대상을 고르기 전에는 버튼이 없는 것처럼 보이고, 고르면 색이 생기며
  /// 활성됩니다. 기본값(false)은 기존처럼 40% 불투명입니다.
  final bool colorlessWhenDisabled;

  /// 글자 색을 덮어씁니다(예: 토론 조기 종료의 빨간 `n/m`).
  final Color? labelColor;

  /// 시안 기준 top입니다. 기본값은 공용 버튼 위치입니다.
  final double top;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);

        return Stack(
          children: [
            Positioned(
              left: MafiaPhoneDesign.left(size, MafiaPhoneDesign.contentLeft),
              top: MafiaPhoneDesign.top(size, top),
              width: MafiaPhoneDesign.contentWidth * scale,
              height: MafiaPhoneDesign.buttonHeight * scale,
              child: Semantics(
                button: true,
                enabled: enabled,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled ? onTap : null,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: enabled
                          ? const Color(0xFFECEBEB)
                          : colorlessWhenDisabled
                          ? Colors.transparent
                          : const Color(0x66ECEBEB),
                      borderRadius: BorderRadius.circular(
                        MafiaPhoneDesign.buttonRadius * scale,
                      ),
                      // 배경과 버튼이 구분되게 그림자를 깔습니다(확정 2026-08).
                      // 무색 상태(대상을 고르기 전)에는 버튼이 없는 것처럼
                      // 보여야 하므로 그림자도 두지 않습니다.
                      boxShadow: enabled || !colorlessWhenDisabled
                          ? [
                              BoxShadow(
                                color: const Color(0x73000000),
                                blurRadius: 10 * scale,
                                offset: Offset(0, 5 * scale),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color:
                              labelColor ??
                              (enabled
                                  ? const Color(0xFF212730)
                                  : colorlessWhenDisabled
                                  ? const Color(0x33ECEBEB)
                                  : const Color(0x66212730)),
                          fontSize: 32 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 화면 아래에 보관된 내 역할 카드입니다. 시안처럼 위쪽 일부만 보입니다.
///
/// 밤·낮 어느 화면에서든 내 신분을 다시 확인할 수 있게 남겨 둡니다. 카드
/// 에셋이 아직 없는 역할은 뒷면으로 대신 그리므로 게임이 깨지지 않습니다.
//=======================셸이 맡는 공통 요소==============================
/// 배경과 보관 카드를 **셸(휴대폰 진행 화면)이 계속 그리는 중**임을 알리는
/// 표시입니다.
///
/// 확정(2026-08): 단계가 바뀔 때 화면 전체가 새로 그려지는 느낌을 없애려면,
/// 단계와 무관하게 그대로 있는 요소(배경·내 신분 카드)는 전환 **밖**에
/// 있어야 합니다. 그래서 셸이 그것들을 직접 그리고, 이 표시가 있는 동안
/// 각 단계 화면은 자기 배경·보관 카드를 그리지 않습니다.
///
/// 이 표시가 없으면(위젯 테스트처럼 화면 하나만 띄울 때) 화면들이 예전처럼
/// 자기 배경과 카드를 그립니다.
class MafiaPhoneShellChrome extends InheritedWidget {
  const MafiaPhoneShellChrome({super.key, required super.child});

  /// 셸이 배경·보관 카드를 맡고 있는지입니다.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MafiaPhoneShellChrome>() !=
      null;

  @override
  bool updateShouldNotify(MafiaPhoneShellChrome oldWidget) => false;
}

class MafiaStoredRoleCard extends StatelessWidget {
  const MafiaStoredRoleCard({super.key, required this.role});

  final MafiaRole? role;

  @override
  Widget build(BuildContext context) {
    // 셸이 카드를 계속 그리고 있으면 단계 화면은 그리지 않습니다.
    if (MafiaPhoneShellChrome.of(context)) return const SizedBox.shrink();
    final card = role?.card ?? Assets.games.mafia.images.cards.roleBack.game;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);

        return Stack(
          children: [
            Positioned(
              left: MafiaPhoneDesign.left(size, MafiaPhoneDesign.contentLeft),
              top: MafiaPhoneDesign.top(size, MafiaPhoneDesign.storedCardTop),
              width: MafiaPhoneDesign.contentWidth * scale,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      MafiaPhoneDesign.buttonRadius * scale,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4D000000),
                        blurRadius: 4,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      MafiaPhoneDesign.buttonRadius * scale,
                    ),
                    child: AspectRatio(
                      aspectRatio: MafiaPhoneDesign.storedCardAspectRatio,
                      child: card.image(
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 휴대폰 배경입니다. 밤/낮 두 가지를 씁니다. P1·P6이 낮, P2~P5가 밤입니다.
///
/// 시안은 배경을 화면보다 크게 잡고 왼쪽·위로 밀어 두었지만, 그 값을 그대로
/// 쓰면 기기 비율이 달라질 때 빈 곳이 생깁니다. [BoxFit.cover]로 채워 어떤
/// 비율에서도 여백이 없게 합니다.
class MafiaPhoneBackground extends StatelessWidget {
  const MafiaPhoneBackground({super.key, required this.isNight});

  const MafiaPhoneBackground.night({super.key}) : isNight = true;

  const MafiaPhoneBackground.day({super.key}) : isNight = false;

  final bool isNight;

  @override
  Widget build(BuildContext context) {
    // 셸이 배경을 계속 그리고 있으면 단계 화면은 그리지 않습니다. 그리면
    // 전환 도중 배경이 두 겹이 되어 한 번 어두워집니다.
    if (MafiaPhoneShellChrome.of(context)) return const SizedBox.shrink();
    final background = Assets.games.mafia.images.background;

    return ColoredBox(
      // 이미지가 뜨기 전 한 프레임 흰 화면이 번쩍이지 않게 깔아 둡니다.
      color: isNight ? const Color(0xFF10131A) : const Color(0xFFF2F2F2),
      child: isNight
          // 밤은 세로 에셋이 236 × 512로 해상도가 낮아 확대하면 뭉개집니다.
          // 태블릿용 고해상도 밤 배경을 90° 돌려 씁니다. 회전한 위젯은 스스로
          // 크기를 갖지 못하므로 FittedBox로 감싸 화면을 채웁니다.
          ? FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: RotatedBox(
                quarterTurns: 1,
                child: background.backgroundNight.game.image(
                  filterQuality: FilterQuality.high,
                ),
              ),
            )
          // 낮은 세로 전용 에셋(941 × 1672)이 있어 그대로 채웁니다.
          : background.backgroundMorningPhone.game.image(
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
    );
  }
}
