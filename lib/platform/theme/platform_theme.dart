import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

//=======================플랫폼 색상 토큰==============================
@immutable
class PlatformColors extends ThemeExtension<PlatformColors> {
  const PlatformColors({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.primary,
    required this.primarySoft,
    required this.text,
    required this.textMuted,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color primary;
  final Color primarySoft;
  final Color text;
  final Color textMuted;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  // 시안(모시겜 선반) 색입니다. 흰 면 + 남색 글자 + 바이올렛 강조.
  static const light = PlatformColors(
    canvas: Color(0xFFF7F4EC),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1ECE0),
    border: Color(0x400E0A3D),
    primary: Color(0xFF5A3FF0),
    primarySoft: Color(0xFFEEEAFE),
    text: Color(0xFF0E0A3D),
    textMuted: Color(0xFF55527A),
    success: Color(0xFF2F6B1E),
    successSoft: Color(0xFFE6F3D3),
    warning: Color(0xFF7A6200),
    warningSoft: Color(0xFFFBF5C9),
    danger: Color(0xFFA82E40),
    dangerSoft: Color(0xFFFCE4E7),
  );

  static const dark = PlatformColors(
    canvas: Color(0xFF151514),
    surface: Color(0xFF211F1D),
    surfaceMuted: Color(0xFF2B2926),
    border: Color(0xFF403D38),
    primary: Color(0xFF8C7FFF),
    primarySoft: Color(0xFF302B52),
    text: Color(0xFFF4F1EB),
    textMuted: Color(0xFFB6B0A7),
    success: Color(0xFF70D2A5),
    successSoft: Color(0xFF183C2D),
    warning: Color(0xFFF0C45A),
    warningSoft: Color(0xFF493B19),
    danger: Color(0xFFFF8178),
    dangerSoft: Color(0xFF4B2523),
  );

  @override
  PlatformColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? primary,
    Color? primarySoft,
    Color? text,
    Color? textMuted,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
  }) => PlatformColors(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    border: border ?? this.border,
    primary: primary ?? this.primary,
    primarySoft: primarySoft ?? this.primarySoft,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    success: success ?? this.success,
    successSoft: successSoft ?? this.successSoft,
    warning: warning ?? this.warning,
    warningSoft: warningSoft ?? this.warningSoft,
    danger: danger ?? this.danger,
    dangerSoft: dangerSoft ?? this.dangerSoft,
  );

  @override
  PlatformColors lerp(covariant PlatformColors? other, double t) {
    if (other == null) return this;
    return PlatformColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
    );
  }
}

extension PlatformThemeContext on BuildContext {
  PlatformColors get platformColors =>
      Theme.of(this).extension<PlatformColors>() ?? PlatformColors.light;
}

//=======================플랫폼 ThemeData==============================
class PlatformTheme {
  const PlatformTheme._();

  static ThemeData light({Locale? locale}) =>
      _build(Brightness.light, PlatformColors.light, locale);
  static ThemeData dark({Locale? locale}) =>
      _build(Brightness.dark, PlatformColors.dark, locale);

  static ThemeData _build(
    Brightness brightness,
    PlatformColors colors,
    Locale? locale,
  ) {
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: brightness,
      primary: colors.primary,
      surface: colors.surface,
      error: colors.danger,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // 시안 본문 글꼴입니다. game_kit에 번들되어 package 경로로 지정합니다.
      fontFamily: MosiFonts.bodyFamily(locale),
      fontFamilyFallback: MosiFonts.fallbacks(locale),
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      extensions: <ThemeExtension<dynamic>>[colors],
      textTheme: _scaledTextTheme(brightness, colors, locale),
      dividerColor: colors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.text, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.text, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.primary, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.danger, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.danger, width: 3),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MosiColors.navy,
        contentTextStyle: MosiFonts.sans(
          size: 14,
          weight: FontWeight.w600,
          color: MosiColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: MosiColors.ink, width: 2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: MosiColors.ink, width: 3),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: colors.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: MosiFonts.sans(
          color: colors.text,
          size: 18,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  // Flutter 기본 TextTheme에는 fontSize가 null인 스타일이 포함될 수 있습니다.
  // TextTheme.apply(fontSizeFactor: ...)는 해당 스타일에서 assertion을 일으키므로,
  // 실제 크기가 있는 스타일만 개별적으로 확대합니다.
  static TextTheme _scaledTextTheme(
    Brightness brightness,
    PlatformColors colors,
    Locale? locale,
  ) {
    final base = ThemeData(
      brightness: brightness,
      fontFamily: MosiFonts.bodyFamily(locale),
      fontFamilyFallback: MosiFonts.fallbacks(locale),
    ).textTheme.apply(bodyColor: colors.text, displayColor: colors.text);

    TextStyle? scale(TextStyle? style) {
      final fontSize = style?.fontSize;
      return fontSize == null
          ? style
          : style!.copyWith(fontSize: fontSize * 1.08);
    }

    return base.copyWith(
      displayLarge: scale(base.displayLarge),
      displayMedium: scale(base.displayMedium),
      displaySmall: scale(base.displaySmall),
      headlineLarge: scale(base.headlineLarge),
      headlineMedium: scale(base.headlineMedium),
      headlineSmall: scale(base.headlineSmall),
      titleLarge: scale(base.titleLarge),
      titleMedium: scale(base.titleMedium),
      titleSmall: scale(base.titleSmall),
      bodyLarge: scale(base.bodyLarge),
      bodyMedium: scale(base.bodyMedium),
      bodySmall: scale(base.bodySmall),
      labelLarge: scale(base.labelLarge),
      labelMedium: scale(base.labelMedium),
      labelSmall: scale(base.labelSmall),
    );
  }
}
