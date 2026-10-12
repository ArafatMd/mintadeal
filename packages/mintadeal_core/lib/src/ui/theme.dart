import 'package:flutter/material.dart';

/// Mintadeal brand colours: deep teal with the logo's orange as accent.
class MintadealColors {
  const MintadealColors._();

  static const teal = Color(0xFF1B7A5E);
  static const deepTeal = Color(0xFF123C38);
  static const orange = Color(0xFFE07020);
  static const mint = Color(0xFFE6F3EE);
}

ThemeData mintadealTheme({Brightness brightness = Brightness.light}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: MintadealColors.teal,
    brightness: brightness,
    secondary: MintadealColors.orange,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
  );
}
