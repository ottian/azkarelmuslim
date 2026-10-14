import 'package:flutter/material.dart';

/// ألوان الراديو القديم: خشب جوز، نحاس، وإضاءة كهرمان دافية
class Retro {
  static const night = Color(0xFF110E0B);
  static const surface = Color(0xFF181410);
  static const panel = Color(0xFF221C16);
  static const panelHigh = Color(0xFF2C241C);
  static const line = Color(0xFF3D3328);
  static const cream = Color(0xFFF4E8D2);
  static const muted = Color(0xFFB4A48A);
  static const amber = Color(0xFFF2B451);
  static const amberDeep = Color(0xFFD9822B);
  static const brass = Color(0xFFC9A56A);
  static const brassDark = Color(0xFF7A5A2C);
  static const walnut = Color(0xFF5B3A22);
  static const walnutDark = Color(0xFF2A1A0E);
  static const green = Color(0xFF5DBB93);
  static const red = Color(0xFFE5533D);

  static const amberGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE0A3), amber, amberDeep],
  );
}

/// الخطوط متضمنة في التطبيق، علشان نسخة الويب متجيبش خطوط من بره
ThemeData buildTheme() {
  final scheme = const ColorScheme.dark(
    primary: Retro.amber,
    onPrimary: Color(0xFF2A1A05),
    primaryContainer: Color(0xFF4A3216),
    onPrimaryContainer: Retro.cream,
    secondary: Retro.green,
    onSecondary: Color(0xFF06261A),
    secondaryContainer: Color(0xFF1E3A2E),
    onSecondaryContainer: Retro.cream,
    tertiary: Retro.brass,
    surface: Retro.surface,
    onSurface: Retro.cream,
    onSurfaceVariant: Retro.muted,
    surfaceContainerLowest: Retro.night,
    surfaceContainerLow: Retro.surface,
    surfaceContainer: Retro.panel,
    surfaceContainerHigh: Retro.panelHigh,
    surfaceContainerHighest: Color(0xFF362C22),
    outline: Retro.line,
    outlineVariant: Color(0xFF2E261E),
    error: Retro.red,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: Brightness.dark,
  );
  final text = base.textTheme.apply(
    fontFamily: 'NotoSansArabic',
    fontFamilyFallback: const ['NotoSans'],
    bodyColor: Retro.cream,
    displayColor: Retro.cream,
  );
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c),
  );
  return base.copyWith(
    scaffoldBackgroundColor: Retro.night,
    textTheme: text,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Retro.night,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: Retro.cream,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Retro.surface,
      indicatorColor: Retro.amber.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall?.copyWith(
          color: s.contains(WidgetState.selected) ? Retro.amber : Retro.muted,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Retro.amber : Retro.muted,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Retro.panel,
      isDense: true,
      prefixIconColor: Retro.muted,
      hintStyle: const TextStyle(color: Retro.muted),
      border: border(Retro.line),
      enabledBorder: border(Retro.line),
      focusedBorder: border(Retro.amber),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Retro.panel,
      selectedColor: Retro.amber,
      side: const BorderSide(color: Retro.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: text.labelLarge?.copyWith(color: Retro.cream),
      secondaryLabelStyle: text.labelLarge?.copyWith(
        color: const Color(0xFF2A1A05),
        fontWeight: FontWeight.bold,
      ),
      checkmarkColor: const Color(0xFF2A1A05),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Retro.amber,
        foregroundColor: const Color(0xFF2A1A05),
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Retro.muted,
      selectedColor: Retro.amber,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Retro.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Retro.line,
    ),
    dividerTheme: const DividerThemeData(color: Retro.line),
    sliderTheme: SliderThemeData(
      activeTrackColor: Retro.amber,
      inactiveTrackColor: Retro.line,
      thumbColor: Retro.cream,
      overlayColor: Retro.amber.withValues(alpha: 0.15),
      trackHeight: 3,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Retro.amber,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
