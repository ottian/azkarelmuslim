import 'package:flutter/material.dart';

const seedGreen = Color(0xFF1B5E4A);

/// الخطوط متضمنة في التطبيق، علشان نسخة الويب متجيبش خطوط من بره
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: seedGreen, brightness: brightness);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'NotoSansArabic',
      fontFamilyFallback: const ['NotoSans'],
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: scheme.surface,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontFamily: 'NotoSansArabic',
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
      ),
    ),
  );
}
