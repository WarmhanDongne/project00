import 'package:flutter/material.dart';

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

  static const light = PlatformColors(
    canvas: Color(0xFFF5F4F1),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F0ED),
    border: Color(0xFFE1DFDA),
    primary: Color(0xFF5748C8),
    primarySoft: Color(0xFFF0EEFF),
    text: Color(0xFF252423),
    textMuted: Color(0xFF77736D),
    success: Color(0xFF23855B),
    successSoft: Color(0xFFE3F4EB),
    warning: Color(0xFFB38310),
    warningSoft: Color(0xFFFFF3D2),
    danger: Color(0xFFD54D45),
    dangerSoft: Color(0xFFFFECEA),
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

  static ThemeData light() => _build(Brightness.light, PlatformColors.light);
  static ThemeData dark() => _build(Brightness.dark, PlatformColors.dark);

  static ThemeData _build(Brightness brightness, PlatformColors colors) {
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
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      extensions: <ThemeExtension<dynamic>>[colors],
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: colors.text,
        displayColor: colors.text,
        fontSizeFactor: 1.08,
      ),
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
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.primary),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: colors.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.text,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
