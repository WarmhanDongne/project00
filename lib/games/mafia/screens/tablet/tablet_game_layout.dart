import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================태블릿 화면 공용 골격==============================
// 태블릿 시안은 모두 가로 1194 × 834이고, 아래 네 가지를 공유합니다.
//
//   종이/밤 배경 → 해(sun) → 룰북 아이콘 → 설정 아이콘 → (단계별 내용)
//
// ⚠️ 시안의 자식은 Figma에서 −90° 회전 상태로 적혀 있습니다. 여기 적은 값은
// **이미 가로로 변환된 좌표**입니다. Flutter에서는 회전하지 않고 그대로 놓습니다.
// 변환 규칙은 `lib/games/mafia/README.md`에 있습니다.

/// 시안 좌표를 실제 화면 크기로 옮기는 기준값입니다.
abstract final class MafiaTabletDesign {
  static const Size size = Size(1194, 834);

  /// 가로 중앙입니다. 시안의 중앙 정렬 요소가 모두 이 값에 옵니다.
  static const double centerX = 597;

  //=======================모든 단계가 공유하는 요소==============================
  static const Rect sun = Rect.fromLTWH(196, 18, 802, 802);
  static const Rect settingIcon = Rect.fromLTWH(1048, 18, 123, 123);
  static const Rect rulebookIcon = Rect.fromLTWH(886, 31, 149, 98);

  /// 시안의 top 값을 실제 높이에 맞춘 값으로 바꿉니다.
  static double top(Size actual, double designTop) =>
      actual.height * (designTop / size.height);

  /// 시안의 left 값을 실제 폭에 맞춘 값으로 바꿉니다.
  static double left(Size actual, double designLeft) =>
      actual.width * (designLeft / size.width);

  /// 시안 대비 확대 비율입니다. 글자·테두리에 곱합니다.
  ///
  /// 가로·세로 중 작은 쪽을 씁니다. 기기 비율이 시안과 달라도 요소가 화면 밖으로
  /// 나가지 않습니다.
  static double scaleOf(Size actual) =>
      actual.width / size.width < actual.height / size.height
      ? actual.width / size.width
      : actual.height / size.height;

  static Size resolve(BoxConstraints constraints) => Size(
    constraints.hasBoundedWidth ? constraints.maxWidth : size.width,
    constraints.hasBoundedHeight ? constraints.maxHeight : size.height,
  );
}

/// 시안 사각형을 그 자리에 놓습니다.
///
/// 태블릿 시안은 좌표가 촘촘해서 `Positioned`를 매번 쓰면 값이 흩어집니다.
/// 시안 사각형을 그대로 넘기면 되게 묶어 둡니다.
class MafiaTabletBox extends StatelessWidget {
  const MafiaTabletBox({
    super.key,
    required this.rect,
    required this.child,
    this.ignorePointer = true,
  });

  /// 시안(1194 × 834) 기준 사각형입니다.
  final Rect rect;
  final Widget child;
  final bool ignorePointer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaTabletDesign.resolve(constraints);
        final scale = MafiaTabletDesign.scaleOf(size);
        // 화면 비율이 시안과 다를 때 전체를 가운데로 모읍니다.
        final offsetX = (size.width - MafiaTabletDesign.size.width * scale) / 2;
        final offsetY =
            (size.height - MafiaTabletDesign.size.height * scale) / 2;

        final content = SizedBox(
          width: rect.width * scale,
          height: rect.height * scale,
          child: child,
        );
        return Stack(
          children: [
            Positioned(
              left: offsetX + rect.left * scale,
              top: offsetY + rect.top * scale,
              child: ignorePointer ? IgnorePointer(child: content) : content,
            ),
          ],
        );
      },
    );
  }
}

/// 태블릿 배경입니다. 낮은 종이, 밤은 어두운 배경을 씁니다.
class MafiaTabletBackground extends StatelessWidget {
  const MafiaTabletBackground({super.key, required this.isNight});

  final bool isNight;

  @override
  Widget build(BuildContext context) {
    final background = Assets.games.mafia.images.background;
    final image = isNight
        ? background.backgroundNight.game
        : background.backgroundMorning.game;
    return ColoredBox(
      color: isNight ? const Color(0xFF10131A) : const Color(0xFFE9E9E9),
      child: image.image(fit: BoxFit.cover, filterQuality: FilterQuality.high),
    );
  }
}

/// 낮 화면 가운데의 햇살입니다. 시안에서 발표·투표 화면의 시선이 모이는 곳입니다.
class MafiaTabletSun extends StatelessWidget {
  const MafiaTabletSun({super.key});

  @override
  Widget build(BuildContext context) {
    return MafiaTabletBox(
      rect: MafiaTabletDesign.sun,
      child: Assets.games.mafia.images.other.sun.game.image(
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// 우상단 룰북·설정 아이콘입니다.
///
/// 시안에는 그림만 있고 동작이 정해져 있지 않습니다. 눌렀을 때 열 화면은
/// 호출부가 넘겨 줍니다.
class MafiaTabletChrome extends StatelessWidget {
  const MafiaTabletChrome({
    super.key,
    this.onRulebookPressed,
    this.onSettingsPressed,
  });

  final VoidCallback? onRulebookPressed;
  final VoidCallback? onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    final icons = Assets.games.mafia.images.icons;
    return Stack(
      children: [
        MafiaTabletBox(
          rect: MafiaTabletDesign.rulebookIcon,
          ignorePointer: false,
          child: _button(
            icons.roleIcon.game.image(fit: BoxFit.contain),
            onRulebookPressed,
            '룰북 열기',
          ),
        ),
        MafiaTabletBox(
          rect: MafiaTabletDesign.settingIcon,
          ignorePointer: false,
          child: _button(
            icons.settingIcon.game.image(fit: BoxFit.contain),
            onSettingsPressed,
            '설정 열기',
          ),
        ),
      ],
    );
  }

  Widget _button(Widget icon, VoidCallback? onPressed, String label) {
    return Semantics(
      button: onPressed != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: icon,
      ),
    );
  }
}

/// 태블릿의 큰 안내 문구입니다. 시안의 `탈락자 닉네임`(64px)이 기준입니다.
class MafiaTabletHeadline extends StatelessWidget {
  const MafiaTabletHeadline({
    super.key,
    required this.text,
    required this.top,
    this.fontSize = 64,
    this.color = Colors.black,
    this.fontWeight = FontWeight.w700,
  });

  final String text;

  /// 시안 기준 top입니다.
  final double top;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaTabletDesign.resolve(constraints);
        final scale = MafiaTabletDesign.scaleOf(size);
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: MafiaTabletDesign.top(size, top),
              child: IgnorePointer(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: fontSize * scale,
                      fontWeight: fontWeight,
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
