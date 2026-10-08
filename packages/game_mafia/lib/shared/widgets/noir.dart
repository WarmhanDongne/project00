// [noir.dart] 는 마피아 'Noir Poster' 시안의 공용 생김새를 모아 둔 파일이다.
//
// - [Package] : 마피아
// - [Widget] : 태블릿·휴대폰이 함께 쓰는 바탕, 인물 카드, 액자, 버튼, 띠를 구성함
//
// 즉, 두 기기의 모든 단계 화면이 같은 영화 포스터 말투로 보이게 하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_mafia/game_assets.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_kit/core/constants/room_character.dart';
import 'package:game_mafia/shared/widgets/profile_image.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 글자
// ---------------------------------------------------------------------------
/// 시안의 제목 글꼴(Black Han Sans)은 번들하지 않아 공용 본문 글꼴 굵게로
/// 대신합니다.
TextStyle mafiaNoirDisplay(
  double size, {
  Color color = MafiaColors.noirPaper,
  double? height = 1.1,
  double letterSpacing = 0,
  List<Shadow>? shadows,
}) => TextStyle(
  fontFamily: 'IBMPlexSansKR',
  package: 'game_kit',
  fontSize: size,
  fontWeight: FontWeight.w700,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
  shadows: shadows,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// 시안의 본문(Noto Sans KR)입니다.
TextStyle mafiaNoirBody(
  double size, {
  Color color = MafiaColors.noirDust,
  FontWeight weight = FontWeight.w400,
  double letterSpacing = 0,
  double? height = 1.5,
}) => TextStyle(
  fontFamily: 'IBMPlexSansKR',
  package: 'game_kit',
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

/// 남은 시간을 `2:30`처럼 적습니다.
String mafiaNoirClock(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  return '${safe ~/ 60}:${(safe % 60).toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// 얼굴 필터
// ---------------------------------------------------------------------------
/// 얼굴을 바랜 사진처럼(sepia 0.35 · saturate 0.7) 보이게 하는 색 행렬입니다.
const ColorFilter mafiaNoirSepia = ColorFilter.matrix(<double>[
  0.6299, 0.4006, 0.0782, 0, 0, //
  0.1641, 0.8352, 0.0730, 0, 0, //
  0.1452, 0.3430, 0.5190, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// 사망자·관전자의 흑백 얼굴입니다.
const ColorFilter mafiaNoirGrayscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// 플레이어 얼굴입니다. 살아 있으면 바랜 사진, 죽었으면 흑백입니다.
class MafiaNoirFace extends StatelessWidget {
  const MafiaNoirFace({
    super.key,
    required this.player,
    this.grayscale = false,
  });

  final MafiaPlayer player;
  final bool grayscale;

  @override
  Widget build(BuildContext context) {
    final id = player.characterId.trim();
    // 캐릭터 그림은 배경이 투명합니다. 카드 뒷면을 깔면 모서리가 검게 보여서,
    // 그림만 얹고 바탕(원·액자)은 부모가 그립니다.
    final face = id.isEmpty
        ? MafiaProfileImage(url: player.profileImageUrl)
        : Image.asset(
            roomCharacterAssetPath(id),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                MafiaProfileImage(url: player.profileImageUrl),
          );
    return ColorFiltered(
      colorFilter: grayscale ? mafiaNoirGrayscale : mafiaNoirSepia,
      child: face,
    );
  }
}

/// 네모 액자 속 작은 얼굴입니다(상단바·명단).
class MafiaNoirFaceTile extends StatelessWidget {
  const MafiaNoirFaceTile({
    super.key,
    required this.player,
    this.size = 46,
    this.borderColor = MafiaColors.noirInk,
    this.grayscale = false,
  });

  final MafiaPlayer player;
  final double size;
  final Color borderColor;
  final bool grayscale;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: MafiaColors.noirTeal,
      border: Border.all(color: borderColor, width: 2),
    ),
    child: MafiaNoirFace(player: player, grayscale: grayscale),
  );
}

// ---------------------------------------------------------------------------
// 바탕
// ---------------------------------------------------------------------------
/// 포스터 바탕의 방사형 줄무늬입니다.
///
/// 시안은 `repeating-conic-gradient`로 한 점에서 퍼지는 빛줄기를 깝니다.
/// 같은 각도(그린 4~5°, 빈 5~4°)로 부채꼴을 반복해 그립니다.
class MafiaNoirRays extends StatelessWidget {
  const MafiaNoirRays({
    super.key,
    required this.base,
    this.rayColor,
    this.origin = const Alignment(0, -0.5),
    this.rayDegrees = 5,
    this.periodDegrees = 10,
    this.child,
  });

  /// 밤 바탕입니다(먹색에 옅은 종이빛 줄기).
  const MafiaNoirRays.night({
    super.key,
    this.origin = const Alignment(0, -0.4),
    this.child,
  }) : base = MafiaColors.noirInk,
       rayColor = const Color(0x0BD9C2A2),
       rayDegrees = 5,
       periodDegrees = 10;

  /// 낮 바탕입니다(종이색에 옅은 먹빛 줄기).
  const MafiaNoirRays.day({
    super.key,
    this.origin = const Alignment(0, -1),
    this.child,
  }) : base = MafiaColors.noirPaper,
       rayColor = const Color(0x110B0E0D),
       rayDegrees = 4,
       periodDegrees = 9;

  /// 처형·승패 화면의 핏빛 줄기입니다.
  const MafiaNoirRays.blood({
    super.key,
    this.origin = const Alignment(0, -0.2),
    this.child,
  }) : base = MafiaColors.noirInk,
       rayColor = const Color(0x298E2A22),
       rayDegrees = 5,
       periodDegrees = 10;

  final Color base;
  final Color? rayColor;
  final Alignment origin;
  final double rayDegrees;
  final double periodDegrees;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: base,
    child: CustomPaint(
      painter: rayColor == null
          ? null
          : _RaysPainter(
              color: rayColor!,
              origin: origin,
              ray: rayDegrees,
              period: periodDegrees,
            ),
      child: child ?? const SizedBox.expand(),
    ),
  );
}

class _RaysPainter extends CustomPainter {
  const _RaysPainter({
    required this.color,
    required this.origin,
    required this.ray,
    required this.period,
  });

  final Color color;
  final Alignment origin;
  final double ray;
  final double period;

  @override
  void paint(Canvas canvas, Size size) {
    final center = origin.alongSize(size);
    final radius = size.longestSide * 2;
    final paint = Paint()..color = color;
    final path = Path();
    final rayRad = ray * math.pi / 180;
    for (var degrees = 0.0; degrees < 360; degrees += period) {
      final start = degrees * math.pi / 180 - math.pi / 2;
      path
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(start) * radius,
          center.dy + math.sin(start) * radius,
        )
        ..lineTo(
          center.dx + math.cos(start + rayRad) * radius,
          center.dy + math.sin(start + rayRad) * radius,
        )
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.origin != origin ||
      oldDelegate.ray != ray ||
      oldDelegate.period != period;
}

// ---------------------------------------------------------------------------
// 인물 카드
// ---------------------------------------------------------------------------
/// 비스듬히 잘린 검은 이름 띠입니다(포스터 아래쪽).
class _SlantClipper extends CustomClipper<Path> {
  const _SlantClipper(this.rise);

  /// 왼쪽 위 모서리가 내려오는 비율입니다(시안 30~36%).
  final double rise;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, size.height * rise)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_SlantClipper oldClipper) => oldClipper.rise != rise;
}

/// 사선으로 가로지르는 띠(표적·치료·처형·사망 등)입니다.
@immutable
class MafiaNoirBannerSpec {
  const MafiaNoirBannerSpec({
    required this.label,
    this.color = MafiaColors.noirBlood,
    this.textColor = MafiaColors.noirPaper,
    this.top = 0.47,
    this.angle = -20,
    this.letterSpacing = 0.2,
  });

  final String label;
  final Color color;
  final Color textColor;

  /// 카드 높이에 대한 띠 위치(0~1)입니다.
  final double top;

  /// 띠 기울기(도)입니다.
  final double angle;

  /// 글자 간격(em)입니다.
  final double letterSpacing;
}

/// 시안의 인물 카드(얼굴 + 원 + 사선 이름 띠)입니다.
///
/// 밤 지목·투표 격자, 태블릿 참가자 줄, 사망 포스터가 모두 이 위젯입니다.
/// 크기는 [width]만 받고 높이는 시안 비율(112 × 160)을 따릅니다.
class MafiaNoirPortraitCard extends StatelessWidget {
  const MafiaNoirPortraitCard({
    super.key,
    required this.player,
    required this.width,
    this.height,
    this.borderColor = MafiaColors.noirBrass,
    this.borderWidth = 2,
    this.circleColor = MafiaColors.noirTeal,
    this.banner,
    this.cornerColor,
    this.glowColor,
    this.grayscale = false,
    this.innerHairline = false,
    this.nameSize,
    this.coverImage,
  });

  final MafiaPlayer player;
  final double width;

  /// 생략하면 시안 비율(112:160)입니다.
  final double? height;
  final Color borderColor;
  final double borderWidth;
  final Color circleColor;
  final MafiaNoirBannerSpec? banner;

  /// 오른쪽 위 삼각 표식 색입니다(동료가 고른 사람).
  final Color? cornerColor;

  /// 선택된 카드 둘레의 번짐 빛입니다.
  final Color? glowColor;
  final bool grayscale;

  /// 태블릿 카드처럼 안쪽에 가는 놋쇠 선을 한 번 더 두릅니다.
  final bool innerHairline;
  final double? nameSize;

  /// 얼굴 대신 깔 그림입니다(신분이 공개된 사망자의 직업 카드).
  final GameImage? coverImage;

  static const double aspect = 160 / 112;

  @override
  Widget build(BuildContext context) {
    final h = height ?? width * aspect;
    final unit = width / 112;
    final cover = coverImage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: MafiaColors.noirSlab,
        borderRadius: BorderRadius.circular(6 * unit),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.45),
              blurRadius: 24 * unit,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(math.max(0, 6 * unit - 2)),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            if (cover != null)
              ColorFiltered(
                colorFilter: mafiaNoirGrayscale,
                child: cover.image(fit: BoxFit.cover),
              )
            else ...[
              Positioned(
                left: width * 0.14,
                top: h * 0.08,
                width: width * 0.68,
                height: width * 0.68,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: width * 0.12,
                top: h * 0.065,
                width: width * 0.72,
                height: width * 0.72,
                child: MafiaNoirFace(player: player, grayscale: grayscale),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: h * 0.36,
                child: ClipPath(
                  clipper: const _SlantClipper(0.34),
                  child: ColoredBox(
                    color: MafiaColors.noirInk,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          4 * unit,
                          0,
                          4 * unit,
                          8 * unit,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            player.nickname,
                            maxLines: 1,
                            style: mafiaNoirDisplay(
                              nameSize ?? 22 * unit,
                              color: grayscale
                                  ? MafiaColors.noirDust
                                  : MafiaColors.noirPaper,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (innerHairline)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(4 * unit),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3 * unit),
                      border: Border.all(
                        color: MafiaColors.noirBrass.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            if (cornerColor != null)
              Positioned(
                right: 0,
                top: 0,
                width: 44 * unit,
                height: 44 * unit,
                child: CustomPaint(painter: _CornerPainter(cornerColor!)),
              ),
            if (banner != null)
              MafiaNoirBanner(spec: banner!, cardWidth: width, cardHeight: h),
          ],
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) => oldDelegate.color != color;
}

/// 카드를 사선으로 가로지르는 띠입니다. 카드 밖으로 넘치는 부분은 잘립니다.
class MafiaNoirBanner extends StatelessWidget {
  const MafiaNoirBanner({
    super.key,
    required this.spec,
    required this.cardWidth,
    required this.cardHeight,
  });

  final MafiaNoirBannerSpec spec;
  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    final fontSize = math.max(10.0, cardWidth * 0.13);
    return Positioned(
      left: -cardWidth * 0.2,
      right: -cardWidth * 0.2,
      top: cardHeight * spec.top,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(spec.label),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutBack,
        builder: (context, value, child) => Transform.rotate(
          angle: spec.angle * math.pi / 180,
          child: Transform.scale(scaleX: value, child: child),
        ),
        child: Container(
          color: spec.color,
          padding: EdgeInsets.symmetric(vertical: fontSize * 0.12),
          alignment: Alignment.center,
          child: Text(
            spec.label,
            maxLines: 1,
            style: mafiaNoirDisplay(
              fontSize,
              color: spec.textColor,
              letterSpacing: fontSize * spec.letterSpacing,
            ),
          ),
        ),
      ),
    );
  }
}

/// 큰 인물 포스터입니다(아침 사망·처형 대상·조사 결과).
///
/// 인물 카드와 같은 말투지만 크고, 액자 안쪽 선과 진한 그림자가 붙습니다.
class MafiaNoirPoster extends StatelessWidget {
  const MafiaNoirPoster({
    super.key,
    required this.player,
    required this.width,
    required this.height,
    this.banner,
    this.borderColor = MafiaColors.noirInk,
    this.circleColor = MafiaColors.noirTeal,
    this.grayscale = true,
    this.subtitle,
    this.glowColor,
  });

  final MafiaPlayer player;
  final double width;
  final double height;
  final MafiaNoirBannerSpec? banner;
  final Color borderColor;
  final Color circleColor;
  final bool grayscale;

  /// 이름 아래 작은 줄입니다(예: `3표 · 처형 확정`).
  final String? subtitle;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final unit = width / 320;
    final subtitle = this.subtitle;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: MafiaColors.noirSlab,
        borderRadius: BorderRadius.circular(8 * unit),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: (glowColor ?? MafiaColors.noirInk).withValues(
              alpha: glowColor == null ? 0.35 : 0.4,
            ),
            blurRadius: 50 * unit,
            offset: Offset(0, glowColor == null ? 24 * unit : 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6 * unit),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(7 * unit),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4 * unit),
                    border: Border.all(
                      color: MafiaColors.noirBrass.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: width * 0.156,
              top: height * 0.09,
              width: width * 0.688,
              height: width * 0.688,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: width * 0.125,
              top: height * 0.07,
              width: width * 0.75,
              height: width * 0.75,
              child: MafiaNoirFace(player: player, grayscale: grayscale),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: height * 0.42,
              child: ClipPath(
                clipper: const _SlantClipper(0.3),
                child: ColoredBox(
                  color: MafiaColors.noirInk,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        12 * unit,
                        0,
                        12 * unit,
                        28 * unit,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              player.nickname,
                              maxLines: 1,
                              style: mafiaNoirDisplay(60 * unit, height: 1),
                            ),
                          ),
                          if (subtitle != null) ...[
                            SizedBox(height: 6 * unit),
                            Text(
                              subtitle,
                              style: mafiaNoirBody(
                                16 * unit,
                                color: MafiaColors.noirBrass,
                                letterSpacing: 3 * unit,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (banner != null)
              MafiaNoirBanner(
                spec: banner!,
                cardWidth: width,
                cardHeight: height,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 액자·버튼
// ---------------------------------------------------------------------------
/// 검은 바탕에 놋쇠 테두리와 안쪽 가는 선을 두른 상자입니다(타이머·투표함).
class MafiaNoirFrame extends StatelessWidget {
  const MafiaNoirFrame({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderWidth = 3,
    this.inset = 8,
    this.color = MafiaColors.noirInk,
    this.padding,
  });

  final Widget child;
  final double? width;
  final double? height;
  final double borderWidth;
  final double inset;
  final Color color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: MafiaColors.noirBrass, width: borderWidth),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(inset - borderWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: MafiaColors.noirBrass.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: Center(child: child),
          ),
        ),
      ],
    ),
  );
}

/// 시안의 큰 버튼입니다. 면 바깥으로 4px 띄운 테두리 선을 한 번 더 두릅니다.
class MafiaNoirButton extends StatefulWidget {
  const MafiaNoirButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = MafiaColors.noirPaper,
    this.textColor = MafiaColors.noirInk,
    this.outlineColor = MafiaColors.noirBrass,
    this.trailing,
    this.fontSize = 22,
    this.letterSpacing = 0.1,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;
  final Color outlineColor;

  /// 글자 뒤에 붙는 놋쇠색 보조 글자입니다(예: `2 / 5`).
  final String? trailing;
  final double fontSize;
  final double letterSpacing;

  @override
  State<MafiaNoirButton> createState() => _MafiaNoirButtonState();
}

class _MafiaNoirButtonState extends State<MafiaNoirButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = constraints.hasBoundedHeight
            ? constraints.maxHeight / 62
            : 1.0;
        return Semantics(
          button: true,
          enabled: enabled,
          label: widget.trailing == null
              ? widget.label
              : '${widget.label} ${widget.trailing}',
          excludeSemantics: true,
          onTap: widget.onTap,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onTapDown: enabled ? (_) => _setPressed(true) : null,
            onTapUp: enabled ? (_) => _setPressed(false) : null,
            onTapCancel: enabled ? () => _setPressed(false) : null,
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1,
              duration: const Duration(milliseconds: 90),
              child: AnimatedOpacity(
                opacity: enabled ? 1 : 0.45,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  padding: EdgeInsets.all(4 * unit),
                  decoration: BoxDecoration(
                    border: Border.all(color: widget.outlineColor, width: 2),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    color: widget.color,
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: 12 * unit),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.label,
                            maxLines: 1,
                            style: mafiaNoirDisplay(
                              widget.fontSize * unit,
                              color: widget.textColor,
                              letterSpacing:
                                  widget.fontSize * unit * widget.letterSpacing,
                            ),
                          ),
                          if (widget.trailing != null) ...[
                            SizedBox(width: 12 * unit),
                            Text(
                              widget.trailing!,
                              style: mafiaNoirDisplay(
                                widget.fontSize * unit,
                                color: MafiaColors.noirBrass,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 상단 모서리의 네모 아이콘 버튼(규칙·나가기)입니다.
class MafiaNoirIconButton extends StatelessWidget {
  const MafiaNoirIconButton({
    super.key,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.size = 44,
    this.color = MafiaColors.noirSlab,
  });

  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: MafiaColors.noirBrass, width: 2),
        ),
        child: child,
      ),
    ),
  );
}

/// 나가기 아이콘(문과 화살표)입니다.
class MafiaNoirExitGlyph extends StatelessWidget {
  const MafiaNoirExitGlyph({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _ExitPainter());
}

class _ExitPainter extends CustomPainter {
  const _ExitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final paint = Paint()
      ..color = MafiaColors.noirBrass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(
        Path()
          ..moveTo(14 * k, 4 * k)
          ..lineTo(19 * k, 4 * k)
          ..lineTo(19 * k, 20 * k)
          ..lineTo(14 * k, 20 * k),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(10 * k, 8 * k)
          ..lineTo(6 * k, 12 * k)
          ..lineTo(10 * k, 16 * k),
        paint,
      )
      ..drawLine(Offset(6 * k, 12 * k), Offset(16 * k, 12 * k), paint);
  }

  @override
  bool shouldRepaint(_ExitPainter oldDelegate) => false;
}

/// 위아래 가는 선 사이에 이름표와 값을 둔 줄입니다(예: `아침까지 0:42`).
class MafiaNoirRuledLabel extends StatelessWidget {
  const MafiaNoirRuledLabel({
    super.key,
    required this.label,
    required this.value,
    this.lineColor = const Color(0xFF2A2F2C),
    this.labelColor = MafiaColors.noirDust,
    this.valueColor = MafiaColors.noirBrass,
    this.valueSize = 26,
    this.valueWidget,
  });

  final String label;
  final String value;
  final Color lineColor;
  final Color labelColor;
  final Color valueColor;
  final double valueSize;

  /// 값 대신 넣을 위젯입니다(작은 얼굴 + 이름 등).
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    decoration: BoxDecoration(
      border: Border.symmetric(horizontal: BorderSide(color: lineColor)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: mafiaNoirBody(14, color: labelColor, letterSpacing: 2),
        ),
        const SizedBox(width: 10),
        valueWidget ??
            Text(value, style: mafiaNoirDisplay(valueSize, color: valueColor)),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// 밤 풍경
// ---------------------------------------------------------------------------
/// 보름달과 도시 실루엣입니다(밤 화면). [width] 기준으로 그립니다.
class MafiaNoirCityscape extends StatelessWidget {
  const MafiaNoirCityscape({
    super.key,
    required this.width,
    required this.height,
    this.moonSize,
  });

  final double width;
  final double height;
  final double? moonSize;

  // 시안 휴대폰(402 × 260)의 건물 폭·높이입니다. 창문은 (왼쪽, 위) 비율입니다.
  static const _buildings = <(double, double, bool)>[
    (40, 60, false),
    (34, 96, true),
    (60, 52, false),
    (40, 120, true),
    (70, 70, false),
    (36, 100, true),
    (54, 58, false),
  ];

  @override
  Widget build(BuildContext context) {
    // 건물 높이는 높이 기준, 폭은 화면 폭 기준으로 늘립니다. 넓은 태블릿에서
    // 건물이 달을 덮을 만큼 커지지 않고, 도시가 옆으로 넓게 깔립니다.
    final unit = math.min(width / 402, height / 260);
    final widthUnit = math.min(width / 402, unit * 2.4);
    final moon = moonSize ?? 180 * unit;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: (width - moon) / 2,
            top: 0,
            width: moon,
            height: moon,
            child: const _BreathingMoon(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < _buildings.length; index++)
                  _Building(
                    width: _buildings[index].$1 * widthUnit,
                    height: _buildings[index].$2 * unit,
                    light: index.isEven,
                    tall: _buildings[index].$3,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 아주 느리게 숨 쉬는 달입니다. 멈춘 화면처럼 보이지 않게 합니다.
class _BreathingMoon extends StatefulWidget {
  const _BreathingMoon();

  @override
  State<_BreathingMoon> createState() => _BreathingMoonState();
}

class _BreathingMoonState extends State<_BreathingMoon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _glow,
    builder: (context, _) => DecoratedBox(
      decoration: BoxDecoration(
        color: MafiaColors.noirPaper,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: MafiaColors.noirPaper.withValues(
              alpha: 0.10 + 0.08 * _glow.value,
            ),
            blurRadius: 40,
            spreadRadius: 6 + 6 * _glow.value,
          ),
        ],
      ),
    ),
  );
}

class _Building extends StatelessWidget {
  const _Building({
    required this.width,
    required this.height,
    required this.light,
    required this.tall,
  });

  final double width;
  final double height;
  final bool light;
  final bool tall;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    color: light ? const Color(0xFF1E2B29) : MafiaColors.noirTeal,
    child: tall
        ? Align(
            alignment: const Alignment(-0.2, -0.6),
            child: Container(
              width: width * 0.2,
              height: width * 0.26,
              color: MafiaColors.noirPaper,
            ),
          )
        : null,
  );
}

// ---------------------------------------------------------------------------
// 조사
// ---------------------------------------------------------------------------
/// 이름 끝 글자에 받침이 있으면 [withFinal], 없으면 [withoutFinal]을 붙입니다.
///
/// 예: `mafiaJosa('민준', '이', '가')` → `민준이`, `mafiaJosa('태오', '이', '가')`
/// → `태오가`. 한글이 아니면 [withoutFinal]을 씁니다.
String mafiaJosa(String name, String withFinal, String withoutFinal) {
  if (name.isEmpty) return name;
  final code = name.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return '$name$withoutFinal';
  final hasFinal = (code - 0xAC00) % 28 != 0;
  return '$name${hasFinal ? withFinal : withoutFinal}';
}

// ---------------------------------------------------------------------------
// 진행 막대
// ---------------------------------------------------------------------------
/// 다음 단계까지 남은 시간을 채워 가는 가는 막대입니다.
///
/// 로딩 표시가 아니라 **발표가 얼마나 남았는지**를 보여 줍니다. 정해진
/// 시간 동안 한 번만 차고 멈춥니다.
class MafiaNoirProgress extends StatelessWidget {
  const MafiaNoirProgress({
    super.key,
    required this.duration,
    this.label,
    this.color = MafiaColors.noirInk,
    this.labelColor = MafiaColors.noirUmber,
  });

  final Duration duration;
  final String? label;
  final Color color;
  final Color labelColor;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        builder: (context, value, _) => Container(
          height: 4,
          color: color.withValues(alpha: 0.2),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value,
            child: Container(height: 4, color: color),
          ),
        ),
      ),
      if (label != null) ...[
        const SizedBox(height: 8),
        Text(label!, style: mafiaNoirBody(13, color: labelColor)),
      ],
    ],
  );
}
