import 'package:flutter/material.dart';

const kBlue = Color(0xFF1D4ED8); // primary
const kOrange = Color(0xFFF59E0B); // secondary
const kGreen = Color(0xFF16A34A); // tertiary (success)
const kRed = Color(0xFFDC2626); // error

ThemeData lightTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: kBlue,
    brightness: Brightness.light,
  );
  final scheme = base.copyWith(
    secondary: kOrange,
    onSecondary: const Color(0xFF0B1220),
    tertiary: kGreen,
    onTertiary: const Color(0xFF0B1220),
    error: kRed,
    onError: Colors.white,
  );
  return ThemeData(useMaterial3: true, colorScheme: scheme);
}

ThemeData darkTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: kBlue,
    brightness: Brightness.dark,
  );
  final scheme = base.copyWith(
    secondary: const Color.fromARGB(255, 102, 131, 211),
    onSecondary: const Color(0xFF0B1220),
    tertiary: kGreen,
    onTertiary: const Color(0xFF0B1220),
    error: kRed,
    onError: Colors.white,
  );
  return ThemeData(useMaterial3: true, colorScheme: scheme);
}
