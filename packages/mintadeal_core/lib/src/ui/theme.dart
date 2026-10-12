import 'package:flutter/material.dart';

/// Colours taken from the Mintadeal logo: orange wordmark, red cart, charcoal frame.
class MintadealColors {
  const MintadealColors._();

  /// The logo's orange, for the wordmark, highlights and large text.
  static const orange = Color(0xFFE46C0A);

  /// A deeper shade of the logo orange for buttons: white text on it stays readable (4.9:1).
  static const deepOrange = Color(0xFFB9530A);

  /// The cart's red, for deal badges and discounts.
  static const red = Color(0xFFD51C29);

  static const charcoal = Color(0xFF3B3B3B);

  static const cream = Color(0xFFFFF4EB);
}

ThemeData mintadealTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: MintadealColors.orange,
    brightness: brightness,
    primary: dark ? const Color(0xFFFFB68A) : MintadealColors.deepOrange,
    onPrimary: dark ? const Color(0xFF4A1E00) : Colors.white,
    secondary: dark ? const Color(0xFFFFB3AE) : MintadealColors.red,
    onSecondary: dark ? const Color(0xFF5F0A10) : Colors.white,
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
    badgeTheme: BadgeThemeData(backgroundColor: scheme.secondary, textColor: scheme.onSecondary),
  );
}

/// The Mintadeal logo. On dark backgrounds it sits on a light tile so the charcoal cart stays visible.
class MintadealLogo extends StatelessWidget {
  const MintadealLogo({super.key, this.height = 48});

  final double height;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset('assets/logo.png', package: 'mintadeal_core', height: height,
        semanticLabel: 'Mintadeal');
    if (Theme.of(context).brightness == Brightness.light) return image;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: height * 0.2, vertical: height * 0.1),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(height * 0.2)),
      child: image,
    );
  }
}
