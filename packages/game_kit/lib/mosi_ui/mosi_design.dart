// [mosi_design.dart] 는 모시겜 앱 전체가 함께 쓰는 디자인 토큰과 기본 부품을 모은 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Design] : 색·글꼴·굵은 테두리·오프셋 그림자 부품을 정의함
//
// 플랫폼 화면(로그인, 선반, 상점)과 게임 안 공용 모달(설정, 규칙, 나가기)이 같은
// 모양을 써야 해서 플랫폼이 아니라 game_kit에 둡니다. 게임 package가 플랫폼을
// import하지 않아도 같은 디자인을 쓸 수 있습니다.

// ========================[ import ]==========================
import 'package:game_kit/mosi_ui/mosi_motion.dart';
import 'package:flutter/material.dart';

export 'package:game_kit/mosi_ui/mosi_motion.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/core/constants/room_character.dart';

// ============================================================

//=======================색 토큰==============================
/// 시안의 고정 색입니다. 화면마다 바뀌는 배경은 [MosiShelfTheme]이 정합니다.
abstract final class MosiColors {
  static const violet = Color(0xFF5A3FF0);
  static const violetDeep = Color(0xFF3A22C8);
  static const lilac = Color(0xFF8A78F8);
  static const court = Color(0xFF2F6FD0);
  static const navy = Color(0xFF0E0A3D);
  static const navyDeepest = Color(0xFF05031F);
  static const ink = Color(0xFF111111);
  static const ink2 = Color(0xFF26263A);
  static const white = Color(0xFFFFFFFF);
  static const lime = Color(0xFFA4D65E);
  static const sky = Color(0xFF3E8BE6);
  static const sun = Color(0xFFF2E14C);
  static const coral = Color(0xFFE8835A);
  static const red = Color(0xFFE0465A);
  static const green = Color(0xFF1F6E4A);
  static const cream = Color(0xFFF7F4EC);
  static const paper = Color(0xFFF1ECE0);

  /// 흰 바탕 위 보조 글자입니다(4.5:1 이상).
  static const muted = Color(0xFF55527A);
  static const mutedStrong = Color(0xFF4A4766);

  /// 흰 바탕 위 비활성 점선·빈 자리 글자입니다.
  static const navyFaint = Color(0x660E0A3D);
  static const navyDim = Color(0x9E0E0A3D);

  /// 모달 뒤를 덮는 남색 막입니다.
  static const scrim = Color(0x9E0E0A3D);
}

//=======================글꼴==============================
/// 번들 글꼴은 package 경로로, 중국어 대체 글꼴은 기기 글꼴 이름으로 지정합니다.
abstract final class MosiFonts {
  static const package = 'game_kit';
  static const body = 'IBMPlexSansKR';
  static const display = 'SpaceGrotesk';
  static const serif = 'PlayfairDisplay';

  // Fully-qualified bundled families keep native fallbacks out of the package
  // namespace. Flutter can then choose a system CJK font for the active script.
  static List<String> fallbacks(Locale? locale) {
    if (locale?.languageCode == 'zh') {
      final traditional =
          locale?.scriptCode == 'Hant' ||
          const ['TW', 'HK', 'MO'].contains(locale?.countryCode);
      return [
        if (traditional) ...[
          'PingFang TC',
          'Microsoft JhengHei',
          'Noto Sans CJK TC',
          'Noto Sans TC',
        ] else ...[
          'PingFang SC',
          'Microsoft YaHei',
          'Noto Sans CJK SC',
          'Noto Sans SC',
        ],
        'sans-serif',
        'packages/$package/$body',
      ];
    }
    return ['packages/$package/$body', 'sans-serif'];
  }

  static String bodyFamily(Locale? locale) => locale?.languageCode == 'zh'
      ? fallbacks(locale).first
      : 'packages/$package/$body';

  /// 본문 한글 글꼴입니다.
  static TextStyle sans({
    Locale? locale,
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: bodyFamily(locale),
    fontFamilyFallback: fallbacks(locale),
    locale: locale,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// 영문 라벨(`MOSIGAME`, `JOIN ROOM`)과 숫자 강조에 씁니다.
  static TextStyle grotesk({
    Locale? locale,
    double size = 12,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: 'packages/$package/$display',
    fontFamilyFallback: fallbacks(locale),
    locale: locale,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// 게임 상자 제목(`LIAR'S POKER`)에 씁니다.
  static TextStyle playfair({
    Locale? locale,
    double size = 18,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: 'packages/$package/$serif',
    fontFamilyFallback: fallbacks(locale),
    locale: locale,
    fontSize: size,
    fontWeight: FontWeight.w900,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

//=======================선반 배경 테마==============================
/// 선반·상세 화면 배경색 묶음입니다. 고른 게임마다 배경이 바뀝니다.
@immutable
class MosiShelfTheme {
  const MosiShelfTheme({
    required this.ground,
    required this.fg,
    required this.fgDim,
    required this.deep,
    required this.btnBg,
    required this.btnFg,
    required this.accA,
    required this.accB,
  });

  final Color ground;
  final Color fg;
  final Color fgDim;
  final Color deep;
  final Color btnBg;
  final Color btnFg;
  final Color accA;
  final Color accB;

  static const violet = MosiShelfTheme(
    ground: MosiColors.violet,
    fg: MosiColors.white,
    fgDim: Color(0x99FFFFFF),
    deep: MosiColors.navy,
    btnBg: MosiColors.lime,
    btnFg: MosiColors.navy,
    accA: MosiColors.lime,
    accB: MosiColors.sun,
  );

  static const court = MosiShelfTheme(
    ground: MosiColors.court,
    fg: MosiColors.white,
    fgDim: Color(0x99FFFFFF),
    deep: MosiColors.navy,
    btnBg: MosiColors.sun,
    btnFg: MosiColors.navy,
    accA: MosiColors.sun,
    accB: MosiColors.sun,
  );

  static const midnight = MosiShelfTheme(
    ground: MosiColors.navy,
    fg: MosiColors.white,
    fgDim: Color(0x80FFFFFF),
    deep: MosiColors.navyDeepest,
    btnBg: MosiColors.coral,
    btnFg: MosiColors.navy,
    accA: MosiColors.coral,
    accB: MosiColors.coral,
  );

  static const paper = MosiShelfTheme(
    ground: MosiColors.paper,
    fg: MosiColors.navy,
    fgDim: Color(0x800E0A3D),
    deep: MosiColors.navy,
    btnBg: MosiColors.violet,
    btnFg: MosiColors.white,
    accA: MosiColors.violet,
    accB: MosiColors.court,
  );

  static const lime = MosiShelfTheme(
    ground: MosiColors.lime,
    fg: MosiColors.navy,
    fgDim: Color(0x8C0E0A3D),
    deep: MosiColors.navy,
    btnBg: MosiColors.navy,
    btnFg: MosiColors.lime,
    accA: MosiColors.violetDeep,
    accB: MosiColors.navy,
  );

  static MosiShelfTheme lerp(MosiShelfTheme a, MosiShelfTheme b, double t) =>
      MosiShelfTheme(
        ground: Color.lerp(a.ground, b.ground, t)!,
        fg: Color.lerp(a.fg, b.fg, t)!,
        fgDim: Color.lerp(a.fgDim, b.fgDim, t)!,
        deep: Color.lerp(a.deep, b.deep, t)!,
        btnBg: Color.lerp(a.btnBg, b.btnBg, t)!,
        btnFg: Color.lerp(a.btnFg, b.btnFg, t)!,
        accA: Color.lerp(a.accA, b.accA, t)!,
        accB: Color.lerp(a.accB, b.accB, t)!,
      );
}

//=======================굵은 테두리 + 오프셋 그림자 상자==============================
/// 시안의 기본 면입니다: 굵은 검은 테두리와 번지지 않는 오프셋 그림자.
class MosiBox extends StatelessWidget {
  const MosiBox({
    super.key,
    required this.child,
    this.color = MosiColors.white,
    this.borderColor = MosiColors.ink,
    this.borderWidth = 3,
    this.radius = 10,
    this.shadowOffset = 10,
    this.shadowColor = MosiColors.navy,
    this.padding,
    this.width,
    this.height,
    this.clip = false,
  });

  final Widget child;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double radius;
  final double shadowOffset;
  final Color shadowColor;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: borderWidth > 0
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
        boxShadow: shadowOffset > 0
            ? [
                BoxShadow(
                  color: shadowColor,
                  offset: Offset(shadowOffset, shadowOffset),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

//=======================버튼==============================
enum MosiButtonVariant { filled, outline, ghost }

/// 누르면 그림자 쪽으로 눌려 들어가는 시안 버튼입니다.
class MosiButton extends StatefulWidget {
  const MosiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = MosiButtonVariant.filled,
    this.background = MosiColors.lime,
    this.foreground = MosiColors.navy,
    this.borderColor = MosiColors.ink,
    this.shadowColor = MosiColors.navy,
    this.height = 52,
    this.fontSize = 16,
    this.radius = 8,
    this.shadowOffset = 4,
    this.borderWidth,
    this.expand = false,
    this.loading = false,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
    this.semanticLabel,
    this.loadingDots = false,
    this.success = false,
    this.successLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final MosiButtonVariant variant;
  final Color background;
  final Color foreground;
  final Color borderColor;
  final Color shadowColor;
  final double height;
  final double fontSize;
  final double radius;
  final double shadowOffset;
  final double? borderWidth;
  final bool expand;
  final bool loading;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  /// 로딩 중 원형 표시 대신 버튼 색을 유지한 채 점 세 개를 튀깁니다.
  ///
  /// 로비 시안: 누른 버튼만 진행 중으로 바뀌고 회색으로 꺼지지 않습니다.
  final bool loadingDots;

  /// 방금 끝난 일을 체크 표시로 알립니다(입장 성공·저장 완료). 누를 수 없습니다.
  final bool success;

  /// [success]일 때 체크 옆에 붙는 문구입니다. 없으면 체크만 그립니다.
  final String? successLabel;

  @override
  State<MosiButton> createState() => _MosiButtonState();
}

class _MosiButtonState extends State<MosiButton> {
  bool _pressed = false;

  bool get _enabled =>
      widget.onPressed != null && !widget.loading && !widget.success;

  /// 점 로딩·성공 상태는 버튼 색을 그대로 둡니다(꺼진 것처럼 보이지 않게).
  bool get _keepsColor =>
      (widget.loading && widget.loadingDots) || widget.success;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.variant == MosiButtonVariant.filled;
    final ghost = widget.variant == MosiButtonVariant.ghost;
    final lit = _enabled || _keepsColor;
    final shadow = filled && lit ? widget.shadowOffset : 0.0;
    final shift = _pressed ? shadow : 0.0;
    final background = !lit && filled
        ? const Color(0xFFE4E2EA)
        : filled
        ? widget.background
        : Colors.transparent;
    final foreground = lit
        ? widget.foreground
        : widget.foreground.withValues(alpha: 0.55);
    final borderWidth = widget.borderWidth ?? (filled ? 3.0 : 2.0);

    final content = widget.success
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MosiDrawnCheck(color: foreground, size: 24),
              if (widget.successLabel != null) ...[
                const SizedBox(width: 6),
                Text(
                  widget.successLabel!,
                  maxLines: 1,
                  style: MosiFonts.sans(
                    locale: Localizations.maybeLocaleOf(context),
                    size: widget.fontSize,
                    weight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ],
            ],
          )
        : widget.loading && widget.loadingDots
        ? MosiLoadingDots(color: foreground)
        : widget.loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: foreground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.leading != null) ...[
                IconTheme(
                  data: IconThemeData(color: foreground, size: 20),
                  child: widget.leading!,
                ),
                const SizedBox(width: 8),
              ],
              // 버튼 폭이 좁아도(작은 휴대폰·긴 번역) 글자를 자르지 않고 줄입니다.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: widget.fontSize,
                      weight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                IconTheme(
                  data: IconThemeData(color: foreground, size: 20),
                  child: widget.trailing!,
                ),
              ],
            ],
          );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      onTap: _enabled ? widget.onPressed : null,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTap: _enabled
              ? () {
                  HapticFeedback.selectionClick();
                  widget.onPressed!();
                }
              : null,
          child: Padding(
            // 로딩/비활성 상태에서도 버튼의 전체 크기와 위치는 유지합니다.
            padding: EdgeInsets.only(
              right: filled ? widget.shadowOffset : 0,
              bottom: filled ? widget.shadowOffset : 0,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 70),
              transform: Matrix4.translationValues(shift, shift, 0),
              height: widget.height,
              width: widget.expand ? double.infinity : null,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(widget.radius),
                border: ghost
                    ? null
                    : Border.all(
                        color: filled ? widget.borderColor : foreground,
                        width: borderWidth,
                      ),
                boxShadow: shadow > 0 && !_pressed
                    ? [
                        BoxShadow(
                          color: widget.shadowColor,
                          offset: Offset(shadow, shadow),
                        ),
                      ]
                    : null,
              ),
              // Container에 alignment를 주면 가로로 가득 늘어나므로 Center의
              // widthFactor로 내용 폭만 차지하게 합니다.
              child: Center(
                widthFactor: widget.expand ? null : 1,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: KeyedSubtree(
                    key: ValueKey((widget.loading, widget.success)),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 테두리만 있는 둥근 아이콘 버튼입니다(닫기, 뒤로).
class MosiIconButton extends StatelessWidget {
  const MosiIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color = MosiColors.navy,
    this.background = Colors.transparent,
    this.size = 44,
    this.iconSize = 20,
    this.borderWidth = 2,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color color;
  final Color background;
  final double size;
  final double iconSize;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: CircleBorder(
          side: BorderSide(color: color, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: iconSize, color: color),
          ),
        ),
      ),
    );
  }
}

//=======================알약(칩)==============================
/// 폭은 부모에 맞춰 줄바꿈하고, 높이가 모자라면 스크롤하거나 자르지 않고
/// 내용 전체를 조금 줄여 한눈에 보이게 합니다.
///
/// 기기 글자 크기를 키웠거나 문구가 긴 언어에서도 고정 높이 칸(상점 계산대,
/// 로비 선반 아래 소개)의 글자와 버튼이 잘리지 않게 할 때 씁니다.
class MosiFitHeight extends StatelessWidget {
  const MosiFitHeight({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: SizedBox(width: constraints.maxWidth, child: child),
    ),
  );
}

class MosiPill extends StatelessWidget {
  const MosiPill({
    super.key,
    required this.label,
    this.color = MosiColors.navy,
    this.background,
    this.borderColor,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    this.leading,
  });

  final String label;
  final Color color;
  final Color? background;
  final Color? borderColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor ?? color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label,
            style: MosiFonts.sans(
              locale: Localizations.maybeLocaleOf(context),
              size: fontSize,
              weight: FontWeight.w700,
              color: color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

//=======================캐릭터 얼굴==============================
/// 포커페이스 캐릭터 얼굴입니다. 그림 자체에 원형 배경이 들어 있습니다.
class MosiFace extends StatelessWidget {
  const MosiFace({
    super.key,
    required this.characterId,
    this.size = 40,
    this.ring = false,
  });

  final String? characterId;
  final double size;

  /// 검은 테두리를 한 번 더 두릅니다(목록·카드 안).
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final character = roomCharacterById(characterId);
    final image = Image.asset(
      character.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: character.label,
      gaplessPlayback: true,
    );
    if (!ring) return image;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: MosiColors.ink, width: 2.5),
      ),
      child: ClipOval(child: image),
    );
  }
}

//=======================로고==============================
/// 라임 사각형 위 계단 모양 로고와 `모시겜 / MOSIGAME` 글자입니다.
class MosiLogo extends StatelessWidget {
  const MosiLogo({
    super.key,
    this.color = MosiColors.white,
    this.markSize = 34,
    this.titleSize = 22,
    this.showText = true,
  });

  final Color color;
  final double markSize;
  final double titleSize;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: markSize,
      height: markSize,
      child: const CustomPaint(painter: _MosiLogoPainter()),
    );
    if (!showText) return mark;
    return Semantics(
      label: '모시겜',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          SizedBox(width: markSize * 0.3),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '모시겜',
                style: MosiFonts.sans(
                  locale: Localizations.maybeLocaleOf(context),
                  size: titleSize,
                  weight: FontWeight.w700,
                  color: color,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: titleSize * 0.14),
              Text(
                'MOSIGAME',
                style: MosiFonts.grotesk(
                  locale: Localizations.maybeLocaleOf(context),
                  size: titleSize * 0.46,
                  color: color,
                  letterSpacing: titleSize * 0.11,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MosiLogoPainter extends CustomPainter {
  const _MosiLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 34;
    RRect r(double x, double y, double w, double h, double rad) =>
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * s, y * s, w * s, h * s),
          Radius.circular(rad * s),
        );
    final navy = Paint()..color = MosiColors.navy;
    canvas.drawRRect(r(5, 5, 26, 26, 5), navy);
    canvas.drawRRect(r(2, 2, 26, 26, 5), Paint()..color = MosiColors.lime);
    canvas.drawRRect(r(7.5, 6.5, 3.5, 6, 1.2), navy);
    canvas.drawRRect(r(11.5, 12.8, 7, 5, 1.2), navy);
    canvas.drawRRect(r(19, 17.5, 3.5, 6, 1.2), navy);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//=======================모달 프레임==============================
/// 시안 모달의 흰 판입니다: 3px 검은 테두리 + 12px 남색 오프셋 그림자.
class MosiDialogFrame extends StatelessWidget {
  const MosiDialogFrame({
    super.key,
    required this.child,
    this.width = 460,
    this.padding = const EdgeInsets.all(28),
    this.color = MosiColors.white,
    this.radius = 12,
    this.shadowOffset = 12,
    this.semanticLabel,
  });

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final double shadowOffset;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: semanticLabel != null,
      label: semanticLabel,
      explicitChildNodes: true,
      child: Padding(
        padding: EdgeInsets.only(right: shadowOffset, bottom: shadowOffset),
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle(
            style: MosiFonts.sans(
              locale: Localizations.maybeLocaleOf(context),
              color: MosiColors.navy,
            ),
            child: MosiBox(
              width: width,
              padding: padding,
              color: color,
              radius: radius,
              shadowOffset: shadowOffset,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 시안 모달 머리줄: 제목 + 원형 닫기 버튼.
class MosiDialogHeader extends StatelessWidget {
  const MosiDialogHeader({
    super.key,
    required this.title,
    this.onClose,
    this.trailing,
    this.titleSize = 22,
  });

  final String title;
  final VoidCallback? onClose;
  final Widget? trailing;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: MosiFonts.sans(
              locale: Localizations.maybeLocaleOf(context),
              size: titleSize,
              weight: FontWeight.w700,
              color: MosiColors.navy,
              letterSpacing: -0.5,
            ),
          ),
        ),
        if (trailing != null) ...[trailing!, const SizedBox(width: 12)],
        if (onClose != null)
          MosiIconButton(
            icon: Icons.close_rounded,
            tooltip: '닫기',
            onPressed: onClose,
          ),
      ],
    );
  }
}

/// 시안 모달을 띄웁니다. 뒤는 남색 막으로 덮습니다.
Future<T?> showMosiDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  Rect? origin,
}) {
  // 누른 버튼 자리([origin])가 있으면 그 자리에서 펼쳐지고 같은 곳으로
  // 접힙니다(로비 시안 8번). 없으면 화면 가운데에서 살짝 커집니다.
  final screen = MediaQuery.sizeOf(context);
  final alignment = origin == null || screen.isEmpty
      ? Alignment.center
      : Alignment(
          (origin.center.dx / screen.width * 2 - 1).clamp(-1.0, 1.0),
          (origin.center.dy / screen.height * 2 - 1).clamp(-1.0, 1.0),
        );
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: MosiColors.scrim,
    useRootNavigator: useRootNavigator,
    transitionDuration: Duration(milliseconds: origin == null ? 220 : 320),
    pageBuilder: (context, _, _) => SafeArea(
      child: Center(child: Builder(builder: builder)),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: origin == null ? Curves.easeOutBack : Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.6),
        ),
        child: ScaleTransition(
          alignment: alignment,
          scale: Tween<double>(
            begin: origin == null ? 0.92 : 0.2,
            end: 1,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

//=======================입력칸==============================
/// 시안 입력칸 모양입니다: 2px 남색 테두리, 흰 바탕, 높이 48.
InputDecoration mosiInputDecoration({
  String? hintText,
  Widget? suffix,
  String? errorText,
  bool dense = false,
}) {
  OutlineInputBorder border(Color color, [double width = 2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hintText,
    hintStyle: MosiFonts.sans(size: 16, color: MosiColors.navyDim),
    filled: true,
    fillColor: MosiColors.white,
    isDense: dense,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    suffixIcon: suffix,
    errorText: errorText,
    errorStyle: MosiFonts.sans(
      size: 12,
      weight: FontWeight.w600,
      color: MosiColors.red,
    ),
    border: border(MosiColors.navy),
    enabledBorder: border(MosiColors.navy),
    focusedBorder: border(MosiColors.violet, 3),
    errorBorder: border(MosiColors.red),
    focusedErrorBorder: border(MosiColors.red, 3),
    disabledBorder: border(MosiColors.navyFaint),
  );
}

//=======================점선 테두리==============================
/// 빈 자리·들어오는 중 표시에 쓰는 점선 둥근 테두리입니다.
class MosiDashedBorder extends StatelessWidget {
  const MosiDashedBorder({
    super.key,
    required this.child,
    this.color = MosiColors.navy,
    this.radius = 23,
    this.strokeWidth = 2,
    this.dash = 6,
    this.gap = 4,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}

/// 가로 점선 구분선입니다.
class MosiDashedDivider extends StatelessWidget {
  const MosiDashedDivider({
    super.key,
    this.color = MosiColors.navy,
    this.thickness = 2,
  });

  final Color color;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(color: color, thickness: thickness),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color, required this.thickness});

  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + 6).clamp(0, size.width), y),
        paint,
      );
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.thickness != thickness;
}
