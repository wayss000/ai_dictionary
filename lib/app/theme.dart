import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5))
      .copyWith(
        primary: const Color(0xFF4539BA),
        surface: const Color(0xFFFFFEFC),
        surfaceContainerLow: const Color(0xFFF8F6F2),
        surfaceContainerHighest: const Color(0xFFEEEAE5),
        onSurface: const Color(0xFF252336),
        onSurfaceVariant: const Color(0xFF625F70),
        outlineVariant: const Color(0xFFE0DBD6),
      );
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  );
  return ThemeData(
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surfaceContainerLow,
    useMaterial3: true,
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: controlShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: controlShape,
        side: BorderSide(color: colors.outlineVariant),
        foregroundColor: colors.onSurface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: InputBorder.none,
      hintStyle: TextStyle(color: colors.onSurfaceVariant),
    ),
  );
}
