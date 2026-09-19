import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
  );
}
