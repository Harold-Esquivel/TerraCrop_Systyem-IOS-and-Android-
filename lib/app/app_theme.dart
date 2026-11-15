import 'package:flutter/material.dart';

const ink = Color(0xFF15364B);
const muted = Color(0xFF5C7182);
const blue = Color(0xFF1769D2);
const paleBlue = Color(0xFFEAF3FF);
const green = Color(0xFF16815E);
const canvas = Color(0xFFF5FAF8);
const border = Color(0xFFDCE8E5);

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.ink,
    required this.muted,
    required this.canvas,
    required this.surface,
    required this.softBlue,
    required this.softGreen,
    required this.border,
    required this.blue,
    required this.green,
    required this.warningSurface,
  });
  final Color ink,
      muted,
      canvas,
      surface,
      softBlue,
      softGreen,
      border,
      blue,
      green,
      warningSurface;
  static const light = AppColors(
    ink: Color(0xFF15364B),
    muted: Color(0xFF5C7182),
    canvas: Color(0xFFF5FAF8),
    surface: Colors.white,
    softBlue: Color(0xFFEAF3FF),
    softGreen: Color(0xFFE7F6EE),
    border: Color(0xFFDCE8E5),
    blue: Color(0xFF1769D2),
    green: Color(0xFF16815E),
    warningSurface: Color(0xFFFFF2E6),
  );
  static const dark = AppColors(
    ink: Color(0xFFEAF4FA),
    muted: Color(0xFFABBDCB),
    canvas: Color(0xFF0B1722),
    surface: Color(0xFF142737),
    softBlue: Color(0xFF16334F),
    softGreen: Color(0xFF153B32),
    border: Color(0xFF2B4353),
    blue: Color(0xFF83BCFF),
    green: Color(0xFF6DDBAD),
    warningSurface: Color(0xFF463022),
  );
  @override
  AppColors copyWith({
    Color? ink,
    Color? muted,
    Color? canvas,
    Color? surface,
    Color? softBlue,
    Color? softGreen,
    Color? border,
    Color? blue,
    Color? green,
    Color? warningSurface,
  }) => AppColors(
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    softBlue: softBlue ?? this.softBlue,
    softGreen: softGreen ?? this.softGreen,
    border: border ?? this.border,
    blue: blue ?? this.blue,
    green: green ?? this.green,
    warningSurface: warningSurface ?? this.warningSurface,
  );
  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      softBlue: mix(softBlue, other.softBlue),
      softGreen: mix(softGreen, other.softGreen),
      border: mix(border, other.border),
      blue: mix(blue, other.blue),
      green: mix(green, other.green),
      warningSurface: mix(warningSurface, other.warningSurface),
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);
}

final appTheme = _theme(Brightness.light);
final appDarkTheme = _theme(Brightness.dark);

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(seedColor: blue, brightness: brightness)
      .copyWith(
        primary: colors.blue,
        onPrimary: dark ? const Color(0xFF09213C) : Colors.white,
        secondary: colors.green,
        onSecondary: dark ? const Color(0xFF0A2B20) : Colors.white,
        surface: colors.surface,
        onSurface: colors.ink,
        onSurfaceVariant: colors.muted,
        outline: colors.border,
        outlineVariant: colors.border,
        primaryContainer: colors.softBlue,
        secondaryContainer: colors.softGreen,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: [colors],
    scaffoldBackgroundColor: colors.canvas,
    fontFamily: 'Roboto',
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 29,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
        color: colors.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w800,
        letterSpacing: -.7,
        color: colors.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: colors.ink,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: colors.ink),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.canvas,
      foregroundColor: colors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dividerColor: colors.border,
    iconTheme: IconThemeData(color: colors.blue),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.blue, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.blue,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: colors.softGreen,
      backgroundColor: colors.surface,
      side: BorderSide(color: colors.border),
      labelStyle: TextStyle(color: colors.ink),
      checkmarkColor: colors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
